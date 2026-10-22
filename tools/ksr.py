"""Reader for Kaiser savegames (*.KSR).

Layout (from the save/load routines 1050:058b / 1050:07ed):
  header   0x295 bytes  raw copy of the global game record at DS:6108
  players  N x 0x6d5    raw copies of the player records (N = header[1])
  extra    0x192 bytes  only if header.email_game_q and game_state == 3

Field layouts live in tools/kaiser_structs.py; docs/ksr-format.md tracks
the evidence.
Usage:
  python3 -I tools/ksr.py Kaiser/NILSLARS.KSR          dump one save
  python3 -I tools/ksr.py --check Kaiser/*.KSR         verify all saves
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kaiser_structs import (EXTRA_SIZE, HEADER_FIELDS, HEADER_SIZE,  # noqa: E402,F401
                            PLAYER_FIELDS, PLAYER_SIZE)

MAGIC = 0x7B  # '{' -- also the version number 123 (v1.23)


def real48(b):
    """Decode a Turbo Pascal 6-byte Real."""
    exp = b[0]
    if exp == 0:
        return 0.0
    mant = int.from_bytes(b[1:6], 'little')
    sign = -1.0 if mant & (1 << 39) else 1.0
    mant &= (1 << 39) - 1
    return sign * (1.0 + mant / float(1 << 39)) * 2.0 ** (exp - 129)


def read_field(data, off, typ):
    if typ == 'u8':
        return data[off]
    if typ == 's16':
        return struct.unpack_from('<h', data, off)[0]
    if typ == 'u16':
        return struct.unpack_from('<H', data, off)[0]
    if typ == 's32':
        return struct.unpack_from('<i', data, off)[0]
    if typ == 'real':
        return real48(data[off:off + 6])
    if typ.startswith('cstr'):
        n = int(typ[4:])
        return data[off:off + n].split(b'\0')[0].decode('cp1252')
    if typ.startswith('raw'):
        n = int(typ[3:])
        return data[off:off + n].hex(' ')
    raise ValueError(typ)


def parse_fields(data, fields):
    return {name: read_field(data, off, typ) for off, typ, name in fields}


def ldiv(a, b):
    """Pascal 'div': truncates toward zero."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


def s32(v):
    return ((v + 0x80000000) & 0xFFFFFFFF) - 0x80000000


def checksums_ok(p):
    a = s32(p['v22_q'] + (p['v54_q'] - p['vcb_q']))
    b = s32(p['v22_q'] + (p['vcb_q'] - p['v54_q']))
    c = ldiv(p['v54_q'] + p['vcb_q'], 1000)
    return a == p['check_a'] and b == p['check_b'] and c == p['check_c']


class Save:
    def __init__(self, path):
        self.path = path
        self.raw = open(path, 'rb').read()
        self.header_raw = self.raw[:HEADER_SIZE]
        self.header = parse_fields(self.header_raw, HEADER_FIELDS)
        n = self.header['num_players']
        self.players_raw = [
            self.raw[HEADER_SIZE + i * PLAYER_SIZE:
                     HEADER_SIZE + (i + 1) * PLAYER_SIZE] for i in range(n)]
        self.players = [parse_fields(p, PLAYER_FIELDS)
                        for p in self.players_raw]
        expected = HEADER_SIZE + n * PLAYER_SIZE
        if self.header['email_game_q'] and self.header['game_state'] == 3:
            expected += EXTRA_SIZE
        self.size_ok = len(self.raw) == expected

    def problems(self):
        out = []
        if self.header['magic'] != MAGIC:
            out.append(f"bad magic 0x{self.header['magic']:02x}")
        if not self.size_ok:
            out.append(f'size {len(self.raw)} does not match header')
        for i, p in enumerate(self.players):
            if not checksums_ok(p):
                out.append(f"player {i} ({p['name']}): checksum mismatch")
        return out


def main(argv):
    check = '--check' in argv
    paths = [a for a in argv if not a.startswith('--')]
    bad = 0
    for path in paths:
        s = Save(path)
        probs = s.problems()
        if check:
            status = 'OK ' if not probs else 'BAD'
            bad += bool(probs)
            print(f"{status} {path}  players={s.header['num_players']}"
                  + (f"  {'; '.join(probs)}" if probs else ''))
            continue
        print(f'== {path}')
        for k, v in s.header.items():
            print(f'  {k:<12} {v}')
        for i, p in enumerate(s.players):
            print(f'  -- player {i}')
            for k, v in p.items():
                print(f'     {k:<12} {v}')
        for prob in probs:
            print('  !!', prob)
    if check:
        print(f'{len(paths) - bad}/{len(paths)} saves pass')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
