"""UI layer for emulating game functions that open dialogs.

The game logic (segments 2, 3, 4, 6, 7, 14) runs for real in the emulator.
Everything that would touch Windows or OWL is replaced:
  - dialog constructors (KaiserDlg.Init, MessageDlg.Init, ...) return a fake
    object whose VMT (in free DS memory) leads to logging stubs for
    Execute / Done; Execute returns a scripted result and can fill result
    fields of the object;
  - whole UI functions (menus, reports, battles not ported yet, sounds)
    return a scripted value without side effects;
  - any other code in a UI segment stops the emulation (guard).
Every call is logged as one entry, e.g.
    MessageDlg[3364](W,s:4b52...,s:48616c6c6f)=O1
    Execute(O1;d:0000...)=1+38:05
    Done(O1,1)
Pointers are symbolic: W window, P<i>:<off> into player i, D<off> into DS,
O<n> fake object n, S other (locals). Strings are hex (s:...), records
passed by reference r<len>:hex. The port's test UI (port/tests/ruletest.pas)
produces the same entries.
"""
import struct

from unicorn.x86_const import UC_X86_REG_DS

FAKE_VMT = 0xF000          # DS offset of the fake dialog VMT (beyond the data)
OBJ_SEG = 0x1000           # fake dialog objects: paragraphs after the scratch start
OBJ_SIZE = 0x200           # (object n at n*OBJ_SIZE, the application at 0xFE00)
WINDOW = (0x0EEE, 0x1234)  # the parent window pointer the game passes around

# constructors: name -> (address, argument kinds in Pascal order after
# Self and the VMT word). Kinds: p pointer, s string, w word, b byte,
# l longint, rN record of N bytes (by reference)
CTORS = {
    'KaiserDlg': ('1058:0002', ['p', 's']),
    'MessageDlg': ('1058:024d', ['p', 's', 's']),
    'Message2Dlg': ('1058:0364', ['p', 's', 's', 's']),
    'HeroNameDlg': ('1058:05a1', ['p', 's', 'w']),
    'UnitInfoDlg': ('1058:0862', ['p', 's', 'r61', 'b', 'w']),
    'PromotionDlg': ('1010:58d3', ['p', 's']),
    'StartFinanzDlg': ('1010:59ef', ['p', 's']),
    'StartPopDlg': ('1010:5c1a', ['p', 's']),
    'HexenDlg': ('1010:5e43', ['p', 's']),
}
# virtual methods of the fake objects: VMT slot -> (name, arg kinds after Self,
# returns a value)
METHODS = {
    0x08: ('Done', ['b'], False),            # a Boolean pushed as a word (AH is garbage)
    0x38: ('ExecDialog', ['p'], True),       # on the application object (DS:5bde)
    0x4c: ('Execute', [], True),
    0x58: ('GetText', [], 'ptr'),            # HeroNameDlg: the entered name (at +0x100)
}
APP_PTR = 0x5bde           # DS: pointer to the OWL application object
TEXT_OFS = 0x100           # where a fake dialog keeps its text result
# whole functions: name -> (address, far?, argument kinds, returns a value)
FUNCS = {
    'ShowBuildingLossDlg': ('1040:0565', True, ['p', 's', 'r44', 'b'], False),
    'Do_KornVerteilen': ('1040:8551', True, ['p', 'p', 'b'], False),
    'Do_TruppenAufstellen': ('1038:6a30', True, ['p', 'p', 'b'], False),
    'PlaySound': ('1070:0002', True, ['w', 'w'], False),
    'Email_AskPassword': ('1020:014e', True, ['p', 'p', 's', 's'], True),
    'ShowHeroLevelUp': ('1040:384b', True, ['p', 'r32'], False),
    'FightRaiders': ('1018:0c5f', True, ['p', 'p', 'b', 'b'], True),
    'TradeCaravan': ('1040:08a2', True, ['p', 'p', 'w'], False),
    'Do_Geheimdienst': ('1038:0002', True, ['p', 'p', 'b', 'b', 'w'], False),
    'Do_HandelMitGuetern': ('1040:1439', True, ['p', 'p'], False),
    'AskWarehousesFull': ('1040:081e', True, ['p', 'p', 'b', 'b'], False),
    'Do_LandHandeln': ('1040:7e4b', True, ['p', 'p', 'b', 'b'], False),
    'Do_Gebaeude': ('1040:6cff', True, ['p', 'p', 'b', 'b'], False),
    'FreeMem': ('10c8:0147', True, ['p', 'w'], False),   # a dialog freed without Done
}
# segments that may only run through the stubs above (UI, OWL, battle view)
GUARDED_SEGMENTS = [1, 5, 8, 9, 10, 11, 12, 13, 15, 16, 17, 19, 20, 21, 22, 23, 24]
# code in guarded segments that is plain logic and may run
ALLOWED = [('1060:03d9', 0x14e)]           # FormatPlayerTitle


