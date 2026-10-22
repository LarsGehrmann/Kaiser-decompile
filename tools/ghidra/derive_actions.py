"""Name the subsystem functions behind each main-window menu command.

Most command handlers (names/25_handlers.csv) just check the game state
and call one game function with the current player's record. That callee
is named Do_<Command>. Handlers calling several game functions are
skipped; they need a manual look.

Reads ghidra_out/decomp (run export_all.py first), writes
tools/ghidra/names/26_actions.csv.
Usage: python3 -I tools/ghidra/derive_actions.py
"""
import csv
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DECOMP = os.path.join(ROOT, 'ghidra_out', 'decomp')
LIBRARY_SEGS = range(19, 27)  # OWL, Objects, Strings, System ...


def seg_of(addr):
    return (int(addr.split(':')[0], 16) - 0x1000) // 8 + 1


def load_bodies():
    bodies = {}
    for name in os.listdir(DECOMP):
        src = open(os.path.join(DECOMP, name), encoding='utf-8').read()
        for part in re.split(r'(?m)^// ==== ', src)[1:]:
            m = re.match(r'(\S+) @ (\S+) ====', part)
            if m:
                bodies[m.group(2)] = part
    return bodies


def main():
    bodies = load_bodies()
    rows, skipped = [], []
    with open(os.path.join(HERE, 'names', '25_handlers.csv'),
              encoding='utf-8') as fh:
        handlers = [r for r in csv.DictReader(fh)
                    if r['name'].startswith('KaiserWindow::Cm')]
    for h in handlers:
        body = bodies.get(h['address'], '')
        callees = sorted(set(re.findall(r'FUN_(10[0-9a-f]{2})_([0-9a-f]{4})',
                                        body.split('\n', 1)[-1])))
        game = [f'{s}:{o}' for s, o in callees
                if seg_of(f'{s}:{o}') not in LIBRARY_SEGS
                and f'{s}:{o}' != h['address']]  # own name in signature
        cmd = h['name'].split('::Cm', 1)[1]
        if len(game) == 1:
            rows.append([game[0], f'Do_{cmd}', 'func',
                         f"Called by menu handler {h['name']} "
                         f"({h['address']}), gets the current player record"])
        else:
            skipped.append(f"{h['name']}: {len(game)} game callees")
    with open(os.path.join(HERE, 'names', '26_actions.csv'), 'w',
              newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['address', 'name', 'kind', 'comment'])
        w.writerows(rows)
    print(f'{len(rows)} action functions named, {len(skipped)} skipped')
    for s in skipped:
        print('  skipped', s)


if __name__ == '__main__':
    main()
