# UI and infrastructure segments – main program, files/INI, dialog base, menus, bitmaps, toolbar

Segments 1 (1000), 11 (1050), 12 (1058), 13 (1060), 16 (1078), 17 (1080) and 18 (1088), plus the
three last unnamed library helpers in segments 19 (OWindows) and 26 (System).
Names come from `tools/ghidra/names/*.csv` (later files win). Names marked `*` are new in
`95_ui_infra.csv` (129 functions). VMT slot numbers are byte offsets into the VMT (DS:xxxx,
see `docs/owl-tables.md`): +08 Done, +2C GetClassName, +34 GetWindowClass, +38 SetupWindow,
+3C CanClose, +4C Paint (windows) or Execute (dialogs), +50 EndDlg.

Parameter lists are given in Pascal order (Ghidra shows far Pascal parameters reversed).

## Findings

### Main window: layout, painting and mouse hotspots

- Window size per resolution: ResolutionWidth/Height DS:4536/453c = 640/800/1024 × 480/600/768.
  `SetupWindow` centres the window and fixes the client height at ResolutionHeight − 40.
  Window class: icon `KRONENICON`, black background brush, `CS_DBLCLKS`.
- The **toolbar is docked on the left**, 32 px wide (20×20 button bitmaps + 4 px frame + 8 px
  border, orientation 2). `KaiserWindow::Paint` ends with a ForEach over the child windows that
  sends message **0478h** with wParam 1 and lParam = @ClientRect; the toolbar answers by docking
  itself to the parent's edge and shrinking the rect (`T4418::Msg0478`). All background pictures
  are therefore blitted at x = 32.
- `Paint` by `game_state`: 0 = title screen (`PaintTitleScreen`: 8×8 `MUSTER` pattern, `WAPPEN`
  200×250 and `BIGLOGO` 250×125 stretched by the resolution factor DS:4542 = Real48 1.0/1.25/1.6),
  game commands greyed, caption "Kaiser"; 1 = map (`DrawPlayerBuildings`), game commands enabled,
  save enabled, Berichte check marks from `report_flags`, caption = `FormatPlayerTitle`, MIDI
  stopped; 2/6/7 (turn hand-over etc.) = only the pattern (`PaintPatternBackground`) so the next
  player sees nothing of the previous one. E-mail games grey out Speichern/Speichern unter.
- Map text uses the LOGFONT at DS:60c8 built by `Unit13_Init`: Comic Sans MS, −12 px, bold.
- Mouse (`HandleMapClick`, origin in 32-px tiles DS:0270/0276[res] = (0,0) / (2,2) / (6,4)):
  - bottom strip y = H−76 … H−40: the army1 units (`army1_count`), one 32-px cell each, counted
    from x = W−144 leftwards; hidden while the army is away (`army_away`). Right click = unit
    info popup (1040:330f kind 1), double click = Truppen aufstellen.
  - 3×3 block at tiles (ox+7…ox+9, oy+5…oy+7) = the garrison (army2); cell → unit number via
    DS:0266 = `2 1 3 / 5 4 6 / 7 – 8` (column-major); right click = info popup kind 2.
  - double click on the building icons: granary → Korn verteilen, warehouse → Handel mit Gütern
    (only with goods trade), smithy → Hofschmiede, tavern → Sabotage (each only when the player
    owns at least one).
- **Music** (`kaiser.mid` through the MCI sequencer, device id at Self+0x494c) plays only on the
  title screen: `WMSize` (restore/maximise) starts it when Schalmeienklänge is on, the first
  in-game `Paint` closes it, `MMMciNotify` loops it, `EndGame` plays it again.
- `CanClose` asks only while a game runs; `CmBossKey` sets Self+0x4958 to skip the question.
- `LoadFromCommandLine` (when ParamCount > 0): loads ParamStr(1); `autosave.ksr` / `boss.ksr`
  are loaded but not kept as the current file name, so a later Speichern asks for a name.

### OWLToolbar unit (segment 17)

Three object types (instance sizes from the VMTs):

| Type | VMT | Size | Fields |
|---|---|---|---|
| Toolbar (TWindow descendant, class `OWLToolbar`) | DS:4418 | 57h | +41 resource name (PChar or integer id), +45 TCollection of tools, +51 captured tool, +55 orientation (1 top, 2 left, 4 right) |
| ToolSpacer (Tool) | DS:4484 | 08h | +2 owner toolbar, +6 size (width = height) |
| ToolButton (Tool) | DS:44c4 | 1Dh | +2 owner, +6 HBITMAP, +8 command, +0a pressed (capture active), +0b drawn down, +0c enabled, +0d RECT, +15/+17 bitmap width/height, +19 DC, +1b memory DC |

Tool virtuals: +0C GetWidth, +10 GetHeight, +14 HitTest, +18 Paint, +1C BeginPress, +20 MouseMove,
+24 EndPress, +28 RightClick, +2C HasCommand, +30 SetEnabled, +34 SetPosition, +38 Read, +3C Write.
Toolbar adds +50 Store, +54 CreateTool, +58 EnableTool, +5C AdvanceToolPos, +60 LoadTools,
+64 GetOrientation, +68 SetOrientation.

- **`ToolBarData` resource format**: `word N`, then N × `(word bitmap_id, word command)`.
  bitmap_id 0 = spacer whose size is the second word; otherwise `LoadBitmap(MAKEINTRESOURCE(id))`.
  Tools are placed from (2,2); the toolbar adds 8 px to both extents.
  - `KAISERTOOLS_640` (19 tools): 201, 202, 203, 205, 204, 221, 222, 223, 224, 211, 213, 214, 301,
    302, 303, 305, 304, spacer 4, 401.
  - `KAISERTOOLS_800` (25 tools): 201, 202, 203, 205, 204, sp 6, 221, 222, 223, 224, sp 6, 211,
    213, 214, sp 6, 301, 302, 303, 305, sp 6, 311, 312, 304, sp 8, 401 (bitmap 23 instead of 12).
- Left button: press feedback with capture; release inside posts `WM_COMMAND(command)` to the
  main window. **Right button = context help popup**: `WinHelp(kaiser.hlp, HELP_CONTEXTPOPUP,
  command + 1000)`. No tooltips.
- Drawing (`ToolButton::Draw`): black rectangle on the LTGRAY face, white/grey (RGB 128,128,128)
  3-D edge (offset 2, pressed offset 3); disabled buttons are blitted through the 8×8
  `GrayingBitmap` pattern brush with ROP 00A803A9h, enabled ones with SRCCOPY.
- The game enables/disables toolbar buttons by **collection index**, not by command
  (`Menu_Enable/DisableGameCommands`, `KaiserWindow::SetupWindow`), using the last index
  from the byte table DS:4554 = 12h, 18h (19 / 25 tools).

### KAISER.INI

- Path: `Unit18_InitGlobals` builds DS:6796 = `GetCurDir + '\KAISER.INI'`, i.e. the **current
  directory at start-up** (Program Manager's working directory, or the Windows directory when
  the icon has none – this explains the `C:\WINDOWS` observation in README.md). Section `[Kaiser]`.
- Read once in `InitMainWindow` (`Ini_ReadSettings`), written back in `KaiserWindow::Done`
  (`Ini_WriteSettings`); `Letzter Pfad`/`Letzte Datei` are written immediately (`Ini_WriteLastGame`).

| Key | Values / default | Global |
|---|---|---|
| `Geschichtsschreibung` | `an`/`aus`, default `an` (any other text = off) | Opt_Autosave |
| `Krach & Geschrei` | `an`/`aus`, default `an` | Opt_SoundEffects |
| `Schalmeienklänge` | `an`/`aus`, default `an` | Opt_Music |
| `Debug` | default `aus`; `an` enables the census editor in new games; **never written back** | Opt_Debug DS:63a1 |
| `Auflösung` | `800x600` → 1, value equal to DS:60be → 2, anything else → 0 (640x480); default `800x600` | Opt_Resolution |
| `Hintergrund rot` / `grün` / `blau` | integers, default 255 / 255 / 172 (pale yellow) → solid brush DS:63a6 used by the main window and by every dialog (`WM_CTLCOLOR`) | DS:63a2..63a4 |
| `Delta X`, `Delta Y` | integers, default 0: extra width/height of the battle window (482+X × 458+Y, seg 10); Delta Y is also added to the main window height by the resolution commands (frame/menu height correction) | DS:6790/6792 |
| `Schlacht-Timer` | integer, default 400, minimum 50 | DS:6794 |
| `<country name>` ×10 | key = built-in country name, default = itself → country names used in titles | DS:63a8 |
| `<adjective>` ×10 | key = built-in adjective (DS:4878), default = itself | DS:6696 |
| `Spieler0` … `Spieler9` | last human player names, default empty | DS:659c |
| `<CPU name>` ×10 | key = built-in computer player name, default = itself | DS:64a2 |
| `Letzter Pfad`, `Letzte Datei` | full path (255) and 8.3 file name (12) of the last game (Ctrl+L) | — |

**Hidden INI value:** the comparison string for resolution 2 (DS:60be) is never initialised
(`Unit11_Init` only sets `an`, `aus`, `Kaiser`, `640x480`, `800x600`), so `Auflösung=` with an
**empty value** selects 1024×768, and `Ini_WriteSettings` writes an empty value in that mode.

### 1024×768 mode is incomplete (from the code; not run)

DS:4554 holds the last toolbar index only for resolutions 0 and 1 (12h, 18h). For resolution 2
the byte read is DS:4556 = 48h (the `H` of the title table `Herr`), so `SetupWindow`,
`Menu_EnableGameCommands` and `Menu_DisableGameCommands` call `TCollection.At` with indices up
to 72 on a 25-tool collection → `coIndexError` → runtime error 213. Every `Paint` runs one of
these loops, so switching with the hidden command 612 should crash on the next repaint, and an
INI with resolution 2 should crash at start-up. Also `CmResolution1024` does not reload the
toolbar resource.

### KAISER.REC – records (`Rekorde`), 0x187 bytes

Read by `Records_Load` (`CmRekorde`, REKORDDLG 1040:44f8, record check 1040:4557), written by
`Records_Save`. Strings are zero-terminated char arrays. The record check only accepts a new
record when the stored id (GameHeader word +12h, apparently a per-game id; `_q`) differs from the current game's.

| Offset | Type | Content | Default |
|---|---|---|---|
| 00 | s32 | checksum A = years + population − land + taler − hero level − hero kills | |
| 04 | char[41] | holder of record 1 (FormatPlayerTitle) | Kaiser Arno Nymus von Niemandsland |
| 2D | u16 | record 1: fewest years to become Kaiser (lower is better) | 100 |
| 2F | char[25] | date `dd.mm.yyyy` | 01.01.2000 |
| 48 | u16 | game id | 0 |
| 4A | char[41] | holder of record 2 | as above |
| 73 | s32 | record 2: largest land (ha) | 100000 |
| 77 | char[25] | date | |
| 90 | u16 | game id | |
| 92 | char[41] | holder of record 3 | |
| BB | s32 | record 3: largest population | 10000 |
| BF | char[25] | date | |
| D8 | u16 | game id | |
| DA | s32 | checksum B = sum of the six values | |
| DE | char[41] | holder of record 4 | |
| 107 | s32 | record 4: most Taler | 1000000 |
| 10B | char[25] | date | |
| 124 | u16 | game id | |
| 126 | char[41] | holder of record 5 (player) | |
| 14F | char[25] | record 5: strongest hero, name | Sir Iggy |
| 168 | u8 | hero level (score = level × 3 + kills) | 6 |
| 169 | char | validity marker `V` | |
| 16A | s16 | hero kills | 1 |
| 16C | char[25] | date | |
| 185 | u16 | game id | |

