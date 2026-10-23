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
    'HumanCountDlg': ('1040:2017', ['p', 's']),
    'ComputerCountDlg': ('1040:234c', ['p', 's']),
    'PlayerDataDlg': ('1040:2569', ['p', 's', 'p', 'b']),
    'TButton': ('1098:04e8', ['p', 'w', 's', 'w', 'w', 'w', 'w', 'b']),
    'ButtonChoiceDlg': ('1058:0da7', ['p', 's', 'w', 'r5']),   # KAMPFOPTDLG: enabled buttons
    'HelpChoice2Dlg': ('1058:043e', ['p', 's', 's', 's', 'w']),   # KRIEGSER*DLG
    'MassacreDlg': ('1028:0461', ['p', 's']),
    'PlunderResultDlg': ('1028:0c00', ['p', 's']),
    'PlunderChoiceDlg': ('1028:1290', ['p', 's']),
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
    'ShowBuildingLossDlg': ('1040:0565', True, ['p', 's', 'L', 'b'], False),
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
    # the turn loop (NextPlayer, CpuTurn, ResolveWar)
    'Battle': ('1018:0558', True, ['p', 'p', 'p', 'b', 'b', 'b'], True),
    'Victory': ('1000:3459', True, ['p'], False),
    'EndGame': ('1000:0a6f', True, ['p'], False),
    'ShowEmailHandOver': ('1020:02ee', True, ['p', 'p', 'p'], False),
    'SaveGame': ('1050:058b', True, ['p', 'p', 'p'], False),
    'ShowPasswordFail': ('1020:0216', True, ['p'], False),
    'EmailGameStep': ('1000:2637', True, ['p'], False),
    'Menu_DisableSave': ('1060:0037', True, ['w', 'w'], False),
    'Randomize': ('10c8:13d7', True, [], False),        # the clock: RandSeed stays
    # the battle window's drawing (Battle_DrawUnitStatus: see DRAW_UNIT_STATUS)
    'Battle_RedrawUnit': ('1048:6192', True, ['b', 'b', 'p'], False),
    'Battle_DrawCell': ('1048:2803', True, ['w', 'w', 'b', 'p'], False),
    'Battle_ClearTargetPanel': ('1048:196c', True, ['p'], False),
    'Battle_EnableButtons': ('1048:0daa', True, ['p'], False),
    'Battle_DisableButtons': ('1048:0dde', True, ['p'], False),
    'Battle_End': ('1048:8ff5', True, ['b', 'p'], False),   # EndDlg(code)
    'DisableButton2': ('1058:0591', True, ['p'], False),
}
# DrawUnitStatus(DC, side, unit, panel, Self) draws, but first recomputes the
# unit's motivation (ComputeMotivation(unit, side, Self), if the unit exists):
# the stub logs the call and continues in ComputeMotivation
DRAW_UNIT_STATUS = ('1048:1a60', ['w', 'b', 'b', 'b', 'p'], '1048:3ae4')
# segments that may only run through the stubs above (UI, OWL, battle view)
GUARDED_SEGMENTS = [1, 5, 8, 9, 10, 11, 12, 13, 15, 16, 17, 19, 20, 21, 22, 23, 24]
# the logic of the battle window (segment 10); its drawing and message
# handlers stay guarded and are stubbed in FUNCS
BATTLE_LOGIC = [
    ('1048:0002', 0x7c7),    # Init
    ('1048:0966', 0x25d),    # InitMorale
    ('1048:0e12', 0xc4),    # GetResults
    ('1048:345c', 0x20),    # OtherSide
    ('1048:347c', 0x3b),    # IsInCity
    ('1048:34b7', 0x121),    # IsThreatened
    ('1048:35d8', 0x96),    # HeroShouldFlee
    ('1048:366e', 0x58),    # AnyUnitInMelee
    ('1048:36c6', 0xfb),    # CountAdjacentEnemies
    ('1048:37c1', 0x14a),    # HasAdjacentFriendOfType
    ('1048:390b', 0x2d),    # InBounds
    ('1048:3938', 0x1ac),    # StrengthBalance
    ('1048:3ae4', 0x1f2),    # ComputeMotivation
    ('1048:3cd6', 0xa2),    # RefreshUnitCodes
    ('1048:3d78', 0x208),    # CanMoveTo
    ('1048:3fc0', 0x59c),    # MoveUnit
    ('1048:455c', 0x3e8),    # CanAttack
    ('1048:4944', 0x711),    # Duel
    ('1048:5055', 0x498),    # AttackUnit
    ('1048:54ed', 0x669),    # AttackObject
    ('1048:5b56', 0x10a),    # CanHeal
    ('1048:5c60', 0x6e),    # HealUnit
    ('1048:5cce', 0xf2),    # DoHeal
    ('1048:5dc0', 0x3d2),    # DesertionCheck
    ('1048:631a', 0x28e),    # EndAction
    ('1048:65a8', 0x356),    # AiStep
    ('1048:68fe', 0xd6),    # AiChooseAggressive
    ('1048:69d4', 0x349),    # AiEnemyOutguns
    ('1048:6d1d', 0xee),    # AiFindEnemyHero
    ('1048:6e0b', 0x72),    # AiFirstEnemy
    ('1048:6e7d', 0xb9),    # AiLastEnemy
    ('1048:6f36', 0x117),    # AiFindHelplessEnemy
    ('1048:704d', 0xff),    # AiFindFastEnemy
    ('1048:714c', 0x128),    # AiFindWeakestEnemy
    ('1048:7274', 0x12f),    # AiFindMostWoundedFriend
    ('1048:73a3', 0xf0),    # AiFindEnemyWithAbility
    ('1048:7493', 0xee),    # AiFindHealingEnemy
    ('1048:7581', 0x8c),    # AiPickWallTarget
    ('1048:760d', 0x118),    # AiPickAdjacentBuilding
    ('1048:7725', 0x2f6),    # AiChooseTarget
    ('1048:7a1b', 0xf7),    # AiNearestEnemy
    ('1048:7b12', 0x22b),    # AiStepToward
    ('1048:7d3d', 0x34e),    # AiTryAttack
    ('1048:808b', 0x118),    # AiChooseStance
    ('1048:81a3', 0x30a),    # AiMove
    ('1048:84ad', 0x133),    # AiShouldRetreat
    ('1048:85e0', 0x4e4),    # StartSideTurn
    ('1048:8ac4', 0x155),    # ResetSide
    ('1048:8c19', 0x79),    # CombatOptions_MoreThanOneActive
    ('1048:8f08', 0xed),    # NextUnit
    ('1048:96d1', 0x16e),    # WMTimer
    ('1048:983f', 0x2b),    # StartTimer
    ('1048:986a', 0x41),    # StopTimer
    ('1048:98ab', 0x86),    # CmWarten
    ('1048:9931', 0x36),    # CmFertig
    ('1048:9967', 0xf0),    # CmAufgeben
    ('1048:8c92', 0x276),    # CombatOptionsMenu
    ('1048:900d', 0x1a1),    # WMLButtonDown
]
# code in guarded segments that is plain logic and may run
ALLOWED = BATTLE_LOGIC + [('1060:03d9', 0x14e),           # FormatPlayerTitle
           ('1000:35ad', 0x125),           # NextPlayer
           ('1000:36d2', 0xee),            # CpuTurn
           ('1000:37c0', 0x10f),           # ResolveWar
           ('1000:2476', 0x1c1),           # CmBeenden
           ('1000:33c0', 0x99),            # BeginHumanTurn
           ('1000:0ce6', 0x156),           # CmNeuesSpiel
           ('1040:1d98', 0x192),           # NewGame_AskPlayerCounts
           ('1040:1f2a', 0xeb),            # NewGame_AskPlayerData
           ('1050:1212', 0xe6)]            # LoadMapData (the resource API is emulated)


