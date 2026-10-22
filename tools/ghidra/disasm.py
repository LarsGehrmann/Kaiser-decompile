"""Annotated disassembly of functions, for reading formulas.

The decompiler drops the register operands of Borland's Real48 helpers
(DX:BX:AX hold a 6-byte Real), so constants like tax rates vanish from the
C output. This prints the instructions and adds:
  - decoded Real48 constants: MOV AX/BX/DX immediates before a Real call
  - names of called functions
  - for functions that copy the player record by value (rep movsb of
    0x6d5 bytes into a local), the record offset of [BP-x] operands

Usage: tools/.venv/bin/python -I tools/ghidra/disasm.py 1068:19bd [...]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kghidra import open_kaiser  # noqa: E402

PLAYER_SIZE = 0x6d5


def real48(ax, bx, dx):
    b = [ax & 0xFF, ax >> 8, bx & 0xFF, bx >> 8, dx & 0xFF, dx >> 8]
    if b[0] == 0:
        return 0.0
    mant = int.from_bytes(bytes(b[1:6]), 'little')
    sign = -1.0 if mant & (1 << 39) else 1.0
    mant &= (1 << 39) - 1
    return sign * (1.0 + mant / float(1 << 39)) * 2.0 ** (b[0] - 129)


def bp_off(text):
    """'0xf926' or '-0x6da' -> signed BP offset (-0x6da)."""
    v = int(text, 16) if not text.startswith('-') else -int(text[1:], 16)
    return v - 0x10000 if v >= 0x8000 else v


def main():
    targets = sys.argv[1:]
    with open_kaiser() as program:
        af = program.getAddressFactory()
        fm = program.getFunctionManager()
        listing = program.getListing()
        for t in targets:
            func = fm.getFunctionAt(af.getAddress(t)) if ':' in t else None
            if func is None:
                func = next((f for f in fm.getFunctions(True)
                             if f.getName() == t), None)
            if func is None:
                print(f'?? {t}')
                continue
            print(f'==== {func.getName(True)} @ {func.getEntryPoint()}')
            regs = {}
            record_base = None  # BP offset of a by-value player record copy
            insns = list(listing.getInstructions(func.getBody(), True))
            for i, ins in enumerate(insns):
                text = str(ins)
                note = ''
                m = re.match(r'MOV (AX|BX|DX|CX|SI|DI),0x([0-9a-f]+)$', text)
                if m:
                    regs[m.group(1)] = int(m.group(2), 16)
                elif re.match(r'(XOR|SUB) (AX|BX|DX|CX|SI|DI),\2$', text):
                    regs[text.split()[1].split(',')[0]] = 0
                elif re.match(r'MOV (AX|BX|DX|CX|SI|DI),', text):
                    regs.pop(text.split()[1].split(',')[0], None)
                if text.startswith('MOV CX,0x6d5'):
                    # LEA DI,[BP + x] (x = negative offset) precedes the copy
                    for back in insns[max(0, i - 6):i]:
                        mb = re.search(r'LEA DI,\[BP \+ (-?0x[0-9a-f]+)\]',
                                       str(back))
                        if mb:
                            record_base = bp_off(mb.group(1))
                if text.startswith('CALLF') or text.startswith('CALL '):
                    refs = ins.getReferencesFrom()
                    name = ''
                    for r in refs:
                        f2 = fm.getFunctionAt(r.getToAddress())
                        if f2:
                            name = f2.getName(True)
                    if name.startswith('System::_Real') or \
                            name.startswith('System::Real'):
                        note = f'  ; {name}'
                        # first operand DX:BX:AX, second DI:SI:CX
                        if all(k in regs for k in ('AX', 'BX', 'DX')):
                            note += (' a=' + f'{real48(regs["AX"], regs["BX"], regs["DX"]):.6g}')
                        if all(k in regs for k in ('CX', 'SI', 'DI')):
                            note += (' b=' + f'{real48(regs["CX"], regs["SI"], regs["DI"]):.6g}')
                    elif name:
                        note = f'  ; {name}'
                    regs = {}
                if record_base is not None:
                    mo = re.search(r'\[BP \+ (-?0x[0-9a-f]+)\]', text)
                    if mo:
                        off = bp_off(mo.group(1)) - record_base
                        if 0 <= off < PLAYER_SIZE:
                            note += f'  ; rec+0x{off:x}'
                print(f'{ins.getAddress()}  {text}{note}')
            print()


if __name__ == '__main__':
    main()