The checksums are written but `Records_Load` only checks the size and the `V` marker.

### KAISER.SCO – annals (`Annalen`, HIGHSCOREDLG), 1 + 0xabe bytes

`Annals_Save`/`Annals_Load`: first byte `{` (the savegame magic 7Bh, written from
`GameHeader.magic`), then 2750 bytes = 5 tables × 0x226; each table 11 entries × 50 bytes
(10 visible + 1 slot for the new candidate, sorted by 1068:67db). Entry (from 1040:3fc4):
+00 char[41] FormatPlayerTitle, +29 u8 spell (epithet), +2A s32 score (1068:12fe), +2E s16 year
(+1400), +30 u16 game id (a game enters a table only once). A missing or invalid file is
replaced by zeros (1068:67c5).

### E-mail game passwords

In e-mail games the human players' passwords (player +0x5d7, char[25], entered in seg 5
1020:0002, checked with 3 attempts in 1020:014e) are obfuscated in the savegame:
`SaveGame_EncryptPasswords` adds the bytes of the string `001: Kann Datei ` (DS:2f84, really an
error message) character by character, `LoadGame_DecryptPasswords` subtracts them.

### Hero name cheat

`HeroNameDlg` (HELDDLG, RITTERHELDDLG, REKHELDDLG) proposes a random name from string ids
101…320. In a game with `census_editor_enabled` (INI `Debug=an`), entering the name
**`guams dlo`** sets flag +49h and the callers (1010:xxxx, 1040:xxxx) create a **Lindwurm**
(unit type 12, 1068:5439) instead of the hero.

### Dialog class hierarchy (segment 12)

```
TDialog
└─ KaiserDlg (VMT DS:3364, DMT DS:3350: WM_SETFONT, WM_CTLCOLOR)  ~59 dialog types
   ├─ MessageDlg DS:33c6 (static 101), Message2Dlg DS:3472 (statics 101/102)
   ├─ PlayerSelectDlg DS:357a (combo box 101), Button2Dlg DS:3652, ChoiceDlg DS:36ea
   └─ HelpDlg (DMT DS:33b8: id 999 → WinHelp popup, virtual +54 SetHelpContext)
      ├─ HelpMessageDlg DS:341a, HelpChoice2Dlg DS:34c6, HeroNameDlg DS:351e
      └─ UnitInfoDlg DS:35e6 (SetTimer 400 ms, sprites 1100+type / 1300+type)
```

`KaiserDlg::SetupWindow` (1058:004a) centres every dialog over its parent and is called by the
SetupWindow of ~55 descendants; `KaiserDlg::Done` (1058:0166) is slot +08 of almost every game
dialog VMT.

### Existing names that should be changed (not renamed in the CSV)

| Address | Current name | Proposed | Evidence |
|---|---|---|---|
| 1058:0002 | `Do_Info` (26_actions.csv) | `KaiserDlg::Init` | TDialog.Init wrapper with 61 callers: called by every dialog constructor and with VMT DS:3364 for plain dialogs; `CmInfo` merely uses it for the INFO dialog. The comment "gets the current player record" is wrong. |
| 1058:00fb | `T0536::Msg0030` | `KaiserDlg::WMSetFont` | wm 30h = WM_SETFONT, stores wParam at +28; DMT DS:3350 is the base DMT, not specific to VMT 0536 |
| 1058:0111 | `T0536::Msg0019` | `KaiserDlg::WMCtlColor` | wm 19h = WM_CTLCOLOR, returns brush DS:63a6 |
| 1058:0221 | `T0916::IdCtl999` | `HelpDlg::IdHelp` | handler in the shared DMT DS:33b8 |
| 1058:0aba / 0ca1 | `T35e6::WMPaint` / `WMTimer` | `UnitInfoDlg::WMPaint` / `WMTimer` | VMT DS:35e6 = UnitInfoDlg |
| 1058:0d7f, 0d93 | `T3652::IdCtl101/102` | `Button2Dlg::IdButton101/102` | EndDlg(id) |
| 1058:0ec9 … 0f7d | `T36ea::IdCtl101…110` | `ChoiceDlg::IdButton101…110` | EndDlg(id) |
| 1080:067d | `T4418::Msg0478` | `Toolbar::WMLayoutInParent` | docking protocol, see above |
| 1080:091d … 0a13 | `T4418::WM*` | `Toolbar::WM*` | VMT DS:4418 = Toolbar |
| 1060:019c | `Do_612` (26_actions.csv) | already overridden by `UpdateSettingsMenu` (90_hidden.csv) | — |

README.md says KAISER.INI is read from `C:\WINDOWS` "without a path": the path is the current
directory (see above), which is the Windows directory only when no working directory is set.

## Segment 1 (1000) – main program, KaiserWindow (VMT DS:01a4)

### Application and main window lifecycle

| Address | Name | Purpose |
|---|---|---|
| 1000:3a3c | `entry` | Program main: InitTask, unit init chain (segs 26,18,17,14,13,12,11,10,9,8,7,4,3,2), App.Init/Run/Done, Halt |
| 1000:0002 | `KaiserApp::InitMainWindow` | Creates the main window (1000:0045) and loads accelerators MENUKEYS |
| 1000:0045 | `KaiserWindow::Init` | Main window constructor: menu MAINMENU, bitmaps PALAST/KATHEDRALE, toolbar KAISERTOOLS_640/800, default file name autosave.ksr. Player array at Self+0x41 (stride 0x6d5), game header copy at Self+0x4493, file name at Self+0x4625 |
| 1000:0226 | `KaiserWindow::GetWindowClass` * | VMT DS:01a4 slot +34: inherited GetWindowClass, then hIcon = LoadIcon(KRONENICON, DS:025a), hbrBackground = GetStockObject(BLACK_BRUSH), style \|= CS_DBLCLKS (8) |
| 1000:0268 | `KaiserWindow::SetupWindow` * | VMT DS:01a4 slot +38: TWindow.SetupWindow, disables toolbar buttons 0..DS:4554[res], UpdateSettingsMenu, MoveWindow centred on screen (client height fixed to ResolutionHeight-40), ParamCount>0 -> 1000:1136 |
| 1000:0af4 | `KaiserWindow::CanClose` * | VMT DS:01a4 slot +3c: while a game runs (game_state 1) and Self+0x4958 (set by CmBossKey) is 0, asks via MessageBox and only closes on IDYES (6) |
| 1000:39c3 | `KaiserWindow::Done` * | VMT DS:01a4 slot +08: deletes bitmaps PALAST/KATHEDRALE/LOGO (Self+0x494e..52) and background brush DS:63a6, WinHelp(HELP_QUIT), MidiClose, Ini_WriteSettings, TWindow.Done |

### Painting and mouse input

| Address | Name | Purpose |
|---|---|---|
| 1000:0b5d | `KaiserWindow::Paint` * | VMT DS:01a4 slot +4c: game_state 0 title screen 1060:064b + disable commands; 1 DrawPlayerBuildings + enable commands/save, reports menu, caption = player title, stop MIDI; 2/6/7 blank pattern 1060:0527; e-mail game disables save |
| 1000:0b32 | `KaiserWindow::Paint_LayoutChild` * | Nested ForEach callback of Paint: SendMessage(child, 0x478, 1, @ClientRect) so the toolbar docks itself and shrinks the client rect |
| 1000:08ba | `KaiserWindow::WMSize` | Title screen only (game_state 0): minimised -> MidiClose; restored/maximised and music on -> MidiOpen/MidiPlay kaiser.mid |
| 1000:039d | `KaiserWindow::WMLButtonDblClk` | Double click: HandleMapClick(DblClick = True, Y, X) |
| 1000:03bb | `KaiserWindow::WMRButtonDown` | Right button: HandleMapClick(DblClick = False, Y, X) = info popups |
| 1000:03d9 | `KaiserWindow::HandleMapClick` * | (DblClick, Y, X) from WMLButtonDblClk/WMRButtonDown: bottom strip = army1 units (right-click info 1040:330f kind 1, dbl-click Truppen aufstellen); 3x3 block DS:0266 = army2 units (info kind 2); dbl-click granary/warehouse/smithy/tavern -> Korn verteilen/Handel/Hofschmiede/Sabotage |

### Background music (MCI sequencer)

| Address | Name | Purpose |
|---|---|---|
| 1000:0920 | `KaiserWindow::MidiOpen` * | mciSendCommand(MCI_OPEN 0x803, MCI_OPEN_ELEMENT\|MCI_WAIT) for the file name argument (kaiser.mid), stores device id at Self+0x494c; returns success |
| 1000:0985 | `KaiserWindow::MidiPlay` * | If device id Self+0x494c: mciSendCommand(MCI_PLAY 0x806, MCI_NOTIFY) with callback = HWindow (MMMciNotify restarts the loop) |
| 1000:0a0e | `KaiserWindow::MidiClose` * | If device id Self+0x494c: MCI_STOP (0x808) then MCI_CLOSE (0x804), both MCI_WAIT, clears the id; 6 callers (WMSize minimise, Paint in-game, Done, MMMciNotify) |
| 1000:09cf | `KaiserWindow::MMMciNotify` | MM_MCINOTIFY successful: close, reopen and replay kaiser.mid (endless loop while music is on) |

### Files, annals, records, boss key

| Address | Name | Purpose |
|---|---|---|
| 1000:0ce6 | `KaiserWindow::CmNeuesSpiel` | DMT handler: cm 101 Neues Spiel |
| 1000:0e3c | `KaiserWindow::CmFileOpen` | Menu 102 Oeffnen: GetOpenFileName, then LoadGame |
| 1000:1136 | `KaiserWindow::LoadFromCommandLine` * | ParamStr(1) -> LoadGame; error MessageBox; autosave.ksr/boss.ksr are not kept as current file; else save_path/save_file set; start-turn dialog or EmailGameStep; Ini_WriteLastGame |
| 1000:1099 | `ExtractFileName` * | Nested helper of 1000:1136: copies the part of Path after the last backslash to Dest (whole string if no backslash) |
| 1000:1292 | `KaiserWindow::CmLoadLastGame` | Cmd 803 (Ctrl+L): load the last savegame from KAISER.INI and resume |
| 1000:13ce | `KaiserWindow::CmSpeichern` | DMT handler: cm 103 Speichern |
| 1000:1427 | `KaiserWindow::CmFileSaveAs` | Menu 104 Speichern unter: GetSaveFileName, then SaveGame |
| 1000:1541 | `KaiserWindow::CmAnnalen` | DMT handler: cm 106 Annalen |
| 1000:1575 | `KaiserWindow::CmRekorde` | DMT handler: cm 107 Rekorde |
| 1000:3944 | `KaiserWindow::CmBossKey` | Cmd 801 (key b): save to boss.ksr and close immediately |

### Game menu commands

