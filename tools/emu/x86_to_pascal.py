"""Translate the Borland Real48 runtime cores (segment 26, 10c8:0b6e-0e82) into Pascal.

The routines are transliterated instruction by instruction onto a simulated
16-bit register file with CF/ZF/SF, so the port reproduces Borland's rounding
and truncation exactly. Near CALL/RET and the shared code tails become a small
state machine with goto labels.

Input: the annotated disassembly from tools/ghidra/disasm.py (Ghidra syntax).
Output: port/src/real48core.inc (included by port/src/real48.pas).
Usage: python3 -I tools/emu/x86_to_pascal.py ghidra_out/disasm_seg26_real.txt
"""
import re
import sys

ENTRIES = {  # entry point -> Pascal constant
    '0b6e': 'ceSub', '0b72': 'ceAdd', '0c35': 'ceMul', '0d38': 'ceDiv',
    '0daf': 'ceCmp', '0dd9': 'ceFromLong', '0e15': 'ceToLong',
}
W = {'AX', 'BX', 'CX', 'DX', 'SI', 'DI', 'BP', 'SP'}
B = {'AL': ('AX', 0), 'AH': ('AX', 1), 'BL': ('BX', 0), 'BH': ('BX', 1),
     'CL': ('CX', 0), 'CH': ('CX', 1), 'DL': ('DX', 0), 'DH': ('DX', 1)}


def imm(s):
    s = s.strip()
    neg = s.startswith('-')
    v = int(s.lstrip('-'), 0)
    return -v if neg else v


class Op:
    """An operand: register, immediate or [BP+n] memory."""

    def __init__(self, text, size_hint=None):
        t = text.strip()
        self.text = t
        m = re.match(r'(byte|word) ptr \[BP \+ (-?0x[0-9a-f]+)\]', t)
        if m:
            self.kind, self.size, self.off = 'mem', 1 if m.group(1) == 'byte' else 2, imm(m.group(2))
        elif t in W:
            self.kind, self.size = 'reg', 2
        elif t in B:
            self.kind, self.size = 'reg8', 1
        else:
            self.kind, self.size, self.val = 'imm', size_hint, imm(t)

    def get(self):
        if self.kind == 'reg':
            return 'SP' if self.text == 'SP' else f'R.{self.text}'
        if self.kind == 'reg8':
            r, hi = B[self.text]
            return f'Hi(R.{r})' if hi else f'Lo(R.{r})'
        if self.kind == 'mem':
            f = 'MemB' if self.size == 1 else 'MemW'
            return f'{f}(R.BP + {self.off})'
        return str(self.val & (0xFF if self.size == 1 else 0xFFFF))

    def set(self, expr):
        if self.kind == 'reg':
            if self.text == 'SP':
                return f'SP := Word({expr});'
            return f'R.{self.text} := Word({expr});'
        if self.kind == 'reg8':
            r, hi = B[self.text]
            if hi:
                return f'R.{r} := (R.{r} and $00FF) or (Word(Byte({expr})) shl 8);'
            return f'R.{r} := (R.{r} and $FF00) or Byte({expr});'
        if self.kind == 'mem':
            f = 'SetMemB' if self.size == 1 else 'SetMemW'
            return f'{f}(R.BP + {self.off}, {expr});'
        raise ValueError('cannot assign to immediate')


def parse(lines):
    insns = []
    for line in lines:
        m = re.match(r'10c8:([0-9a-f]{4})\s+(\S+)\s*(.*?)(\s+;.*)?$', line.strip())
        if m:
            insns.append((m.group(1), m.group(2), m.group(3).strip()))
    return insns


