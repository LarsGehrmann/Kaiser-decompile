"""Generate Real48 / Random test vectors by running the original runtime in the emulator.

Each line: op a(12 hex) b(12 hex) -> result(12 hex) or error code / integer.
  add|sub|mul|div  a b  -> result or 'E<code>'
  cmp              a b  -> -1/0/1
  fromlong         v    -> result
  round|trunc      a    -> integer or 'E207'
  random seed range     -> value newseed
  randreal seed         -> result newseed
Usage: tools/.venv/bin/python -I tools/emu/gen_real48_vectors.py N > port/tests/real48.vec
"""
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kaiser_emu import KaiserEmu, EmuError  # noqa: E402

FAR = {'add': '10c8:0e83', 'sub': '10c8:0e89', 'mul': '10c8:0e95',
       'div': '10c8:0e9b', 'cmp': '10c8:0ea5', 'fromlong': '10c8:0ea9',
       'round': '10c8:0eb5'}


def regs(r48):
    return (r48[0] | r48[1] << 8, r48[2] | r48[3] << 8, r48[4] | r48[5] << 8)


def unregs(ax, bx, dx):
    return bytes([ax & 255, ax >> 8, bx & 255, bx >> 8, dx & 255, dx >> 8])


def rand_real(rng):
    kind = rng.random()
    if kind < 0.05:
        return bytes(6)                                   # zero
    b = bytearray(rng.getrandbits(8) for _ in range(6))
    if kind < 0.6:
        b[0] = rng.randint(0x60, 0xa8)                     # typical game range
    elif kind < 0.8:
        b[0] = rng.randint(1, 0xff)                        # anything
    else:
        b[0] = rng.choice([1, 2, 0x7f, 0x80, 0x81, 0xfe, 0xff])
    if rng.random() < 0.2:
        b[1:5] = bytes(4)                                  # short mantissa
    return bytes(b)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20000   # args: N [SEED [OPS]]
    rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1234)
    emu = KaiserEmu()
    out = sys.stdout
    # RunError would jump into the exit code; stop before: detect via CF in
    # the core instead by calling the far wrapper and catching the jump.
    ops = ['add', 'sub', 'mul', 'div', 'cmp', 'add', 'mul',
           'fromlong', 'round', 'trunc', 'random', 'randreal']
    if len(sys.argv) > 3:                 # e.g. "sqrt" or "add,sqrt"
        ops = sys.argv[3].split(',')
    for i in range(n):
        op = rng.choice(ops)
        if op == 'sqrt':
            a = rand_real(rng)
            if rng.random() < 0.7:
                a = bytes([a[0]]) + a[1:5] + bytes([a[5] & 0x7f])   # mostly >= 0
            ra = regs(a)
            try:
                r = emu.call_regs('10c8:0f5c', ax=ra[0], bx=ra[1], dx=ra[2])
                out.write(f'{op} {a.hex()} {unregs(r["ax"], r["bx"], r["dx"]).hex()}\n')
            except EmuError:
                out.write(f'{op} {a.hex()} E{emu.last_runerror}\n')
        elif op in ('add', 'sub', 'mul', 'div', 'cmp'):
            a, b = rand_real(rng), rand_real(rng)
            if rng.random() < 0.1:
                b = bytes([a[0]]) + bytes(rng.getrandbits(8) for _ in range(5))
            ra, rb = regs(a), regs(b)
            try:
                r = emu.call_regs(FAR[op], ax=ra[0], bx=ra[1], dx=ra[2],
                                  cx=rb[0], si=rb[1], di=rb[2])
            except EmuError:
                out.write(f'{op} {a.hex()} {b.hex()} E{emu.last_runerror}\n')
                continue
            if op == 'cmp':
                zf = (r['flags'] >> 6) & 1
                res = 0 if zf else (-1 if r['cf'] else 1)
                out.write(f'{op} {a.hex()} {b.hex()} {res}\n')
            else:
                out.write(f'{op} {a.hex()} {b.hex()} {unregs(r["ax"], r["bx"], r["dx"]).hex()}\n')
        elif op == 'fromlong':
            v = rng.choice([rng.randint(-2**31, 2**31 - 1), rng.randint(-70000, 70000),
                            0, 1, -1, 2**31 - 1, -2**31])
            u = v & 0xFFFFFFFF
            r = emu.call_regs(FAR[op], ax=u & 0xFFFF, dx=u >> 16)
            out.write(f'{op} {v} {unregs(r["ax"], r["bx"], r["dx"]).hex()}\n')
        elif op in ('round', 'trunc'):
            a = rand_real(rng)
            ra = regs(a)
            try:
                if op == 'round':
                    r = emu.call_regs('10c8:0eb5', ax=ra[0], bx=ra[1], dx=ra[2])
                else:
                    r = emu.call_regs('10c8:0ead', ax=ra[0], bx=ra[1], dx=ra[2])
                v = struct.unpack('<i', struct.pack('<HH', r['ax'], r['dx']))[0]
                out.write(f'{op} {a.hex()} {v}\n')
            except EmuError:
                out.write(f'{op} {a.hex()} E{emu.last_runerror}\n')
        elif op == 'random':
            seed, rng_ = rng.getrandbits(32), rng.choice([rng.randint(1, 65535), 2, 10, 100, 0x14a])
            emu.rand_seed(seed)
            ax, dx = emu.call_far('10c8:1342', [('word', rng_)])
            out.write(f'{op} {seed} {rng_} {ax} {emu.rand_seed()}\n')
        else:
            seed = rng.getrandbits(32)
            emu.rand_seed(seed)
            r = emu.call_regs('10c8:135f')
            out.write(f'{op} {seed} {unregs(r["ax"], r["bx"], r["dx"]).hex()} {emu.rand_seed()}\n')


if __name__ == '__main__':
    main()
