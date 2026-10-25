# Phase 3 – reimplementation

Goal: a native port that plays exactly like the original (same rules, same random
numbers, same savegames), runs on current Windows (and macOS/Linux), and reuses the
original resources. Deliverables: the macOS app and a Windows 11 executable (milestone 8).

## Decisions

- **Language: Free Pascal** (later Lazarus for the GUI). Closest to the original Borland
  Pascal 7 source: same record layouts, `div`/`mod` semantics, Pascal strings; builds native
  64-bit programs for Windows, macOS and Linux.
- **Exactness first.** The original uses Borland's software Real48 arithmetic and its random
  number generator. Both are reproduced bit-exactly, otherwise simulations drift apart.
- **Differential testing against the original machine code.** Most game rules are pure logic
  (segments 2, 3, 7, 14) and the runtime (segment 26) needs no Windows. These functions are
  executed directly from `kaiser.exe` in a 16-bit x86 emulator (Unicorn) and their results are
  compared with the port on many inputs (real savegame records plus random variations).
- **Code layout**: `port/src` engine units (no UI), `port/tools` command-line tools,
  `port/tests` test programs; `tools/gen_pascal_types.py` generates the record types
  (`kaisertypes.pas`) and the data segment (`kaiserds.pas`) from `tools/kaiser_structs.py`;
  the emulator harness lives in `tools/emu/`; `tools/gen_pascal_res.py` generates the string
  table resources with a `LoadString` (`kaiserres.pas`). Engine units by original segment:
  `rules.pas` (14), `turn.pas` (3), `ai.pas` (2 and 7), `game.pas` (the turn loop of 1);
  `kaiserui.pas` is the interface to the UI.
- **Globals stay where they were.** `KaiserDS.DS` is a packed record with the layout of the
  original data segment (0x681c bytes), initialised with its contents from `kaiser.exe`.
  Known tables and globals are named fields at their original offsets (`DS.Game` = DS:6108,
  `DS.PromotionLand` = DS:57f8, `DS.UnitCanDesert` = DS:52b8, …). Unknown bytes are padding.
  So an index that runs past a table reads the same neighbouring bytes as in the original
  (`CanBePromoted` reads `PromotionLand[11]` for a Kaiser).
