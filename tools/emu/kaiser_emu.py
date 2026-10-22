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

from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
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
        self._load_segments()
        self._apply_relocations()
        self.pristine_ds = bytes(self.read(self.ds_para, 0, 0x10000))
        # far return target: a HLT instruction in the stub segment
        self.return_ip = 0xFF00
        self.uc.mem_write(self.lin(self.stub_para, self.return_ip), b'\xf4')

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
    def _run(self, para, off, max_insns=5_000_000):
        def hook(uc, address, size, user):
            if self.stub_para * 16 <= address < self.stub_para * 16 + 0xFF00:
                uc.emu_stop()
                raise_box.append(f'Windows API call (stub offset {address - self.stub_para * 16:#x})')

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
        try:
            self.uc.emu_start(self.lin(para, off),
                              self.lin(self.stub_para, self.return_ip),
                              count=max_insns)
        except UcError as e:
            raise EmuError(f'emulation failed: {e}')
        finally:
            self.uc.hook_del(h)
            self.uc.hook_del(h2)
        if raise_box:
            raise EmuError(raise_box[0])
        cs = self.uc.reg_read(UC_X86_REG_CS)
        ip = self.uc.reg_read(UC_X86_REG_IP)
        if (cs, ip) != (self.stub_para, self.return_ip):
            raise EmuError(f'did not return (stopped at {cs:04x}:{ip:04x})')

    def _setup(self, stack_words):
        uc = self.uc
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

    def call_far(self, addr, args, **regs):
        """Call a far Pascal procedure. args: list of ('word', v) /
        ('long', v) / ('ptr', (para, off)) in Pascal order (left to right).
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
            else:
                raise ValueError(kind)
        # the stack grows down: first pushed = highest address
        stack = list(reversed(words))
        self._setup([self.return_ip, self.stub_para] + stack)
        for k, v in regs.items():
            self.uc.reg_write(REGS[k], v & 0xFFFF)
        self.uc.reg_write(UC_X86_REG_CS, para)
        self.uc.reg_write(UC_X86_REG_IP, off)
        self._run(para, off)
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
