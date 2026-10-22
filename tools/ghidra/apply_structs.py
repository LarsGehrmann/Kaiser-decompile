"""Create Kaiser's record types in Ghidra from tools/kaiser_structs.py.

- TGameHeader (0x295) placed over the global game record at DS:6108
- TPlayer (0x6d5)
- KaiserWindow (0x4959) with players: TPlayer[10] at +0x41
- Self (param_1) of every KaiserWindow:: method typed KaiserWindow far *

Idempotent: existing types are replaced.
Usage: tools/.venv/bin/python -I tools/ghidra/apply_structs.py
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kghidra import open_kaiser  # noqa: E402

# load by path: putting tools/ on sys.path would let tools/ghidra/ shadow
# the 'ghidra' Java package
_spec = importlib.util.spec_from_file_location(
    'kaiser_structs', os.path.join(os.path.dirname(HERE), 'kaiser_structs.py'))
_ks = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ks)
HEADER, HEADER_SIZE = _ks.HEADER, _ks.HEADER_SIZE
PLAYER, PLAYER_SIZE = _ks.PLAYER, _ks.PLAYER_SIZE
PLAYER_PTR_PARAMS = _ks.PLAYER_PTR_PARAMS

WINDOW_SIZE = 0x4959
WINDOW_FIELDS = [
    (0x41, 'players', 'TPlayer[10]'),
    (0x4493, 'extra_block', 'byte[0x192]'),
    (0x4625, 'save_file', 'char[13]'),
    (0x4632, 'save_path', 'char[256]'),
]


def main():
    from ghidra.program.model.data import (
        ArrayDataType, ByteDataType, CategoryPath, CharDataType,
        DataTypeConflictHandler, PointerDataType, SignedByteDataType,
        SignedDWordDataType, SignedWordDataType, StructureDataType,
        TypedefDataType, WordDataType)
    from ghidra.program.model.data import DataUtilities
    from ghidra.program.model.listing import ParameterImpl
    from ghidra.program.model.listing.Function import FunctionUpdateType
    from ghidra.program.model.symbol import SourceType

    cat = CategoryPath('/Kaiser')
    real48 = TypedefDataType(cat, 'Real48',
                             ArrayDataType(ByteDataType.dataType, 6, 1))
    simple = {'u8': ByteDataType.dataType, 's8': SignedByteDataType.dataType,
              'u16': WordDataType.dataType, 's16': SignedWordDataType.dataType,
              's32': SignedDWordDataType.dataType, 'real': real48}

    def dtype(t):
        if t in simple:
            return simple[t]
        if t.startswith('cstr'):
            return ArrayDataType(CharDataType.dataType, int(t[4:]), 1)
        if t.startswith('raw'):
            return ArrayDataType(ByteDataType.dataType, int(t[3:]), 1)
        raise ValueError(t)

    def struct(name, size, fields):
        s = StructureDataType(cat, name, size)
        for off, typ, fname, comment in fields:
            dt = dtype(typ)
            s.replaceAtOffset(off, dt, dt.getLength(), fname, comment)
        return s

    with open_kaiser(write=True, description='apply structs') as program:
        dtm = program.getDataTypeManager()
        replace = DataTypeConflictHandler.REPLACE_HANDLER
        hdr = dtm.addDataType(struct('TGameHeader', HEADER_SIZE, HEADER),
                              replace)
        player = dtm.addDataType(struct('TPlayer', PLAYER_SIZE, PLAYER),
                                 replace)
        win = StructureDataType(cat, 'KaiserWindow', WINDOW_SIZE)
        for off, fname, spec in WINDOW_FIELDS:
            if spec == 'TPlayer[10]':
                dt = ArrayDataType(player, 10, PLAYER_SIZE)
            elif spec.startswith('byte['):
                dt = ArrayDataType(ByteDataType.dataType,
                                   int(spec[5:-1], 0), 1)
            else:
                dt = ArrayDataType(CharDataType.dataType,
                                   int(spec[5:-1], 0), 1)
            win.replaceAtOffset(off, dt, dt.getLength(), fname, None)
        win = dtm.addDataType(win, replace)

        # global game record
        af = program.getAddressFactory()
        addr = af.getAddress('10d0:6108')
        DataUtilities.createData(
            program, addr, hdr, -1,
            DataUtilities.ClearDataMode.CLEAR_ALL_CONFLICT_DATA)
        st = program.getSymbolTable()
        st.createLabel(addr, 'GameHeader', SourceType.USER_DEFINED) \
            .setPrimary()

        # Self of KaiserWindow methods
        far_win = PointerDataType(win, 4, dtm)
        from ghidra.app.decompiler import DecompInterface
        from ghidra.program.model.pcode import HighFunctionDBUtil
        from ghidra.util.task import TaskMonitor
        ifc = DecompInterface()
        ifc.openProgram(program)
        def commit_params(f):
            res = ifc.decompileFunction(f, 60, TaskMonitor.DUMMY)
            if res.decompileCompleted():
                HighFunctionDBUtil.commitParamsToDatabase(
                    res.getHighFunction(), True,
                    HighFunctionDBUtil.ReturnCommitOption.NO_COMMIT,
                    SourceType.ANALYSIS)

        far_player = PointerDataType(player, 4, dtm)
        typed_players = 0
        for f in program.getFunctionManager().getFunctions(True):
            idx = PLAYER_PTR_PARAMS.get(f.getName())
            if idx is None:
                continue
            if f.getParameterCount() == 0:
                commit_params(f)
            params = list(f.getParameters())
            if idx >= len(params) or params[idx].getLength() != 4:
                print('cannot type player param of', f.getName())
                continue
            params[idx] = ParameterImpl('player', far_player, program)
            f.replaceParameters(
                FunctionUpdateType.DYNAMIC_STORAGE_FORMAL_PARAMS, True,
                SourceType.USER_DEFINED, params)
            typed_players += 1

        typed = 0
        for f in program.getFunctionManager().getFunctions(True):
            if f.getParentNamespace().getName() != 'KaiserWindow':
                continue
            if f.getParameterCount() == 0:
                # parameters only exist as decompiler guesses: commit them
                res = ifc.decompileFunction(f, 60, TaskMonitor.DUMMY)
                if not res.decompileCompleted():
                    continue
                HighFunctionDBUtil.commitParamsToDatabase(
                    res.getHighFunction(), True,
                    HighFunctionDBUtil.ReturnCommitOption.NO_COMMIT,
                    SourceType.ANALYSIS)
            params = list(f.getParameters())
            if not params or params[0].getLength() != 4:
                continue
            params[0] = ParameterImpl('Self', far_win, program)
            f.replaceParameters(
                FunctionUpdateType.DYNAMIC_STORAGE_FORMAL_PARAMS, True,
                SourceType.USER_DEFINED, params)
            typed += 1
        print(f'structs applied; Self typed in {typed} KaiserWindow methods, '
              f'player param in {typed_players} functions')


if __name__ == '__main__':
    main()
