# Segment → unit map of `kaiser.exe`

Derived from the Ghidra text exports, raw-byte disassembly of the NE image,
the relocation table (far calls and VMT pointers), the VMT/DMT tables in the
data segment and the unit-init chain in `entry` (1000:3a3c). Names for the
library code live in `tools/ghidra/names/10_runtime.csv` (System, Strings,
WinDos) and `tools/ghidra/names/20_owl.csv` (Objects, OWindows, ODialogs,
OMemory, Validate).

The library layout is the Borland Pascal 7 one, not TPW 1.x. Evidence:
`Objects` (TCollection), `OWindows`, `ODialogs`, `OMemory` and `Validate`
are separate units, and `Objects` has `Abstract` = RunError(211) plus
MaxCollectionSize = 3FFCh. `TEdit` also has a `Validator` field
and `wm_PostInvalid` handling. In the EXE the linker placed the main program
first, then the game units, then the library units, with System last.

| Seg | Ghidra base | Size | Unit | Init (called from `entry`) | Evidence / notes |
|---|---|---|---|---|---|
| 1 | 1000 | 15036 | **Main program** (`program Kaiser`) | — (`entry` 1000:3a3c) | InitTask, unit init chain, App.Init/Run/Done; GetOpen/SaveFileName, mciSendCommand (`kaiser.mid`), LoadMenu/LoadAccelerators. Holds the app's InitMainWindow override (1000:0002, VMT DS:0010 slot +18h) and the main window type (VMT DS:01a4, instance size 0x4959). |
| 2 | 1008 | 17115 | game unit | 1008:42d6 | No API imports. Random/LongMul/LongDiv/Real heavy, so pure game logic. |
| 3 | 1010 | 24387 | game unit | 1010:5f3e | No API imports. Logic plus a few dialog method overrides (1010:5c8e, 5e96, 5f1a, 5ef6). |
| 4 | 1018 | 4522 | game unit | 1018:11a5 | No API imports, 7 functions. Pure logic. |
| 5 | 1020 | 825 | game unit (no init) | — | No API imports. Small dialog helpers (creates dialog via 1058:0002 and calls Execute). |
| 6 | 1028 | 5085 | game unit (no init) | — | No API imports. Logic: Random, Real, Str(Longint). |
| 7 | 1030 | 4379 | game unit | 1030:1116 | No API imports. Pure logic. |
| 8 | 1038 | 38153 | game unit | 1038:9504 | GDI drawing plus many game dialogs (ABFRAGE*DLG, CENSUSDLG, ...), Val/StrPas heavy. |
| 9 | 1040 | 38783 | game unit | 1040:9738 | GDI plus game dialogs (BIERKARAWANEDLG, HAUSHALTSDLG, ...), SetTimer. The biggest unit. |
| 10 | 1048 | 39854 | game unit | 1048:9b67 | Battle/map view: GDI, cursors (GOCURSOR/HEALCURSOR), KAMPFOPTDLG, SetTimer, WinHelp. |
| 11 | 1050 | 5042 | game unit (config / file I/O) | 1050:1362 | INI (Get/WritePrivateProfile*), FindResource MAPDATA, the only user of System file I/O (Assign/Reset/Rewrite/BlockRead/BlockWrite/Close/IOResult/{$I+} check), MessageBox `001: Kann Datei ...`. |
| 12 | 1058 | 3990 | game unit (common dialog base) | 1058:0f91 | Owns the base dialog type used by ~59 TDialog descendants (shared DMT DS:3350 → 1058:00fb/0111, Done 1058:0166). Also SetTimer and WinHelp(`kaiser.hlp`). |
| 13 | 1060 | 8840 | game unit (main-window painting / menus) | 1060:2241 | CheckMenuItem/ModifyMenu/DrawMenuBar, TextOut, BIGLOGO, `Speichern unter`, many Str(Longint). |
| 14 | 1068 | 28551 | game unit | 1068:6f82 | One LoadString only, otherwise pure logic: the most Real48 math, Random and Sqrt. |
| 15 | 1070 | 191 | game unit (sound, no init) | — | sndPlaySound on a `WAVEDATA` resource (Find/Load/LockResource). |
| 16 | 1078 | 714 | game unit (bitmap helpers, no init) | — | BitBlt/StretchBlt, CreateCompatibleDC, LoadBitmap. |
| 17 | 1080 | 4598 | toolbar unit (`OWLToolbar` window class) | 1080:11d3 | `ToolBarData` resource, `GrayingBitmap`, TWindow descendant VMT DS:4418 (25 virtuals) plus two TObject descendants (DS:4484, DS:44c4). WinHelp uses `kaiser.hlp`, so it is customised or the author's own code. Its init chains an ExitProc (DS:5ff2). Not named here. |
| 18 | 1088 | 214 | game unit (globals init) | 1088:0002 | Init only: fills name tables via StrCopy, GetCurDir, `\KAISER.INI` path. |
| 19 | 1090 | 9249 | **OWindows** (OWL) | — | TWindowsObject, TWindow and TApplication. Window thunks (MakeObjectInstance), props `OW1`/`OW2`, StdWndProc/InitWndProc, `TurboWindow` class, `Error code = %d. Continue?`. RegisterClass/CreateWindowEx/message loop/DefMDIChildProc. |
| 20 | 1098 | 6573 | **ODialogs** (OWL) | — | TDialog, TControl, TButton, TCheckBox, TRadioButton, TStatic, TEdit, TListBox (methods only), TComboBox and TScrollBar. BWCC class names `BorBtn/BorCheck/BorRadio`, scroll-bar and EndDialog APIs. |
| 21 | 10a0 | 61 | **Validate** | — | Only TValidator.Valid survived smart linking; called by TEdit.IsValid. |
| 22 | 10a8 | 1304 | **Objects** | — | Abstract, TObject, TStream.Get/Put/StrWrite, TCollection (VMT DS:5faa). |
| 23 | 10b0 | 180 | **OMemory** | — (InitMemory called from TApplication.Init) | LowMemory/RestoreMemory/HeapFunc. Safety pool at DS:5fd4..5fda. |
| 24 | 10b8 | 101 | **WinDos** | — | GetDate and GetCurDir (OemToAnsi, DosError DS:6818). |
| 25 | 10c0 | 480 | **Strings** | — | StrLen, StrEnd, StrMove, StrCopy, StrPCopy, StrCat, StrComp, StrIComp, StrPas, StrNew, StrDispose. |
| 26 | 10c8 | 6558 | **System** | 10c8:0002 (first) | Startup (WaitEvent/InitApp/GetWinFlags), heap, RunError/Halt, file I/O, strings, sets, Real48, Random, Str/Val, Move/FillChar, DMT dispatch. PRELOAD. |
| 27 | 10d0 | 24616 | DGROUP (data) | — | Typed constants, VMTs/DMTs, OWL proc variables, System variables at the end. |

