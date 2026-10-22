"""Apply hand-maintained names from tools/ghidra/names/*.csv to Ghidra.

CSV columns: address,name,kind,comment
  address  segment:offset, e.g. 10c8:01ca
  name     new symbol name (may include a namespace: 'System::GetMem')
  kind     'func' (create function if missing) | 'label' | 'noreturn'
  comment  optional plate comment, e.g. the evidence for the name

Keeping names in CSV (not only in the .gpr) means they survive a fresh
re-import and are reviewable in git.
Usage: tools/.venv/bin/python -I tools/ghidra/apply_names.py
"""
import csv
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kghidra import open_kaiser  # noqa: E402

NAMES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'names')


def load_rows():
    rows = []
    for path in sorted(glob.glob(os.path.join(NAMES_DIR, '*.csv'))):
        with open(path, encoding='utf-8') as fh:
            for row in csv.DictReader(fh):
                if row['address'] and not row['address'].startswith('#'):
                    row['_file'] = os.path.basename(path)
                    rows.append(row)
    return rows


def main():
    from ghidra.app.cmd.function import CreateFunctionCmd
    from ghidra.program.model.listing import CodeUnit
    from ghidra.program.model.symbol import SourceType
    from ghidra.util.task import TaskMonitor

    rows = load_rows()
    with open_kaiser(write=True, description='apply names') as program:
        af = program.getAddressFactory()
        fm = program.getFunctionManager()
        st = program.getSymbolTable()
        listing = program.getListing()
        applied = 0
        for row in rows:
            addr = af.getAddress(row['address'])
            if addr is None:
                print(f"{row['_file']}: bad address {row['address']}")
                continue
            kind = (row.get('kind') or 'func').strip()
            ns_name, _, name = row['name'].rpartition('::')
            ns = None
            if ns_name:
                ns = st.getNamespace(ns_name, None) or \
                    st.createNameSpace(None, ns_name, SourceType.USER_DEFINED)
            if kind in ('func', 'noreturn'):
                func = fm.getFunctionAt(addr)
                if func is None:
                    CreateFunctionCmd(addr).applyTo(program,
                                                    TaskMonitor.DUMMY)
                    func = fm.getFunctionAt(addr)
                if func is None:
                    print(f"{row['_file']}: no function at {addr}")
                    continue
                func.setName(name, SourceType.USER_DEFINED)
                if ns is not None:
                    func.setParentNamespace(ns)
                if kind == 'noreturn':
                    func.setNoReturn(True)
            else:
                sym = st.createLabel(addr, name, ns, SourceType.USER_DEFINED)
                sym.setPrimary()
            if row.get('comment'):
                listing.setComment(addr, CodeUnit.PLATE_COMMENT,
                                   row['comment'])
            applied += 1
        print(f'applied {applied}/{len(rows)} names')


if __name__ == '__main__':
    main()