| Address | Name | Purpose |
|---|---|---|
| 1000:1598 | `KaiserWindow::CmKornVerteilen` | DMT handler: cm 201 Korn verteilen |
| 1000:15d7 | `KaiserWindow::CmLandHandeln` | DMT handler: cm 202 Land handeln |
| 1000:1611 | `KaiserWindow::CmGebaeude` | DMT handler: cm 203 Gebäude |
| 1000:164b | `KaiserWindow::CmSteuernFestsetzen` | DMT handler: cm 204 Steuern festsetzen |
| 1000:168c | `KaiserWindow::CmHandelMitGuetern` | DMT handler: cm 205 Handel mit Gütern |
| 1000:16d0 | `KaiserWindow::CmDemissionieren` | DMT handler: cm 209 Demissionieren |
| 1000:17bb | `KaiserWindow::CmEntwicklungshilfe` | DMT handler: cm 221 Entwicklungshilfe |
| 1000:17fc | `KaiserWindow::CmAbkommen` | DMT handler: cm 222 Abkommen |
| 1000:183d | `KaiserWindow::CmTributFordern` | DMT handler: cm 223 Tribut fordern |
| 1000:187e | `KaiserWindow::CmSabotage` | DMT handler: cm 224 Sabotage |
| 1000:18bf | `KaiserWindow::CmTruppenAufstellen` | DMT handler: cm 211 Truppen aufstellen |
| 1000:18fe | `KaiserWindow::CmManoeverAbhalten` | DMT handler: cm 213 Manöver abhalten |
| 1000:193f | `KaiserWindow::CmKriegFuehren` | DMT handler: cm 214 Krieg führen |
| 1000:1b70 | `KaiserWindow::CmDemographischeDaten` | DMT handler: cm 301 Demographische Daten |
| 1000:1b9f | `KaiserWindow::CmFinanzhaushalt` | DMT handler: cm 302 Finanzhaushalt |
| 1000:1bd9 | `KaiserWindow::CmKarriereberatung` | DMT handler: cm 303 Karriereberatung |
| 1000:1c04 | `KaiserWindow::CmGeheimdienst` | DMT handler: cm 305 Geheimdienst |
| 1000:1c42 | `KaiserWindow::CmInternationalerVergleich` | DMT handler: cm 304 Internationaler Vergleich |
| 1000:1c66 | `KaiserWindow::CmHofschmiede` | DMT handler: cm 306 Hofschmiede |
| 1000:1c91 | `KaiserWindow::CmMilitaer` | DMT handler: cm 312 Militär |
| 1000:1cf0 | `KaiserWindow::CmWirtschaft` | DMT handler: cm 311 Wirtschaft |
| 1000:1d4b | `KaiserWindow::CmSpiel` | DMT handler: cm 320 Spiel |

### Options, reports, help and hidden commands

| Address | Name | Purpose |
|---|---|---|
| 1000:1dd8 | `KaiserWindow::CmGeschichtsschreibung` | DMT handler: cm 601 Geschichtsschreibung |
| 1000:1e17 | `KaiserWindow::CmKrachUndGeschrei` | DMT handler: cm 602 Krach und Geschrei |
| 1000:1e56 | `KaiserWindow::CmSchalmeienklaenge` | DMT handler: cm 603 Schalmeienklänge |
| 1000:1ec3 | `KaiserWindow::CmLaendernamen` | DMT handler: cm 604 Ländernamen |
| 1000:1ed4 | `KaiserWindow::Cm640x480` | DMT handler: cm 610 640x480 |
| 1000:1f4e | `KaiserWindow::Cm800x600` | DMT handler: cm 611 800x600 |
| 1000:1fc8 | `KaiserWindow::CmResolution1024` | Cmd 612 (no menu entry): hidden 1024x768 window size |
| 1000:202e | `KaiserWindow::CmBerichtKlatschUndTratsch` | DMT handler: cm 701 Klatsch und Tratsch |
| 1000:20b7 | `KaiserWindow::CmBerichtBevoelkerungsentwicklung` | DMT handler: cm 702 Bevölkerungsentwicklung |
| 1000:2140 | `KaiserWindow::CmBerichtStaatshaushalt` | DMT handler: cm 703 Staatshaushalt |
| 1000:21c9 | `KaiserWindow::CmBerichtGeheimdienst` | DMT handler: cm 704 Geheimdienst |
| 1000:2252 | `KaiserWindow::CmBerichtHandelMitGuetern` | DMT handler: cm 705 Handel mit Gütern |
| 1000:22db | `KaiserWindow::CmBerichtKornVerteilen` | DMT handler: cm 706 Korn verteilen |
| 1000:2364 | `KaiserWindow::CmBerichtLandHandeln` | DMT handler: cm 707 Land handeln |
| 1000:23ed | `KaiserWindow::CmBerichtGebaeude` | DMT handler: cm 708 Gebäude |
| 1000:2476 | `KaiserWindow::CmBeenden` | DMT handler: cm 401 Beenden |
| 1000:38cf | `KaiserWindow::CmUeberDieHilfe` | DMT handler: cm 503 Über die Hilfe |
| 1000:38ed | `KaiserWindow::CmHilfe` | DMT handler: cm 501 Hilfe |
| 1000:390b | `KaiserWindow::CmInfo` | DMT handler: cm 502 Info |
| 1000:398e | `KaiserWindow::Cm802` | DMT handler: cm 802 |

### Turn flow

| Address | Name | Purpose |
|---|---|---|
| 1000:0a6f | `KaiserWindow::EndGame` | Called after victory / game end; plays kaiser.mid |
| 1000:2637 | `KaiserWindow::EmailGameStep` | E-mail game sequencer over game_state 2..14: after each step saves the game for the next human and returns to state 0. States 3/8/9/0xb-0xe = phases of a pending battle (data in the 0x192 extra block at Self+0x4493) |
| 1000:33c0 | `KaiserWindow::BeginHumanTurn` | game_state=6, runs the start-of-turn processing 1010:37b6, game_state = its result, then autosave to autosave.ksr if Opt_Autosave and not e-mail |
| 1000:3459 | `KaiserWindow::Victory` | Title 10 reached: coronation 1040:4bc7; for humans without census editor also high score 1040:3fc4 / records 1040:4557; then 1000:0a6f |
| 1000:35ad | `KaiserWindow::NextPlayer` | current_player++, wraps to 0 with year++; skips players with skip_turn (clearing it); runs CpuTurn for computer players and checks victory (title 10) |
| 1000:36d2 | `KaiserWindow::CpuTurn` | Computer player turn: AI economy 1008:0002, AI war-target choice 1008:24eb (war -> ResolveWar), AI end of turn 1008:29ea |
| 1000:37c0 | `KaiserWindow::ResolveWar` | War of current_player against param target: battle 1018:0558 (retried once on result 3), news item 8 (won) or 9 (lost) |

## Segment 11 (1050) – files: savegames, annals, records, KAISER.INI, MAPDATA

### Savegames (.KSR)

| Address | Name | Purpose |
|---|---|---|
| 1050:058b | `SaveGame` | Writes header DS:6108 (0x295), N player records (0x6d5) with anti-cheat checksums, optional 0x192 extra block. See docs/ksr-format.md |
| 1050:07ed | `LoadGame` | Reads and validates a .KSR (magic 0x7B, checksums); copies header to DS:6108. See docs/ksr-format.md |
| 1050:03fd | `SaveGame_EncryptPasswords` * | Nested in SaveGame (e-mail games): for each human (cpu_level 0) adds the bytes of '001: Kann Datei ' (DS:2f84) to the password at player+0x5d7 |
| 1050:04c4 | `LoadGame_DecryptPasswords` * | Nested in LoadGame (e-mail games): inverse of 1050:03fd, subtracts the key bytes from player+0x5d7 |
| 1050:12f8 | `ShowFileError` | Error message for load/save: 1 open, 2 write, 3 bad magic, 5 short read or checksum |

### Annals (KAISER.SCO) and records (KAISER.REC)

| Address | Name | Purpose |
|---|---|---|
| 1050:000d | `Annals_Save` * | Rewrite KAISER.SCO (literal 1050:0002): 1 byte GameHeader.magic ('{') + 0xabe-byte annals table; called by HighscoreDlg 1040:3f44 |
| 1050:0070 | `Annals_Load` * | Reset KAISER.SCO (literal 1050:0065): first byte must be '{' and 0xabe bytes must follow, else False (callers then zero the table, 1068:67c5) |
| 1050:011d | `Records_Load` * | Reads KAISER.REC (literal 1050:0112), 0x187 bytes; short file or byte +169h != 'V' -> defaults (Kaiser Arno Nymus von Niemandsland, 100 years / 100000 ha / 10000 people / 1000000 Taler, hero Sir Iggy, 01.01.2000) |
| 1050:030f | `Records_Save` * | Sets marker +169h='V', checksums +00 (years+pop-land+taler-hlevel-hkills) and +DAh (sum of all), Rewrite KAISER.REC (literal 1050:0304) 0x187 bytes |

### KAISER.INI

| Address | Name | Purpose |
|---|---|---|
| 1050:0ade | `Ini_ReadSettings` * | Called by InitMainWindow: [Kaiser] keys Geschichtsschreibung, Krach & Geschrei, Schalmeienklaenge, Debug (an/aus), Aufloesung, Hintergrund rot/gruen/blau, Delta X/Y, Schlacht-Timer (min 50), 10 country names/adjectives, Spieler0..9, 10 CPU names |
| 1050:0e65 | `Ini_WriteSettings` * | Called by KaiserWindow::Done: writes all keys of Ini_ReadSettings back to KAISER.INI (except Debug) via WritePrivateProfileString |
| 1050:1185 | `Ini_ReadLastGame` * | (Path, FileName): GetPrivateProfileString [Kaiser] 'Letzter Pfad' (255 chars) and 'Letzte Datei' (12 chars), default empty; used by CmLoadLastGame |
| 1050:11cf | `Ini_WriteLastGame` * | (FileName, Path): if Path <> nil writes 'Letzter Pfad' and 'Letzte Datei'; called after open, load-from-command-line and save-as |
| 1050:1362 | `Unit11_Init` * | Unit init of seg 11 (entry chain): DS:609e 'an', 60a2 'aus', 60a6 'Kaiser' (INI section), 60ae '640x480', 60b6 '800x600'; DS:60be (1024 value) stays empty |

### Resources

| Address | Name | Purpose |
|---|---|---|
| 1050:1212 | `LoadMapData` | FINDRESOURCE MAPDATA id n+1, copies 165 bytes (15x11, column-major) |

## Segment 12 (1058) – common dialog classes

### KaiserDlg – base of all game dialogs (VMT DS:3364, DMT DS:3350)

| Address | Name | Purpose |
|---|---|---|
| 1058:0002 | `Do_Info` | KaiserDlg.Init(AParent, AName): TDialog.Init, sets bit 40h in Attr.Param; base constructor of every game dialog (61 callers) and used directly with VMT DS:3364 for plain dialogs (INFO, ...). Existing name is misleading, see Renames |
| 1058:004a | `KaiserDlg::SetupWindow` * | SetupWindow of the common dialog base (VMT DS:3364 slot +38, inherited by ~55 dialogs): stores width/height at +2a/+2c, centres the dialog over its parent, invalidates |
| 1058:0166 | `KaiserDlg::Done` * | Slot +08 of nearly all game dialog VMTs: selects old font +28 back into the window DC, deletes font +26, TDialog.Done |
| 1058:00fb | `T0536::Msg0030` | WM_SETFONT (30h): stores the dialog font handle (wParam) at +28h |
| 1058:0111 | `T0536::Msg0019` | WM_CTLCOLOR (19h): transparent text background; edits get WHITE_BRUSH, list boxes and scroll bars stay default, all other controls and the dialog get the INI background brush DS:63a6 |
| 1058:0f91 | `Unit12_Init` * | Empty unit init of seg 12 (called from entry chain) |