No WinCrt, OStdDlgs or WinTypes/WinProcs code is linked; WinTypes and WinProcs
are interface-only units.

## Global application object

* `entry` calls `TApplication.Init` (1090:1f08) as
  `App.Init('Kaiser')`. It pushes **DS:04fe** (the PChar `"Kaiser"`, the
  application name), then the VMT word **0x0010**, then `@App` = **DS:6028**.
  So the VMT is at **DS:0010**, not DS:04fe. Its header reads instance size
  0x12, -size 0xFFEE and DMT 0. 0x12 bytes is exactly the BP7 `TApplication` (VMT ptr, Status,
  Name, MainWindow, HAccTable, KBHandlerWnd), so the game's descendant adds
  no fields.
* App VMT slots (DS:0010+): +08 Done 1090:1faf, +0C IdleAction, +10
  InitApplication, +14 InitInstance, **+18 InitMainWindow = 1000:0002 (game
  override)**, +1C Run (called by `entry`), +20 MessageLoop, +24
  ProcessAppMsg, +28 ProcessDlgMsg, +2C ProcessAccels, +30 ProcessMDIAccels,
  +34 MakeWindow, +38 ExecDialog, +3C ValidWindow, +40 Error, +44 CanClose.
  `entry` then calls Done through slot +08.
* Field layout of App (DS:6028): +0 VMT, +2 Status, +4 Name, +8
  MainWindow, +0C HAccTable, +0E KBHandlerWnd.
* `Application` (the OWL global `PApplication`) is at **DS:5bde**.
  TApplication.Init sets it, and the
  StdWndProc instance (MakeProcInstance) is at DS:5c02/5c04.
* The main window type is VMT **DS:01a4**. It is a TWindow descendant with
  instance size **0x4959** (about 18.8 KB, probably most of the game state)
  and DMT DS:0058. Its overrides are Done 1000:39c3, GetWindowClass 1000:0226,
  SetupWindow 1000:0268, CanClose 1000:0af4 and Paint 1000:0b5d.

## OWL object model as seen in the binary

