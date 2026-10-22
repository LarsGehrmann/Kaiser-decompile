"""Extract all resources of an NE executable into a directory tree.

  STRING        -> strings.tsv (id, text)
  DIALOG        -> dialogs.txt (decoded templates with control ids)
  MENU          -> menus.txt
  ACCELERATOR   -> accelerators.txt
  BITMAP        -> bitmap/<id>.bmp (+ .png via macOS sips with --png)
  ICON/CURSOR   -> icon/<group>.ico, cursor/<id>.cur
  everything else (MAPDATA, WAVEDATA, ...) -> <type>/<id>.bin
  WAVEDATA that starts with RIFF is saved as .wav

Usage: tools/.venv/bin/python -I tools/ne_resources.py Kaiser/kaiser.exe \
           extracted/res [--png]
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ne import NEFile  # noqa: E402

BUTTON_STYLES = {0: 'PUSHBUTTON', 1: 'DEFPUSHBUTTON', 2: 'CHECKBOX',
                 3: 'AUTOCHECKBOX', 4: 'RADIOBUTTON', 5: '3STATE',
                 6: 'AUTO3STATE', 7: 'GROUPBOX', 9: 'AUTORADIOBUTTON',
                 11: 'OWNERDRAW'}
PREDEF_CLASS = {0x80: 'BUTTON', 0x81: 'EDIT', 0x82: 'STATIC',
                0x83: 'LISTBOX', 0x84: 'SCROLLBAR', 0x85: 'COMBOBOX'}


def zstr(data, p):
    end = data.index(b'\0', p)
    return data[p:end].decode('cp1252'), end + 1


def name_or_ord(data, p):
    """16-bit resource templates: 0xFF + word = ordinal, else zstring."""
    if data[p] == 0xFF:
        return f'#{struct.unpack_from("<H", data, p + 1)[0]}', p + 3
    return zstr(data, p)


def rid(r):
    return str(r.res_id)


def decode_strings(r):
    out, p = [], 0
    base = (r.res_id - 1) * 16
    for i in range(16):
        if p >= len(r.data):
            break
        n = r.data[p]
        if n:
            out.append((base + i, r.data[p + 1:p + 1 + n].decode('cp1252')))
        p += 1 + n
    return out


def decode_dialog(r):
    d = r.data
    style, count, x, y, cx, cy = struct.unpack_from('<IBHHHH', d, 0)
    p = 13
    menu, p = name_or_ord(d, p)
    cls, p = zstr(d, p)
    caption, p = zstr(d, p)
    font = ''
    if style & 0x40:  # DS_SETFONT
        size = struct.unpack_from('<H', d, p)[0]
        face, p = zstr(d, p + 2)
        font = f' FONT {size} "{face}"'
    lines = [f'DIALOG {rid(r)}  ({x},{y},{cx},{cy})  style=0x{style:08x}'
             f'  caption="{caption}"'
             + (f' class="{cls}"' if cls else '')
             + (f' menu={menu}' if menu else '') + font]
    for _ in range(count):
        ix, iy, icx, icy, cid, istyle = struct.unpack_from('<HHHHHI', d, p)
        p += 14
        if d[p] & 0x80:
            ctl = PREDEF_CLASS.get(d[p], f'0x{d[p]:02x}')
            p += 1
        else:
            ctl, p = zstr(d, p)
        text, p = name_or_ord(d, p)
        extra = d[p]
        p += 1 + extra
        if ctl == 'BUTTON':
            ctl = BUTTON_STYLES.get(istyle & 0xF, ctl)
        cid_s = str(cid if cid < 0x8000 else cid - 0x10000)
        lines.append(f'    {ctl:<16} id={cid_s:<6} ({ix},{iy},{icx},{icy})'
                     f'  "{text}"  style=0x{istyle:08x}')
    return lines


def decode_menu(r):
    d = r.data
    _ver, hdr = struct.unpack_from('<HH', d, 0)
    p = 4 + hdr
    lines = [f'MENU {rid(r)}']

    def walk(p, depth):
        while True:
            flags = struct.unpack_from('<H', d, p)[0]
            p += 2
            if flags & 0x10:  # MF_POPUP
                text, p = zstr(d, p)
                lines.append('    ' * depth + f'POPUP "{text}"')
                p = walk(p, depth + 1)
            else:
                mid = struct.unpack_from('<H', d, p)[0]
                text, p = zstr(d, p + 2)
                if not text and not mid:
                    lines.append('    ' * depth + 'SEPARATOR')
                else:
                    lines.append('    ' * depth +
                                 f'MENUITEM id={mid:<5} "{text}"'
                                 + (f' flags=0x{flags:x}' if flags & ~0x80
                                    else ''))
            if flags & 0x80:  # MF_END
                return p

    walk(p, 1)
    return lines


def decode_accel(r):
    lines, p = [f'ACCELERATORS {rid(r)}'], 0
    while p + 5 <= len(r.data):
        flags, key, cmd = struct.unpack_from('<BHH', r.data, p)
        mods = [n for bit, n in ((0x04, 'SHIFT'), (0x08, 'CONTROL'),
                                 (0x10, 'ALT')) if flags & bit]
        kind = 'VIRTKEY' if flags & 1 else 'ASCII'
        lines.append(f'    key=0x{key:02x} {kind} {"+".join(mods)} '
                     f'-> cmd {cmd}')
        p += 5
        if flags & 0x80:
            break
    return lines


def bmp_file(data):
    hdr = struct.unpack_from('<I', data, 0)[0]
    if hdr == 12:  # BITMAPCOREHEADER
        bpp = struct.unpack_from('<H', data, 10)[0]
        pal = (1 << bpp) * 3 if bpp <= 8 else 0
    else:
        bpp, clr_used = struct.unpack_from('<H', data, 14)[0], \
            struct.unpack_from('<I', data, 32)[0]
        n = clr_used or ((1 << bpp) if bpp <= 8 else 0)
        pal = n * 4
    off = 14 + hdr + pal
    return b'BM' + struct.pack('<IHHI', 14 + len(data), 0, 0, off) + data


def ico_file(group, by_id, cursor=False):
    """Build a .ico/.cur from a GROUP_ICON/GROUP_CURSOR and its members."""
    _res, typ, count = struct.unpack_from('<HHH', group.data, 0)
    images, entries = [], []
    for i in range(count):
        e = group.data[6 + 14 * i:6 + 14 * (i + 1)]
        member = by_id.get(struct.unpack_from('<H', e, 12)[0])
        if member is None:
            continue
        img = member.data[4:] if cursor else member.data  # skip hotspot
        images.append(img)
        entries.append(e[:12])
    out = struct.pack('<HHH', 0, 2 if cursor else 1, len(images))
    off = 6 + 16 * len(images)
    for e, img in zip(entries, images):
        out += e[:8] + struct.pack('<II', len(img), off)
        off += len(img)
    return out + b''.join(images)


def main():
    exe, out_dir = sys.argv[1], sys.argv[2]
    to_png = '--png' in sys.argv
    f = NEFile(exe)
    os.makedirs(out_dir, exist_ok=True)

    def write(rel, data, mode='wb'):
        path = os.path.join(out_dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, mode, **({} if 'b' in mode else
                                 {'encoding': 'utf-8'})) as fh:
            fh.write(data)
        return path

    strings, dialogs, menus, accels, bitmaps = [], [], [], [], []
    icons = {r.res_id: r for r in f.resources if r.type_name == 'ICON'}
    cursors = {r.res_id: r for r in f.resources if r.type_name == 'CURSOR'}
    for r in f.resources:
        t = r.type_name
        if t == 'STRING':
            strings += decode_strings(r)
        elif t == 'DIALOG':
            dialogs += decode_dialog(r) + ['']
        elif t == 'MENU':
            menus += decode_menu(r) + ['']
        elif t == 'ACCELERATOR':
            accels += decode_accel(r) + ['']
        elif t == 'BITMAP':
            bitmaps.append(write(f'bitmap/{rid(r)}.bmp', bmp_file(r.data)))
        elif t == 'GROUP_ICON':
            write(f'icon/{rid(r)}.ico', ico_file(r, icons))
        elif t == 'GROUP_CURSOR':
            write(f'cursor/{rid(r)}.cur', ico_file(r, cursors, cursor=True))
        elif t in ('ICON', 'CURSOR'):
            pass  # bundled into their groups
        else:
            ext = '.wav' if r.data[:4] == b'RIFF' else '.bin'
            write(f'{t.lower()}/{rid(r)}{ext}', r.data)

    write('strings.tsv', ''.join(
        f'{i}\t' + s.replace('\t', '\\t').replace('\n', '\\n') + '\n'
        for i, s in strings), 'w')
    write('dialogs.txt', '\n'.join(dialogs), 'w')
    write('menus.txt', '\n'.join(menus), 'w')
    write('accelerators.txt', '\n'.join(accels), 'w')
    write('index.tsv', ''.join(
        f'{r.type_name}\t{r.res_id}\t0x{r.file_offset:06x}\t{len(r.data)}\n'
        for r in f.resources), 'w')

    if to_png and bitmaps:
        # sips cannot read 4-bit BMPs, so this needs Pillow (tools/.venv)
        from PIL import Image
        png_dir = os.path.join(out_dir, 'bitmap_png')
        os.makedirs(png_dir, exist_ok=True)
        for path in bitmaps:
            name = os.path.splitext(os.path.basename(path))[0] + '.png'
            Image.open(path).save(os.path.join(png_dir, name))
    print(f'{len(f.resources)} resources: {len(strings)} strings, '
          f'{sum(1 for x in dialogs if x.startswith("DIALOG"))} dialogs, '
          f'{len(bitmaps)} bitmaps')


if __name__ == '__main__':
    main()