### HelpDlg – base with "?" button 999 (DMT DS:33b8)

| Address | Name | Purpose |
|---|---|---|
| 1058:01bb | `HelpDlg::Init` * | (AParent, AName, HelpCtx): KaiserDlg.Init + TButton id 999 (+30), help context at +2e; base of dialogs with DMT DS:33b8 (27 callers) |
| 1058:0210 | `HelpDlg::SetHelpContext` * | Virtual slot +54 of the help dialogs: Self+2e := Ctx (WinHelp context used by the '?' button 999) |
| 1058:0221 | `T0916::IdCtl999` | '?' button id 999: WinHelp(kaiser.hlp, HELP_CONTEXTPOPUP, +2eh) when a context is set |

### Message dialogs (one or two text lines)

| Address | Name | Purpose |
|---|---|---|
| 1058:024d | `MessageDlg::Init` * | (AParent, AName, AText): KaiserDlg.Init + TStatic id 101 (80 chars, +7f), copies AText to +2e; VMT DS:33c6, 15 callers |
| 1058:02ae | `MessageDlg::SetupWindow` * | VMT DS:33c6 slot +38: KaiserDlg.SetupWindow, then static 101 := text +2e |
| 1058:02d6 | `HelpMessageDlg::Init` * | (AParent, AName, AText, HelpCtx): HelpDlg.Init + TStatic id 101 (+85), text at +34; VMT DS:341a |
| 1058:033b | `HelpMessageDlg::SetupWindow` * | VMT DS:341a slot +38: centre, static 101 := text +34 |
| 1058:0364 | `Message2Dlg::Init` * | (AParent, AName, Text1, Text2): KaiserDlg.Init + statics 101 (+d0) and 102 (+d4), texts at +2e/+7f; VMT DS:3472, 10 callers |
| 1058:03fd | `Message2Dlg::SetupWindow` * | VMT DS:3472/0be8 slot +38: centre, statics 101/102 := texts +2e/+7f |

### HelpChoice2Dlg – two texts, buttons 1/2 (VMT DS:34c6, KRIEGSER*DLG)

| Address | Name | Purpose |
|---|---|---|
| 1058:043e | `HelpChoice2Dlg::Init` * | (AParent, AName, Text1, Text2, HelpCtx): HelpDlg + statics 101/102 + buttons 1/2 with enable flags +e6/+e7; VMT DS:34c6, KRIEGSER*DLG war declarations |
| 1058:0522 | `HelpChoice2Dlg::SetupWindow` * | VMT DS:34c6 slot +38: centre, set both texts, disable button 1/2 when flag +e6/+e7 is 0 |
| 1058:0591 | `HelpChoice2Dlg::DisableButton2` * | Clears +e7: button id 2 ('Auf den Feldern') disabled; seg 6 calls it when the army is away (player+0x584) |

### HeroNameDlg – name a new hero (VMT DS:351e)

| Address | Name | Purpose |
|---|---|---|
| 1058:05a1 | `HeroNameDlg::Init` * | (AParent, AName, HelpCtx): HelpDlg + TEdit id 101 (16 chars, +34), cheat flag +49 := 0; VMT DS:351e, used by HELDDLG/RITTERHELDDLG/REKHELDDLG |
| 1058:05f8 | `HeroNameDlg::SetupWindow` * | VMT DS:351e slot +38: centre, proposes a random hero name LoadString(101+Random(220)), help context 0xd1 |
| 1058:0649 | `HeroNameDlg::GetName` * | VMT DS:351e slot +58: returns @Self+38 (the entered name) |
| 1058:0666 | `HeroNameDlg::CanClose` * | VMT DS:351e slot +3c: reads the edit into +38; if census_editor_enabled and name = 'guams dlo' (DS:374a+3751) sets +49 -> callers create a Lindwurm (1068:5439 type 12) instead of the hero |

### PlayerSelectDlg – choose another player (VMT DS:357a)

| Address | Name | Purpose |
|---|---|---|
| 1058:06d2 | `PlayerSelectDlg::Init` * | (AParent, AName, Players, NumPlayers, Exclude): KaiserDlg + TComboBox 101; list of formatted player titles (1060:03d9) except Exclude, index map +35; VMT DS:357a (SPENDE/TRADE/TRIBUT/SABOAUSWAHLDLG) |
| 1058:07a6 | `PlayerSelectDlg::SetupWindow` * | VMT DS:357a slot +38: fills the combo box with the names, selects entry +32 |
| 1058:0820 | `PlayerSelectDlg::CanClose` * | VMT DS:357a slot +3c: selected index -> player number via map +35 into +32 |
| 1058:084d | `PlayerSelectDlg::GetPlayer` * | VMT DS:357a slot +54: returns chosen player number +32 |

### UnitInfoDlg – unit stats with animated portrait (VMT DS:35e6)

| Address | Name | Purpose |
|---|---|---|
| 1058:0862 | `UnitInfoDlg::Init` * | (AParent, AName, Unit, Mode, HelpCtx): HelpDlg + 8 statics 101..108, copies the 0x3d-byte unit record to +35; VMT DS:35e6 (SOELDNERDLG etc.) |
| 1058:090f | `UnitInfoDlg::SetupWindow` * | VMT DS:35e6 slot +38: shows name, rank (mode 'e', 1068:61db) or ability (mode 'f', DS:53d8), attack, defence, max_hp, range, steps, pay; draws portrait; SetTimer(400 ms) |
| 1058:0af8 | `UnitInfoDlg::DrawPortrait` * | (Frame): 33x33 memory bitmap filled with background brush, masked sprite 1100+type (frame 0) or 1300+type (frame 1) via 1078:00c4, BitBlt scaled by dialog size |
| 1058:0aba | `T35e6::WMPaint` | WM_PAINT: default paint, then DrawPortrait with the current frame (+74h) |
| 1058:0ca1 | `T35e6::WMTimer` | WM_TIMER (400 ms): with probability 1/4 shows the other animation frame for one tick |
| 1058:0cdb | `UnitInfoDlg::Done` * | VMT DS:35e6 slot +08: KillTimer +72, KaiserDlg.Done |

### Button dialogs (VMT DS:3652 LAGERVOLLDLG, DS:36ea KAMPFOPTDLG)

| Address | Name | Purpose |
|---|---|---|
| 1058:0d0d | `Button2Dlg::Init` * | (AParent, AName): KaiserDlg + buttons 101/102 whose handlers (T3652::IdCtl101/102) call EndDlg; VMT DS:3652, LAGERVOLLDLG |
| 1058:0d7f | `T3652::IdCtl101` | Button 101: EndDlg(101) (VMT slot +50h) |
| 1058:0d93 | `T3652::IdCtl102` | Button 102: EndDlg(102) |
| 1058:0da7 | `ChoiceDlg::Init` * | (AParent, AName, Count, Enabled[10]): KaiserDlg + Count buttons 101.. ; enable flags at +2f; VMT DS:36ea, KAMPFOPTDLG |
| 1058:0e50 | `ChoiceDlg::SetupWindow` * | VMT DS:36ea slot +38: centre, Enable/Disable each button by its flag |
| 1058:0ec9 | `T36ea::IdCtl101` | Button 101: EndDlg(101) (VMT slot +50h) |
| 1058:0edd | `T36ea::IdCtl102` | Button 102: EndDlg(102) (VMT slot +50h) |
| 1058:0ef1 | `T36ea::IdCtl103` | Button 103: EndDlg(103) (VMT slot +50h) |
| 1058:0f05 | `T36ea::IdCtl104` | Button 104: EndDlg(104) (VMT slot +50h) |
| 1058:0f19 | `T36ea::IdCtl105` | Button 105: EndDlg(105) (VMT slot +50h) |
| 1058:0f2d | `T36ea::IdCtl106` | Button 106: EndDlg(106) (VMT slot +50h) |
| 1058:0f41 | `T36ea::IdCtl107` | Button 107: EndDlg(107) (VMT slot +50h) |
| 1058:0f55 | `T36ea::IdCtl108` | Button 108: EndDlg(108) (VMT slot +50h) |
| 1058:0f69 | `T36ea::IdCtl109` | Button 109: EndDlg(109) (VMT slot +50h) |
| 1058:0f7d | `T36ea::IdCtl110` | Button 110: EndDlg(110) (VMT slot +50h) |

## Segment 13 (1060) – main window painting and menus

### Menu state

| Address | Name | Purpose |
|---|---|---|
| 1060:0002 | `Menu_EnableSave` * | ModifyMenu 103 '&Speichern' and 104 'Speichern &unter' to MF_ENABLED, DrawMenuBar (Paint when a game runs) |
| 1060:0037 | `Menu_DisableSave` * | ModifyMenu 103/104 to MF_GRAYED, DrawMenuBar (Paint in e-mail games) |
| 1060:006c | `Menu_EnableGameCommands` * | (Toolbar, HWnd, HMenu): ModifyMenu the 31 game commands (ids DS:3e4c, texts DS:39f0 stride 0x24) MF_ENABLED, then toolbar buttons 0..DS:4554[res] SetEnabled(True) |
| 1060:0104 | `Menu_DisableGameCommands` * | Same tables as 1060:006c but MF_GRAYED and toolbar SetEnabled(False) (title screen, turn hand-over) |
| 1060:019c | `UpdateSettingsMenu` | Check marks of the Einstellungen menu (autosave, sound, music, resolution) |
| 1060:0254 | `Menu_UpdateReportChecks` * | Check marks of menu 701..708 (Berichte) from bits 0..7 of player report_flags (+0x5f6) |

### Painting

| Address | Name | Purpose |
|---|---|---|
| 1060:0527 | `PaintPatternBackground` * | Fills the client area minus 33/40 px with the MUSTER pattern brush (memory DC, BitBlt at x=32, right of the 32-px toolbar); Paint for game_state 2/6/7 |
| 1060:064b | `PaintTitleScreen` * | MUSTER background plus WAPPEN (200x250) and BIGLOGO (250x125) stretched by the resolution factor DS:4542[res] (1.0/1.25/1.6) via 1078:0228; Paint for game_state 0 |
| 1060:0868 | `DrawPlayerBuildings` | Main window: draws the building icons of the current player on the map |

### Strings and init

| Address | Name | Purpose |
|---|---|---|
| 1060:03d9 | `FormatPlayerTitle` * | (WithEpithet, WithKaiserPrefix, Dest, Player): ['Kaiser - '] + title (male/female table) + ' ' + name + [' genannt "' + spell epithet DS:3eda/4020 + '"'] + ' von ' + country; 30 callers |
| 1060:2241 | `Unit13_Init` * | Unit init: LOGFONT DS:60c8 = -12 px, bold (700), PROOF_QUALITY, FF_DECORATIVE\|VARIABLE_PITCH, 'Comic Sans MS' (CreateFontIndirect in DrawPlayerBuildings) |