def arg_bytes(kinds):
    n = 0
    for k in kinds:
        n += 4 if k[0] in 'pslrL' else 2
    return n


class UILayer:
    """chooser(entry_without_result, kind) -> (ax, {offset: bytes}) decides
    results; kind is 'ctor', 'method' or 'func'."""

    def __init__(self, emu, players_para, chooser, unstub=()):
        self.unstub = set(unstub)        # FUNCS that run for real (dialog tests)
        self.emu = emu
        self.players_para = players_para
        self.window_alias = None         # a fake window object standing for W
        self.battle_alias = None         # the battle window object: B<offset>
        self.chooser = chooser
        self.log = []
        self.objects = []
        self._install()
        from dlg_driver import DialogDriver
        self.driver = DialogDriver(self)
        from kaiser_emu import ghidra_seg
        for addr in self.driver.addresses():
            si, off = ghidra_seg(addr)
            b = emu.lin(emu.para[si], off)
            emu.guard_allow.append((b, b + 5))
        for seg in (8, 9, 12):                       # the dialog types' own code
            b, e = emu.segment_range(seg)
            emu.guard_allow.append((b, e))


    # -- symbolic arguments --------------------------------------------------
    def sym(self, seg, off):
        from kaiser_structs import PLAYER_SIZE
        if (seg, off) == WINDOW or (seg, off) == self.window_alias:
            return 'W'
        if self.battle_alias is not None:
            bseg, boff = self.battle_alias
            rel = seg * 16 + off - (bseg * 16 + boff)
            if 0 <= rel < 0xfa7:
                return f'B{rel}'
        rel = seg * 16 + off - self.players_para * 16     # (any segment:offset form)
        if 0 <= rel < 10 * PLAYER_SIZE:
            return f'P{rel // PLAYER_SIZE}:{rel % PLAYER_SIZE}'
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
            if k[0] in 'pslrL':
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
                elif k == 'L':
                    # TLandLoss: BuildingsLostForLand never writes bytes 4..7,
                    # they keep whatever the stack held (the port zeroes them)
                    data = bytearray(self.emu.read(seg, off, 44))
                    data[4:8] = bytes(4)
                    out.append('r44:' + data.hex())
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
            if name not in self.unstub:
                emu.redirect(addr, self._func_handler(name, far, kinds, has_ret))
        emu.redirect(DRAW_UNIT_STATUS[0], self._draw_unit_status_handler())
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
        redirected = ([a for a, _ in CTORS.values()] +
                      [f[0] for n, f in FUNCS.items() if n not in self.unstub] +
                      [DRAW_UNIT_STATUS[0]])
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
        if hasattr(self, 'driver'):
            self.driver.reset()
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
            if (words[0], words[1]) != (0, 0) and vmt == 0:
                # an inherited constructor (VMT 0): the object is set up by
                # its own constructor, leave it alone (a real dialog type:
                # the driver needs its template)
                obj = (words[1], words[0])
                if name == 'KaiserDlg' and kinds[1] == 's':
                    off_s, seg_s = args[len(args) - 4 + 0], args[len(args) - 4 + 1]
                    nm = self.cstring(seg_s, off_s) if seg_s else b''
                    if hasattr(self, 'driver'):
                        self.driver.set_template(nm.decode('latin-1'))
                size = 0
                self.objects.append(obj)
                self.sizes.append(size)
                self.log.append(f'{entry}=O{k + 1}')
                emu.stub_return(6 + n, True, obj[1], obj[0])
                return
            if (words[0], words[1]) != (0, 0):        # an object constructed in place
                obj = (words[1], words[0])
                emu.write(obj[0], obj[1], bytes(size))
            else:
                if k >= 0xFE00 // OBJ_SIZE:
                    raise RuntimeError('too many dialogs')
                obj = (emu.scratch_para + OBJ_SEG, k * OBJ_SIZE)
                # all of it: GetText (+0x100) lies beyond most instance sizes
                emu.write(obj[0], obj[1], bytes(OBJ_SIZE))
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
                if seg != self.emu.scratch_para + OBJ_SEG and (seg, off) in self.objects:
                    # an object constructed in place (e.g. a local): nothing
                    # beyond its instance size
                    size = self.sizes[self.objects.index((seg, off))]
                    data = {o: b for o, b in data.items() if o + len(b) <= size}
                for o, b in sorted(data.items()):
                    emu.write(seg, off + o, b)
                entry += f'={ax}' + ''.join(f'+{o:x}:{b.hex()}' for o, b in sorted(data.items()))
            self.log.append(entry)
            emu.stub_return(4 + n, True, ax, dx)
        return handler

    def _draw_unit_status_handler(self):
        from kaiser_emu import ghidra_seg
        from unicorn.x86_const import UC_X86_REG_SP, UC_X86_REG_SS, UC_X86_REG_CS, UC_X86_REG_IP
        kinds = DRAW_UNIT_STATUS[1]

        def handler():
            emu = self.emu
            words = emu.stack_words(6, 4)          # Self (2), panel, unit, side, DC
            self.log.append(f'Battle_DrawUnitStatus({self.format_args(kinds, words)})')
            self_off, self_seg, _panel, unit, side = words[0], words[1], words[2], words[3] & 0xFF, words[4] & 0xFF
            count = emu.read(self_seg, self_off + side * 0x6d5 + 0x165, 1)[0]
            if count < unit & 0xFF:
                emu.stub_return(12, True)
                return
            # the same return address, arguments (unit pointer, side, Self)
            ss = emu.uc.reg_read(UC_X86_REG_SS)
            sp = emu.uc.reg_read(UC_X86_REG_SP)
            ip, cs = struct.unpack('<HH', emu.read(ss, sp, 4))
            u = self_off + side * 0x6d5 + 0x12a + (unit & 0xFF) * 0x3d
            sp += 2
            emu.write(ss, sp, struct.pack('<7H', ip, cs, self_off, self_seg, side, u & 0xFFFF, self_seg))
            emu.uc.reg_write(UC_X86_REG_SP, sp)
            si, off = ghidra_seg(DRAW_UNIT_STATUS[2])
            emu.uc.reg_write(UC_X86_REG_CS, emu.para[si])
            emu.uc.reg_write(UC_X86_REG_IP, off)
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
