"""Reader for Kaiser savegames (*.KSR).

Layout (from the save/load routines 1050:058b / 1050:07ed):
  header   0x295 bytes  raw copy of the global game record at DS:6108
  players  N x 0x6d5    raw copies of the player records (N = header[1])
  extra    0x192 bytes  only if header.flag_0b and header.mode_0a == 3

Field names are provisional; docs/ksr-format.md tracks the evidence.
Usage:
  python3 -I tools/ksr.py Kaiser/NILSLARS.KSR          dump one save
  python3 -I tools/ksr.py --check Kaiser/*.KSR         verify all saves
"""
import struct
import sys

HEADER_SIZE = 0x295
PLAYER_SIZE = 0x6d5
EXTRA_SIZE = 0x192
MAGIC = 0x7B  # '{' -- also the version number 123 (v1.23)

# (offset, type, name) -- types: u8 s16 u16 s32 real cstr<N> raw<N>
HEADER_FIELDS = [
    (0x00, 'u8', 'magic'),
    (0x01, 'u8', 'num_players'),
    (0x0a, 'u8', 'mode_0a'),           # == 3 -> extra block present
    (0x0b, 'u8', 'flag_0b'),           # != 0 -> RandSeed restored on load
    (0x0e, 's32', 'rand_seed'),        # Random($FFFF) at save time
]

PLAYER_FIELDS = [
    (0x00, 'cstr32', 'name'),
    (0x22, 's16', 'check_salt'),       # input of the checksums
    (0x26, 's32', 'check_a'),          # salt + (val_54 - val_cb)
    (0x54, 's32', 'val_54'),           # probably Taler (goes negative)
    (0xc7, 's32', 'check_c'),          # (val_54 + val_cb) div 1000
    (0xcb, 's32', 'val_cb'),           # probably Land (~100000 at start)
    (0x133, 's32', 'check_b'),         # salt + (val_cb - val_54)
    (0x139, 'cstr40', 'name_139'),     # often a CP name from the string table
]


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
    a = s32(p['check_salt'] + (p['val_54'] - p['val_cb']))
    b = s32(p['check_salt'] + (p['val_cb'] - p['val_54']))
    c = ldiv(p['val_54'] + p['val_cb'], 1000)
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
        if self.header['flag_0b'] and self.header['mode_0a'] == 3:
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