## Segment 16 (1078) – bitmap helpers

### Blitting

| Address | Name | Purpose |
|---|---|---|
| 1078:0002 | `Bmp_Draw` * | (DC, HBmp, X, Y, W, H): CreateCompatibleDC, BitBlt SRCCOPY from (0,0) of a loaded bitmap handle; battle screen icons |
| 1078:0062 | `Bmp_DrawPart` * | (DC, HBmp, X, Y, SrcX, SrcY, W, H): like 1078:0002 with a source offset (strip of sub-images) |
| 1078:00c4 | `Bmp_DrawMasked` * | (DC, Id, X, Y, W, H): LoadBitmap(Id+1000) with SRCAND then LoadBitmap(Id) with SRCPAINT = transparent sprite; 10 callers |
| 1078:0199 | `Bmp_DrawSilhouette32` * | (DC, Id, X, Y): only the mask LoadBitmap(Id+2100) of sprite 1100+Id, 32x32 SRCAND = black silhouette; battle map (seg 10) |
| 1078:0228 | `Bmp_DrawStretched` * | (DC, HBmp, X, Y, W, H, Scale: Real): StretchBlt SRCCOPY to Round(W*Scale) x Round(H*Scale); title screen |

## Segment 17 (1080) – OWLToolbar unit

### Toolbar window (VMT DS:4418, class "OWLToolbar")

| Address | Name | Purpose |
|---|---|---|
| 1080:0002 | `Toolbar_Max` * | Max(A, B) of two integers; used by Toolbar::AdvanceToolPos |
| 1080:0023 | `Toolbar::Init` * | (AParent, AResName, AOrientation): TWindow.Init, Style WS_CHILD\|WS_VISIBLE\|WS_BORDER, X/Y -1, W/H 5, tools collection +45, orientation +55, then LoadTools (slot +60); KaiserWindow.Init uses KAISERTOOLS_640/800, orientation 2 |
| 1080:00de | `Toolbar::Done` * | VMT DS:4418 slot +08: TWindow.Done, disposes the tools collection, frees resource name |
| 1080:0115 | `Toolbar::Store_WriteTool` * | Nested ForEach callback of Toolbar::Store: Tool^.Write(S) (slot +3c) |
| 1080:0130 | `Toolbar::Store` * | VMT DS:4418 slot +50: TWindow.Store, writes orientation, flag 0+id or 1+StrWrite(name) for the resource name, then each tool |
| 1080:01df | `Toolbar::SetResource` * | (AResName): disposes and re-creates the tools collection, SetResName, LoadTools; Cm640x480/Cm800x600 switch KAISERTOOLS_640/800 |
| 1080:0229 | `Toolbar::LoadTools` * | VMT DS:4418 slot +60: FindResource(name, 'ToolBarData'): word N, N x (bitmap id, command); CreateTool + AdvanceToolPos from (2,2), adds 8 px border; Status -4 if missing |
| 1080:034f | `Toolbar::GetOrientation` * | VMT DS:4418 slot +64: returns +55 (1 top, 2 left, 4 right) |
| 1080:0364 | `Toolbar::SetOrientation_PlaceTool` * | Nested ForEach callback of SetOrientation: Tool^.SetPosition(pos), Toolbar.AdvanceToolPos, counter+1 |
| 1080:03aa | `Toolbar::SetOrientation` * | VMT DS:4418 slot +68: stores orientation, relayouts all tools from W/H 5, +8 border, SetWindowPos size |
| 1080:0413 | `Toolbar::CreateTool` * | VMT DS:4418 slot +54: bitmap id 0 -> ToolSpacer(size = 2nd word, VMT DS:4484), else ToolButton(bitmap, command, x, y, VMT DS:44c4) |
| 1080:046b | `Toolbar::EnableTool_Match` * | Nested FirstThat callback: Tool^.HasCommand(Cmd) (slot +2c) |
| 1080:048b | `Toolbar::EnableTool` * | VMT DS:4418 slot +58: (Cmd, Enable): first tool with that command -> SetEnabled(Enable) |
| 1080:04c6 | `Toolbar::GetClassName` * | VMT DS:4418 slot +2c: returns 'OWLToolbar' |
| 1080:04df | `Toolbar::GetWindowClass` * | VMT DS:4418 slot +34: inherited, hbrBackground = GetStockObject(LTGRAY_BRUSH) |
| 1080:0503 | `Toolbar::AdvanceToolPos` * | VMT DS:4418 slot +5c: (Tool, var Pos): orientation 1 -> Pos.X += width, H := Max(H, height); 2/4 -> Pos.Y += height, W := Max(W, width) |
| 1080:057f | `Toolbar::Paint_PaintTool` * | Nested ForEach callback of Paint: Tool^.Paint(DC, MemDC) (slot +18) |
| 1080:05a5 | `Toolbar::Paint` * | VMT DS:4418 slot +4c: white highlight line along the top edge, one compatible memory DC shared by all tools |
| 1080:060f | `Toolbar::FreeResName` * | StrDispose(+41) when the resource name is a string (+43 <> 0) |
| 1080:0637 | `Toolbar::SetResName` * | (AName): integer id kept as is (segment 0), otherwise StrNew copy at +41 |
| 1080:067d | `T4418::Msg0478` | wm 0478h (wm_User+78h) from the parent Paint, lParam = client rect: docks the toolbar at the top (1), left (2) or right (4) edge, resizes it to the client height/width, shrinks the rect. Rename proposed: Toolbar::WMLayoutInParent |
| 1080:08f5 | `Toolbar::WMLButtonDown_HitTest` * | Nested FirstThat callback: Tool^.HitTest(X, Y) (slot +14) |
| 1080:091d | `T4418::WMLButtonDown` | Tool under the cursor (HitTest) becomes the captured tool (+51h): Tool.BeginPress(X, Y) |
| 1080:0969 | `Toolbar::WMRButtonDown_HitTest` * | Nested FirstThat callback: Tool^.HitTest(X, Y) (slot +14) |
| 1080:0991 | `T4418::WMRButtonDown` | Tool under the cursor: Tool.RightClick(X, Y, HWindow) (context help popup) |
| 1080:09e5 | `T4418::WMMouseMove` | Captured tool: MouseMove (press/release feedback) |
| 1080:0a13 | `T4418::WMLButtonUp` | Captured tool: EndPress; clears +51h when it returns True |

### Tool – abstract base (TObject descendant, default virtuals)

| Address | Name | Purpose |
|---|---|---|
| 1080:0a5a | `Tool::Init` * | Constructor of the abstract tool (TObject descendant): stores owner toolbar at +2 |
| 1080:0a80 | `Tool::HitTest` * | Default slot +14: returns False |
| 1080:0a8f | `Tool::Paint` * | Default slot +18: empty |
| 1080:0a96 | `Tool::BeginPress` * | Default slot +1c (mouse down): empty |
| 1080:0a9d | `Tool::MouseMove` * | Default slot +20: empty |
| 1080:0aa4 | `Tool::EndPress` * | Default slot +24 (mouse up): returns an uninitialised Boolean |
| 1080:0aaf | `Tool::RightClick` * | Default slot +28: returns an uninitialised Boolean |
| 1080:0aba | `Tool::SetEnabled` * | Default slot +30: empty |
| 1080:0ac1 | `Tool::SetPosition` * | Default slot +34: empty |
| 1080:0ac8 | `Tool::HasCommand` * | Default slot +2c: returns False |
| 1080:0ad7 | `Tool::Read` * | Default slot +38 (stream read): empty |
| 1080:0ade | `Tool::Write` * | Default slot +3c (stream write): empty |

### ToolSpacer (VMT DS:4484)

| Address | Name | Purpose |
|---|---|---|
| 1080:0ae5 | `ToolSpacer::Init` * | (Toolbar, Size): Tool.Init, size at +6; VMT DS:4484 (instance 8 bytes) |
| 1080:0b17 | `ToolSpacer::GetWidth` * | VMT DS:4484 slot +0c: returns size +6 |
| 1080:0b2c | `ToolSpacer::GetHeight` * | VMT DS:4484 slot +10: returns size +6 |

### ToolButton (VMT DS:44c4)

| Address | Name | Purpose |
|---|---|---|
| 1080:0b41 | `ToolButton::Init` * | (Toolbar, BitmapId, Cmd, X, Y): Tool.Init, LoadBitmap(id) +6, command +8, enabled +0c := 1, bitmap size +15/+17, rect +0d = (X, Y, X+w+4, Y+h+4); VMT DS:44c4 |
| 1080:0bee | `ToolButton::Done` * | VMT DS:44c4 slot +08: if still pressed releases DCs and capture, deletes bitmap, TObject.Done |
| 1080:0c4b | `ToolButton::HasCommand` * | VMT DS:44c4 slot +2c: Cmd = +8 |
| 1080:0c68 | `ToolButton::SetEnabled` * | VMT DS:44c4 slot +30: invalidates its rect when +0c changes |
| 1080:0cab | `ToolButton::GetWidth` * | VMT DS:44c4 slot +0c: rect right - left |
| 1080:0cc4 | `ToolButton::GetHeight` * | VMT DS:44c4 slot +10: rect bottom - top |
| 1080:0cdd | `ToolButton::SetPosition` * | VMT DS:44c4 slot +34: (X, Y): rect := X, Y, X+bmWidth+4, Y+bmHeight+4 |
| 1080:0d20 | `ToolButton::HitTest` * | VMT DS:44c4 slot +14: PtInRect(rect, X, Y) |
| 1080:0d42 | `ToolButton::Paint` * | VMT DS:44c4 slot +18: forwards to ToolButton::Draw |
| 1080:0d59 | `ToolButton::Draw` * | (DC, MemDC): black frame on LTGRAY face; up = white/grey 3D edge, bitmap at +2, down = grey edge, bitmap at +3; disabled -> GrayingBitmap brush ROP 0x00A803A9, else SRCCOPY |
| 1080:0f5f | `ToolButton::PressDown` * | If enabled and not drawn down: +0b := 1, redraw |
| 1080:0f8b | `ToolButton::PressUp` * | If drawn down: +0b := 0, redraw |
| 1080:0fb0 | `ToolButton::BeginPress` * | VMT DS:44c4 slot +1c: GetDC + memory DC, +0a := 1, SetCapture(toolbar), PressDown when hit |
| 1080:1014 | `ToolButton::MouseMove` * | VMT DS:44c4 slot +20: PressDown while the cursor is inside, PressUp outside |
| 1080:1046 | `ToolButton::EndPress` * | VMT DS:44c4 slot +24: if inside PostMessage(owner, WM_COMMAND, Cmd); ReleaseCapture, frees DCs, returns True (toolbar clears captured tool) |
| 1080:10c6 | `ToolButton::RightClick` * | VMT DS:44c4 slot +28: if hit WinHelp(kaiser.hlp, HELP_CONTEXTPOPUP, Cmd + 1000) |
| 1080:110b | `ToolButton::Read` * | VMT DS:44c4 slot +38: S.Read(...) (TStream slot +1c), arguments lost in decompile |
| 1080:1128 | `ToolButton::Write` * | VMT DS:44c4 slot +3c: S.Write(...) (TStream slot +28), arguments lost in decompile |

### Unit init / exit, shared GDI objects

