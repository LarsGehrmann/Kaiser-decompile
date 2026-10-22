"""Generate differential test vectors for ported rule functions.

For each vector: take a real savegame, pick a player, change a few fields at
random (to reach many branches), set RandSeed, call the ORIGINAL function in
the emulator and record its return value, the new RandSeed and every byte it
changed in the player array and the game header.

Line format (space separated key=value):
  func=NAME save=FILE p=IDX seed=S args=a,b mut=off:hex;... ->
  ret=V seedout=S2 diff=off:hex;... hdiff=off:hex;...
  (ret=E<code> if the original stopped with a runtime error)
Offsets in mut/diff are relative to the start of the player array.

Usage: tools/.venv/bin/python -I tools/emu/gen_rule_vectors.py FUNC[,FUNC] N [SEED]
       > port/tests/rules.vec
"""
import glob
import os
import random
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
from kaiser_emu import KaiserEmu, EmuError  # noqa: E402
import kaiser_structs as ks  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SAVES = sorted(glob.glob(os.path.join(ROOT, 'Kaiser', '*.KSR')) +
               glob.glob(os.path.join(ROOT, 'Kaiser', '*.ksr')))
HDR_DS = 0x6108
PSIZE = ks.PLAYER_SIZE

# name: (address, [args], return kind, fields worth mutating)
# args: 'P' = far pointer to the test player, 'A' = far pointer to the player
#       array, 'N' = num_players (byte), 'I' = player index (byte),
#       'Q' = harvest quality 1..5 (byte)
POP = ['population', 'grain_distributed', 'spell', 'event', 'flags_5bd_q',
       'birth_rate', 'death_rate', 'happiness', 'tax_rate', 'justice',
       'asylum_law', 'fame', 'title', 'cpu_level', 'taverns', 'army1_count',
       'army2_count']
ECON = ['population', 'markets', 'mills', 'taverns', 'smithies', 'granaries',
        'warehouses', 'land', 'land_used', 'taler', 'tax_rate', 'justice',
        'happiness', 'spell', 'salt', 'beer', 'wine', 'weapons', 'title',
        'harvest_quality', 'grain', 'palace_parts', 'cathedral_parts',
        'university_parts']
SPECS = {
    'GrainCapacity': ('1068:0885', ['P'], 'long', ECON),
    'SmithyOutput': ('1068:0bd3', ['P'], 'long', ECON),
    'WarehouseFreeSpace': ('1068:2ce7', ['P'], 'long', ECON),
    'FreeBuildingLand': ('1068:2e4c', ['P'], 'long', ECON),
    'CreditLimit': ('1068:1df2', ['P'], 'long', ['title']),
    'TaxIncome': ('1068:1cd8', ['P'], 'long', ECON),
    'JusticeIncome': ('1068:1d60', ['P'], 'long', ECON),
    'WarehouseRent': ('1068:2da4', ['P'], 'long', ECON),
    'Interest': ('1068:290e', ['P'], 'long', ['taler']),
    'IncomeFromBuildings': ('1068:19bd', ['P'], 'long', ECON),
    'ComputeHarvest': ('1068:298f', ['P', 'Q'], 'long', ECON),
    'ImmigrationRate': ('1068:17f3', ['P'], 'real', POP),
    'EmigrationRate': ('1068:18fa', ['P'], 'real', POP),
    'UpdateBirthDeathRates': ('1068:0ee4', ['P'], 'none', POP),
    'UpdateHappiness': ('1068:13a8', ['P'], 'word', POP),
    'UpdateGrainPrice': ('1068:2a08', ['P', 'Q'], 'none', ECON),
    'UnclaimedLand': ('1068:2f86', ['A', 'N'], 'long', ['land']),
}


def field_info(name):
    for off, typ, fname, _ in ks.PLAYER:
        if fname == name:
            return off, typ
    raise KeyError(name)


def r48(x):
    import math
    if x == 0:
        return bytes(6)
    neg = x < 0
    x = abs(x)
    e = math.floor(math.log2(x))
    m = round((x / 2 ** e - 1) * 2 ** 39)
    if m >= 2 ** 39:
        m -= 2 ** 39
        e += 1
    m |= (1 << 39) if neg else 0
    return bytes([e + 129]) + m.to_bytes(5, 'little')


