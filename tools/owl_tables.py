"""Find Borland Pascal VMTs and DMTs (dynamic method tables) in kaiser.exe.

BP7 layout (all offsets inside the data segment):
  VMT  +0 InstanceSize  +2 -InstanceSize  +4 DMT offset (0 = none)
       +6 reserved      +8.. far pointers to virtual methods
  DMT  +0 parent DMT    +2 cache index    +4 cache entry   +6 count
       +8 count x word index, then count x far pointer to the handler

OWL dispatches messages through DMT indices:
  wm_First $0000 + WM_xxx   window messages
  cm_First $A000 + id       menu commands
  id_First $8000 + id       child control notifications
  nf_First $9000 + code     notification codes

Far pointers in the data segment are filled in by the loader, so they are
resolved through the data segment's relocation records.

Usage:
  python3 -I tools/owl_tables.py Kaiser/kaiser.exe docs/owl-tables.md \
      tools/ghidra/names/25_handlers.csv
"""
import csv
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ne import NEFile  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# readable names for game object types, keyed by VMT offset in DS
TYPE_NAMES = {0x01a4: 'KaiserWindow'}
WM_NAMES = {
    0x0001: 'WMCreate', 0x0002: 'WMDestroy', 0x0003: 'WMMove',
    0x0005: 'WMSize', 0x0006: 'WMActivate', 0x0007: 'WMSetFocus',
    0x0008: 'WMKillFocus', 0x000F: 'WMPaint', 0x0010: 'WMClose',
    0x0014: 'WMEraseBkgnd', 0x0018: 'WMShowWindow', 0x001A: 'WMWinIniChange',
    0x0020: 'WMSetCursor', 0x0024: 'WMGetMinMaxInfo', 0x002B: 'WMDrawItem',
    0x002C: 'WMMeasureItem', 0x0100: 'WMKeyDown', 0x0101: 'WMKeyUp',
    0x0102: 'WMChar', 0x0110: 'WMInitDialog', 0x0111: 'WMCommand',
    0x0112: 'WMSysCommand', 0x0113: 'WMTimer', 0x0114: 'WMHScroll',
    0x0115: 'WMVScroll', 0x0116: 'WMInitMenu', 0x0117: 'WMInitMenuPopup',
    0x011F: 'WMMenuSelect', 0x0133: 'WMCtlColor', 0x0200: 'WMMouseMove',
    0x0201: 'WMLButtonDown', 0x0202: 'WMLButtonUp', 0x0203: 'WMLButtonDblClk',
    0x0204: 'WMRButtonDown', 0x0205: 'WMRButtonUp', 0x0206: 'WMRButtonDblClk',
    0x0215: 'WMCaptureChanged', 0x03B9: 'MMMciNotify',
}


class Image:
    def __init__(self, path):
        self.ne = NEFile(path)
        self.ds_index = self.ne.autodata_seg
        self.ds = self.ne.segments[self.ds_index - 1]
        self.data = self.ds.data
        # site offset in DS -> (segment index, offset) for far pointers
        self.far = {}
        for r in self.ds.relocs:
            if r.kind != 'INTERNALREF' or r.src_type != 3:
                continue
            seg, val = r.target
            if seg == 0xFF:
                seg, off, _ = self.ne.entries[val]
            else:
                off = val
            for site in r.sites:
                self.far[site] = (seg, off)

    def w(self, off):
        return struct.unpack_from('<H', self.data, off)[0]

    def ghidra_addr(self, seg, off):
        # Ghidra's NE loader places segment n at 0x1000 + 8*(n-1)
        return f'{0x1000 + 8 * (seg - 1):04x}:{off:04x}'

    def find_vmts(self):
        out = []
        for off in range(0, len(self.data) - 8, 2):
            size, neg = self.w(off), self.w(off + 2)
            if not (2 <= size < 0x8000 and (size + neg) & 0xFFFF == 0):
                continue
            dmt = self.w(off + 4)
            # a VMT's first virtual slot (+8) must be a relocated far pointer
            if off + 8 not in self.far and dmt == 0:
                continue
            if dmt and not self._plausible_dmt(dmt):
                continue
            out.append(off)
        return out

    def _plausible_dmt(self, off):
        if off + 8 > len(self.data):
            return False
        count = self.w(off + 6)
        if not 0 < count < 200:
            return False
        first_ptr = off + 8 + 2 * count
        return first_ptr in self.far

    def vmt_slots(self, vmt):
        slots, p = [], vmt + 8
        while p in self.far:
            slots.append(self.far[p])
            p += 4
        return slots

    def dmt(self, off):
        parent, count = self.w(off), self.w(off + 6)
        idx = [self.w(off + 8 + 2 * i) for i in range(count)]
        ptrs = [self.far.get(off + 8 + 2 * count + 4 * i)
                for i in range(count)]
        return parent, list(zip(idx, ptrs))


