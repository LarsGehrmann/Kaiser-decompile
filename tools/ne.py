"""Minimal parser for 16-bit Windows NE executables.

Covers what we need for kaiser.exe: header, segment table + relocations,
resource table, entry table, name tables and imports. Import ordinals are
resolved to API names via Wine's 16-bit .spec files in tools/specs/.
"""
import os
import re
import struct
from dataclasses import dataclass, field

SPEC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specs')
SPEC_FILES = {
    'KERNEL': 'krnl386.exe16.spec',
    'USER': 'user.exe16.spec',
    'GDI': 'gdi.exe16.spec',
    'MMSYSTEM': 'mmsystem.dll16.spec',
    'COMMDLG': 'commdlg.dll16.spec',
    'KEYBOARD': 'keyboard.drv16.spec',
}

RT_NAMES = {
    1: 'CURSOR', 2: 'BITMAP', 3: 'ICON', 4: 'MENU', 5: 'DIALOG',
    6: 'STRING', 7: 'FONTDIR', 8: 'FONT', 9: 'ACCELERATOR', 10: 'RCDATA',
    12: 'GROUP_CURSOR', 14: 'GROUP_ICON', 16: 'VERSION',
}

SEG_DATA = 0x0001
SEG_MOVABLE = 0x0010
SEG_PRELOAD = 0x0040
SEG_RELOCINFO = 0x0100
SEG_DISCARDABLE = 0x1000

RELOC_SRC = {0: 'LOBYTE', 2: 'SEGMENT', 3: 'FAR_ADDR', 5: 'OFFSET',
             11: 'FAR48', 13: 'OFFSET32'}
RELOC_TARGET = {0: 'INTERNALREF', 1: 'IMPORTORDINAL', 2: 'IMPORTNAME',
                3: 'OSFIXUP'}


def load_spec(module):
    """Return {ordinal: name} for a Windows 3.x system module."""
    fname = SPEC_FILES.get(module.upper())
    names = {}
    if not fname:
        return names
    for line in open(os.path.join(SPEC_DIR, fname), encoding='utf-8'):
        line = line.split('#')[0].strip()
        m = re.match(r'(\d+)\s+(\S+)\s+(?:-\S+\s+)*([A-Za-z_@?$][\w@?$]*)',
                     line)
        if m:
            names[int(m.group(1))] = m.group(3)
    return names


@dataclass
class Reloc:
    src_type: int
    flags: int
    offset: int          # offset of the (first) fixup site in the segment
    target: tuple        # depends on flags & 3, see RELOC_TARGET
    sites: list = field(default_factory=list)  # all chained fixup sites

    @property
    def kind(self):
        return RELOC_TARGET[self.flags & 3]

    @property
    def additive(self):
        return bool(self.flags & 4)


@dataclass
class Segment:
    index: int           # 1-based, as used by NE references
    file_offset: int
    length: int          # bytes in file
    flags: int
    min_alloc: int
    data: bytes
    relocs: list

    @property
    def is_data(self):
        return bool(self.flags & SEG_DATA)

    def flag_str(self):
        parts = ['DATA' if self.is_data else 'CODE']
        if self.flags & SEG_MOVABLE:
            parts.append('MOVABLE')
        if self.flags & SEG_PRELOAD:
            parts.append('PRELOAD')
        if self.flags & SEG_DISCARDABLE:
            parts.append('DISCARDABLE')
        return ' '.join(parts)


@dataclass
class Resource:
    type_id: object      # int for standard types, str for named types
    res_id: object       # int or str
    file_offset: int
    length: int
    flags: int
    data: bytes

    @property
    def type_name(self):
        if isinstance(self.type_id, int):
            return RT_NAMES.get(self.type_id, f'TYPE_{self.type_id}')
        return self.type_id