def translate(insns):
    addrs = [a for a, _, _ in insns]
    targets = set(ENTRIES)
    ret_sites = []
    for i, (a, mn, ops) in enumerate(insns):
        if mn.startswith('J') or mn == 'CALL':
            targets.add(ops.split(':')[-1])
        if mn == 'CALL':
            ret_sites.append(insns[i + 1][0])
            targets.add(insns[i + 1][0])
    out = []
    emit = out.append
    for i, (a, mn, ops) in enumerate(insns):
        if a in targets:
            emit(f'L{a}:')
        args = [x for x in re.split(r',(?![^\[]*\])', ops) if x] if ops else []
        if mn.startswith('J') or mn == 'CALL':
            args = []          # branch targets are handled below
        size = None
        if args:
            d = Op(args[0])
            size = d.size
        ops_ = [Op(x, size) for x in args]
        bits = 8 if size == 1 else 16
        mask = '$FF' if size == 1 else '$FFFF'
        top = '$80' if size == 1 else '$8000'

        def flags_logic(res):
            return (f'T := {res}; {ops_[0].set("T")} R.CF := False; '
                    f'R.ZF := (T and {mask}) = 0; R.SF := (T and {top}) <> 0;')

        if mn == 'MOV':
            emit(ops_[0].set(ops_[1].get()))
        elif mn == 'XCHG':
            emit(f'T := {ops_[0].get()}; {ops_[0].set(ops_[1].get())} {ops_[1].set("T")}')
        elif mn in ('OR', 'AND', 'XOR'):
            op = {'OR': 'or', 'AND': 'and', 'XOR': 'xor'}[mn]
            emit(flags_logic(f'({ops_[0].get()} {op} {ops_[1].get()}) and {mask}'))
        elif mn == 'TEST':
            emit(f'T := ({ops_[0].get()} and {ops_[1].get()}) and {mask}; R.CF := False; '
                 f'R.ZF := T = 0; R.SF := (T and {top}) <> 0;')
        elif mn in ('ADD', 'ADC', 'SUB', 'SBB', 'CMP'):
            carry = ' + Ord(R.CF)' if mn in ('ADC', 'SBB') else ''
            if mn in ('ADD', 'ADC'):
                emit(f'U := LongWord({ops_[0].get()}) + LongWord({ops_[1].get()}){carry}; '
                     f'R.CF := U > {mask}; T := U and {mask}; {ops_[0].set("T")} '
                     f'R.ZF := T = 0; R.SF := (T and {top}) <> 0;')
            else:
                store = '' if mn == 'CMP' else ops_[0].set('T') + ' '
                emit(f'U := LongWord({ops_[0].get()}) - LongWord({ops_[1].get()}){carry.replace("+", "-")}; '
                     f'R.CF := LongInt(U) < 0; T := U and {mask}; {store}'
                     f'R.ZF := T = 0; R.SF := (T and {top}) <> 0;')
        elif mn == 'NEG':
            emit(f'R.CF := {ops_[0].get()} <> 0; T := (0 - LongInt({ops_[0].get()})) and {mask}; '
                 f'{ops_[0].set("T")} R.ZF := T = 0; R.SF := (T and {top}) <> 0;')
        elif mn in ('INC', 'DEC'):
            d = '+ 1' if mn == 'INC' else '- 1'
            emit(f'T := (LongInt({ops_[0].get()}) {d}) and {mask}; {ops_[0].set("T")} '
                 f'R.ZF := T = 0; R.SF := (T and {top}) <> 0;')
        elif mn == 'NOT':
            emit(ops_[0].set(f'(not {ops_[0].get()}) and {mask}'))
        elif mn in ('SHL', 'SHR'):
            cnt = ops_[1].get() if ops_[1].kind != 'imm' else str(ops_[1].val)
            if mn == 'SHL':
                emit(f'N := {cnt} and 31; if N > 0 then begin U := LongWord({ops_[0].get()}) shl N; '
                     f'R.CF := (U shr {bits}) and 1 = 1; T := U and {mask}; {ops_[0].set("T")} '
                     f'R.ZF := T = 0; R.SF := (T and {top}) <> 0; end;')
            else:
                emit(f'N := {cnt} and 31; if N > 0 then begin U := LongWord({ops_[0].get()}); '
                     f'R.CF := (U shr (N - 1)) and 1 = 1; T := (U shr N) and {mask}; {ops_[0].set("T")} '
                     f'R.ZF := T = 0; R.SF := (T and {top}) <> 0; end;')
        elif mn in ('RCL', 'RCR'):
            assert ops_[1].kind == 'imm' and ops_[1].val == 1, (a, mn, ops)
            if mn == 'RCL':
                emit(f'U := (LongWord({ops_[0].get()}) shl 1) or Ord(R.CF); R.CF := (U shr {bits}) and 1 = 1; '
                     f'{ops_[0].set(f"U and {mask}")}')
            else:
                emit(f'U := LongWord({ops_[0].get()}) or (LongWord(Ord(R.CF)) shl {bits}); '
                     f'R.CF := U and 1 = 1; {ops_[0].set(f"U shr 1")}')
        elif mn == 'MUL':
            if ops_[0].size == 1:
                emit(f'R.AX := Word(Lo(R.AX) * {ops_[0].get()}); R.CF := Hi(R.AX) <> 0;')
            else:
                emit(f'U := LongWord(R.AX) * LongWord({ops_[0].get()}); R.AX := U and $FFFF; '
                     f'R.DX := U shr 16; R.CF := R.DX <> 0;')
        elif mn == 'PUSH':
            emit(f'Push({ops_[0].get()});')
        elif mn == 'POP':
            emit(f'{ops_[0].set("Pop")}')
        elif mn == 'PUSHF':
            emit('Push(Ord(R.CF) or (Ord(R.ZF) shl 6) or (Ord(R.SF) shl 7));')
        elif mn == 'POPF':
            emit('T := Pop; R.CF := T and 1 <> 0; R.ZF := T and $40 <> 0; R.SF := T and $80 <> 0;')
        elif mn == 'CMC':
            emit('R.CF := not R.CF;')
        elif mn == 'STC':
            emit('R.CF := True;')
        elif mn == 'CLC':
            emit('R.CF := False;')
        elif mn == 'JMP':
            emit(f'goto L{ops.split(":")[-1]};')
        elif mn.startswith('J'):
            cond = {'JZ': 'R.ZF', 'JNZ': 'not R.ZF', 'JC': 'R.CF', 'JNC': 'not R.CF',
                    'JS': 'R.SF', 'JNS': 'not R.SF', 'JBE': 'R.CF or R.ZF',
                    'JA': 'not R.CF and not R.ZF'}[mn]
            emit(f'if {cond} then goto L{ops.split(":")[-1]};')
        elif mn == 'CALL':
            ret = insns[i + 1][0]
            emit(f'PushRet({ret_sites.index(ret) + 1}); goto L{ops.split(":")[-1]};')
        elif mn == 'RET':
            emit('case PopRet of')
            emit('  0: Exit;')
            for k, r in enumerate(ret_sites):
                emit(f'  {k + 1}: goto L{r};')
            emit('end;')
        else:
            raise ValueError(f'unsupported instruction at {a}: {mn} {ops}')
    labels = sorted(targets & set(addrs))
    head = ['{ Generated by tools/emu/x86_to_pascal.py from the Borland runtime of',
            '  kaiser.exe (10c8:0b6e-0e82). Do not edit by hand. }',
            'label ' + ', '.join(f'L{x}' for x in labels) + ';',
            'begin',
            '  RetTop := 0; SP := Length(Stack);',
            '  case Entry of']
    for a, name in ENTRIES.items():
        head.append(f'    {name}: goto L{a};')
    head.append('  end;')
    return '\n'.join(head + ['  ' + l if not l.startswith('L') else l for l in out] + ['end;'])


def main():
    lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
    insns = sorted({x[0]: x for x in parse(lines) if '0b6e' <= x[0] <= '0e82'}.values())
    code = translate(insns)
    out = sys.argv[2] if len(sys.argv) > 2 else 'port/src/real48core.inc'
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write(code + '\n')
    print(f'{len(insns)} instructions -> {out}')


if __name__ == '__main__':
    main()