def load_menu_names():
    names = {}
    path = os.path.join(ROOT, 'extracted', 'res', 'menus.txt')
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            m = re.search(r'MENUITEM id=(\d+)\s+"([^"]*)"', line)
            if m:
                names[int(m.group(1))] = m.group(2).replace('&', '')
    return names


def describe(index, menu):
    if index >= 0xA000:
        cmd = index - 0xA000
        return f'cm {cmd}', menu.get(cmd, '')
    if index >= 0x9000:
        return f'nf {index - 0x9000}', ''
    if index >= 0x8000:
        return f'id {index - 0x8000}', ''
    return f'wm 0x{index:04x}', WM_NAMES.get(index, '')


def ident(text):
    words = re.findall(r'[A-Za-zÄÖÜäöüß0-9]+', text)
    s = ''.join(w[:1].upper() + w[1:] for w in words)
    for a, b in (('Ä', 'Ae'), ('Ö', 'Oe'), ('Ü', 'Ue'), ('ä', 'ae'),
                 ('ö', 'oe'), ('ü', 'ue'), ('ß', 'ss')):
        s = s.replace(a, b)
    return s


def main():
    img = Image(sys.argv[1])
    md_path = sys.argv[2]
    csv_path = sys.argv[3] if len(sys.argv) > 3 else None
    menu = load_menu_names()
    vmts = img.find_vmts()
    lines = ['# OWL object types (VMTs and DMTs)', '',
             'Generated by `tools/owl_tables.py`. Addresses are Ghidra '
             'addresses (segment base 0x1000 + 8*(n-1)).', '']
    handler_rows = []
    lines += ['| VMT (DS) | Size | Virtuals | DMT | Handlers |',
              '|---|---|---|---|---|']
    details = []
    for v in vmts:
        size, dmt_off = img.w(v), img.w(v + 4)
        slots = img.vmt_slots(v)
        handlers = img.dmt(dmt_off)[1] if dmt_off else []
        lines.append(f'| {v:04x} | 0x{size:x} | {len(slots)} | '
                     + (f'{dmt_off:04x}' if dmt_off else '—')
                     + f' | {len(handlers)} |')
        if not handlers:
            continue
        parent = img.dmt(dmt_off)[0]
        details += ['', f'## VMT DS:{v:04x} (size 0x{size:x}), '
                    f'DMT DS:{dmt_off:04x}, parent DMT DS:{parent:04x}', '',
                    '| Index | Message | Meaning | Handler |',
                    '|---|---|---|---|']
        used = set()
        for index, ptr in handlers:
            kind, meaning = describe(index, menu)
            addr = img.ghidra_addr(*ptr) if ptr else '?'
            details.append(f'| 0x{index:04x} | {kind} | {meaning} | {addr} |')
            if ptr and ptr[0] <= 18:  # game code only, not library units
                if index >= 0xA000:
                    cmd = index - 0xA000
                    # 701-708 = "Berichte" submenu, reuses action names
                    prefix = 'Bericht' if 700 < cmd < 800 else ''
                    name = 'Cm' + prefix + (ident(meaning) or str(cmd))
                    if name in used:
                        name += f'_{cmd}'
                    used.add(name)
                elif index < 0x8000 and index in WM_NAMES:
                    name = WM_NAMES[index]
                elif 0x8000 <= index < 0x9000:
                    name = f'IdCtl{index - 0x8000}'
                else:
                    name = f'Msg{index:04x}'
                handler_rows.append((addr, f'{TYPE_NAMES.get(v, f"T{v:04x}")}::{name}',
                                     f'{kind} {meaning}'.strip()))
    with open(md_path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines + details) + '\n')
    if csv_path:
        with open(csv_path, 'w', newline='', encoding='utf-8') as fh:
            w = csv.writer(fh)
            w.writerow(['address', 'name', 'kind', 'comment'])
            seen = set()
            for addr, name, comment in handler_rows:
                if addr in seen:
                    continue
                seen.add(addr)
                w.writerow([addr, name, 'func',
                            f'DMT handler: {comment} (tools/owl_tables.py)'])
    print(f'{len(vmts)} VMTs, {len(handler_rows)} game handlers')


if __name__ == '__main__':
    main()
