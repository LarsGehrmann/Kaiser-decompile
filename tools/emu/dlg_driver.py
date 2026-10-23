"""Real dialog objects of the original in the emulator.

The game's dialog types (segments 8, 9, 12, ...) are OWL TDialog descendants
whose methods hold game rules: SetupWindow fills the controls, the control
handlers (DMT entries id_First + id) react to the user, CanClose takes the
result. To test them, the original's own objects run in the emulator:

  - OWL's control constructors (TStatic.InitResource, TButton.InitResource,
    ...) return fake control objects that remember their resource id;
  - the control methods (SetText, GetPosition, SetCheck, Enable, ...) work on
    a small state model of the control and are logged, e.g.
        SetText(c101,s:3132)  GetPosition(c101)=5  Disable(c106)
  - TDialog.Execute is a driver: it calls SetupWindow, then plays a script of
    user events (click / scroll / select / type / ok / cancel) by calling the
    handlers the dialog type has in its DMT (or OWL's default for OK and
    Cancel: CanClose, then EndDlg), until EndDlg is called;
  - EndDlg ends the dialog with its code; Done (KaiserDlg.Done) is logged;
  - the heap (System _HeapAlloc) is a bump allocator for the objects.

The port (port/src/dlglogic.pas, port/tests) plays the same script on its
dialog types with the same control model and logs the same calls.

Script format (vector field dlg=): events separated by ';':
  c<id>        click a button / check box / radio button
  s<id>:<pos>  move a scroll bar to pos (clamped to its range)
  l<id>:<idx>  select entry idx of a list/combo box
  t<id>:<hex>  type text into an edit
  ok / cancel  the OK / Cancel button (id 1 / 2)
"""
import struct

from unicorn.x86_const import (UC_X86_REG_SP, UC_X86_REG_SS, UC_X86_REG_CS,
                               UC_X86_REG_IP, UC_X86_REG_AX, UC_X86_REG_DX,
                               UC_X86_REG_FLAGS)

CTL_SEG = 0x3000          # fake control objects (paragraphs after the scratch start)
HEAP_SEG = 0x4000         # heap for the dialog objects (64 KB)

# OWL constructors: name -> (address, arguments after Self/VMT in Pascal order)
CONTROL_CTORS = {
    'static': ('1098:0792', ['p', 'w', 'w']),       # TStatic.InitResource(Parent, Id, TextLen)
    'button': ('1098:0566', ['p', 'w']),            # TButton.InitResource(Parent, Id)
    'check': ('1098:05d4', ['p', 'w']),             # TCheckBox.InitResource
    'scroll': ('1098:15bc', ['p', 'w']),            # TScrollBar.InitResource
    'edit': ('1098:089d', ['p', 'w', 'w']),         # TEdit.InitResource(Parent, Id, TextLen)
    'combo': ('1098:13c0', ['p', 'w', 'w']),        # TComboBox.InitResource(Parent, Id, TextLen)
}
# OWL methods: name -> (address, argument bytes after Self, returns)
CONTROL_METHODS = {
    'SetText': ('1098:0864', 4),                    # TStatic.SetText(PChar)
    'GetText': ('1098:083a', 6),                    # TStatic.GetText(PChar, MaxChars): Integer
    'Enable': ('1090:0779', 0),
    'Disable': ('1090:07af', 0),
    'Show': ('1090:10fe', 2),
    'SetCaption': ('1090:16bc', 4),                 # TWindow.SetCaption(PChar)
    'SetCheck': ('1098:06d1', 2),
    'GetCheck': ('1098:066e', 0),
    'SetRange': ('1098:1763', 4),
    'SetPosition': ('1098:1785', 2),
    'GetPosition': ('1098:1740', 0),
    'AddString': ('1098:12f2', 4),
    'GetSelIndex': ('1098:135b', 0),
    'SetSelIndex': ('1098:138d', 2),
    'ComboSetText': ('1098:1540', 4),
}
EXECUTE = '1098:014f'        # TDialog.Execute (VMT +0x4c)
END_DLG = '1098:023d'        # TDialog.EndDlg (VMT +0x50)
KAISER_SETUP = '1058:004a'   # KaiserDlg.SetupWindow: centres the window
KAISER_DONE = '1058:0166'    # KaiserDlg.Done (VMT +0x08)
OWL_CANCLOSE = '1090:1154'   # TWindowsObject.CanClose: all children agree (fake controls do)
HEAP_ALLOC = '10c8:01ca'     # System _HeapAlloc (near, AX = size -> DX:AX, CF)
HEAP_FREE = '10c8:02d7'      # System _HeapFree (near)


