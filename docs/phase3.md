# Phase 3 – reimplementation

Goal: a native port that plays exactly like the original (same rules, same random
numbers, same savegames), runs on current Windows (and macOS/Linux), and reuses the
original resources.

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
  the army). In the emulator every `ENTER n,0` frame of the logic segments starts zeroed (the
  instruction is patched to `INT3` and emulated with a zero fill), the stack is zeroed before
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
| 6 | Battle engine (segment 10) | scripted battles, differential where possible | |
| 7 | GUI (Lazarus): main window, menus, dialogs from the extracted dialog templates, bitmaps, sounds | manual play-through against the original in DOSBox-X | |

## Running

```sh
port/build.sh                                   # needs: brew install fpc
port/bin/ksrtool roundtrip Kaiser/*.KSR Kaiser/*.ksr
port/bin/ksrtool show Kaiser/NILSLARS.KSR
port/bin/real48test port/tests/real48.vec       # runtime vs. original
port/bin/ruletest Kaiser port/tests/rules.vec   # rule functions vs. original
port/bin/ruletest Kaiser port/tests/turn.vec    # turn processing, AI, turn loop vs. original
port/bin/ksrsim Kaiser/LARS23.KSR 100 1 out.ksr # play on 100 turns, save the result
port/bin/ksrsim new:2:5:3 100 1                 # new game: 2 humans, 5 computers, level 3
tools/emu/sim_compare.sh 100 1 /tmp/cmp         # all savegames: port vs. original, turn by turn
```

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
