"""Compare whole AI-vs-AI battles of the port and the emulated original.

Usage: battle_compare.py SEEDS [MAXTICKS]

For every savegame, for pairs of players that both have a Heer with some
attack or defence (attacker i, defender i+1), field and city battle, SEEDS
seeds: port/bin/ksrbattle against tools/emu/battle_original.py. Prints the
differing battles and a summary.
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
from gen_rule_vectors import load_save, PSIZE   # noqa: E402


def fit(players, i):
    n = players[i * PSIZE + 0x137]
    units = [players[i * PSIZE + 0xfc + k * 0x3d:][:0x3d] for k in range(1, n + 1)]
    return n > 0 and sum(u[0x1b] + u[0x1c] for u in units) > 0 and all(u[0x1d] > 0 for u in units)


def main():
    seeds = int(sys.argv[1])
    max_ticks = sys.argv[2] if len(sys.argv) > 2 else '5000'
    saves = sorted(glob.glob(os.path.join(ROOT, 'Kaiser', '*.KSR')) +
                   glob.glob(os.path.join(ROOT, 'Kaiser', '*.ksr')))
    same = diff = 0
    for save in saves:
        _, players, num = load_save(save)
        for a in range(num):
            d = (a + 1) % num
            if a == d or not fit(players, a) or not fit(players, d):
                continue
            for city in (0, 1):
                for seed in range(1, seeds + 1):
                    args = [save, str(a), str(d), str(city), str(seed), max_ticks]
                    port = subprocess.run([os.path.join(ROOT, 'port', 'bin', 'ksrbattle')] + args,
                                          capture_output=True, text=True).stdout.strip()
                    orig = subprocess.run([os.path.join(ROOT, 'tools', '.venv', 'bin', 'python'),
                                           os.path.join(HERE, 'battle_original.py')] + args,
                                          capture_output=True, text=True)
                    o = orig.stdout.strip() or orig.stderr.strip().splitlines()[-1]
                    if port == o:
                        same += 1
                    else:
                        diff += 1
                        print(f'DIFF {os.path.basename(save)} {a} {d} {city} {seed}\n  port {port}\n  orig {o}')
                    sys.stdout.flush()
    print(f'{same} battles identical, {diff} different')


if __name__ == '__main__':
    main()
