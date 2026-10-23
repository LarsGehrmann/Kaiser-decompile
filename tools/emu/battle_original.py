"""A battle in the emulated original, the AI playing both sides.

Usage: battle_original.py SAVE ATTACKER DEFENDER CITY SEED [MAXTICKS]

BattleWnd::Init (1048:0002), both sides computer, the state SetupWindow
leaves, then WMTimer (1048:96d1) ticks until the battle ends (EndDlg).
Prints the same line as port/bin/ksrbattle: end code, ticks, units left,
RandSeed and a CRC32 of the battle window (offsets 0x2e..0xf9a).
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
from ui_stubs import UILayer, WINDOW                   # noqa: E402
from gen_rule_vectors import (HDR_DS, PSIZE, BW_AREA, load_save,  # noqa: E402
                              setup_battle_window)


def main():
    save, att, dfn, city, seed = sys.argv[1], *(int(x) for x in sys.argv[2:6])
    max_ticks = int(sys.argv[6]) if len(sys.argv) > 6 else 5000
    header, players, num = load_save(save)
    emu = KaiserEmu()
    sp = emu.scratch_para
    ui = UILayer(emu, sp, lambda e, k: (1, {}) if k == 'method' else (0, {}))
    emu.reset_ds()
    emu.write(emu.ds_para, 0x6794, struct.pack('<H', 400))       # INI Schlacht-Timer
    emu.write(emu.ds_para, HDR_DS, bytes(header))
    emu.write(sp, 0, bytes(10 * PSIZE))
    emu.write(sp, 0, bytes(players))
    emu.write(sp, BW_AREA, bytes(ks.BATTLE_SIZE))
    emu.rand_seed(seed)
    ui.reset()
    ui.battle_alias = (sp, BW_AREA)
    emu.call_far('1048:0002', [('ptr', WINDOW), ('ptr', (0, 0)), ('ptr', (sp, att * PSIZE)),
                               ('ptr', (sp, dfn * PSIZE)), ('word', 0), ('word', city),
                               ('word', 0x2d2c), ('ptr', (sp, BW_AREA))])
    emu.write(sp, BW_AREA + 0xe2b, b'\0\0')
    setup_battle_window(emu, sp)
    code, ticks = 0, 0
    while code == 0 and ticks < max_ticks:
        ui.log = []
        emu.call_far('1048:96d1', [('ptr', (0, 0)), ('ptr', (sp, BW_AREA))])
        ticks += 1
        for e in ui.log:
            if e.startswith('Battle_End('):
                code = int(e[len('Battle_End('):].split(',')[0])
    b = bytes(emu.read(sp, BW_AREA, ks.BATTLE_SIZE))
    print(f'code={code} ticks={ticks} att={b[0x703 + 0x137]} def={b[0x2e + 0x137]} '
          f'seed={emu.rand_seed()} crc={zlib.crc32(b[0x2e:0xf9b]):08X}')


if __name__ == '__main__':
    main()
