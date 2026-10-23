"""Run code from the original kaiser.exe in a 16-bit x86 emulator (Unicorn).

The NE segments are placed in a real-mode address space (one paragraph-aligned
block per segment), relocations are applied the way the Windows loader would
(segment selectors become paragraph numbers), and Windows API imports point to
a stub segment that stops the emulation if it is ever called.

This is used for differential testing: the Free Pascal port must give the same
results as the original machine code.

    emu = KaiserEmu()
    ax, bx, dx = emu.call_regs('10c8:0e95', ax=..., bx=..., dx=..., cx=..., si=..., di=...)
    result = emu.call_far('1068:13a8', [('ptr', addr_of_player)])
"""
import os
import struct
import sys

from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INTR
from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX,
                               UC_X86_REG_DX, UC_X86_REG_SI, UC_X86_REG_DI,
                               UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_CS,
                               UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS,
                               UC_X86_REG_IP, UC_X86_REG_FLAGS)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
from ne import NEFile  # noqa: E402

EXE = os.path.join(ROOT, 'Kaiser', 'kaiser.exe')
MEM_SIZE = 0x100000           # 1 MB real-mode address space
FIRST_PARA = 0x1000           # segments start at linear 0x10000
STACK_SIZE = 0x8000
REGS = {'ax': UC_X86_REG_AX, 'bx': UC_X86_REG_BX, 'cx': UC_X86_REG_CX,
        'dx': UC_X86_REG_DX, 'si': UC_X86_REG_SI, 'di': UC_X86_REG_DI,
        'bp': UC_X86_REG_BP, 'es': UC_X86_REG_ES}


# segments with game logic (the others hold UI code, which tests stub out,
# and the runtime); their ENTER frames get zeroed locals
LOGIC_SEGMENTS = (2, 3, 4, 6, 7, 8, 9, 13, 14)


def ghidra_seg(addr):
    """'1068:13a8' -> (segment index 14, offset 0x13a8)."""
    s, o = addr.split(':')
    return (int(s, 16) - 0x1000) // 8 + 1, int(o, 16)


class EmuError(Exception):
    pass


