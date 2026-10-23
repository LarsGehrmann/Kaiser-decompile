"""How much of the original's code the differential tests execute.

  coverage.py run N [JOBS]   generate N vectors per tested function (every SPECS
                             entry of gen_rule_vectors.py, one process each) with
                             the emulator recording its executed basic blocks
                             (KAISER_COVERAGE), into tools/emu/coverage/; also
                             the whole-battle comparison (battle_compare.py 1)
                             and the simulator comparison (sim_compare.sh, all
                             savegames and four new games, 30 turns)
  coverage.py report         per segment: the code bytes of the functions
                             (ghidra_out/functions.csv) and how many of them ran;
                             the functions reached

The generated vectors are not kept: the checked-in .vec files are the tests.
The vectors of a run are also compared with the port (port/bin/ruletest) and the
report says how many matched.
"""
import collections
import csv
import glob
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, 'coverage')
PY = os.path.join(ROOT, 'tools', '.venv', 'bin', 'python')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

SEGMENT_ROLE = {
    1: 'main window, turn loop', 2: 'AI', 3: 'turn processing', 4: 'war', 5: 'e-mail game',
    6: 'battle aftermath', 7: 'AI', 8: 'menu actions (military, diplomacy)',
    9: 'menu actions (economy, reports)', 10: 'battle window', 11: 'files (INI, annals)',
    12: 'dialog base types', 13: 'main window drawing', 14: 'rule library',
}


def functions():
    names = []
    from gen_rule_vectors import SPECS
    names += list(SPECS)
    try:
        from gen_rule_vectors import DLG_TYPES
        names += ['Dlg_' + t for t in DLG_TYPES]
    except ImportError:
        pass
    return names


def run(n, jobs):
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '*')) + glob.glob(os.path.join(OUT, 'sim', '*')):
        if os.path.isfile(f):
            os.remove(f)

    def one(func):
        env = dict(os.environ, KAISER_COVERAGE=os.path.join(OUT, func + '.cov'),
                   KAISER_EMU_MAX_INSNS='400000000')
        vec = os.path.join(OUT, func + '.vec')
        with open(vec, 'w') as out:
            r = subprocess.run([PY, '-I', os.path.join(HERE, 'gen_rule_vectors.py'), func, str(n), '7'],
                               stdout=out, stderr=subprocess.DEVNULL, env=env, cwd=ROOT)
        t = subprocess.run([os.path.join(ROOT, 'port', 'bin', 'ruletest'), 'Kaiser', vec],
                           capture_output=True, text=True, cwd=ROOT)
        last = (t.stdout.strip().splitlines() or ['?'])[-1]
        return func, r.returncode, last

    def compare(job):
        name, argv = job
        env = dict(os.environ, KAISER_COVERAGE=os.path.join(OUT, name + '.cov'))
        r = subprocess.run(argv, capture_output=True, text=True, env=env, cwd=ROOT)
        lines = r.stdout.strip().splitlines()
        if name == 'sim_compare':
            same = sum(1 for x in lines if ': identical' in x)
            return name, r.returncode, f'{same} of {len(lines)} games identical'
        return name, r.returncode, (lines or ['?'])[-1]

    saves = sorted(glob.glob(os.path.join(ROOT, 'Kaiser', '*.KSR')) +
                   glob.glob(os.path.join(ROOT, 'Kaiser', '*.ksr')))
    compares = [('battle_compare', [PY, os.path.join(HERE, 'battle_compare.py'), '1']),
                ('sim_compare', [os.path.join(HERE, 'sim_compare.sh'), '30', '1',
                                 os.path.join(OUT, 'sim')] + saves +
                 ['new:1:3:1', 'new:1:5:2', 'new:2:4:3', 'new:1:8:4'])]
    with ThreadPoolExecutor(jobs) as ex:
        done = [ex.submit(compare, c) for c in compares]
        for func, rc, last in ex.map(one, functions()):
            print(f'{func:32} {"ok " if rc == 0 else "ERR"} {last}', flush=True)
        for d in done:
            func, rc, last = d.result()
            print(f'{func:32} {"ok " if rc == 0 else "ERR"} {last}', flush=True)


def report():
    from kaiser_emu import KaiserEmu
    emu = KaiserEmu()
    starts = sorted((p * 16, s) for s, p in emu.para.items())
    seg_len = {seg.index: seg.length for seg in emu.ne.segments}

    def seg_of(lin):
        for base, s in reversed(starts):
            if base <= lin:
                return s, lin - base
        return None, None

    covered = collections.defaultdict(set)          # segment -> executed offsets
    for path in glob.glob(os.path.join(OUT, '*.cov')):
        for line in open(path):
            a, n = (int(x, 16) for x in line.split())
            s, off = seg_of(a)
            if s is not None and off < seg_len.get(s, 0):
                covered[s].update(range(off, off + n))
    funcs = collections.defaultdict(list)
    with open(os.path.join(ROOT, 'ghidra_out', 'functions.csv')) as f:
        for row in csv.DictReader(f):
            seg = int(row['segment'])
            off = int(row['address'].split(':')[1], 16)
            funcs[seg].append((off, int(row['size']), row['name']))
    tot_b = tot_c = tot_f = tot_fc = 0
    print(f'{"seg":>3} {"role":36} {"funcs":>5} {"reached":>7} {"bytes":>7} {"executed":>8}  share')
    for seg in sorted(funcs):
        if seg < 1 or seg > 14:
            continue
        fs = funcs[seg]
        b = sum(sz for _, sz, _ in fs)
        c = 0
        reached = 0
        for off, sz, _ in fs:
            k = sum(1 for x in range(off, off + sz) if x in covered[seg])
            c += k
            if k > 8:
                reached += 1
        tot_b += b
        tot_c += c
        tot_f += len(fs)
        tot_fc += reached
        share = 100.0 * c / b if b else 0
        print(f'{seg:>3} {SEGMENT_ROLE.get(seg, ""):36} {len(fs):>5} {reached:>7} {b:>7} {c:>8}  {share:5.1f} %')
    print(f'{"":>3} {"segments 1-14":36} {tot_f:>5} {tot_fc:>7} {tot_b:>7} {tot_c:>8}  '
          f'{100.0 * tot_c / tot_b:5.1f} %')


if __name__ == '__main__':
    if sys.argv[1] == 'run':
        run(int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 4)
    else:
        report()