def random_value(rng, name, typ):
    if typ == 'real':
        if rng.random() < 0.1:
            return bytes(6)
        return r48(rng.choice([rng.random(), rng.random() * 1.2, rng.random() * 0.1]))
    if name in ('spell',):
        v = rng.randint(0, 12)
    elif name == 'event':
        v = rng.randint(0, 23)
    elif name == 'title':
        v = rng.randint(0, 10)
    elif name == 'harvest_quality':
        v = rng.randint(1, 5)
    elif name == 'flags_5bd_q':
        v = rng.choice([0, 0x40, 0x80, 0x100, 0x800, rng.getrandbits(16)])
    elif name in ('army1_count', 'army2_count'):
        v = rng.randint(0, 8)
    elif name in ('palace_parts', 'cathedral_parts', 'university_parts'):
        v = rng.randint(0, 12)
    elif typ == 's32':
        v = rng.choice([rng.randint(0, 200), rng.randint(0, 200000),
                        rng.randint(-50000, 2000000), 0])
    elif typ in ('s16', 'u16'):
        v = rng.randint(0, 100) if name == 'fame' else rng.randint(0, 30000)
    else:
        v = rng.randint(0, 255)
    fmt = {'u8': '<B', 's8': '<b', 's16': '<h', 'u16': '<H', 's32': '<i'}[typ]
    if typ == 's8':
        v = max(-128, min(127, v))
    if typ == 'u8':
        v &= 0xFF
    if typ == 's16':
        v = max(-32768, min(32767, v))
    return struct.pack(fmt, v)


def load_save(path):
    raw = open(path, 'rb').read()
    n = raw[1]
    return raw[:ks.HEADER_SIZE], bytearray(raw[ks.HEADER_SIZE:ks.HEADER_SIZE + n * PSIZE]), n


def diff(a, b):
    out, i = [], 0
    while i < len(a):
        if a[i] != b[i]:
            j = i
            while j < len(a) and a[j] != b[j]:
                j += 1
            out.append(f'{i}:{bytes(b[i:j]).hex()}')
            i = j
        else:
            i += 1
    return ';'.join(out)


def main():
    funcs = sys.argv[1].split(',')
    n = int(sys.argv[2])
    rng = random.Random(int(sys.argv[3]) if len(sys.argv) > 3 else 7)
    emu = KaiserEmu()
    sp = emu.scratch_para
    for func in funcs:
        addr, args, ret, fields = SPECS[func]
        for _ in range(n):
            save = rng.choice(SAVES)
            header, players, num = load_save(save)
            p = rng.randrange(num)
            muts = []
            for _ in range(rng.randint(0, 4)):
                fname = rng.choice(fields)
                off, typ = field_info(fname)
                val = random_value(rng, fname, typ)
                muts.append((p * PSIZE + off, val))
            for off, val in muts:
                players[off:off + len(val)] = val
            seed = rng.getrandbits(32)
            emu.reset_ds()
            emu.write(emu.ds_para, HDR_DS, header)
            emu.write(sp, 0, players)
            emu.rand_seed(seed)
            call_args, shown = [], []
            for a in args:
                if a == 'P':
                    call_args.append(('ptr', (sp, p * PSIZE)))
                elif a == 'A':
                    call_args.append(('ptr', (sp, 0)))
                elif a == 'N':
                    call_args.append(('word', num))
                    shown.append(str(num))
                elif a == 'I':
                    call_args.append(('word', p))
                    shown.append(str(p))
                elif a == 'Q':
                    q = rng.randint(1, 5)
                    call_args.append(('word', q))
                    shown.append(str(q))
            try:
                ax, dx = emu.call_far(addr, call_args)
                r = emu.last_regs
                if ret == 'long':
                    rv = str(struct.unpack('<i', struct.pack('<HH', ax, dx))[0])
                elif ret == 'word':
                    rv = str(ax)
                elif ret == 'byte':
                    rv = str(ax & 0xFF)
                elif ret == 'real':
                    rv = struct.pack('<HHH', ax, r['bx'], dx).hex()
                else:
                    rv = '-'
            except EmuError:
                if emu.last_runerror is None:
                    raise
                rv = f'E{emu.last_runerror}'
            after = emu.read(sp, 0, len(players))
            hafter = emu.read(emu.ds_para, HDR_DS, ks.HEADER_SIZE)
            mut = ';'.join(f'{o}:{v.hex()}' for o, v in muts)
            print(f'func={func} save={os.path.basename(save)} p={p} seed={seed} '
                  f'args={",".join(shown) or "-"} mut={mut or "-"} -> ret={rv} '
                  f'seedout={emu.rand_seed()} diff={diff(players, after) or "-"} '
                  f'hdiff={diff(header, hafter) or "-"}')


if __name__ == '__main__':
    main()
