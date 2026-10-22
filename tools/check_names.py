"""Consistency check for tools/ghidra/names/*.csv and the exported function list.

Reports
  - addresses named differently in several files (later file wins in apply_names.py)
  - names used for more than one address (within the same namespace)
  - functions in game segments that are still unnamed (FUN_...) in ghidra_out/functions.csv
Usage: python3 -I tools/check_names.py
"""
import csv
import glob
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = os.path.join(ROOT, 'tools', 'ghidra', 'names')


def main():
    by_addr = defaultdict(list)
    for path in sorted(glob.glob(os.path.join(NAMES, '*.csv'))):
        with open(path, encoding='utf-8') as fh:
            for row in csv.DictReader(fh):
                if row['address'] and not row['address'].startswith('#'):
                    by_addr[row['address']].append((os.path.basename(path),
                                                    row['name']))
    overrides = {a: v for a, v in by_addr.items()
                 if len({n for _, n in v}) > 1}
    final = {a: v[-1][1] for a, v in by_addr.items()}
    by_name = defaultdict(list)
    for a, n in final.items():
        by_name[n].append(a)
    dups = {n: a for n, a in by_name.items() if len(a) > 1}

    print(f'{len(final)} named addresses in {len(glob.glob(NAMES + "/*.csv"))} files')
    print(f'{len(overrides)} addresses renamed by a later file:')
    for a, v in sorted(overrides.items()):
        print(f'  {a}: ' + ' -> '.join(f'{n} ({f})' for f, n in v))
    print(f'{len(dups)} names used for several addresses:')
    for n, a in sorted(dups.items()):
        print(f'  {n}: {", ".join(sorted(a))}')

    funcs = os.path.join(ROOT, 'ghidra_out', 'functions.csv')
    if os.path.exists(funcs):
        rows = [r for r in csv.DictReader(open(funcs))
                if r['segment'] != '0']
        unnamed = [r for r in rows if r['name'].startswith('FUN_')]
        print(f'{len(unnamed)} of {len(rows)} functions still unnamed in the export')
        for r in unnamed[:40]:
            print(f"  seg {r['segment']:>2} {r['address']} size {r['size']}")


if __name__ == '__main__':
    main()
