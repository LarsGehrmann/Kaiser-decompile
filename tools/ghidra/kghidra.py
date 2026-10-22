"""Shared helper for PyGhidra scripts working on ghidra/Kaiser.gpr.

    from kghidra import open_kaiser
    with open_kaiser(write=True) as program:
        ...  # changes are made inside a transaction and saved on exit

Close the project in the Ghidra GUI first: Ghidra locks it while open.
"""
import contextlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GHIDRA_HOME = Path(os.environ.get('GHIDRA_HOME',
                                  '/opt/homebrew/opt/ghidra/libexec'))
os.environ.setdefault(
    'JAVA_HOME',
    '/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home')

import pyghidra  # noqa: E402

if not pyghidra.started():
    pyghidra.start(install_dir=GHIDRA_HOME)

from ghidra.util.task import TaskMonitor  # noqa: E402


@contextlib.contextmanager
def open_kaiser(write=False, description='script'):
    project = pyghidra.open_project(ROOT / 'ghidra', 'Kaiser')
    try:
        with pyghidra.program_context(project, '/kaiser.exe') as program:
            if not write:
                yield program
                return
            with pyghidra.transaction(program, description):
                yield program
            program.getDomainFile().save(TaskMonitor.DUMMY)
    finally:
        project.close()


def flat_api(program):
    from ghidra.program.flatapi import FlatProgramAPI
    return FlatProgramAPI(program)