class Control:
    def __init__(self, kind, cid, style=0):
        self.kind, self.id, self.style = kind, cid, style
        self.text = b''
        self.check = 0
        self.lo, self.hi, self.pos = 0, 100, 0
        self.items = []
        self.sel = -1
        self.enabled = not (style & 0x08000000)       # WS_DISABLED


class DialogDriver:
    def __init__(self, ui):
        self.ui = ui
        self.emu = ui.emu
        self.reset()
        self._install()

    def set_template(self, name, obj=None):
        """The dialog being built (object obj = (seg, off)): its template
        gives the control styles and initial texts."""
        self.template = {}
        self.by_id = {}
        if obj is not None:
            self.dialogs[obj] = {'template': self.template, 'by_id': self.by_id}
        for r in self.emu.ne.resources:
            if r.type_id == 5 and str(r.res_id).upper() == name.upper():
                d = r.data
                count = d[4]
                p = 13
                for _ in range(3):                    # menu, class, caption
                    if d[p] == 0xFF:
                        p += 3
                    else:
                        p = d.index(0, p) + 1
                if struct.unpack_from('<I', d, 0)[0] & 0x40:
                    p = d.index(0, p + 2) + 1
                for _ in range(count):
                    cid, style = struct.unpack_from('<HI', d, p + 8)
                    p += 14
                    if d[p] & 0x80:
                        cls = {0x80: 'BUTTON', 0x81: 'EDIT', 0x82: 'STATIC', 0x83: 'LISTBOX',
                               0x84: 'SCROLLBAR', 0x85: 'COMBOBOX'}.get(d[p], '')
                        p += 1
                    else:
                        e = d.index(0, p)
                        cls, p = d[p:e].decode('latin-1'), e + 1
                    if d[p] == 0xFF:
                        text, p = b'', p + 3
                    else:
                        e = d.index(0, p)
                        text, p = bytes(d[p:e]), e + 1
                    p += 1 + d[p]
                    if cid >= 0x8000:
                        cid -= 0x10000
                    self.template[cid] = (cls, style, text)
                return

    def reset(self):
        self.controls = {}           # (seg, off) -> Control
        self.by_id = {}
        self.heap_next = 0x10
        self.script = []
        self.scripts = []            # one event list per real dialog (in order)
        self.end_code = None
        self.template = {}           # id -> (class, style) of the running dialog
        self.dialogs = {}            # dialog object -> its template and controls
        self.run = None
        self.stack = []              # the runs of the dialogs a nested dialog interrupts

    # -- helpers ------------------------------------------------------------
    def _stack(self, n, skip=4):
        return self.emu.stack_words(n, skip)

    def _name(self, seg, off):
        c = self.controls.get((seg, off))
        if c is not None:
            return f'c{c.id}'
        return self.ui.sym(seg, off)

    def _install(self):
        emu = self.emu
        for kind, (addr, kinds) in CONTROL_CTORS.items():
            emu.redirect(addr, self._ctor(kind, kinds))
        for name, (addr, nargs) in CONTROL_METHODS.items():
            emu.redirect(addr, self._method(name, nargs))
        emu.redirect(EXECUTE, self._execute)
        emu.redirect(END_DLG, self._end_dlg)
        emu.redirect(KAISER_SETUP, lambda: emu.stub_return(4, True))
        emu.redirect(KAISER_DONE, self._done)
        emu.redirect(OWL_CANCLOSE, lambda: emu.stub_return(4, True, 1))
        self._heap_alloc_patch()
        self.next_stub = emu.new_stub(self._next)

    def addresses(self):
        """Patched entries (for the guard's allow list)."""
        return ([a for a, _ in CONTROL_CTORS.values()] +
                [a for a, _ in CONTROL_METHODS.values()] +
                [EXECUTE, END_DLG, KAISER_SETUP, KAISER_DONE, OWL_CANCLOSE])

    # -- heap -----------------------------------------------------------------
    def _heap_alloc_patch(self):
        emu = self.emu
        from kaiser_emu import ghidra_seg

        def alloc():
            size = emu.uc.reg_read(UC_X86_REG_AX)
            off = self.heap_next
            self.heap_next = (self.heap_next + size + 15) & ~15
            seg = emu.scratch_para + HEAP_SEG
            emu.write(seg, off, bytes(size))
            emu.uc.reg_write(UC_X86_REG_FLAGS, emu.uc.reg_read(UC_X86_REG_FLAGS) & ~1)
            emu.stub_return(0, False, off, seg, cs=emu.para[26])
        emu.redirect(HEAP_ALLOC, alloc)
        emu.redirect(HEAP_FREE, lambda: emu.stub_return(0, False, cs=emu.para[26]))

    # -- controls ---------------------------------------------------------------
    def _ctor(self, kind, kinds):
        def handler():
            emu = self.emu
            n = sum(4 if k == 'p' else 2 for k in kinds)
            words = self._stack(3 + n // 2)       # Self (2), VMT, args (last first)
            args = words[3:]
            cid = args[0] if len(kinds) == 2 else args[1]
            if cid >= 0x8000:
                cid -= 0x10000
            k = len(self.controls)
            seg, off = emu.scratch_para + CTL_SEG, 0x10 + 0x20 * k
            ctx = self.dialogs.get((args[-1], args[-2]))     # the parent dialog
            template = ctx['template'] if ctx else self.template
            by_id = ctx['by_id'] if ctx else self.by_id
            cls, style, text = template.get(cid, ('', 0, b''))
            c = Control(kind, cid, style)
            if kind in ('static', 'edit'):
                c.text = text
            self.controls[(seg, off)] = c
            by_id[cid] = c
            emu.stub_return(6 + n, True, off, seg)
        return handler

    def _method(self, name, nargs):
        def handler():
            emu = self.emu
            words = self._stack(2 + nargs // 2)
            so, ss = words[0], words[1]
            who = self._name(ss, so)
            c = self.controls.get((ss, so))
            args = words[2:]
            ax = 0
            if name in ('SetText', 'SetCaption', 'ComboSetText', 'AddString'):
                off, seg = args[0], args[1]
                text = self.ui.cstring(seg, off)
                self.ui.log.append(f'{name}({who},s:{text.hex()})')
                if c is not None:
                    if name == 'AddString':
                        c.items.append(text)
                        ax = len(c.items) - 1
                    else:
                        c.text = text
            elif name == 'GetText':
                maxc, off, seg = args[0], args[1], args[2]
                text = c.text[:max(maxc - 1, 0)] if c is not None else b''
                emu.write(seg, off, text + b'\0')
                self.ui.log.append(f'GetText({who})=s:{text.hex()}')
                ax = len(text)
            elif name in ('Enable', 'Disable'):
                if c is not None:
                    c.enabled = name == 'Enable'
                self.ui.log.append(f'{name}({who})')
            elif name == 'Show':
                self.ui.log.append(f'Show({who},{args[0]})')
            elif name == 'SetCheck':
                if c is not None:
                    c.check = args[0]
                self.ui.log.append(f'SetCheck({who},{args[0]})')
            elif name == 'GetCheck':
                ax = c.check if c is not None else 0
                self.ui.log.append(f'GetCheck({who})={ax}')
            elif name == 'SetRange':
                hi, lo = struct.unpack('<hh', struct.pack('<HH', args[0], args[1]))
                if c is not None:
                    c.lo, c.hi = lo, hi
                    c.pos = min(max(c.pos, lo), hi)
                self.ui.log.append(f'SetRange({who},{lo},{hi})')
            elif name == 'SetPosition':
                v = struct.unpack('<h', struct.pack('<H', args[0]))[0]
                if c is not None:
                    c.pos = min(max(v, c.lo), c.hi)
                self.ui.log.append(f'SetPosition({who},{v})')
            elif name == 'GetPosition':
                ax = c.pos if c is not None else 0
                self.ui.log.append(f'GetPosition({who})={ax}')
            elif name == 'GetSelIndex':
                ax = c.sel if c is not None else -1
                self.ui.log.append(f'GetSelIndex({who})={ax}')
            elif name == 'SetSelIndex':
                v = struct.unpack('<h', struct.pack('<H', args[0]))[0]
                if c is not None:
                    c.sel = v if 0 <= v < len(c.items) else -1
                self.ui.log.append(f'SetSelIndex({who},{v})')
                ax = v
            emu.stub_return(4 + nargs, True, ax & 0xFFFF)
        return handler

    # -- the dialog's run -------------------------------------------------------
    def _vmt_slot(self, seg, off, slot):
        vmt = struct.unpack('<H', self.emu.read(seg, off, 2))[0]
        ip, cs = struct.unpack('<HH', self.emu.read(self.emu.ds_para, vmt + slot, 4))
        return cs, ip

    def handler_of(self, seg, off, cid):
        """The DMT handler for id_First + cid of the object's type (or None)."""
        emu = self.emu
        vmt = struct.unpack('<H', emu.read(seg, off, 2))[0]
        dmt = struct.unpack('<H', emu.read(emu.ds_para, vmt + 4, 2))[0]
        index = 0x8000 + (cid & 0xFFFF) if cid >= 0 else cid & 0xFFFF
        while dmt:
            parent, _, _, count = struct.unpack('<4H', emu.read(emu.ds_para, dmt, 8))
            idx = struct.unpack(f'<{count}H', emu.read(emu.ds_para, dmt + 8, 2 * count))
            for k, v in enumerate(idx):
                if v == index:
                    ip, cs = struct.unpack('<HH', emu.read(emu.ds_para, dmt + 8 + 2 * count + 4 * k, 4))
                    if cs == emu.para[20]:
                        return None       # OWL's TDialog.Ok / Cancel: the driver's default
                    return cs, ip
            dmt = parent
        return None

    def _execute(self):
        emu = self.emu
        ss = emu.uc.reg_read(UC_X86_REG_SS)
        sp = emu.uc.reg_read(UC_X86_REG_SP)
        ip, cs, so, sseg = struct.unpack('<4H', emu.read(ss, sp, 8))
        if self.run is not None:                     # a dialog opened by a dialog
            self.stack.append((self.run, self.script, self.end_code))
        ctx = self.dialogs.get((sseg, so))
        if ctx:
            self.by_id, self.template = ctx['by_id'], ctx['template']
        self.run = {'ret': (cs, ip), 'sp': sp + 8, 'self': (sseg, so), 'step': 0,
                    'base': sp - 0x40, 'pending': None}
        self.end_code = None
        self.script = [e for e in (self.scripts.pop(0) if self.scripts else '').split(';') if e]
        self.ui.log.append(f'Execute({self.ui.sym(sseg, so)})')
        # SetupWindow first
        self._call(self._vmt_slot(sseg, so, 0x38), [so, sseg], 'setup')

    def _call(self, target, words, what):
        """Call target (cs, ip) far with the argument words (pushed last
        first = the list as it lies on the stack), returning into the driver."""
        emu = self.emu
        ss = emu.uc.reg_read(UC_X86_REG_SS)
        base = self.run['base']
        frame = struct.pack('<HH', self.next_stub[1], self.next_stub[0]) + struct.pack(f'<{len(words)}H', *words)
        sp = base - len(frame)
        emu.write(ss, sp, frame)
        emu.uc.reg_write(UC_X86_REG_SP, sp)
        emu.uc.reg_write(UC_X86_REG_CS, target[0])
        emu.uc.reg_write(UC_X86_REG_IP, target[1])
        self.run['pending'] = what

    def _finish(self, code):
        emu = self.emu
        cs, ip = self.run['ret']
        emu.uc.reg_write(UC_X86_REG_SP, self.run['sp'])
        emu.uc.reg_write(UC_X86_REG_AX, code & 0xFFFF)
        emu.uc.reg_write(UC_X86_REG_DX, 0)
        emu.uc.reg_write(UC_X86_REG_CS, cs)
        emu.uc.reg_write(UC_X86_REG_IP, ip)
        self.ui.log.append(f'=>{code}')
        if self.stack:
            self.run, self.script, self.end_code = self.stack.pop()
            ctx = self.dialogs.get(self.run['self'])
            if ctx:
                self.by_id, self.template = ctx['by_id'], ctx['template']
        else:
            self.run = None

    def _next(self):
        """A dialog method returned into the driver: the next event."""
        emu = self.emu
        ax = emu.uc.reg_read(UC_X86_REG_AX)
        if self.run['pending'] == 'canclose' and ax & 0xFF and self.end_code is None:
            self.end_code = self.run['ok_id']
        if self.end_code is not None:
            self._finish(self.end_code)
            return
        sseg, so = self.run['self']
        while True:
            if self.run['step'] >= len(self.script):
                self.end_code = 2                    # the script ran out: Cancel
                self._finish(2)
                return
            ev = self.script[self.run['step']]
            self.run['step'] += 1
            self.ui.log.append(f'[{ev}]')
            cid = self._apply(ev)
            if cid is None:
                continue
            h = self.handler_of(sseg, so, cid)
            msg = (emu.scratch_para + CTL_SEG, 0)
            emu.write(msg[0], msg[1], struct.pack('<HHHHHHH', 0, 0, cid & 0xFFFF, 0, 0, 0, 0))
            if h is not None:
                self._call(h, [so, sseg, msg[1], msg[0]], 'handler')
                return
            if cid == 1:                              # TDialog.Ok: CanClose, EndDlg(1)
                self.run['ok_id'] = 1
                self._call(self._vmt_slot(sseg, so, 0x3c), [so, sseg], 'canclose')
                return
            if cid == 2:                              # TDialog.Cancel
                self.end_code = 2
                self._finish(2)
                return

    def _apply(self, ev):
        """Change the control model for a user event; the id whose handler
        runs (None: no notification)."""
        if ev in ('ok', 'cancel'):
            cid0 = 1 if ev == 'ok' else 2
            c0 = self.by_id.get(cid0)
            if c0 is not None and not c0.enabled:
                return None
            return cid0
        kind, rest = ev[0], ev[1:]
        cid0 = int(rest.partition(':')[0])
        c0 = self.by_id.get(cid0)
        if c0 is not None and not c0.enabled:
            return None                                  # a disabled control: no effect
        if kind == 'c':
            cid = int(rest)
            c = self.by_id.get(cid)
            cls, style, _ = self.template.get(cid, ('', 0, b''))
            if c is not None and cls == 'BUTTON' and style & 0xF in (3, 6):
                c.check = 0 if c.check else 1            # BS_AUTOCHECKBOX
            elif c is not None and cls == 'BUTTON' and style & 0xF == 9:
                c.check = 1                              # BS_AUTORADIOBUTTON
            return cid
        cid_s, _, val = rest.partition(':')
        cid = int(cid_s)
        c = self.by_id.get(cid)
        if kind == 's':
            if c is not None:
                c.pos = min(max(int(val), c.lo), c.hi)
            return cid
        if kind == 'l':
            if c is not None:
                v = int(val)
                c.sel = v if 0 <= v < len(c.items) else -1
            return cid
        if kind == 't':
            if c is not None:
                c.text = bytes.fromhex(val)
            return None
        return None

    def _end_dlg(self):
        words = self._stack(3)
        so, sseg, code = words[0], words[1], words[2]
        self.end_code = code
        self.ui.log.append(f'EndDlg({self.ui.sym(sseg, so)},{code})')
        self.emu.stub_return(6, True)

    def _done(self):
        words = self._stack(3)
        so, sseg, flag = words[0], words[1], words[2]
        self.ui.log.append(f'Done({self.ui.sym(sseg, so)},{flag & 0xFF})')
        self.emu.stub_return(6, True)
