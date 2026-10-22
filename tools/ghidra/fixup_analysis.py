"""Fix gaps left by Ghidra's auto-analysis of kaiser.exe.

- The NE entry point (program main / unit-init chain) is labelled 'entry'
  but never disassembled: disassemble it and create the function.
- Re-run auto-analysis so the new code gets references and functions.

Idempotent; safe to re-run.
Usage: tools/.venv/bin/python -I tools/ghidra/fixup_analysis.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kghidra import open_kaiser  # noqa: E402


def main():
    import pyghidra
    from ghidra.app.cmd.disassemble import DisassembleCommand
    from ghidra.app.cmd.function import CreateFunctionCmd
    from ghidra.util.task import TaskMonitor

    with open_kaiser(write=True, description='fixup analysis') as program:
        fm = program.getFunctionManager()
        st = program.getSymbolTable()
        for ep in st.getExternalEntryPointIterator():
            if program.getListing().getInstructionAt(ep) is None:
                DisassembleCommand(ep, None, True).applyTo(
                    program, TaskMonitor.DUMMY)
            if fm.getFunctionAt(ep) is None:
                CreateFunctionCmd(ep).applyTo(program, TaskMonitor.DUMMY)
                print('created function at', ep)
        pyghidra.analyze(program)
        print('functions now:', fm.getFunctionCount())


if __name__ == '__main__':
    main()