- **Uninitialised locals.** Some original functions copy partly uninitialised local records
  (e.g. `RecruitUnit`'s new unit: hit points, steps, motivation; `MarriageDowry` copies it into
  the army). In the emulator every `ENTER n,0` frame of the logic segments (and of the UI
  functions in `ZERO_FRAME_FUNCS`: `RecruitDialog`'s new hero and his level-up gains) starts
  zeroed (the instruction is patched to `INT3` and emulated with a zero fill), the stack is zeroed before
  each call, and the port zero-initialises these locals, so both agree on 0 even deep inside
  `PlayerTurnStart`. Bytes the original never writes in a record it logs (`TLandLoss` bytes
  4..7) are masked in the log.
- **Relocated data.** The port's data segment is the raw image from the file; far pointers that
  the loader fills in (at relocation sites) are 0. Only out-of-range reads that run into such
  pointers differ (e.g. `UnitRankName` for troop levels far past the rank table), and the
  vectors avoid them.
- **Integer width.** The original wraps at 32 bits (longint) or 16 bits (integer), but FPC
  on 64-bit evaluates in 64 bits. The port truncates with `LongInt()`/`SmallInt()` wherever a
  division or comparison follows a possible overflow. Byte `for` loops keep the original's byte
  bound (`for I := 0 to N - 1` with N = 0 runs 256 times). The vectors include extreme values
  to catch this.

## Milestones

| # | Milestone | Validation | Status |
|---|---|---|---|
| 1 | Data layer: `TGameHeader`, `TPlayer`, `TUnit`, load/save `.KSR` | all 30 saves round-trip byte-identically | ✅ |
| 2 | Runtime: `Random`, `RandomReal`, Real48 add/sub/mul/div/compare/round/trunc/from-longint, `Sqrt` | differential test against segment 26 in the emulator | ✅ 300,000 / 300,000 bit-identical (+ 30,000 `Sqrt`) |
| 3 | Rule library: segment 14 functions (rates, happiness, income, harvest, prices, …) | per-function differential tests | ✅ all 102 functions (`port/src/rules.pas`; `Seg14_UnitInit` is empty, the local `SortUnits`/`UnitLess` are tested through `SortArmy`); 100,000 / 100,000 vectors identical (1,000 per function) |
| 4 | Turn processing: PlayerTurnStart/End, events, promotion, revolution, AI year | differential tests; whole computer years from savegames | ✅ segment 3 (`port/src/turn.pas`: all 25 logic functions, the rest are dialog classes, plus `FormatPlayerTitle`), segments 2 and 7 (`ai.pas`, all 36), the turn loop of segment 1 (`game.pas`: `NextPlayer`, `CpuTurn`, `ResolveWar`); UI calls replayed (below); 59,039 vectors (1,000 per function) identical, the one exception a test artefact (stale players from an earlier vector, fixed) |
| 5 | Headless simulator: run a game with computer players only | compare with the emulated original year by year | ✅ `port/bin/ksrsim` plays a savegame or a new game on (`NewGame`, `EndHumanTurn`, `BeginHumanTurn` in `game.pas`); the humans just end their turns. `tools/emu/sim_compare.sh` runs the same in the emulated original: all 30 savegames (seeds 1–3, up to 300 turns each) and 10 new games of different sizes agree turn by turn, 5,093 turns in all: 97 of 100 games identical to the end, the other 3 identical until the original crashes (an original bug: sabotage action 6 puts a 9th unit into a full Garde, `Ai_ArrangeArmies` then overruns its stack; docs/rules/ai.md) |
| 6 | Battle engine (segment 10) | scripted battles, differential where possible | ✅ `port/src/battle.pas`: all logic of the battle window (Init, combat, movement, healing, desertion, the AI, the timer, the human's clicks, buttons and combat options, GetResults); `port/src/war.pas`: segment 4 (BattleSetup, BattleFameAndXp, BattleAftermath, Battle, FightRaiders) and segment 6 (battlefield choice, plunder, burning, massacre, retreat losses). 13,343 vectors over 66 functions identical, from battle states the original's AI played (`port/tests/battle.vec`: 660 of them); 668 whole AI battles from all savegames identical (`battle_compare.py 2 2000`). Found on the way: an endless recursion of the original (`StopTimer` → `AiStep`, battle.md) |
| 7 | GUI (Lazarus): main window, menus, dialogs from the extracted dialog templates, bitmaps, sounds | manual play-through against the original in DOSBox-X | ✅ `port/bin/Kaiser.app` (7a–7d below): every menu command, the dialogs with their ported logic, the battle window, the main window, help; checked by autopilot runs and a visual sweep (below); the manual play-through against DOSBox-X is the user's. Not ported: the e-mail game |
| 8 | Windows 11 executable: the same sources built for Win64 (x86_64, LCL win32 widgetset), cross-compiled from macOS (FPC cross compiler `ppcrossx64` and the LCL built for `win64`); the macOS-only parts (sounds via NSSound, the settings in Application Support) get Windows equivalents (`PlaySound`/`sndPlaySound`, `%APPDATA%\Kaiser`) | the test programs (`ruletest`, `real48test`) pass when run on Windows (or Wine); the GUI starts and plays a game on Windows 11 | built: `port/build-win.sh`, `port/package-win.sh` → `port/bin/Kaiser-win64.zip` (below); not yet run on Windows (no Wine on this Mac: Homebrew's Wine casks are disabled) |

Milestone 7 in steps (the GUI is the UI segments 1, 5, 8, 9, 10 drawing, 12, 13, 15–17 ported
onto the LCL):

| Step | Content | Validation |
|---|---|---|
| 7a | Toolchain (LCL Cocoa built from the Lazarus sources); resources read at runtime from `kaiser.exe` (dialog and menu templates, bitmaps, sounds, strings); a generic dialog from a template; the main window with the original menu; open a savegame, end the turn (`EndHumanTurn`) with the simple dialogs | the app runs a game on; templates render like the originals |
| 7b | The dialog base types of segment 12 (KaiserDlg, MessageDlg, Message2Dlg, choice dialogs …) and the menu actions of segments 8 and 9 (`Do_*`), ported with their handlers | differential tests of the logic parts where the emulator can drive them |
| 7c | The battle window: drawing (DrawMap, DrawCell, DrawUnitStatus), timer, clicks, cursors | play battles: ✅ `port/gui/battleform.pas` (below); field, city, winter, marauder and Lindwurm battles played under the autopilot, from "Krieg führen", a computer's attack (`ResolveWar`) and `FightRaiders`; `battle.vec` unchanged |
| 7d | Main window painting and status (segment 13, 1), Annalen, Rekorde, help, sounds, toolbar | manual play-through |

Toolchain notes: Homebrew's Lazarus cask is gone; `tools/lazarus` (gitignored) is a shallow
clone of Lazarus 3.6, built with `make lazbuild` and `make lcl LCL_PLATFORM=cocoa`. FPC 3.2.2's
Objective-C metadata is rejected by Apple's current linker ("malformed method list atom"); the
GUI links with `-k-ld_classic`.

### 7d: the main window

`port/gui/mainpaint.pas` ports the painting of segment 13 and the toolbar of segment 17;
`mainform.pas` calls it from `FormPaint` (= `KaiserWindow::Paint` 1000:0b5d).

- **Pictures.** `PaintTitleScreen` (1060:064b), `DrawPlayerBuildings` (1060:0868) and
  `PaintPatternBackground` (1060:0527) draw like the original into an off-screen bitmap of
  (W − 33) × (H − 40) that goes to x = 32; GDI is reproduced pixel for pixel (Rectangle with
  the pen inside the rectangle, LineTo without the end point, 8×8 pattern brushes aligned to the
  memory DC, BitBlt/StretchBlt nearest neighbour, the masked sprites). All coordinates, tables
  (map origin DS:41a2/41a8, villages DS:395c/398c, markets DS:37cc/3894, mills DS:3754/3790,
  palace/cathedral pieces DS:3e89/3e95, Garde DS:39ce/39de, limits DS:39be/39c4/39ca) and texts
  come from the data segment; the scale of the title (1.0/1.25/1.6) is Real48 like the original.
  The map font is Comic Sans MS −12 px bold (LOGFONT DS:60c8).
- **Window.** Client area (ResolutionWidth − 2) × (ResolutionHeight − 40) (no thick frame, a
  one-pixel border; SetupWindow fixes the client height), black class background, commands
  610–612 resize it (the hidden 1024×768 keeps the current tool set, like
  `CmResolution1024`). Caption `Kaiser` or `FormatPlayerTitle(…, 1, 1)`.
- **Toolbar** (`TKaiserToolbar`): `TOOLBARDATA` KAISERTOOLS_640/800 from kaiser.exe, the layout
  of `LoadTools`/`AdvanceToolPos` (tools from (2, 2), 24×24 buttons with shared borders, the
  window at (−1, −1) with a black border, so the picture starts at 32 after a black column),
  `ToolButton::Draw` (3-D edges, pressed offset 3, disabled = ROP 00A803A9 with GrayingBitmap).
  Buttons 0..DS:4554[res] are enabled with the game like `Menu_EnableGameCommands`; a release
  inside a button posts its command, also for a disabled button (as in the original).
- **Map clicks** (`HandleMapClick` 1000:03d9): double clicks on the Heer strip (Truppen
  aufstellen), granary, warehouse, smithy and tavern.
- **Info** (502) is the `ABOUTBOX` dialog (DS:04f2; the port had looked for `INFO`). **Hilfe**
  (501, 503: WinHelp KAISER.HLP) opens `docs/manual.md` (tools/help_to_md.py) when found next to
  the program or in a parent folder, else a message. The **"?" buttons** of the dialogs and the
  battle's right click (WinHelp HELP_CONTEXT, topic n) show the topic in a window
  (`port/gui/helpview.pas`: the number → context string map of the help project KAISER.HPJ
  [MAP], kept as `docs/help-map.txt`, the anchor of `docs/manual.md`); the dialog types whose port does not keep the help
  context (+0x2e) take the constants of their `HelpDlg.Init` calls.
- **Right click** on a unit of the map: `ShowUnitLookDlg` (1040:330f).
- **Scroll bars** on macOS: `port/gui/winscroll.pas` draws them like Windows 3.1 (arrows one
  step, repeating while held; the trough OWL's page of 10; the thumb), macOS' own have no
  arrows. Combo and list boxes report a new selection to the dialog's logic (CBN_SELCHANGE /
  LBN_SELCHANGE -> IdNNN).
- Autopilot hooks for these checks: `KAISER_AUTOCLICK=NAME=X:Y;…` (clicks straight to the
  controls), `KAISER_AUTOSELECT=NAME=ID:INDEX`.
- **Keys** (`MENUKEYS`, read from kaiser.exe): the original's accelerators (F1–F12, Ctrl+N/O/S/R/L/P …,
  single letters such as `b`, the boss key: the game to boss.ksr and closed, 1000:3944; Ctrl+L
  loads KAISER.INI's last game, 1000:1292, which loading now records); on macOS also Cmd+N/O/S/R.
  Closing during a game asks like `CanClose` (1000:0af4). "Geschichtsschreibung" writes
  autosave.ksr at every human turn start (next to the port's KAISER.INI).
- **Music** (`port/gui/music.pas`): kaiser.mid in a loop on the title screen like MidiOpen /
  MidiPlay / MMMciNotify / MidiClose (1000:0920–0a0e): started by the first show and a
  restore (WMSize), EndGame and "Schalmeienklänge", stopped by a minimise, the painting of a
  game and the window's end; Windows: MCI (`mciSendString`), macOS: `AVMIDIPlayer` with the
  system's General MIDI sounds.
- **Toolbar right click:** the help topic command + 1000 (1080:0991, WinHelp
  HELP_CONTEXTPOPUP), in the help window.
- **Not ported / different:** map clicks do
  nothing without a running game (the original reads the stale player); for
  1024×768 the original enables toolbar indices up to DS:4556 = 72 and stops with runtime error
  213 (ui-infra.md), the port clamps to the last tool; after a resolution change the window keeps
  its position instead of moving to (0, 0), and the client height stays H − 40 (the original's
  MoveWindow gives the window, not the client, the height H + Delta Y).
- **A side effect kept:** at 800×600 and 1024×768 every paint of a running game calls
  `UpdateBirthDeathRates` and `UpdateHappiness` for the current player (the Zufriedenheit
  line). With the sabotage flag 0x800 set, `UpdateBirthDeathRates` draws a `RandomReal`, so in
  the original the random sequence depends on how often the main window is repainted.
- **Checks:** `KAISER_MAINSHOT=DIR` saves the window for every resolution as
  `DIR/title_WxH.png` (start) and `DIR/game_WxH.png` (after `KAISER_AUTOGAME` or
  `KAISER_LOAD=FILE`; a savegame as the first argument is loaded like `LoadFromCommandLine`
  1000:1136), plus `*_live_*` (the form as LCL paints it), then closes; e.g.
  `KAISER_LOAD=$PWD/Kaiser/LARS23.KSR KAISER_AUTOPILOT=/tmp/s KAISER_MAINSHOT=/tmp/s
  port/bin/Kaiser.app/Contents/MacOS/Kaiser`.

### The visual check

An autopilot sweep (every menu command on LARS23.KSR, a new game, a won game, raids, the
battles; `KAISER_AUTOMENU`, `KAISER_AUTOANSWER=NAME=ID/N`, `KAISER_AUTOMOUSE=NAME=X:Y`, the
window captured with `screencapture -l`) compared with the templates and the original's paint
code found, and fixed:

| Where | Problem | Cause, fix |
|---|---|---|
| SPIELERNAMEDLG (sex) | the other radio button had to be clicked | LCL unchecks the other radio buttons of a form itself; the original's BS_RADIOBUTTONs change only by program: the port keeps the state the game set (`kaiserlcl.pas`) |
| ANORDNENDLG | white grids with a black frame, Garde gate at the top | `DrawHeer`/`DrawGarde` (1038:84a1 / 8699) fill with the dialog brush and NULL_PEN; the walls of the disassembly (gate on the left) |
| ANORDNENDLG | the empty top area | the unit card under the mouse (`DrawUnitInfo` 1038:8921) was missing |
| GEGNERDLG | an empty right half | the country map (`GegnerDlg.DrawMap` 1038:462f, DS:1526/1530) was missing |
| UNITLOOKDLG, REKRUTDLG, the unit editor, KROENUNGSDLG | no picture | `DrawUnitPicture` 1040:367b / 1040:55b5, `DrawPortrait` 1038:56b9, the crown of `WMPaint` 1040:4d8c |
| WIRTSTATDLG, MILSTATDLG, HIGHSCOREDLG | lines through the labels | Windows draws a group box's frame half a text line below its top, also without a caption |
| SABOTAGEBUDGETDLG | a knob without arrows | 9 × 9 vertical scroll bars are spin controls (`TSpinBar`, the upper arrow = SB_LINEUP) |
| GEHEIMDLG and others | a squeezed "?" | buttons narrower than 24 pixels are drawn by LCL, not by Cocoa |
| "?" buttons | nothing happened | the help window (above) |
| a won game | the coronation every turn | `Victory` (1000:3459) ends with `EndGame` (game state 0) |
| Kaiser.app | killed at start after a rebuild | `build.sh` writes a new executable and signs the bundle ad hoc |

Kept as in the original: the "⌘"-like `ORNAMENTICON` and the "U" of `UNIICON` (the icons look
so), the Lagerhalle count 4 units lower (INVESTDLG template), the clipped descender of the
fourth line of RANGLISTENDLG (7 units high in the template).

## The Windows build (milestone 8)

- **Cross compiler.** FPC 3.2.2 from source, `make crossinstall CPU_TARGET=x86_64
  OS_TARGET=win64 PP=fpc OPT="-XR$(xcrun --show-sdk-path) -k-ld_classic"
  INSTALL_PREFIX=~/kaiser-toolchain/fpc` in `~/kaiser-toolchain/fpc-3.2.2` (outside the
  project: FPC's makefiles break on the space in "Kaiser decompile"; `-XR` gives the host
  compiler's link the SDK, `-n` builds have no fpc.cfg). Win64 needs no binutils (internal
  assembler and linker). x86_64-darwin (to run the x86_64 code under Rosetta) does not build
  from an arm64 host: internal error 2014051001 in genmath.inc (80-bit extended).
- **LCL.** In `tools/lazarus`: `packager/registration`, `components/lazutils`,
  `components/freetype`, then `make lcl LCL_PLATFORM=win32`, all with `CPU_TARGET=x86_64
  OS_TARGET=win64 PP=ppcrossx64 OPT="-n -Fu<cross units>/*"`. The GUI's unit paths put the
  LCL before FPC's packages (Free Vision has a `Menus` unit of its own).
- **Sources.** `{$ifdef windows}`: KAISER.INI, KAISER.SCO and KAISER.REC in
  `%APPDATA%\Kaiser`, sounds with `sndPlaySound` (what the original calls), no Cocoa
  appearance. Floating point: `Extended` is `Double` on win64 as on arm64; the game's
  arithmetic is the integer Real48 emulation anyway.
- **Build and package.** `port/build-win.sh` → `port/bin/win64/` (Kaiser.exe, ksrtool,
  ksrsim, ksrbattle, real48test, ruletest). `port/package-win.sh EDITION VERSION` → the
  download `port/bin/release/Kaiser-EDITION-VERSION-Windows-x64.zip`: `Kaiser EDITION.exe`,
  the original's `kaiser.exe` and `kaiser.mid` in `Kaiser\`, the help in `docs\`.
  `port/package-win.sh --tests` → `port/bin/Kaiser-win64-tests.zip`: the test programs, the
  vectors in `tests\`, the savegames and `run-tests.bat` (the checks of "Running").
- **macOS download.** `port/package-mac.sh EDITION VERSION` →
  `port/bin/release/Kaiser-EDITION-VERSION-macOS-arm64.zip`: the app with the original's
  `kaiser.exe` and `kaiser.mid` and the help in `Contents/Resources` (`FindExe` and
  `FindDataFile` look there).
- **Open:** running `run-tests.bat` and a game on Windows 11 (or under Wine).

## Running

The tests need the original game and its savegames in `Kaiser/` at the top of the repository
(not in git: copy your Kaiser 1.23 folder there).

```sh
port/build.sh                                   # needs: brew install fpc
port/bin/ksrtool roundtrip Kaiser/*.KSR Kaiser/*.ksr
port/bin/ksrtool show Kaiser/NILSLARS.KSR
port/bin/real48test port/tests/real48.vec       # runtime vs. original
port/bin/ruletest Kaiser port/tests/rules.vec   # rule functions vs. original
port/bin/ruletest Kaiser port/tests/turn.vec    # turn processing, AI, turn loop vs. original
port/bin/ruletest Kaiser port/tests/battle.vec  # battle window, setup and aftermath vs. original
port/bin/ruletest Kaiser port/tests/actions.vec # menu actions with the original's dialogs
port/bin/ruletest Kaiser port/tests/troops.vec  # the troop dialog (clicks into the unit grids)
port/bin/ruletest Kaiser port/tests/dialogs.vec # the generic dialog types on their own (Dlg_*)
port/bin/ksrsim Kaiser/LARS23.KSR 100 1 out.ksr # play on 100 turns, save the result
port/bin/ksrsim new:2:5:3 100 1                 # new game: 2 humans, 5 computers, level 3
tools/emu/sim_compare.sh 100 1 /tmp/cmp         # all savegames: port vs. original, turn by turn
port/bin/ksrbattle Kaiser/LARS23.KSR 0 1 0 5    # player 0 attacks 1 (field), the AI plays both
tools/emu/battle_compare.py 2                   # whole AI battles: port vs. original
```

## How the battle is tested

The battle window's logic (segment 10) runs in the emulator on a battle object at scratch
0x9000; pointers into it are logged as `B<offset>`, and `bw=` / `bwdiff=` hold the object
(offsets 0x2e..0xf9a) before and the bytes changed.

- **Battle states.** Kind `BW` builds a battle with the original `BattleWnd::Init` (the test
  player attacks player J, field or city), makes both sides computer, applies the state
  `SetupWindow` leaves and lets the original AI play 0–300 timer ticks (`WMTimer`). A tick that
  ends the battle is undone, so the battle is always still on. For the functions of the human
  side the side to move is then made human. Kinds `BU` (a unit of the window), `BN` (a cell
  near the current unit), `BA` (an attacker and an enemy's cell), `MSG` (a mouse click near
  the current unit) depend on that state. `Battle_Play` runs up to 400 ticks: whole battles.
- **What is stubbed.** Drawing (`DrawCell`, `RedrawUnit`, `ClearTargetPanel`, the buttons) and
  `EndDlg` (`Battle_End`) are logged UI calls. `DrawUnitStatus` is logged and then continues in
  the original `ComputeMotivation` (the panel is the only place that recomputes the
  motivation). `SetTimer`, `KillTimer`, `GetDC`, `ReleaseDC` and `SetFocus` are emulated API
  calls with fixed results. The timer interval (INI `Schlacht-Timer`, DS:6794) is 400 on
  both sides.
- **Segments 4 and 6** (`War`): the near procedures `BattleSetup`, `BattleFameAndXp`,
  `BattleAftermath` and the aftermath of segment 6 are called directly; kinds `INFO` and `RES`
  pass a random info block (0x192 bytes) and results block (0x37 bytes) as hex and report them
  in `out=`. `Battle` and `FightRaiders` (whose battle window is allocated on the heap and run
  modally) are glue around tested parts and are not run in the emulator.
- **Whole battles from savegames**: `port/bin/ksrbattle` and `tools/emu/battle_original.py`
  play the same AI battle and print the end code, ticks, units left, `RandSeed` and a CRC of
  the window; `tools/emu/battle_compare.py` runs them for player pairs of all savegames.

Two traps found on the way: unit-type tables indexed with an empty slot's type (255 = −1)
must read index −1 like the original (`PByte(@DS.UnitMelee)[ShortInt(t)]`; FPC turns a
`ShortInt` index into the array's 0..35 range), and 32-bit products must wrap (`MulDiv` in
`war.pas`), since FPC computes `LongInt * LongInt` in 64 bits on this target.

## The battle window in the GUI (7c)

`port/gui/battleform.pas` is the battle window of segment 10 on the LCL; the logic stays in
`port/src/battle.pas` (the tested code), whose drawing calls `Battle_*` LclUI forwards to the
open window. `War.Battle` / `FightRaiders` run it with the UI call `Battle_Execute` (a modal
form; the end code is `BattleEndCode` after the message that called `EndBattle`); the UI calls
`Battle` (a computer attacks a human, `ResolveWar`) and `FightRaiders` (turn start) go to `War`.

- **Drawing** as the original, in its pixels (no scaling; client 480 x 437, MoveWindow
  0x1e2 x 0x1ca): the map 15 x 11 cells of 32 pixels over the 8 x 8 pattern LAND (winter
  SCHNEE, terrain bitmaps +20), framed with a green (white) pen (DrawMap 1068); terrain codes
  2..13 and the rivers as bitmap 1000 + code, walls 1000 + code; units 1100 + type (side 1) /
  1200 + type (side 0), heroes portrait + 50; a unit in a stance is the black silhouette of its
  mask (Bmp_DrawSilhouette32, mask 2100 / 2200 + picture); camouflaged units (ability 29)
  outside the city are not drawn (DrawMap, RedrawUnit). DrawCell (2803) also draws the
  animation frames (0x83.. side 1 with 1300 + type, 0x8d.. side 0 with 1400 + type, 0x97..,
  0xa1.., 0xab.., 0xb5..) and code 10 (the hit, bitmap 1010 over the terrain). Sprites are
  bitmap Id with mask Id + 1000 (`Sprite`). The window is drawn into an off-screen bitmap.
- **Panels** (DrawPanelFrames 17fd, DrawUnitStatus 1a60, ClearTargetPanel 196c): two sunken
  grey frames 200 x 80 at (0, 352) and (280, 352); the unit to move left at (10, 360), the
  target right at (290, 360), 180 x 64, Comic Sans MS bold -12: name, rank orders (black /
  yellow / red + n), the effective attack and defence (motivation, blindness, Berserker,
  Knappen, unconscious, the city walls, Eingraben, surrounded, Heilen; dark red below, dark
  green above the base value), range, steps, ammunition with its icon, the hit point bar
  (red / yellow / green), blind, unconscious, stance, the morale face, the player (attacker
  yellow, defender blue) and the ability, right-aligned. An enemy's numbers show only when the
  unit to move has a rank, its hit points, morale and ability from Haudegen on. The motivation
  is computed on a copy first (the logic's `DrawUnitStatus` stores the same value right after
  the UI call).
- **Messages**: the timer (`DS.OptBattleTimer` ms) calls `WMTimer`; left click
  `WMLButtonDown`, right click `WMRButtonDown` (the combat options KAMPFOPTDLG; the help
  topics it returns are not shown, WinHelp is not ported); Warten / Fertig / Aufgeben call
  `CmWarten` / `CmFertig` / `CmAufgeben`; the buttons are enabled and disabled by the logic.
  WMMouseMove (91ae) is ported in the form: the cursors STOPCURSOR / GOCURSOR / SWORDCURSOR /
  HEALCURSOR (from kaiser.exe) by `CanMoveTo` / `CanAttack` / `CanHeal`, the target panel
  over a unit (through `Battle.DrawUnitStatus`, so hovering recomputes that unit's motivation
  as in the original), the arrow below the map. WMPaint (the map, the frames, the left panel,
  also through `Battle.DrawUnitStatus`) runs when the window appears and after every dialog
  that was opened during the battle. The window cannot be closed (WMClose does nothing).
- **Sounds**: the battle plays its sounds synchronously (mode 0, `sndPlaySound` SND_SYNC), so
  the animations show their frames for the length of a sound: the form shows what was drawn,
  then the sound plays to its end (`port/gui/wavesound.pas`: NSSound in the process, each file loaded once; starting `afplay` for every sound had stalled the battle for up to a second per strike); without sound the original's counting loop is a 100 ms pause.
- **Approximations**: while a message is handled (an AI step, a click, a dialog opened from
  the battle) further timer ticks and mouse events are dropped (Windows would deliver the
  window's WM_TIMER inside the nested modal loop of a dialog, and queue clicks); a repaint is
  always the whole window (the original repaints the uncovered region, so a target panel
  outside it stays); the buttons use the system font.
- **Autopilot**: `KAISER_AUTOPILOT=DIR` saves `DIR/battle_NNN_<tick>.png` at ticks 4, 40, every
  150 and `..._end<code>.png`, at a 30 ms timer; the human sides are played by scripted
  clicks (once the combat options, then attack an enemy in reach, else step towards the
  nearest enemy, else Fertig; the mouse is moved onto the nearest enemy before each snapshot),
  or with `KAISER_AUTOBATTLE=ai` by the AI. `KAISER_AUTOLOAD=SAVE.KSR` starts from a savegame
  instead of a new game; `KAISER_AUTOMENU` also takes `war:A:D` (computer A attacks D:
  `ResolveWar`) and `raid:P:M` (marauders 1 / Lindwurm 2 against P); `KAISER_AUTOANSWER=
  NAME=ID,...` presses button ID in dialog NAME (e.g. `KRIEGSERHADLG=1`: the city battle).
  Example: `KAISER_AUTOPILOT=/tmp/ap KAISER_AUTOGAME=0 KAISER_AUTOLOAD=Kaiser/LARS23.KSR
  KAISER_AUTOMENU=214 port/bin/Kaiser.app/Contents/MacOS/Kaiser`.
- Loading a savegame now calls `Randomize` like the original's LoadGame (1050:07ed; an e-mail
  game takes its stored `RandSeed`).

## How the exact runtime works

- `tools/emu/kaiser_emu.py` loads `kaiser.exe` into a 16-bit x86 emulator (Unicorn),
  applies the NE relocations and can call any function of the original with chosen inputs;
  Windows API calls and `RunError` stop the emulation.
- `tools/emu/x86_to_pascal.py` translates the Borland Real48 cores (10c8:0b6e–0e82, 381
  instructions) mechanically into Pascal on a simulated 16-bit register file
  (`port/src/real48core.inc`); `port/src/real48.pas` wraps them (`R48Add`, `R48Mul`, …,
  `Random`, `RandomReal`).
- `tools/emu/gen_real48_vectors.py N SEED` runs the original runtime on random inputs;
  `port/bin/real48test` compares the port: `port/bin/real48test port/tests/real48.vec`.

## How the rule tests work

- `tools/emu/gen_rule_vectors.py FUNC[,FUNC] N [SEED]` picks a real savegame and player, changes
  0–4 relevant fields at random (to reach the rare branches: spells, events, flags, negative
  money …), sets `RandSeed`, runs the original function and records the return value, the new
  `RandSeed` and every changed byte of the player array and header. `SPECS` in the script lists
  each function's address, arguments, return type and the fields worth mutating.
  Header flags (`hmut`), pointers to fields, unit pointers, out parameters and Real48
  arguments are supported (see the comment at the top of the script). Windows API calls stop
  the emulation unless the emulator implements them (`KaiserEmu.api`: so far `LoadString`).
- `port/bin/ruletest SAVEDIR VECTORS` replays each line on the port and compares the return
  value, out parameters, `RandSeed`, the player array and the header. `port/tests/rules.vec`
  (50 per function) is the checked-in set. Larger sets are generated on demand with another
  seed, e.g. `gen_rule_vectors.py FUNCS 2000 12`.
- The port transliterates each function from the disassembly in the original order of
  operations: Real48 rounding depends on it, and so does the order of the `Random` calls.

## How the UI calls are tested

Turn processing opens dialogs and calls whole UI functions (reports, battles, sounds). The
port goes through `KaiserUI.UI` at exactly these places; the tests replace both sides with a
recording:

- **Emulator** (`tools/emu/ui_stubs.py`): dialog constructors (`KaiserDlg`, `MessageDlg`,
  `Message2Dlg`, `HeroNameDlg`, …) are patched with a jump to a stub that returns a fake
  object (zeroed, fake VMT at DS:F000). Its `Execute`, `ExecDialog`, `Done` and `GetText`
  slots are stubs too, as are whole UI functions (`FUNCS`: `ShowBuildingLossDlg`,
  `FightRaiders`, `Battle`, `Do_*` menus, `PlaySound`, `Victory`, …). Every call is logged with
  its arguments: pointers as `W` (the parent window), `P<i>:<offset>` (into the player array),
  `O<n>` (the n-th fake dialog), `D<offset>`; strings as hex (`i:<id>` for resource ids);
  records as hex. `Execute` also logs what the game wrote into the dialog (`;d:`). The answer
  (return value and data written into the dialog, e.g. the chosen spell) comes from
  `UI_SCRIPTS` in `gen_rule_vectors.py` and is recorded with the call. Code of the UI segments
  that is not stubbed stops the emulation (guard), except plain logic listed in `ALLOWED`
  (`FormatPlayerTitle`, `NextPlayer`, `CpuTurn`, `ResolveWar`). `InvalidateRect` is emulated as
  a no-op. For the turn loop a fake main window is passed whose player array lies at +0x41.
- **Port** (`port/tests/replayui.pas`): `TReplayUI` formats each call the same way, compares it
  with the next recorded call and returns the recorded answer. A vector passes only if the
  sequence of UI calls (`ui=`) is identical, too.

## How the dialog types are tested

The menu actions (`Do_*`, segments 8 and 9) run with the original's own dialog objects
(`tools/emu/dlg_driver.py`); `DIALOG_TESTS` in `gen_rule_vectors.py` lists the actions and
their templates:

- The OWL control constructors (`TStatic`, `TButton`, `TScrollBar`, `TCheckBox`, `TListBox`,
  `TComboBox`, `TEdit` `InitResource`) return fake controls with a state model (text, check,
  range and position, items, selection, enabled from the template's `WS_DISABLED`); their
  methods are logged (`SetText(c201,s:…)`, `Enable(c107)`, `SetPosition(c301,4)` …).
- `TDialog.Execute` becomes a script driver: `SetupWindow`, then the events of `dlg=`
  (`c<id>` click, `s<id>:<pos>` scroll, `l<id>:<idx>` list selection, `t<id>:<hex>` typed
  text, `m<x>:<y>` / `v<x>:<y>` a left click / a mouse move at a client pixel through the
  DMT handlers for wm_LButtonDown 0x0201 / wm_MouseMove 0x0200, `ok`, `cancel`, dialogs
  separated by `/`) through the type's DMT handlers. OK runs
  `CanClose` and ends with 1, Cancel ends with 2; events on disabled controls are ignored.
  A first event `w<width>:<height>` is the window size `KaiserDlg.SetupWindow` stores at
  +0x2a / +0x2c (types that paint scaled areas read it; without it 0, i.e. scale 1).
  Memory comes from a bump allocator (nothing is freed; a full 64 KB segment continues in the
  next one); GDI calls (drawing) return 0 unlogged. A dialog
  opened by a dialog's handler (the Prokurist from the goods dialog) runs nested with the next
  script; each dialog object keeps its own controls.
- The port: dialog types are `TDialogLogic` classes in `port/src/actions.pas` (and
  `troops.pas`, `intel.pas`, `annals.pas`, `gamedialogs.pas`), registered by
  the constructor name; they work on `D.Data` laid out like the original object and reach the
  controls through `TDlgControls`. `port/tests/scriptcontrols.pas` is the same control model
  and script runner; the GUI binds the same classes to LCL forms (`TLogicDialog`). Mouse
  messages go to `TDialogLogic.Mouse` / `MouseMove`; painting stays with the UI (the
  original's drawing methods are logged UI calls, e.g. `TroopDlg_DrawHeer`). A pointer into
  a ported dialog's object is logged as `O<n>+<offset>` (e.g. its copy of the player).

`port/tests/actions.vec`: `Do_LandHandeln` (50), `Do_KornVerteilen` (100), `Do_Gebaeude` (100), `Do_SteuernFestsetzen` (100),
`Do_HandelMitGuetern` with the Prokurist (100), `TradeCaravan` (100), `ShowHeroLevelUp` (50), the census editor (50 each), `Do_Hofschmiede` (50), `Do_DemographischeDaten`, `Do_Finanzhaushalt`, `Do_InternationalerVergleich`, `Do_Karriereberatung`, `Do_ManoeverAbhalten` (100 each), `CmWirtschaft` (100), `CmMilitaer` (50), `Do_Laendernamen` (50), `CmSpiel` (60), `Do_Abkommen`, `Do_TributFordern`, `Do_Sabotage`, `Do_Geheimdienst` with strikes and the sabotage budget opened from it (100 each). Segment 9 frames are zeroed like the logic segments.

- A script event `T` is a timer tick: the type's DMT handler for wm_Timer (0x0113) in the
  emulator, `TDialogLogic.Timer` in the port (for a type whose SetupWindow set a timer:
  `TimerInterval`, which the GUI turns into an LCL timer).

**The generic dialog types on their own** (spec kind `Dlg_<type>`, `DLG_TYPES` in
`gen_rule_vectors.py`). The types of segment 12 and the small types of segments 3, 6 and 9 are
faked in all the other vectors (their constructors are in `CTORS` of `ui_stubs.py`); a
`Dlg_<type>` vector runs one of them for real: that constructor is unstubbed for the run
(`UILayer(unstub=...)`), called with Self nil, the VMT the game uses, the parent W and random
but plausible arguments (templates by name or MAKEINTRESOURCE id, texts, a unit record of a
savegame, numbers, the player array), then the fields the game writes into the object before
Execute get random values (`fld=`: offset in the object and hex), then Execute (VMT +0x4c: the
driver plays `dlg=` on the type's handlers) and Done (VMT +0x08, flag 1). `args=` holds the
constructor's arguments after the parent (`s:<hex>` string, `i:<id>` resource id, `w:` /
`b:` numbers, `r:<hex>` record, `A` the player array), `ret=` Execute's end code, `out=`
the object's result parts after Execute (`<offset>:<hex>;...`: the results the game reads,
the help context of the HelpDlg types, the copied texts). The log has the usual form
(`KaiserDlg[0](W,s:..)=O1|Execute(O1)|SetText(c101,..)|[ok]|=>1|Done(O1,1)`: every type's
constructor goes through the stubbed KaiserDlg.Init). KaiserDlg itself (its Init is OWL's
TDialog.Init) is built in place through that stub and gets its VMT afterwards. The port
(`ruletest`) does the same with `UI.Dialog` / `UI.Execute` / `UI.Done`; `TReplayUI`
leaves the faked types without logic (`LogicFor`), except the one of the vector. UI calls
of the types: `UnitInfoDlg_DrawPortrait(blink,O1)` (painting), `DisableButton2`.

`port/tests/dialogs.vec`: 50 each of `KaiserDlg`, `MessageDlg`, `HelpMessageDlg`, `Message2Dlg`,
`HelpChoice2Dlg`, `HeroNameDlg` (the random name proposal, the Lindwurm's name), `UnitInfoDlg`
(with timer ticks; its Done passes 0 to KaiserDlg.Done), `Button2Dlg`, `ButtonChoiceDlg`
(segment 12), `PromotionDlg`, `StartFinanzDlg`, `StartPopDlg` (Str(Real:2:0) = `R48Str`),
`HexenDlg` (segment 3), `MassacreDlg`, `PlunderResultDlg`, `PlunderChoiceDlg` (segment 6),
`HumanCountDlg` (its CanClose writes the game options into the header), `ComputerCountDlg`,
`PlayerDataDlg` (segment 9) – `port/src/gamedialogs.pas` (not `dialogs.pas`: the LCL has a
unit `Dialogs`); 5,700 (300 per type, seed 12) + 2,280 (120 per type, seed 11) generated
vectors identical. `PlayerSelectDlg` (1058:06d2) of segment 12 was ported before
(`actions.pas`).

Original bugs found by the dialog tests (the specs keep the inputs out of their range):

- KORNDLG: with fewer than 20 inhabitants the need rounds to 0 and the gauge (1040:9081)
  divides by it (runtime error 200).
- GUETERHANDELDLG: labels go into an 11-byte buffer next to the loop counter; a number below
  −999,999,999 overwrites the counter (endless loop).
- GEHEIMDLG (1038:092a): the Landausbau row divides by the player's land; a shown player
  without land stops with runtime error 200 (`preset_intel` gives every player land; the port
  shows 0 %).
- CENSUSDLG (the hidden census editor): "zurück" is enabled at the first player and shows
  player 255 (16-bit wrapped heap garbage); a sex byte other than 0/1 picks a garbage radio
  button. The scripts avoid the first, the specs clamp the second.
- UNITEDITDLG on an empty army slot: `UnitRankName` (1068:61db) copies an out-of-table rank
  text into a 26-byte buffer and smashes the stack (such vectors are dropped, SKIP_ON_CRASH).
- The text constructors of segment 12 (MessageDlg, HelpMessageDlg, Message2Dlg, HelpChoice2Dlg)
  StrCopy their texts unchecked into 81-byte buffers (+0x2e, +0x34, +0x7f, +0x85); a longer
  text overwrites the next buffer or the static control's pointer behind it, and SetupWindow
  calls SetText on a wrong object (the emulator logs `SetText(S,..)`; in Windows a crash). The
  same holds for the texts the game writes into PromotionDlg (+0x2e), MassacreDlg (+0x42) and
  PlunderChoiceDlg (+0x34 / +0x67, 51 bytes). The specs keep texts within the buffers.
- ButtonChoiceDlg (1058:0da7): the button count is a byte loop 0..count-1; with 0 it creates 256
  buttons and writes their pointers past the object (0x61 bytes), with more than 10 too (the
  battle always passes 5). The specs use 1..10.
- `FormatThousands` (1068:6b58, Wirtschaft and other statistics): its length table ends at 9
  digits; a 10-digit number makes it write the digits 11,520 bytes off its buffer and show an
  empty string. The port shows the same and skips the stray write.

`port/tests/troops.vec`: `Do_TruppenAufstellen` (80, all seven modes, with REKRUTDLG and
SOLDDLG nested) and `ChooseUnitToGive` (20) – `port/src/troops.pas`; 8,000 + 3,000
generated vectors identical (docs/rules/military.md).

## How much of the original the tests run

The port is not byte-identical assembly (Free Pascal compiles differently from Borland Pascal 7);
what is identical is the behaviour, checked by the differential tests. How much of the original
those tests actually execute: `tools/emu/coverage.py run 150 7` generates 150 vectors for every
tested function (all `SPECS` and dialog types of `gen_rule_vectors.py`) plus the whole-battle and
simulator comparisons, with the emulator recording each executed basic block
(`KAISER_COVERAGE`); `coverage.py report` maps them to the functions of
`ghidra_out/functions.csv`. Result of 2026-10-23 (44,849 vectors, all identical with the port;
334 whole battles identical; 34 of 34 games identical over 30 turns):

| Segment | Role | Functions | reached | Code bytes | executed | Share |
|---|---|---|---|---|---|---|
| 1 | main window, turn loop | 76 | 10 | 15,032 | 1,835 | 12.2 % |
| 2 | AI | 20 | 19 | 17,113 | 16,938 | 99.0 % |
| 3 | turn processing | 36 | 35 | 24,385 | 23,890 | 98.0 % |
| 4 | war | 7 | 5 | 4,520 | 3,921 | 86.7 % |
| 5 | e-mail game | 7 | 0 | 823 | 5 | 0.6 % |
| 6 | battle aftermath | 20 | 20 | 5,083 | 5,053 | 99.4 % |
| 7 | AI | 18 | 17 | 4,377 | 4,318 | 98.7 % |
| 8 | menu actions (military, diplomacy) | 149 | 140 | 38,148 | 32,433 | 85.0 % |
| 9 | menu actions (economy, reports) | 194 | 167 | 38,781 | 32,923 | 84.9 % |
| 10 | battle window | 78 | 58 | 39,788 | 25,968 | 65.3 % |
| 11 | files (INI, annals) | 15 | 1 | 4,996 | 123 | 2.5 % |
| 12 | dialog base types | 47 | 36 | 3,988 | 2,976 | 74.6 % |
| 13 | main window drawing | 11 | 1 | 8,838 | 331 | 3.7 % |
| 14 | rule library | 104 | 103 | 28,549 | 28,006 | 98.1 % |
| | **segments 1–14** | **782** | **612** | **234,421** | **178,720** | **76.2 %** |

The game logic (segments 2, 3, 6, 7, 14) runs to 98–99 %; what the tests do not run is mostly
drawing and window code that the GUI reimplements on the LCL (segments 1, 10, 13; in 8 and 9 the
`Draw*`/`WMPaint` methods), the file code (11: checked by the round trip of all savegames and
the annals/records format) and the e-mail game (5 and `BattleEmail` in 4, not ported).
`Battle` and `FightRaiders` (segment 4) are tested with their battle window's modal run
scripted (`War_Battle`, `War_FightRaiders`: the BattleWnd's `TDialog.Execute` answers a result
code 10..13 as the port's UI call `Battle_Execute`, its `Done` does nothing); the window itself
is the battle tests' and the GUI's. Segments 15–27 are the Borland runtime and OWL (the Real48
core of segment 26 is tested on its own: `real48.vec`).

## The headless simulator

`ksrsim` is the game without a window: the human players do nothing but end their turn
("Runde beenden" = `EndHumanTurn`: their year end, all computer players in `NextPlayer`,
the next human's turn start). Dialogs answer OK, UI functions answer 0 (a computer that
attacks a human loses the battle until the battle engine exists). After every human turn it
prints the current player, the year, `RandSeed` and a CRC32 of the player array and the game
record. A game ends with a coronation, at game state 0, or when no human is left (the original
`NextPlayer` would loop forever). `new:H:C:L` starts with `NewGame` (the "Neues Spiel" menu):
H humans named `Spieler1..`, C computers of level L, goods trade and initiative on.

`tools/emu/sim_original.py` drives the original the same way: `CmBeenden` (and
`CmNeuesSpiel`) run in the emulator with a fake main window and the same dialog answers;
`Randomize` is stubbed (the seed comes from the command line on both sides). Offered units (`UnitInfoDlg`)
are declined on both sides: with the army dialog stubbed, a passive human would pile them up in
the Garde beyond 8, which overruns the player record.

Result: `sim_compare.sh 300 SEED DIR` for seeds 1–3 over all savegames, plus 10 new games
(`new:1:1:1` … `new:2:8:4`): 5,093 turns, 97 of 100 games identical to the end. In the other 3
(GLANZGLO seed 1 turn 44, SEP14 and LARSUWE2 seed 3, turns 36 and 295) the emulated original
crashes; the port is identical up to there. Cause: sabotage action 6 lets a deserter join a
Garde of 8 units, the computer's next `Ai_ArrangeArmies` sorts 17 units into an array of 16
and overwrites its return address. The port overruns the same array but survives, so those
games only compare up to the crash.