class KaiserEmu:
    def __init__(self, exe=EXE):
        self.ne = NEFile(exe)
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, MEM_SIZE)
        self.para = {}
        para = FIRST_PARA
        for seg in self.ne.segments:
            size = max(seg.min_alloc or 0x10000, seg.length)
            if seg.index == self.ne.autodata_seg:
                size = 0x10000           # full 64 KB DS (heap/stack area)
            self.para[seg.index] = para
            para += (size + 15) // 16
        self.stub_para = para            # imported API calls land here
        para += 0x100
        self.stack_para = para
        para += STACK_SIZE // 16
        self.scratch_para = para         # free memory for test data
        self.scratch_size = (MEM_SIZE // 16 - para) * 16
        if self.scratch_size < 0x10000:
            raise EmuError('not enough emulated memory')
        self.ds_para = self.para[self.ne.autodata_seg]
        self._stub_keys = {}
        self._stub_handlers = {}         # stub offset -> handler (redirected functions)
        self._next_stub = 0x0800          # slots after the import stubs (segment is 4 KB)
        self.guard_ranges = []           # (lin_begin, lin_end, name): executing there stops
        self.guard_allow = []            # (lin_begin, lin_end): allowed inside guard ranges
        self._load_segments()
        self._apply_relocations()
        # string table resources (id -> raw cp1252 bytes) for LoadString
        self.strings = {}
        for r in self.ne.resources:
            if r.type_id == 6:
                p = 0
                for i in range(16):
                    if p >= len(r.data):
                        break
                    n = r.data[p]
                    if n:
                        self.strings[(r.res_id - 1) * 16 + i] = r.data[p + 1:p + 1 + n]
                    p += 1 + n
        # Windows API functions the emulator implements: (module, ordinal)
        self.api = {('USER', 176): self._load_string,
                    ('USER', 125): self._invalidate_rect,
                    ('USER', 10): self._set_timer,
                    ('USER', 12): self._kill_timer,
                    ('USER', 22): self._set_focus,
                    ('USER', 66): self._get_dc,
                    ('USER', 68): self._release_dc,
                    ('KERNEL', 60): self._find_resource,
                    ('KERNEL', 61): self._load_resource,
                    ('KERNEL', 62): self._lock_resource,
                    ('KERNEL', 19): self._global_unlock}
        self.pristine_ds = bytes(self.read(self.ds_para, 0, 0x10000))
        self.api_fallback = False        # unknown APIs: 0 (dialog tests)
        self.api_calls = []
        # far return target: a HLT instruction in the stub segment
        self.return_ip = 0xFF00
        self.uc.mem_write(self.lin(self.stub_para, self.return_ip), b'\xf4')
        self._zero_locals()

    def _zero_locals(self):
        """Every ENTER n,0 frame in the logic segments starts with zeroed locals.

        Locals the original leaves uninitialised (e.g. unit records that
        RecruitUnit copies into the army) would otherwise carry whatever
        earlier calls left on the stack; the port's locals start at 0.
        The ENTER is replaced by INT3 and emulated in an interrupt hook."""
        import csv
        path = os.path.join(ROOT, 'ghidra_out', 'functions.csv')
        if not os.path.exists(path):
            return
        self._enter_at = {}
        for row in csv.DictReader(open(path)):
            try:
                si, off = ghidra_seg(row['address'])
            except (ValueError, KeyError):
                continue
            if si not in LOGIC_SEGMENTS:
                continue
            b = bytes(self.read(self.para[si], off, 4))
            n = b[1] | b[2] << 8
            if b[0] == 0xC8 and b[3] == 0 and n:
                self._enter_at[self.lin(self.para[si], off)] = n
                self.write(self.para[si], off, b'\xcc')

        def on_int(uc, intno, user):
            cs = uc.reg_read(UC_X86_REG_CS)
            ip = uc.reg_read(UC_X86_REG_IP)
            n = self._enter_at.get(self.lin(cs, ip - 1)) if intno == 3 else None
            if n is None:
                uc.emu_stop()
                return
            ss = uc.reg_read(UC_X86_REG_SS)
            sp = (uc.reg_read(UC_X86_REG_SP) - 2) & 0xFFFF
            uc.mem_write(self.lin(ss, sp), struct.pack('<H', uc.reg_read(UC_X86_REG_BP)))
            uc.mem_write(self.lin(ss, sp - n), bytes(n))
            uc.reg_write(UC_X86_REG_BP, sp)
            uc.reg_write(UC_X86_REG_SP, sp - n)
            uc.reg_write(UC_X86_REG_IP, ip + 3)
        self.uc.hook_add(UC_HOOK_INTR, on_int)

    # -- memory helpers --------------------------------------------------
    @staticmethod
    def lin(para, off):
        return para * 16 + off

    def read(self, para, off, n):
        return self.uc.mem_read(self.lin(para, off), n)

    def write(self, para, off, data):
        self.uc.mem_write(self.lin(para, off), bytes(data))

    def reset_ds(self):
        """Restore the data segment (globals) to its initial contents."""
        self.write(self.ds_para, 0, self.pristine_ds)

    # -- loading ---------------------------------------------------------
    def _load_segments(self):
        for seg in self.ne.segments:
            if seg.data:
                self.write(self.para[seg.index], 0, seg.data)

    def _target(self, r):
        kind = r.kind
        if kind == 'INTERNALREF':
            seg, val = r.target
            if seg == 0xFF:
                seg, off, _ = self.ne.entries[val]
            else:
                off = val
            return self.para[seg], off
        if kind in ('IMPORTORDINAL', 'IMPORTNAME'):
            # each import gets its own offset in the stub segment: INT 3
            key = r.target
            if not hasattr(self, '_imports'):
                self._imports = {}
            if key not in self._imports:
                off = len(self._imports) * 2
                self._imports[key] = off
                self._stub_keys[off] = key
                self.write(self.stub_para, off, b'\xcc\xcc')
            return self.stub_para, self._imports[key]
        return None

    def _apply_relocations(self):
        for seg in self.ne.segments:
            base = self.para[seg.index]
            for r in seg.relocs:
                tgt = self._target(r)
                if tgt is None:
                    continue
                para, off = tgt
                for site in r.sites:
                    if r.src_type == 3:          # far pointer: off, seg
                        if r.additive:
                            old = struct.unpack('<H', self.read(base, site, 2))[0]
                            off2 = (old + off) & 0xFFFF
                        else:
                            off2 = off
                        self.write(base, site, struct.pack('<HH', off2, para))
                    elif r.src_type == 2:        # segment
                        self.write(base, site, struct.pack('<H', para))
                    elif r.src_type == 5:        # offset
                        if r.additive:
                            old = struct.unpack('<H', self.read(base, site, 2))[0]
                            off = (old + off) & 0xFFFF
                        self.write(base, site, struct.pack('<H', off))

    # -- calling -------------------------------------------------------------
    def _run(self, para, off, max_insns=None, until=None):
        if max_insns is None:
            max_insns = int(os.environ.get("KAISER_EMU_MAX_INSNS", 50_000_000))
        if until is None:
            until = (self.stub_para, self.return_ip)
        def hook(uc, address, size, user):
            if self.stub_para * 16 <= address < self.stub_para * 16 + 0xFF00:
                off = address - self.stub_para * 16
                if off in self._stub_handlers:
                    try:
                        self._stub_handlers[off]()
                    except Exception as e:      # report instead of losing it in Unicorn
                        uc.emu_stop()
                        raise_box.append(f'stub handler failed: {e!r}')
                    return
                key = self._stub_keys.get(off)
                name = None
                if key is not None:
                    mod = key[0] if isinstance(key[0], str) else self.ne.modules[key[0] - 1]
                    name = (mod, key[1])
                if name in self.api:
                    self.api[name]()
                    return
                if self.api_fallback and name is not None and self._api_arg_bytes(*name) is not None:
                    # an API without effect on the game (drawing, window
                    # handling): pops its arguments, returns 0
                    self.api_calls.append(name)
                    self._api_return(self._api_arg_bytes(*name), 0)
                    return
                uc.emu_stop()
                raise_box.append(f'Windows API call {name} (stub offset {off:#x})')

        def runerror(uc, address, size, user):
            uc.emu_stop()
            self.last_runerror = uc.reg_read(UC_X86_REG_AX)
            raise_box.append(f'RunError {self.last_runerror}')
        raise_box = []
        self.last_runerror = None
        h = self.uc.hook_add(UC_HOOK_CODE, hook, begin=self.stub_para * 16,
                             end=self.stub_para * 16 + 0xFEFF)
        re_lin = self.lin(self.para[26], 0x005d)
        h2 = self.uc.hook_add(UC_HOOK_CODE, runerror, begin=re_lin, end=re_lin)

        def guard(uc, address, size, user):
            for b, e in self.guard_allow:
                if b <= address < e:
                    return
            uc.emu_stop()
            seg = (address >> 4) & 0xFFFF
            raise_box.append(f'unstubbed code at linear {address:#x} ({user})')
        guards = [self.uc.hook_add(UC_HOOK_CODE, guard, user_data=name, begin=b, end=e - 1)
                  for b, e, name in self.guard_ranges]
        try:
            self.uc.emu_start(self.lin(para, off), self.lin(*until),
                              count=max_insns)
        except UcError as e:
            raise EmuError(f'emulation failed: {e}')
        finally:
            self.uc.hook_del(h)
            self.uc.hook_del(h2)
            for g in guards:
                self.uc.hook_del(g)
        if raise_box:
            raise EmuError(raise_box[0])
        cs = self.uc.reg_read(UC_X86_REG_CS)
        ip = self.uc.reg_read(UC_X86_REG_IP)
        if (cs, ip) != until:
            raise EmuError(f'did not return (stopped at {cs:04x}:{ip:04x})')

    # -- redirected (stubbed) functions --------------------------------------
    def new_stub(self, handler):
        """A stub slot that runs handler() when reached; returns (para, off)."""
        off = self._next_stub
        self._next_stub += 2
        if self._next_stub > 0x1000:
            raise EmuError('out of stub slots')
        self.write(self.stub_para, off, b'\xcc\xcc')
        self._stub_handlers[off] = handler
        return self.stub_para, off

    def redirect(self, addr, handler):
        """Patch the entry of a function with a far jump to a stub slot."""
        seg_index, off = ghidra_seg(addr)
        para, soff = self.new_stub(handler)
        self.write(self.para[seg_index], off, struct.pack('<BHH', 0xEA, soff, para))
        return para, soff

    def stack_words(self, n, skip):
        """n words on the stack after skip bytes (the return address)."""
        ss = self.uc.reg_read(UC_X86_REG_SS)
        sp = self.uc.reg_read(UC_X86_REG_SP)
        return struct.unpack(f'<{n}H', self.read(ss, sp + skip, 2 * n))

    def stub_return(self, nbytes, far=True, ax=0, dx=0, cs=None):
        """Return from a redirected function like RETF/RET nbytes."""
        ss = self.uc.reg_read(UC_X86_REG_SS)
        sp = self.uc.reg_read(UC_X86_REG_SP)
        if far:
            ip, cs = struct.unpack('<HH', self.read(ss, sp, 4))
            sp += 4
        else:
            ip, = struct.unpack('<H', self.read(ss, sp, 2))
            sp += 2
        self.uc.reg_write(UC_X86_REG_SP, sp + nbytes)
        self.uc.reg_write(UC_X86_REG_AX, ax & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_DX, dx & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_CS, cs)
        self.uc.reg_write(UC_X86_REG_IP, ip)

    def segment_range(self, seg_index):
        """Linear [begin, end) of a loaded segment."""
        seg = self.ne.segments[seg_index - 1]
        b = self.lin(self.para[seg_index], 0)
        return b, b + max(seg.length, 1)

    # -- emulated Windows API -------------------------------------------------
    def _api_args(self, nbytes):
        """Raw argument words of a PASCAL API call (last argument first)."""
        ss = self.uc.reg_read(UC_X86_REG_SS)
        sp = self.uc.reg_read(UC_X86_REG_SP)
        return struct.unpack(f'<{nbytes // 2}H', self.read(ss, sp + 4, nbytes))

    def _api_return(self, nbytes, ax=0, dx=0):
        """Return from the API call like RETF nbytes."""
        ss = self.uc.reg_read(UC_X86_REG_SS)
        sp = self.uc.reg_read(UC_X86_REG_SP)
        ip, cs = struct.unpack('<HH', self.read(ss, sp, 4))
        self.uc.reg_write(UC_X86_REG_SP, sp + 4 + nbytes)
        self.uc.reg_write(UC_X86_REG_AX, ax & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_DX, dx & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_CS, cs)
        self.uc.reg_write(UC_X86_REG_IP, ip)

    def _load_string(self):
        # LoadString(hInstance, uID, lpBuffer, cchBufferMax): Integer
        cch, buf_off, buf_seg, uid, _hinst = self._api_args(10)
        text = self.strings.get(uid)
        n = 0
        if text is not None and cch > 0:
            n = min(len(text), cch - 1)
            self.write(buf_seg, buf_off, text[:n] + b'\0')
        self._api_return(10, n)

    RESOURCE_AREA = 0xE000         # scratch offset where LockResource puts the data

    def _find_resource(self):
        # FindResource(hInstance, lpName, lpType): handle = index + 1, 0 if missing
        t_off, t_seg, n_off, n_seg, _hinst = self._api_args(10)
        def name(seg, off):
            if seg == 0:
                return off
            raw = bytes(self.read(seg, off, 64))
            return raw[:raw.index(0)].decode('latin-1').upper()
        rtype, rname = name(t_seg, t_off), name(n_seg, n_off)
        handle = 0
        for i, r in enumerate(self.ne.resources):
            tid = r.type_id if isinstance(r.type_id, int) else str(r.type_id).upper()
            rid = r.res_id if isinstance(r.res_id, int) else str(r.res_id).upper()
            if tid == rtype and rid == rname:
                handle = i + 1
                break
        self._api_return(10, handle)

    def _load_resource(self):
        hres, _hinst = self._api_args(4)
        self._api_return(4, hres)

    def _lock_resource(self):
        (h,) = self._api_args(2)
        if h == 0:
            self._api_return(2, 0, 0)
            return
        data = self.ne.resources[h - 1].data
        self.write(self.scratch_para, self.RESOURCE_AREA, data)
        self._api_return(2, self.RESOURCE_AREA, self.scratch_para)

    def _global_unlock(self):
        self._api_args(2)
        self._api_return(2, 0)

    _spec_args = {}

    def _api_arg_bytes(self, module, ordinal):
        """Argument bytes of a PASCAL API from the Wine spec file (None if
        unknown)."""
        import re
        from ne import SPEC_DIR, SPEC_FILES
        mod = module.upper()
        if mod not in self._spec_args:
            table = {}
            fname = SPEC_FILES.get(mod)
            if fname:
                for line in open(os.path.join(SPEC_DIR, fname), encoding='utf-8'):
                    line = line.split('#')[0].strip()
                    m = re.match(r'(\d+)\s+pascal\S*\s+(?:-\S+\s+)*[\w@?$]+\(([^)]*)\)', line)
                    if m:
                        size = sum(4 if a in ('long', 'segptr', 'segstr', 'ptr', 'str') else 2
                                   for a in m.group(2).split())
                        table[int(m.group(1))] = size
            self._spec_args[mod] = table
        return self._spec_args[mod].get(ordinal)

    def _invalidate_rect(self):
        # InvalidateRect(hWnd, lpRect, bErase): repainting is not emulated
        self._api_return(8)

    # the battle window's timer, focus and device contexts: nothing happens
    def _set_timer(self):
        self._api_return(10, 1)           # SetTimer(hWnd, id, elapse, proc): id 1

    def _kill_timer(self):
        self._api_return(4, 1)

    def _set_focus(self):
        self._api_return(2, 0)

    def _get_dc(self):
        self._api_return(2, 0)            # GetDC(hWnd): DC 0

    def _release_dc(self):
        self._api_return(4, 1)

    def _setup(self, stack_words):
        uc = self.uc
        # a zeroed stack makes uninitialised locals read as 0 (the port
        # zero-initialises them), so results are reproducible
        self.write(self.stack_para, 0, bytes(STACK_SIZE))
        sp = STACK_SIZE - 2
        for w in reversed(stack_words):
            sp -= 2
            self.write(self.stack_para, sp, struct.pack('<H', w & 0xFFFF))
        uc.reg_write(UC_X86_REG_SS, self.stack_para)
        uc.reg_write(UC_X86_REG_SP, sp)
        uc.reg_write(UC_X86_REG_DS, self.ds_para)
        uc.reg_write(UC_X86_REG_ES, self.ds_para)
        uc.reg_write(UC_X86_REG_BP, 0)
        uc.reg_write(UC_X86_REG_FLAGS, 0x0002)

    def call_regs(self, addr, near=False, **regs):
        """Call a register-based routine (e.g. Real48 helpers).

        Far routines get a far return address, near routines (same segment)
        are entered through a tiny far trampoline in the stub segment.
        Returns a dict of all general registers and the carry flag."""
        seg_index, off = ghidra_seg(addr)
        para = self.para[seg_index]
        if near:
            # trampoline in the target segment is not possible (code is
            # read-only data); use CALL FAR to a near-call gadget instead:
            # we push a near return to a RETF placed right after the
            # function?  Simpler: only far entry points are supported.
            raise EmuError('near routines: call their far wrapper instead')
        self._setup([self.return_ip, self.stub_para])
        for k, v in regs.items():
            self.uc.reg_write(REGS[k], v & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_CS, para)
        self.uc.reg_write(UC_X86_REG_IP, off)
        self._run(para, off)
        out = {k: self.uc.reg_read(r) for k, r in REGS.items()}
        out['cf'] = self.uc.reg_read(UC_X86_REG_FLAGS) & 1
        out['flags'] = self.uc.reg_read(UC_X86_REG_FLAGS)
        return out

    NEAR_RETURN = 0xFFF0       # HLT in each code segment for near calls

    def call_far(self, addr, args, near=False, **regs):
        """Call a far Pascal procedure. args: list of ('word', v) /
        ('long', v) / ('ptr', (para, off)) / ('real', 6 bytes) in Pascal
        order (left to right). near=True calls a near procedure (returns to
        a HLT at offset FFF0 of its own segment).
        Returns (ax, dx)."""
        seg_index, off = ghidra_seg(addr)
        para = self.para[seg_index]
        words = []
        for kind, v in args:          # Pascal pushes left to right
            if kind == 'word':
                words.append(v)
            elif kind == 'long':
                words.extend([(v >> 16) & 0xFFFF, v & 0xFFFF])
            elif kind == 'ptr':
                words.extend([v[0], v[1]])        # segment pushed first
            elif kind == 'real':              # 6 bytes, lowest word on top
                w = struct.unpack('<HHH', bytes(v))
                words.extend([w[2], w[1], w[0]])
            else:
                raise ValueError(kind)
        # the stack grows down: first pushed = highest address
        stack = list(reversed(words))
        if near:
            self.uc.mem_write(self.lin(para, self.NEAR_RETURN), b'\xf4')
            self._setup([self.NEAR_RETURN] + stack)
            until = (para, self.NEAR_RETURN)
        else:
            self._setup([self.return_ip, self.stub_para] + stack)
            until = (self.stub_para, self.return_ip)
        for k, v in regs.items():
            self.uc.reg_write(REGS[k], v & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_CS, para)
        self.uc.reg_write(UC_X86_REG_IP, off)
        self._run(para, off, until=until)
        self.last_regs = {k: self.uc.reg_read(r) for k, r in REGS.items()}
        return (self.uc.reg_read(UC_X86_REG_AX), self.uc.reg_read(UC_X86_REG_DX))

    # -- globals --------------------------------------------------------------
    def ds_word(self, off, value=None):
        if value is None:
            return struct.unpack('<H', self.read(self.ds_para, off, 2))[0]
        self.write(self.ds_para, off, struct.pack('<H', value & 0xFFFF))

    def rand_seed(self, value=None):
        """System.RandSeed lives at DS:6000 (longint)."""
        if value is None:
            return struct.unpack('<I', self.read(self.ds_para, 0x6000, 4))[0]
        self.write(self.ds_para, 0x6000, struct.pack('<I', value & 0xFFFFFFFF))
