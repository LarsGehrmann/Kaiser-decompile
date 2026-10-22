"""Print decompiled functions from ghidra_out/decomp by address or name.

Usage: python3 -I tools/fn.py 1010:37b6 [PlayerTurnEnd ...] [--brief]
--brief drops the local variable declarations.
"""
import glob
import os
import re
import sys

DECOMP = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      'ghidra_out', 'decomp')
DECL = re.compile(r'\s+(undefined\d?|int|uint|byte|char|bool|long|ulong|short|'
                  r'ushort|word|dword)\s*\**\s*\w+( \[\w+\])?;$')


def functions():
    for path in sorted(glob.glob(os.path.join(DECOMP, 'seg*.c'))):
        for part in re.split(r'(?m)^// ==== ', open(path, encoding='utf-8').read())[1:]:
            m = re.match(r'(\S+) @ (\S+) ====', part)
            if m:
                yield m.group(1), m.group(2), part


def main():
    brief = '--brief' in sys.argv
    wanted = [a for a in sys.argv[1:] if not a.startswith('--')]
    for name, addr, body in functions():
        if addr in wanted or name in wanted:
            lines = body.splitlines()
            if brief:
                lines = [l for l in lines if l.strip() and not DECL.match(l)]
            print('// ==== ' + '\n'.join(lines))


if __name__ == '__main__':
    main()