TWindowsObject fields: +2 Status, +4 HWindow, +6 Parent, +0A ChildList (last
child), +0E TransferBuffer, +12 Instance (thunk), +16 Flags (1 KBHandler,
2 FromResource, 4 AutoCreate, 8 MDIChild, 10h Transfer), +17 CreateOrder,
+19 SiblingList (size 1Dh). TWindow adds Attr at +1D (Title, Style, ExStyle,
X, Y, W, H, Param, Id at +35), DefaultProc +37, Scroller +3B and
FocusChildHandle +3F (size 41h). TDialog: Attr.Name +1D, Attr.Param +21,
IsModal +25.

Common VMT slots: +08 Done, +0C DefWndProc, +10 DefCommandProc, +14
DefChildProc, +18 DefNotificationProc, +1C Register, +20 Create, +24
Destroy, +28 GetId, +2C GetClassName, +30 GetClient, +34 GetWindowClass, +38
SetupWindow, +3C CanClose, +40 Transfer, +44 TransferData, +48
DispatchScroll. Then TWindow adds +4C Paint. TDialog adds +4C Execute and
+50 EndDlg.

Dynamic (message) methods are dispatched through the DMT (VMT+4). The indices are
wm_First+msg, cm_First $A000+cmd, id_First $8000+id and nf_First $9000+code.
The library DMTs are at DS:5b5c (TWindowsObject), 5b9a (TWindow), 5c82
(TControl), 5c56 (TDialog), 5ce0 (TCheckBox), 5dde (TEdit) and 5ec6
(TScrollBar).

Library VMTs in the data segment: 5c90 TButton, 5cee TCheckBox, 5d3e
TRadioButton, 5d8e TStatic, 5e22 TEdit, 5e72 TComboBox, 5efe TScrollBar and
5faa TCollection. The game itself defines about 70 VMTs: 59 TDialog
descendants, a few TWindow descendants (main window DS:01a4, toolbar DS:4418)
and two plain TObject descendants in seg 17.

API procedure variables (BWCC-redirectable) are at DS:5be2 CreateDialogParam,
5be6 DialogBoxParam, 5bea DefWindowProc, 5bee DefMDIChildProc, 5bf2
DefDlgProc and 5bf6 MessageBox. 5bfa is the `BWCCClassNames` flag.

## System unit variables (DS)

5fd2 Objects.StreamTypes, 5fd4 SafetyPoolSize, 5fd6 SafetyPool, 5fdc
HPrevInst, 5fde HInstance, 5fe0 CmdShow, 5fe2 CmdLine, 5fe6 HeapList, 5fe8
HeapLimit, 5fea HeapBlock, 5fec HeapAllocFlags, 5fee HeapError, 5ff2
ExitProc, 5ff6 ExitCode, 5ff8 ErrorAddr, 5ffc PrefixSeg, 5ffe InOutRes,
6000 RandSeed, 6004 SelectorInc, 6006 Test8086, 6007 FileMode, 6008
`Runtime error 000 at 0000:0000` buffer, 6818 WinDos.DosError.

## Notes

* **Corrections to `00_program.csv`.** `10_runtime.csv` overrides them
  because it is applied later. The near heap cores are 10c8:01ca and
  10c8:02d7, now named `_HeapAlloc`/`_HeapFree`. The Pascal-callable
  `GetMem`/`FreeMem` are 10c8:012d and 10c8:0147. 10c8:06ca is not `Move`. It
  is a forward-only block copy that the compiler emits for record/array
  assignment (124 sites, with sizes such as 0x6d5). The real overlap-safe
  `Move` is 10c8:1920, which Objects' TCollection.SetLimit calls.
* The game uses **PChar strings** almost everywhere: StrCopy has 244 call
  sites and StrCat 116. Pascal ShortString helpers appear only around
  StrPas/Val/Str.
* Only seg 11 does file I/O, using untyped files and BlockRead/BlockWrite. Real48 software
  floating point (no 8087 code paths are used) is spread over segs 2, 3, 7,
  8, 9, 10 and 14.
* Units 2, 3, 4, 5, 6, 7, 14 and 18 import **no Windows API** (seg 14 has a
  single LoadString). They are the purest game-logic units and a good
  starting point. Segs 8, 9, 10, 12 and 13 mix logic with GDI/dialog UI.
* In the dead (unreferenced) Real48 code in System there is also a Sin entry
  at 10c8:0fce, which is the fall-through of Cos, and an Exp routine around
  10c8:1101. These are not named because their exact entry points are
  uncertain.