class NEFile:
    def __init__(self, path):
        self.path = path
        self.raw = open(path, 'rb').read()
        if self.raw[:2] != b'MZ':
            raise ValueError('not an MZ executable')
        self.ne_off = self.u16(0x3C) | (self.u16(0x3E) << 16)
        if self.raw[self.ne_off:self.ne_off + 2] != b'NE':
            raise ValueError('no NE header')
        self._parse_header()
        self.modules = self._parse_modules()
        self.segments = self._parse_segments()
        self.resources = self._parse_resources()
        self.resident_names = self._parse_names(
            self.ne_off + self.restab_off, None)
        self.nonresident_names = self._parse_names(
            self.nrestab_off, self.nrestab_off + self.nrestab_len)
        self.entries = self._parse_entries()

    # -- primitives ---------------------------------------------------
    def u8(self, off):
        return self.raw[off]

    def u16(self, off):
        return struct.unpack_from('<H', self.raw, off)[0]

    def u32(self, off):
        return struct.unpack_from('<I', self.raw, off)[0]

    def pstr(self, off):
        n = self.raw[off]
        return self.raw[off + 1:off + 1 + n].decode('cp1252')

    # -- tables -------------------------------------------------------
    def _parse_header(self):
        o = self.ne_off
        h = struct.unpack_from('<2sBBHHI16HIHHHBB', self.raw, o)
        (_, self.linker_ver, self.linker_rev, self.enttab_off,
         self.enttab_len, self.crc, self.flags, self.autodata_seg,
         self.heap_size, self.stack_size, ip, cs, sp, ss,
         self.seg_count, self.mod_count, self.nrestab_len,
         self.segtab_off, self.rsrctab_off, self.restab_off,
         self.modtab_off, self.imptab_off, self.nrestab_off,
         self.movable_entries, self.align_shift, self.rsrc_seg_count,
         self.target_os, self.os_flags) = h
        self.entry_point = (cs, ip)
        self.initial_stack = (ss, sp)
        if len(self.raw) > o + 0x3E:
            self.expected_win_ver = self.u16(o + 0x3E)

    def _parse_modules(self):
        mods = []
        for i in range(self.mod_count):
            name_off = self.u16(self.ne_off + self.modtab_off + 2 * i)
            mods.append(self.pstr(self.ne_off + self.imptab_off + name_off))
        return mods

    def import_name(self, name_off):
        return self.pstr(self.ne_off + self.imptab_off + name_off)

    def _parse_segments(self):
        segs = []
        base = self.ne_off + self.segtab_off
        for i in range(self.seg_count):
            sector, length, flags, min_alloc = struct.unpack_from(
                '<HHHH', self.raw, base + 8 * i)
            file_off = sector << self.align_shift
            if sector and length == 0:
                length = 0x10000
            data = self.raw[file_off:file_off + length] if sector else b''
            relocs = []
            if sector and flags & SEG_RELOCINFO:
                relocs = self._parse_relocs(file_off + length, data)
            segs.append(Segment(i + 1, file_off, length, flags, min_alloc,
                                data, relocs))
        return segs

    def _parse_relocs(self, off, seg_data):
        count = self.u16(off)
        out = []
        for i in range(count):
            p = off + 2 + 8 * i
            src, flags, site, a, b = struct.unpack_from('<BBHHH', self.raw, p)
            kind = flags & 3
            if kind == 0:
                # internal ref: a = segment (0xFF = movable, b = entry ord)
                target = (a & 0xFF, b) if (a & 0xFF) != 0xFF else (0xFF, b)
            elif kind == 1:
                target = (self.modules[a - 1], b)
            elif kind == 2:
                target = (self.modules[a - 1], self.import_name(b))
            else:
                target = (a, b)
            r = Reloc(src, flags, site, target)
            r.sites = self._chain(seg_data, site, src, r.additive)
            out.append(r)
        return out

    @staticmethod
    def _chain(seg_data, site, src, additive):
        # non-additive fixups form a linked list through the fixup sites
        if additive or src == 0:
            return [site]
        sites, seen = [], set()
        while site != 0xFFFF and site not in seen and site + 2 <= len(seg_data):
            sites.append(site)
            seen.add(site)
            site = struct.unpack_from('<H', seg_data, site)[0]
        return sites

    def _parse_resources(self):
        base = self.ne_off + self.rsrctab_off
        if self.rsrctab_off == self.restab_off:
            return []
        shift = self.u16(base)
        p = base + 2
        out = []

        def ident(v):
            if v & 0x8000:
                return v & 0x7FFF
            return self.pstr(base + v)

        while True:
            type_id = self.u16(p)
            if type_id == 0:
                break
            count = self.u16(p + 2)
            p += 8
            for _ in range(count):
                off, length, flags, rid = struct.unpack_from(
                    '<HHHH', self.raw, p)
                p += 12
                foff, flen = off << shift, length << shift
                out.append(Resource(ident(type_id), ident(rid), foff, flen,
                                    flags, self.raw[foff:foff + flen]))
        return out

    def _parse_names(self, off, end):
        names = []
        while (end is None or off < end) and self.raw[off]:
            name = self.pstr(off)
            off += 1 + self.raw[off]
            names.append((self.u16(off), name))
            off += 2
        return names

    def _parse_entries(self):
        """Return {ordinal: (segment, offset, flags)}."""
        p = self.ne_off + self.enttab_off
        end = p + self.enttab_len
        ordinal, out = 1, {}
        while p < end:
            count, seg = self.raw[p], self.raw[p + 1]
            p += 2
            if count == 0:
                break
            for _ in range(count):
                if seg == 0:
                    pass
                elif seg == 0xFF:
                    flags, _int3f, s, o = struct.unpack_from(
                        '<BHBH', self.raw, p)
                    out[ordinal] = (s, o, flags)
                    p += 6
                else:
                    flags, o = struct.unpack_from('<BH', self.raw, p)
                    out[ordinal] = (seg, o, flags)
                    p += 3
                ordinal += 1
        return out

    # -- convenience --------------------------------------------------
    def imported_functions(self):
        """Return {(module, ordinal_or_name): number_of_fixup_sites}."""
        used = {}
        for seg in self.segments:
            for r in seg.relocs:
                if r.kind in ('IMPORTORDINAL', 'IMPORTNAME'):
                    used[r.target] = used.get(r.target, 0) + len(r.sites)
        return used
