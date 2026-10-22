"""Export the current state of the Ghidra project into ghidra_out/.

  functions.csv           one row per function (segment, address, size,
                          name, #callers, #callees, called APIs)
  decomp/seg<NN>.c        decompiled C of every function in that segment
  strings.csv             defined strings in the data segment

Re-run after renaming/typing work so the text dump stays in sync.
Usage: tools/.venv/bin/python tools/ghidra/export_all.py [--no-decomp]
"""
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kghidra import ROOT, open_kaiser  # noqa: E402

OUT = ROOT / 'ghidra_out'


def seg_no(block_name):
    digits = ''.join(c for c in block_name if c.isdigit())
    return int(digits) if digits else 0


def main():
    decomp = '--no-decomp' not in sys.argv
    from ghidra.app.decompiler import DecompInterface, DecompileOptions
    from ghidra.util.task import TaskMonitor

    with open_kaiser() as program:
        fm = program.getFunctionManager()
        mem = program.getMemory()
        rows, by_seg = [], {}
        for f in fm.getFunctions(True):
            block = mem.getBlock(f.getEntryPoint())
            seg = seg_no(block.getName()) if block else 0
            callers = f.getCallingFunctions(TaskMonitor.DUMMY)
            callees = f.getCalledFunctions(TaskMonitor.DUMMY)
            apis = sorted(c.getName() for c in callees if c.isExternal())
            rows.append([seg, str(f.getEntryPoint()), f.getBody().getNumAddresses(),
                         f.getName(), len(callers), len(callees), ' '.join(apis)])
            by_seg.setdefault(seg, []).append(f)

        OUT.mkdir(exist_ok=True)
        with open(OUT / 'functions.csv', 'w', newline='') as fh:
            w = csv.writer(fh)
            w.writerow(['segment', 'address', 'size', 'name', 'callers',
                        'callees', 'apis'])
            w.writerows(rows)

        listing = program.getListing()
        with open(OUT / 'strings.csv', 'w', newline='',
                  encoding='utf-8') as fh:
            w = csv.writer(fh)
            w.writerow(['address', 'value'])
            for d in listing.getDefinedData(True):
                if d.hasStringValue():
                    w.writerow([str(d.getAddress()), d.getValue()])

        if decomp:
            ifc = DecompInterface()
            ifc.setOptions(DecompileOptions())
            ifc.openProgram(program)
            (OUT / 'decomp').mkdir(exist_ok=True)
            failed = 0
            for seg, funcs in sorted(by_seg.items()):
                with open(OUT / 'decomp' / f'seg{seg:02d}.c', 'w',
                          encoding='utf-8') as fh:
                    for f in funcs:
                        res = ifc.decompileFunction(f, 60, TaskMonitor.DUMMY)
                        fh.write(f'// ==== {f.getName()} @ '
                                 f'{f.getEntryPoint()} ====\n')
                        if res.decompileCompleted():
                            fh.write(res.getDecompiledFunction().getC())
                        else:
                            failed += 1
                            fh.write(f'// decompile failed: '
                                     f'{res.getErrorMessage()}\n')
                        fh.write('\n')
            ifc.dispose()
            print(f'decompiled {len(rows) - failed}/{len(rows)} functions')
        print(f'{len(rows)} functions in {len(by_seg)} segments')


if __name__ == '__main__':
    main()
