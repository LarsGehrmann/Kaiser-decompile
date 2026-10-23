"""Play a savegame on in the emulated original: every human just ends the turn.

Usage: sim_original.py SAVE TURNS SEED
       sim_original.py new:HUMANS:COMPUTERS:LEVEL TURNS SEED

The second form starts a new game first (CmNeuesSpiel): human i is
"Spieler<i+1>", male, country i; computer level 1..4; immortality off, goods
trade and initiative on.

Runs the original "Runde beenden" (CmBeenden 1000:2476) TURNS times: the
human's year end, all computer players (NextPlayer), the next human's turn
start. Dialogs answer OK (Execute = 1; offered units are declined), UI functions return 0 (a battle
against a human is lost by the attacker, raiders win). After each turn one
line: turn, current player, year, RandSeed and a CRC32 of the player array
and the game record. port/bin/ksrsim prints the same lines for the port.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import kaiser_structs as ks                            # noqa: E402
from kaiser_emu import KaiserEmu                       # noqa: E402
from ui_stubs import UILayer                           # noqa: E402
from gen_rule_vectors import HDR_DS, PSIZE, load_save  # noqa: E402


def field(fields, name):
    for off, typ, fname, _ in fields:
        if fname == name:
            return off
    raise KeyError(name)


UI = None


def default_answer(entry, kind):
    """OK everywhere, except that humans decline offered units (UnitInfoDlg):
    with the army dialog stubbed, accepted units would pile up in the Garde
    beyond 8 and overrun the player record (in both programs)."""
    if entry.startswith('Execute(O') and UI is not None:
        obj = entry[len('Execute('):entry.index(')')]
        for e in UI.log:
            if e.endswith('=' + obj) and e.startswith('UnitInfoDlg'):
                return (2, {})
    return (1, {}) if kind == 'method' else (0, {})


def new_game_answers(humans, cpus, level):
    """The dialog answers of CmNeuesSpiel, in order."""
    answers = [(1, {0x34: bytes([humans])})]
    if humans < 10:
        answers.append((1, {0x34: bytes([cpus]), 0x3b: bytes([max(level - 1, 0)])}))
    for i in range(humans):
        answers.append((1, {0x2e: b'Spieler%d\0' % (i + 1), 0x4c: b'\0', 0x4d: bytes([i])}))

    def chooser(entry, kind):
        if entry.startswith('Execute(') and answers:
            return answers.pop(0)
        return default_answer(entry, kind)
    return chooser


def main():
    save, turns, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    new = save.startswith('new:')
    if new:
        humans, cpus, level = (int(x) for x in save.split(':')[1:4])
        header, players, num = bytearray(ks.HEADER_SIZE), bytearray(), humans + cpus
        header[field(ks.HEADER, 'goods_trade_enabled')] = 1
        header[field(ks.HEADER, 'initiative_enabled')] = 1
    else:
        header, players, num = load_save(save)
        header[field(ks.HEADER, 'game_state')] = 1
    header[field(ks.HEADER, 'email_game_q')] = 0
    emu = KaiserEmu()
    sp = emu.scratch_para
    global UI
    ui = UI = UILayer(emu, sp, default_answer)
    emu.reset_ds()
    emu.write(emu.ds_para, HDR_DS, bytes(header))
    emu.write(sp, 0, bytes(10 * PSIZE))
    emu.write(sp, 0, bytes(players))
    for c in range(10):                    # runtime name tables as the tests set them
        emu.write(emu.ds_para, 0x6696 + 25 * c, emu.read(emu.ds_para, 0x477e + 25 * (10 + c), 25))
        emu.write(emu.ds_para, 0x64a2 + 25 * c, emu.read(emu.ds_para, 0x477e + 25 * c, 25))
        emu.write(emu.ds_para, 0x63a8 + 25 * c, emu.read(emu.ds_para, 0x477e + 25 * c, 25))
    emu.rand_seed(seed)
    self_ptr = (sp - 5, 0x50 - 0x41)       # a fake main window: players at +0x41
    cpu = field(ks.PLAYER, 'cpu_level')
    title = field(ks.PLAYER, 'title')
    if new:
        ui.reset()
        ui.window_alias = self_ptr
        ui.chooser = new_game_answers(humans, cpus, level)
        emu.call_far('1000:0ce6', [('ptr', (0, 0)), ('ptr', self_ptr)])
        ui.chooser = default_answer
    for turn in range(1, turns + 1):
        ui.reset()
        ui.window_alias = self_ptr
        emu.call_far('1000:2476', [('ptr', (0, 0)), ('ptr', self_ptr)])
        h = bytes(emu.read(emu.ds_para, HDR_DS, ks.HEADER_SIZE))
        p = bytes(emu.read(sp, 0, num * PSIZE))
        cur, year = h[3], struct.unpack_from('<h', h, 7)[0]
        print(f'{turn} cur={cur} year={year} seed={emu.rand_seed()} '
              f'crc={zlib.crc32(p + h):08x} state={h[10]}')
        sys.stdout.flush()
        if h[10] != 1 or any(p[i * PSIZE + title] >= 10 for i in range(num)):
            break                          # game over, coronation
        if all(p[i * PSIZE + cpu] != 0 for i in range(num)):
            break                          # no human left: NextPlayer would not stop


if __name__ == '__main__':
    main()