| Address | Name | Purpose |
|---|---|---|
| 1080:1145 | `Toolbar_CreateGdiObjects` * | Pattern brush from bitmap GrayingBitmap (DS:6102), LTGRAY_BRUSH (6100), WHITE_PEN (60fa), BLACK_PEN (60fe), grey pen RGB(128,128,128) (60fc) |
| 1080:11a6 | `Toolbar_DeleteGdiObjects` * | Deletes the graying brush and the grey pen |
| 1080:11bd | `Toolbar_ExitProc` * | Unit exit procedure: deletes GDI objects, restores the saved ExitProc (DS:6104) |
| 1080:11d3 | `Unit17_Init` * | Unit init of the toolbar unit: chains ExitProc (DS:5ff2 := 1080:11bd), creates the GDI objects |

## Segment 18 (1088) – globals init

### Init

| Address | Name | Purpose |
|---|---|---|
| 1088:0002 | `Unit18_InitGlobals` * | Unit init: header magic '{', background RGB(255,255,172), Delta X/Y 0, Schlacht-Timer 400, copies default country/adjective/CPU names, Spieler0..9 = '', INI path = GetCurDir + '\KAISER.INI' (DS:6796) |

## Appendix – library segments 19 (OWindows) and 26 (System)

Names from `tools/ghidra/names/10_runtime.csv` and `20_owl.csv`; the three entries marked `*` are new.

### Segment 19 (1090) – OWL OWindows

| Address | Name | Purpose |
|---|---|---|
| 1090:0002 | `OWL::_DMTLookup` | Near: same DMT search as System 10c8:1961, used by the OWL message dispatchers |
| 1090:0045 | `OWL::_SetObjectProps` | SetProp(HWindow, 'OW1'/'OW2' at DS:5c0a/5c0e) = Self offset/segment |
| 1090:0071 | `OWL::_RemoveObjectProps` | RemoveProp 'OW1' and 'OW2' |
| 1090:0097 | `OWL::GetObjectPtr` | GetObjectPtr(HWindow): decodes the object-instance thunk from GWL_WNDPROC (E8 call, CS check 2E5Bh) or reads the 'OW1'/'OW2' props |
| 1090:0103 | `OWL::_CallDispatchHook` * | Nested helper of StdWndProc/_DispatchDynamic: when the far proc variable DS:5c12 is set, calls it with the message record and receiver |
| 1090:0133 | `OWL::StdWndProc` | Common window procedure reached from instance thunks: DMT lookup for Msg (or DefWndProc VMT+0Ch); MakeProcInstance(@StdWndProc) in TApplication.Init |
| 1090:018b | `OWL::InitWndProc` | lpfnWndProc of OWL classes: subclasses the new window to CreationWindow (DS:5c06) Instance, sets props, forwards message |
| 1090:01dc | `OWL::MakeObjectInstance` | Builds a call thunk (E8 + object ptr) in a GlobalAlloc block via AllocCSToDSAlias/PrestoChangoSelector |
| 1090:02fa | `OWL::FreeObjectInstance` | Returns a thunk to the free list (AllocCSToDSAlias/FreeSelector) |
| 1090:0341 | `OWL::TWindowsObject_Init` | TObject.Init, Parent^.AddChild, Instance := MakeObjectInstance, EnableAutoCreate |
| 1090:03e9 | `OWL::TWindowsObject_Done_FreeChild` | Local ForEach callback of Done: child^.Free |
| 1090:03ff | `OWL::TWindowsObject_Done` | Destroy (VMT+24h), free children, Parent^.RemoveChild, FreeObjectInstance, TObject.Done |
| 1090:0466 | `OWL::TWindowsObject_Store` | Writes Status/HWindow/... via TStream.Write (VMT+28h) then PutChildren |
| 1090:04db | `OWL::TWindowsObject_PutChildren_SetOrder` | GUESS: local of PutChildren: numbers child windows (GetWindow order) into CreateOrder (+17h) |
| 1090:057e | `OWL::TWindowsObject_PutChildren_PutChild` | Local ForEach callback: S.Put(Child) |
| 1090:059e | `OWL::TWindowsObject_PutChildren` | Writes child count and S.Put for each child |
| 1090:05ec | `OWL::TWindowsObject_CreateChildren_IsNext` | Local FirstThat callback: child CreateOrder = wanted index |
| 1090:0624 | `OWL::TWindowsObject_CreateChildren_DoCreate` | Local: if wb_AutoCreate then child^.Create (VMT+20h); fixes iconic caption |
| 1090:06aa | `OWL::TWindowsObject_CreateChildren_CreateUnordered` | Local FirstThat callback: create children with CreateOrder = 0 |
| 1090:06e2 | `OWL::TWindowsObject_CreateChildren` | Creates children in CreateOrder then the rest; False on failure |
| 1090:0762 | `OWL::TWindowsObject_Transfer` | Returns 0; VMT slot +40h in dialog VMTs |
| 1090:0779 | `OWL::TWindowsObject_Enable` | EnableWindow(HWindow, True) if HWindow <> 0 |
| 1090:07af | `OWL::TWindowsObject_Disable` | EnableWindow(HWindow, False) if HWindow <> 0 |
| 1090:07e5 | `OWL::TWindowsObject_EnableKBHandler` | SetFlags(wb_KBHandler=1, True) |
| 1090:07ff | `OWL::TWindowsObject_EnableAutoCreate` | SetFlags(wb_AutoCreate=4, True) |
| 1090:0819 | `OWL::TWindowsObject_EnableTransfer` | SetFlags(wb_Transfer=10h, True) |
| 1090:0833 | `OWL::TWindowsObject_DisableAutoCreate` | SetFlags(wb_AutoCreate, False) |
| 1090:084d | `OWL::TWindowsObject_DisableTransfer` | SetFlags(wb_Transfer, False) |
| 1090:0867 | `OWL::TWindowsObject_SetFlags` | SetFlags(Mask, OnOff) on Flags byte (+16h) |
| 1090:0899 | `OWL::TWindowsObject_IsFlagSet` | IsFlagSet(Mask): (Flags and Mask) = Mask |
| 1090:08c0 | `OWL::TWindowsObject_AddChild` | Inserts into circular sibling list (ChildList +0Ah, SiblingList +19h) |
| 1090:0942 | `OWL::TWindowsObject_RemoveChild` | Unlinks child from circular sibling list |
| 1090:0a33 | `OWL::TWindowsObject_FirstThat` | FirstThat(Test) over children |
| 1090:0a80 | `OWL::TWindowsObject_ForEach` | ForEach(Action) over children |
| 1090:0ad2 | `OWL::TWindowsObject_GetId` | Returns -1; VMT slot +28h in dialog VMTs |
| 1090:0ae9 | `OWL::TWindowsObject_IndexOf` | 1-based position of a child in the sibling list |
| 1090:0b23 | `OWL::_DispatchDynamic` | Calls dynamic method for index (cm_/id_/nf_First + id) or the default VMT slot passed (DefCommandProc/DefChildProc/DefNotificationProc) |
| 1090:0b50 | `OWL::TWindowsObject_WMCommand` | DMT idx 0111h: routes commands (cm_First) to focused object, notifications to child (nf_First) or id_First |
| 1090:0ce5 | `OWL::TWindowsObject_DispatchScroll` | VMT +48h: scroll messages from controls -> child nf_ handler or DefChildProc |
| 1090:0d85 | `OWL::TWindowsObject_WMVScroll` | DMT idx 0115h: ws_VScroll style -> DefWndProc else DispatchScroll |
| 1090:0dcc | `OWL::TWindowsObject_WMHScroll` | DMT idx 0114h: ws_HScroll style -> DefWndProc else DispatchScroll |
| 1090:0e13 | `OWL::TWindowsObject_DefCommandProc` | VMT +10h: forwards cm_ message to parent/target object |
| 1090:0e9d | `OWL::TWindowsObject_DefChildProc` | VMT +14h: DefWndProc |
| 1090:0eb9 | `OWL::TWindowsObject_DefNotificationProc` | VMT +18h: forwards to Parent id_First + Id |
| 1090:0f27 | `OWL::TWindowsObject_Destroy_ResetChild` | Local ForEach callback of Destroy: EnableAutoCreate on children with a window |
| 1090:0f47 | `OWL::TWindowsObject_Destroy` | VMT +24h: DestroyWindow or WM_MDIDESTROY (221h) for wb_MDIChild |
| 1090:0fca | `OWL::TWindowsObject_GetClassName` | VMT +2Ch: returns 'TurboWindow' |
| 1090:0fea | `OWL::TWindowsObject_GetWindowClass` | VMT +34h in dialog VMTs: calls Abstract |
| 1090:0ffb | `OWL::TWindowsObject_SetupWindow` | CreateChildren, Status := em_InvalidChild (-4) on failure, else TransferData(tf_SetData) |
| 1090:102d | `OWL::TWindowsObject_TransferData_Child` | Local ForEach callback: child^.Transfer if wb_Transfer |
| 1090:106a | `OWL::TWindowsObject_TransferData` | VMT +44h: ForEach Transfer when TransferBuffer (+0Eh) <> nil |
| 1090:10a6 | `OWL::TWindowsObject_Register` | VMT +1Ch: GetClassInfo else GetWindowClass + RegisterClass |
| 1090:10fe | `OWL::TWindowsObject_Show` | Show(ShowCmd): ShowWindow if HWindow <> 0 |
| 1090:1120 | `OWL::TWindowsObject_CanClose_Child` | Local FirstThat callback: child window that refuses CanClose |
| 1090:1154 | `OWL::TWindowsObject_CanClose` | VMT +3Ch: True when no child refuses |
| 1090:1182 | `OWL::TWindowsObject_WMClose` | DMT idx 0010h: CloseWindow |
| 1090:1198 | `OWL::TWindowsObject_CloseWindow` | Application^.CanClose for main window else CanClose, then Free |
| 1090:11ed | `OWL::TWindowsObject_WMDestroy` | DMT idx 0002h: PostQuitMessage for Application^.MainWindow, DefWndProc |
| 1090:122c | `OWL::TWindowsObject_WMNCDestroy` | DMT idx 0082h: remove props, DefWndProc, HWindow := 0 |
| 1090:125d | `OWL::TWindowsObject_WMActivate` | DMT idx 0006h: Application^.SetKBHandler(Self or nil) |
| 1090:12b4 | `OWL::TWindowsObject_WMQueryEndSession` | DMT idx 0011h: Result := CanClose (Application^.CanClose for main window) |
| 1090:130a | `OWL::TWindowsObject_CMExit` | DMT idx FF14h (cm_First+cm_Exit): CloseWindow for main window else DefCommandProc |
| 1090:1349 | `OWL::TWindowsObject_GetClient` | VMT +30h: returns nil |
| 1090:1366 | `OWL::TWindow_Init` | TWindow.Init(AParent, ATitle): Attr.Title := StrNew, DefaultProc := DefWindowProc/DefMDIChildProc, ws_OverlappedWindow or child style, cw_UseDefault |
| 1090:147b | `OWL::TWindow_Done` | StrDispose(Attr.Title), dispose Scroller (+3Bh), TWindowsObject.Done; VMT +8 of OWL control VMTs |
| 1090:14d4 | `OWL::TWindow_InitResource` | InitResource(AParent, ResourceID): wb_FromResource, FillChar(Attr, 1Ah, 0), Attr.Id |
| 1090:1545 | `OWL::TWindow_Store` | TWindowsObject.Store + StrWrite(Title) + Attr fields + S.Put(Scroller) |
| 1090:16bc | `OWL::TWindow_SetCaption` | SetCaption(ATitle): replaces Attr.Title (StrDispose/StrNew), SetWindowText |
| 1090:170f | `OWL::TWindow_GetWindowClass` | VMT +34h: cs_HRedraw\|cs_VRedraw, lpfnWndProc=InitWndProc, idi_Application, idc_Arrow, color_Window+1 |
| 1090:1790 | `OWL::TWindow_GetId` | VMT +28h: returns Attr.Id (+35h) |
| 1090:17ac | `OWL::TWindow_DefWndProc` | VMT +0Ch: CallWindowProc(DefaultProc (+37h), ...) |
| 1090:17ea | `OWL::TWindow_Create` | VMT +20h: Register, CreateWindowEx or WM_MDICREATE (220h) / GetDlgItem for resource windows, then SetupWindow |
| 1090:19e2 | `OWL::TWindow_RestoreFocusChild` | GUESS: SetFocus(FocusChildHandle +3Fh) unless iconic; used on activate/SC_RESTORE |
| 1090:1a21 | `OWL::TWindow_SaveFocusChild` | GUESS: FocusChildHandle := GetFocus if it is a child; used on deactivate/SC_MINIMIZE |
| 1090:1a5b | `OWL::TWindow_UpdateWindowRect` | GUESS: copies GetWindowRect into Attr.X/Y/W/H (client coords for MDI/child) unless iconic/zoomed; used by SetupWindow and WMMove |
| 1090:1b38 | `OWL::TWindow_WMActivate` | DMT idx 0006h: inherited WMActivate + save/restore focus child |
| 1090:1b86 | `OWL::TWindow_WMMDIActivate` | DMT idx 0222h: calls WMActivate through System _DMTCall |
| 1090:1ba7 | `OWL::TWindow_SetupWindow` | VMT +38h: TWindowsObject.SetupWindow, SetFocus for MDI child, Scroller (+3Bh) VMT+10h call, UpdateWindowRect |
| 1090:1bfc | `OWL::TWindow_WMCreate` | DMT idx 0001h: SetupWindow then DefWndProc |
| 1090:1c23 | `OWL::TWindow_WMHScroll` | DMT idx 0114h: Scroller^.HScroll (scroller VMT+20h) when ws_HScroll |
| 1090:1c93 | `OWL::TWindow_WMVScroll` | DMT idx 0115h: Scroller^.VScroll (scroller VMT+1Ch) when ws_VScroll |
| 1090:1d03 | `OWL::TWindow_WMPaint` | DMT idx 000Fh: BeginPaint, Scroller BeginView, Paint (VMT+4Ch), EndView, EndPaint |
| 1090:1d84 | `OWL::TWindow_Paint` | VMT +4Ch: empty |
| 1090:1d90 | `OWL::TWindow_WMSize` | DMT idx 0005h: Scroller VMT+0Ch call, stores W/H for size_Normal |
| 1090:1e07 | `OWL::TWindow_WMMove` | DMT idx 0003h: UpdateWindowRect then DefWndProc |
| 1090:1e2d | `OWL::TWindow_WMLButtonDown` | DMT idx 0201h: Scroller AutoMode capture loop until WM_LBUTTONUP |
| 1090:1eb5 | `OWL::TWindow_WMSysCommand` | DMT idx 0112h: SC_MINIMIZE saves / SC_RESTORE restores focus child |
| 1090:1f08 | `OWL::TApplication_Init` | Called from main with the global App object (DS:6028), its VMT at DS:0010 and the name PChar Kaiser at DS:04fe |
| 1090:1faf | `OWL::TApplication_Done` | FreeProcInstance(StdWndProc instance), TObject.Done; App VMT DS:0010 slot +8 |
| 1090:1fdc | `OWL::TApplication_IdleAction` | Returns False; VMT +0Ch |
| 1090:1ff2 | `OWL::TApplication_InitApplication` | Empty; VMT +10h (called when HPrevInst = 0) |
| 1090:1ffe | `OWL::TApplication_InitInstance` | VMT +14h: InitMainWindow (VMT+18h), MainWindow := MakeWindow, em_InvalidMainWindow (-5) or Show(CmdShow) |
| 1090:2057 | `OWL::TApplication_Run` | VMT +1Ch: MessageLoop if Status = 0 else Error(Status) |
| 1090:2086 | `OWL::TApplication_SetKBHandler` | KBHandlerWnd (+0Eh) := AWindowsObject |
| 1090:20a3 | `OWL::TApplication_MessageLoop` | VMT +20h: PeekMessage / IdleAction / WaitMessage until WM_QUIT, ProcessAppMsg, Translate/DispatchMessage |
| 1090:2126 | `OWL::TApplication_ProcessAppMsg` | VMT +24h: ProcessDlgMsg or ProcessMDIAccels or ProcessAccels |
| 1090:217d | `OWL::TApplication_ProcessDlgMsg` | VMT +28h: IsDialogMessage(KBHandlerWnd^.HWindow) |
| 1090:21c9 | `OWL::TApplication_ProcessAccels` | VMT +2Ch: TranslateAccelerator(HAccTable +0Ch) |
| 1090:220b | `OWL::TApplication_ProcessMDIAccels` | VMT +30h: TranslateMDISysAccel when MainWindow^.GetClient <> nil |
| 1090:2258 | `OWL::TApplication_ValidWindow` | VMT +3Ch: LowMemory -> Error(em_OutOfMemory -2) and dispose, Status <> 0 -> Error and dispose |
| 1090:22e0 | `OWL::TApplication_MakeWindow` | VMT +34h: ValidWindow then Create (VMT+20h) |
| 1090:2357 | `OWL::TApplication_ExecDialog` | VMT +38h: ValidWindow, Execute (dialog VMT+4Ch), dispose |
| 1090:23bb | `OWL::TApplication_Error` | VMT +40h: wvsprintf 'Error code = %d. Continue?' MessageBox 'Application Error', Halt on IDNO |
| 1090:23fd | `OWL::TApplication_CanClose` | VMT +44h: MainWindow^.CanClose |