def arg_bytes(kinds):
    n = 0
    for k in kinds:
        n += 4 if k[0] in 'pslr' else 2
    return n


class UILayer:
    """chooser(entry_without_result, kind) -> (ax, {offset: bytes}) decides
    results; kind is 'ctor', 'method' or 'func'."""

    def __init__(self, emu, players_para, chooser):
        self.emu = emu
        self.players_para = players_para
        self.chooser = chooser
        self.log = []
        self.objects = []
        self._install()

    # -- symbolic arguments --------------------------------------------------
    def sym(self, seg, off):
        from kaiser_structs import PLAYER_SIZE
        if (seg, off) == WINDOW:
            return 'W'
        if seg == self.players_para and off < 10 * PLAYER_SIZE:
            return f'P{off // PLAYER_SIZE}:{off % PLAYER_SIZE}'
        if seg == self.emu.ds_para:
            return f'D{off}'
        for i, (s, o) in enumerate(self.objects):
            if (seg, off) == (s, o):
                return f'O{i + 1}'
        if (seg, off) == self.app:
            return 'A'
        if seg == 0 and off == 0:
            return 'nil'
        return 'S'

    def contents(self, seg, off):
        """What the game wrote into a fake dialog: bytes 2..size, trailing
        zeros dropped."""
        size = OBJ_SIZE
        for i, o in enumerate(self.objects):
            if o == (seg, off):
                size = self.sizes[i]
        data = bytes(self.emu.read(seg, off + 2, max(size - 2, 0))).rstrip(b'\0')
        return data.hex()

    def cstring(self, seg, off):
        data = self.emu.read(seg, off, 512)
        return data[:data.index(0)] if 0 in data else data

    def format_args(self, kinds, words):
        """words: the argument words from the stack, last argument first."""
        out, i = [], 0
        for k in reversed(kinds):            # walk from the last argument
            if k[0] in 'pslr':
                off, seg = words[i], words[i + 1]
                i += 2
                if k == 'p':
                    out.append(self.sym(seg, off))
                elif k == 's' and seg == 0:
                    out.append(f'i:{off}')            # MAKEINTRESOURCE
                elif k == 's':
                    out.append('s:' + self.cstring(seg, off).hex())
                elif k == 'l':
                    out.append(str(struct.unpack('<i', struct.pack('<HH', off, seg))[0]))
                else:
                    n = int(k[1:])
                    out.append(f'r{n}:' + self.emu.read(seg, off, n).hex())
            else:
                v = words[i]
                i += 1
                out.append(str(v & 0xFF) if k == 'b' else str(v))
        return ','.join(reversed(out))

    # -- installation ----------------------------------------------------------
    def _install(self):
        emu = self.emu
        for name, (addr, kinds) in CTORS.items():
            emu.redirect(addr, self._ctor_handler(name, kinds))
        for name, (addr, far, kinds, has_ret) in FUNCS.items():
            emu.redirect(addr, self._func_handler(name, far, kinds, has_ret))
        self.vmt = bytearray(0x80)
        for slot, (name, kinds, has_ret) in METHODS.items():
            para, off = emu.new_stub(self._method_handler(name, kinds, has_ret))
            self.vmt[slot:slot + 4] = struct.pack('<HH', off, para)
        self.app = (emu.scratch_para + OBJ_SEG, 0xFE00)
        self.reset()
        from kaiser_emu import ghidra_seg
        emu.guard_ranges = []
        for seg in GUARDED_SEGMENTS:
            b, e = emu.segment_range(seg)
            emu.guard_ranges.append((b, e, f'segment {seg}'))
        emu.guard_allow = []
        redirected = [a for a, _ in CTORS.values()] + [f[0] for f in FUNCS.values()]
        for addr, size in ALLOWED + [(a, 5) for a in redirected]:   # 5: the patched jump
            si, off = ghidra_seg(addr)
            b = emu.lin(emu.para[si], off)
            emu.guard_allow.append((b, b + size))

    def reset(self):
        """Per test case (after the data segment was reset)."""
        emu = self.emu
        self.log = []
        self.objects = []
        self.sizes = []
        emu.write(emu.ds_para, FAKE_VMT, bytes(self.vmt))
        emu.write(self.app[0], self.app[1], struct.pack('<H', FAKE_VMT) + bytes(OBJ_SIZE - 2))
        emu.write(emu.ds_para, APP_PTR, struct.pack('<HH', self.app[1], self.app[0]))

    def _ctor_handler(self, name, kinds):
        def handler():
            emu = self.emu
            n = arg_bytes(kinds)
            words = emu.stack_words(3 + n // 2, 4)   # Self (2 words), VMT, args
            args = words[3:]
            vmt = words[2]
            entry = f'{name}[{vmt:x}]({self.format_args(kinds, args)})'
            k = len(self.objects)
            size = emu.ds_word(vmt)                   # instance size from the VMT
            if (words[0], words[1]) != (0, 0):        # an object constructed in place
                obj = (words[1], words[0])
            else:
                if k >= 0xFE00 // OBJ_SIZE:
                    raise RuntimeError('too many dialogs')
                obj = (emu.scratch_para + OBJ_SEG, k * OBJ_SIZE)
            emu.write(obj[0], obj[1], bytes(size))
            emu.write(obj[0], obj[1], struct.pack('<H', FAKE_VMT))
            self.objects.append(obj)
            self.sizes.append(size)
            self.log.append(f'{entry}=O{k + 1}')
            emu.stub_return(6 + n, True, obj[1], obj[0])
        return handler

    def _method_handler(self, name, kinds, has_ret):
        def handler():
            emu = self.emu
            n = arg_bytes(kinds)
            words = emu.stack_words(2 + n // 2, 4)   # Self, args
            self_sym = self.sym(words[1], words[0])
            args = self.format_args(kinds, words[2:])
            entry = f'{name}({self_sym}{"," + args if args else ""})'
            if name == 'Execute':
                entry += ';d:' + self.contents(words[1], words[0])
            elif name == 'ExecDialog':
                entry += ';d:' + self.contents(words[3], words[2])
            ax, dx, data = 0, 0, {}
            if has_ret == 'ptr':
                ax, dx = words[0] + TEXT_OFS, words[1]
            elif has_ret:
                ax, data = self.chooser(entry, 'method')
                # result fields go into the executed dialog (for ExecDialog: its argument)
                seg, off = (words[3], words[2]) if name == 'ExecDialog' else (words[1], words[0])
                for o, b in sorted(data.items()):
                    emu.write(seg, off + o, b)
                entry += f'={ax}' + ''.join(f'+{o:x}:{b.hex()}' for o, b in sorted(data.items()))
            self.log.append(entry)
            emu.stub_return(4 + n, True, ax, dx)
        return handler

    def _func_handler(self, name, far, kinds, has_ret):
        si = int(FUNCS[name][0].split(':')[0], 16)

        def handler():
            emu = self.emu
            n = arg_bytes(kinds)
            words = emu.stack_words(n // 2, 4 if far else 2)
            entry = f'{name}({self.format_args(kinds, words)})'
            ax = 0
            if has_ret:
                ax, _ = self.chooser(entry, 'func')
                entry += f'={ax}'
            self.log.append(entry)
            emu.stub_return(n, far, ax)
        return handler