### Segment 26 (10c8) – Borland System unit

| Address | Name | Purpose |
|---|---|---|
| 10c8:0002 | `System::__SystemInit` | Called from main right after KERNEL.InitTask: stores ES/SI/DI/DX/BX:ES into PrefixSeg/HPrevInst/HInstance/CmdShow/CmdLine (DS:5ffc/5fdc/5fde/5fe0/5fe2), WaitEvent, InitApp, Test8086 from GetWinFlags, SelectorInc=__AHINCR |
| 10c8:005d | `System::RunError` | Sets ExitCode/ErrorAddr, runs ExitProc chain, shows 'Runtime error' MessageBox, terminates via int 21h |
| 10c8:0061 | `System::Halt` | Same exit path as RunError with ErrorAddr = nil |
| 10c8:00d2 | `System::_RunExitProcs` | Near helper of Halt/RunError: while ExitProc (DS:5ff2) <> nil: clear it and InOutRes, far-jump to it with return to itself |
| 10c8:00f0 | `System::_ErrNumToStr` | Near helper: converts AX to digits (radix CX) backwards at DS:BX; fills the Runtime error 000 at 0000:0000 text at DS:6008 |
| 10c8:012d | `System::GetMem` | Pascal GetMem/New: far, Size param; calls heap core 10c8:01ca and RunError(203 heap overflow) on CF |
| 10c8:0147 | `System::FreeMem` | Pascal FreeMem/Dispose: far (P, Size); calls heap core 10c8:02d7 and RunError(204 invalid pointer) on CF |
| 10c8:0167 | `System::MemAvail` | GetFreeSpace(0) plus free bytes (word at +8) of every sub-heap segment in HeapList (DS:5fe6); returns longint |
| 10c8:0195 | `System::MaxAvail` | GlobalCompact(0) maxed with the largest sub-heap free counter in HeapList |
| 10c8:01ca | `System::_HeapAlloc` | Overrides 00_program GetMem: near heap core, AX=size -> DX:AX/CF; HeapLimit/HeapBlock sub-allocation or GlobalAlloc+GlobalLock; retries via HeapError (DS:5fee). Far Pascal GetMem is 10c8:012d |
| 10c8:0222 | `System::_HeapGlobalAlloc` | Near: GlobalAlloc(HeapAllocFlags DS:5fec, AX) + GlobalLock -> DX:AX |
| 10c8:023c | `System::_HeapSubAlloc` | Near: rounds size to 4, walks HeapList segments for a free block, else creates a new heap segment (10c8:026a) |
| 10c8:026a | `System::_HeapNewSegment` | Near: allocates HeapBlock bytes and writes sub-heap header 'TP' (0x5054) + free list, links into HeapList |
| 10c8:02a6 | `System::_HeapFindFree` | Near: first-fit search of a sub-heap free list (ES), splits the block, decrements free counter at ES:8 |
| 10c8:02d7 | `System::_HeapFree` | Overrides 00_program FreeMem: near heap core (AX=size, BX:CX=ptr); validates 'TP' header, inserts/merges free block or GlobalFree for large blocks. Far Pascal FreeMem is 10c8:0147 |
| 10c8:0327 | `System::_HeapMergeFree` | Near: merges a free block with the following adjacent free block |
| 10c8:0388 | `System::IOResult` | xchg InOutRes (DS:5ffe) with 0, returns old value |
| 10c8:038f | `System::_IOCheck` | {$I+} check emitted after I/O calls: if InOutRes <> 0 then RunError(InOutRes); called 19x from seg 11 only |
| 10c8:039d | `System::_RangeCheckLong` | {$R+} longint range check: compares DX:AX with low/high bounds at ES:DI, RunError(201) |
| 10c8:03c5 | `System::_OverflowError` | {$Q+} overflow target: RunError(215 arithmetic overflow) |
| 10c8:03cb | `System::_StackCheck` | {$S+} stack check: compares requested frame (AX) against SP and stack bottom SS:[0Ah], RunError(202 stack overflow) |
| 10c8:03ef | `System::_Construct` | Object constructor prologue: allocate Self if nil, store VMT pointer at Self+DI |
| 10c8:0439 | `System::_Destruct` | Object destructor epilogue: FreeMem(Self) when called with the dispose flag |
| 10c8:046c | `System::_ObjCopy` | GUESS: object assignment helper: copies VMT.InstanceSize bytes Src->Dst but preserves Dst VMT field (offset param); no callers |
| 10c8:048f | `System::_ObjVMTCheck` | {$R+} virtual call check: VMT size word + negsize word must sum to 0, else RunError(210 object not initialized) |
| 10c8:049f | `System::AssignPChar` | Assign(var F; Name: PChar) entry (DX<>0): FileRec Handle=0, Mode=fmClosed 0D7B0h, copies NUL-terminated name (<=79) to F+30h, AnsiToOem |
| 10c8:04e4 | `System::ResetFile` | Reset(var F: File; RecSize): int21 AH=3Dh with AL=FileMode (DS:6007); closes if open; InOutRes 102 if not assigned |
| 10c8:04ed | `System::RewriteFile` | Rewrite(var F: File; RecSize): int21 AX=3C00h, shares body with Reset; sets Mode=fmInOut 0D7B3h |
| 10c8:0549 | `System::Truncate` | Truncate(var F): int21 AH=40h with CX=0 at current position |
| 10c8:0565 | `System::CloseFile` | Close(var F: File): int21 AH=3Eh (skips handles <=4), Mode:=fmClosed |
| 10c8:058a | `System::_CheckFileOpen` | Near: Mode <> fmInOut (0D7B3h) -> InOutRes:=103 (file not open) |
| 10c8:0599 | `System::_ReadRec` | Typed-file Read of one record: int21 AH=3Fh, CX=RecSize, InOutRes 100 on short read |
| 10c8:05a0 | `System::_WriteRec` | Typed-file Write of one record: int21 AH=40h, CX=RecSize, InOutRes 101 on short write |
| 10c8:05cf | `System::BlockRead` | BlockRead(var F; var Buf; Count; Result): int21 AH=3Fh with Count*RecSize, error 100 |
| 10c8:05d6 | `System::BlockWrite` | BlockWrite(var F; var Buf; Count; Result): int21 AH=40h, error 101 |
| 10c8:0637 | `System::Seek` | Seek(var F; N: Longint): N*RecSize, int21 AX=4200h |
| 10c8:0667 | `System::ParamStr` | ParamStr(Index): scans CmdLine (DS:5fe2); Index 0 -> GetModuleFileName(HInstance) |
| 10c8:069f | `System::ParamCount` | Counts CmdLine parameters via 10c8:06aa |
| 10c8:06aa | `System::_GetParam` | Near: skips blanks / finds next parameter in CmdLine |
| 10c8:06ca | `System::_BlockCopy` | Overrides 00_program Move: forward-only rep movsb (Src, Dst, Count), no overlap check; 124 call sites copying records (sizes 0x6d5, 0x3d, 8...) = compiler structured-copy helper. Real Move is 10c8:1920 |
| 10c8:06e2 | `System::_LongMul` | 32-bit multiply DX:AX * BX:CX (uses 386 path when Test8086 >= 2) |
| 10c8:071f | `System::_LongDiv` | 32-bit signed divide DX:AX / BX:CX, RunError on zero |
| 10c8:07c5 | `System::_LongShr` | DX:AX shr CL (386 shrd path when Test8086>=2) |
| 10c8:07de | `System::_LongShl` | DX:AX shl CL (386 shld path when Test8086>=2) |
| 10c8:07f7 | `System::_StrLoad` | Copies a ShortString (full length) into a temp string |
| 10c8:0811 | `System::_StrStore` | String assignment: copy ShortString to Dest truncated to MaxLen (Src, Dest, MaxLen) |
| 10c8:0835 | `System::Copy` | Copy(S, Index, Count) into temp; clamps Index>=1 and Count to length; used by Insert/Delete |
| 10c8:0876 | `System::_StrConcat` | Concatenation: appends string to temp, length capped at 255 |
| 10c8:08a2 | `System::Pos` | Pos(Substr, S): repne scasb for first char then repe cmpsb |
| 10c8:08e8 | `System::_StrCmp` | ShortString compare, result in flags (min-length repe cmpsb then length compare) |
| 10c8:0913 | `System::_StrChar` | Char -> String temp (length 1) |
| 10c8:0925 | `System::_StrPacked` | Packed array of Char -> String temp (stores length, copies N bytes) |
| 10c8:0940 | `System::Insert` | Insert(Source, var S, Index) via Copy/Concat/StrStore |
| 10c8:099f | `System::Delete` | Delete(var S, Index, Count) via Copy/Concat/StrStore |
| 10c8:0a0e | `System::_SetLoad` | Expand packed set (offset/size in BX) into 32-byte set temp, zero-filling |
| 10c8:0a38 | `System::_SetInit` | GUESS: writes one word then 15 zero words = initialise a 32-byte set temp |
| 10c8:0a4e | `System::_SetAddElem` | Set constructor: include element (bit = elem and 7 in byte elem shr 3) |
| 10c8:0a6f | `System::_SetAddRange` | Set constructor: include range Lo..Hi |
| 10c8:0aa3 | `System::_SetStore` | Store set temp into packed set variable (skip BH bytes, copy BL bytes) |
| 10c8:0ac3 | `System::_SetBitPos` | GUESS: computes byte index (DX) and rotated bit mask (AL) of element AL within a packed set (offset DH, size DL); 1 caller in seg 10 |
| 10c8:0ae3 | `System::_SetUnion` | 32-byte set: or 16 words |
| 10c8:0aff | `System::_SetDiff` | 32-byte set: and not, 16 words |
| 10c8:0b1d | `System::_SetIntersect` | 32-byte set: and 16 words |
| 10c8:0b39 | `System::_SetEqual` | 32-byte set compare: repe cmpsw 16 words |
| 10c8:0b50 | `System::_SetSubset` | Set <= test: (A or B) = B word by word |
| 10c8:0b6e | `System::_RealSubCore` | Real48 near core: flip sign of DI (operand 2) then fall into add core |
| 10c8:0b72 | `System::_RealAddCore` | Real48 near core: DX:BX:AX + DI:SI:CX, CF on overflow |
| 10c8:0c35 | `System::_RealMulCore` | Real48 near core: DX:BX:AX * DI:SI:CX (partial products), CF on overflow |
| 10c8:0d38 | `System::_RealDivCore` | Real48 near core: DX:BX:AX / DI:SI:CX (shift-subtract) |
| 10c8:0daf | `System::_RealCmpCore` | Real48 near core: compare DX:BX:AX with DI:SI:CX, result in flags |
| 10c8:0dc6 | `System::_RealCmpMagnitude` * | Real48 helper of _RealCmpCore: cmp exponent AL/CL, then DX/DI, BX/SI, AH/CH (flags only) |
| 10c8:0dd9 | `System::_LongToRealCore` | Near core: Longint DX:AX -> Real48 (normalise, exponent 0A0h) |
| 10c8:0e15 | `System::_RealToLongCore` | Near core: Real48 -> Longint; CH=0 truncate, CH=1 round; CF on overflow |
| 10c8:0e83 | `System::_RealAdd` | Far Real48 add: calls 10c8:0b72, RunError(205 floating point overflow) on CF |
| 10c8:0e89 | `System::_RealSub` | Far Real48 subtract: calls 10c8:0b6e, RunError(205) |
| 10c8:0e95 | `System::_RealMul` | Far Real48 multiply: calls 10c8:0c35, RunError(205); 157 call sites |
| 10c8:0e9b | `System::_RealDiv` | Far Real48 divide: divisor exponent 0 -> RunError(200 division by zero), overflow -> 205 |
| 10c8:0ea5 | `System::_RealCmp` | Far Real48 compare (flags) |
| 10c8:0ea9 | `System::_RealFromLong` | Far Longint (DX:AX) -> Real48; 134 call sites |
| 10c8:0ead | `System::Trunc` | Trunc(Real): CH=0 then 10c8:0e15, RunError(207 invalid floating point op) on overflow |
| 10c8:0eb5 | `System::Round` | Round(Real): CH=1 then 10c8:0e15, RunError(207); 117 call sites |
| 10c8:0ecf | `System::_RealAddKeep` | Near: Real add preserving DI:SI:CX operand |
| 10c8:0eed | `System::_RealDivKeep` | Near: Real divide preserving DI:SI:CX operand |
| 10c8:0ef7 | `System::Int` | Int(Real): masks off fraction bits according to exponent (0 if \|x\|<1) |
| 10c8:0f48 | `System::Frac` | Frac(Real) = x - Int(x) (calls 10c8:0ef7 then sub core) |
| 10c8:0f5c | `System::Sqrt` | Sqrt(Real): halves exponent for first guess then Newton iterations (div/add/dec exponent); negative -> RunError(207) |
| 10c8:0fbb | `System::Cos` | GUESS: adds -pi/2 constant (81 21A2 DAA2 490F), negates, falls into sine series at 10c8:0fce (Sin entry); no callers |
| 10c8:1059 | `System::Ln` | Ln(Real): x<=0 -> RunError(207); uses ln2 constant (mantissa 3172 17F7 D2) and polynomial table at CS:10DE; no callers |
| 10c8:11a5 | `System::ArcTan` | ArcTan(Real): inverts \|x\|>1 and subtracts from pi/2, polynomial tables at CS:1286; no callers |
| 10c8:1342 | `System::Random` | Random(Range): next RandSeed (via 10c8:139f) scaled to Range |
| 10c8:135f | `System::RandomReal` | Random (no arg, Real result): next RandSeed normalised to 0<=x<1 Real48 |
| 10c8:139f | `System::_NextRandSeed` | Near: RandSeed (DS:6000) := RandSeed*134775813 + 1 |
| 10c8:13d7 | `System::Randomize` | int21 AH=2Ch (get time): RandSeed := CX:DX |
| 10c8:13e4 | `System::_LongToStr` | Near: signed Longint -> decimal digits at ES:DI (backwards), adds - |
| 10c8:1400 | `System::_ULongToStr` | Near: unsigned DX:AX -> digits in radix SI |
| 10c8:1420 | `System::_StrToLong` | Near: parses [+\|-]digits or $hex at ES:DI (len CX) into DX:AX, CF on error |
| 10c8:14c7 | `System::_RealToStr` | Near: formats Real48 (width/decimals in CX, max 11 digits), fixed or scientific with E+nn |
| 10c8:15b3 | `System::_RealStrNextDigit` * | Str(Real) helper: next digit char from the frame buffer [BP+SI-14h], '0' when exhausted |
| 10c8:15bf | `System::_RealToDigits` | Near: Real48 -> 12 ASCII digits + decimal exponent |
| 10c8:164a | `System::_StrToReal` | Near: parses [sign]digits[.digits][E[sign]digits] into Real48 |
| 10c8:16f6 | `System::_ParseRealDigits` | Near: accumulates decimal digits into Real (x*10+d) |
| 10c8:1734 | `System::_RealScale10` | Near: multiplies/divides Real by 10^CL using power table at CS:1784 |
| 10c8:17c0 | `System::_RealMul10` | Near: Real48 * 10 via shifts and add |
| 10c8:180e | `System::_StrLong` | Str(L: Longint:Width, var S; MaxLen): space-pads; 26 call sites |
| 10c8:1859 | `System::_ValLong` | Val(S, var L: Longint, var Code): skips blanks, Code = error position |
| 10c8:188a | `System::_StrReal` | Str(R: Real:Width:Decimals, var S; MaxLen) |
| 10c8:18ed | `System::_ValReal` | Val(S, var R: Real, var Code) |
| 10c8:1920 | `System::Move` | Move(var Source, Dest; Count): overlap-safe (std when Src<Dst); called by Objects TCollection.SetLimit (10a8:0453) like BP7 source |
| 10c8:1944 | `System::FillChar` | FillChar(var X; Count; Value): byte fill loop |
| 10c8:1958 | `System::_DMTFind` | Dynamic method lookup (calls 10c8:1961), returns entry in DI |
| 10c8:195c | `System::_DMTCall` | Dynamic method call: lookup via DMT chain (VMT+4) then jmp far [DI]; RunError(210) if index not found. Used for OWL message-response methods |
| 10c8:1961 | `System::_DMTLookup` | Near: searches DMT index tables up the parent chain, updates the 1-entry cache in the DMT |

