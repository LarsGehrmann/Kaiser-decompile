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
  table resources with a `LoadString` (`kaiserres.pas`).
- **Globals stay where they were.** `KaiserDS.DS` is a packed record with the layout of the
  original data segment (0x681c bytes), initialised with its contents from `kaiser.exe`.
  Known tables and globals are named fields at their original offsets (`DS.Game` = DS:6108,
  `DS.PromotionLand` = DS:57f8, `DS.UnitCanDesert` = DS:52b8, …). Unknown bytes are padding.
  So an index that runs past a table reads the same neighbouring bytes as in the original
  (`CanBePromoted` reads `PromotionLand[11]` for a Kaiser).
- **Uninitialised locals.** Some original functions copy partly uninitialised local records
  (e.g. `RecruitUnit`'s new unit: hit points, steps, motivation). The emulator zeroes its stack
  before every call and the port zero-initialises these locals, so both agree on 0.
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
| 2 | Runtime: `Random`, `RandomReal`, Real48 add/sub/mul/div/compare/round/trunc/from-longint | differential test against segment 26 in the emulator | ✅ 300,000 / 300,000 bit-identical |
| 3 | Rule library: segment 14 functions (rates, happiness, income, harvest, prices, …) | per-function differential tests | in progress: 84 of 102 functions (`port/src/rules.pas`); full run 84,000 / 84,000 vectors identical (1,000 per function) |
| 4 | Turn processing: PlayerTurnStart/End, events, promotion, revolution, AI year | differential tests; whole computer years from savegames | |
| 5 | Headless simulator: run a game with computer players only | compare with the emulated original year by year | |
| 6 | Battle engine (segment 10) | scripted battles, differential where possible | |
| 7 | GUI (Lazarus): main window, menus, dialogs from the extracted dialog templates, bitmaps, sounds | manual play-through against the original in DOSBox-X | |

## Running

```sh
port/build.sh                                   # needs: brew install fpc
port/bin/ksrtool roundtrip Kaiser/*.KSR Kaiser/*.ksr
port/bin/ksrtool show Kaiser/NILSLARS.KSR
port/bin/real48test port/tests/real48.vec       # runtime vs. original
port/bin/ruletest Kaiser port/tests/rules.vec   # rule functions vs. original
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
  (100 per function) is the checked-in set. Larger sets are generated on demand with another
  seed, e.g. `gen_rule_vectors.py FUNCS 2000 12`.
- The port transliterates each function from the disassembly in the original order of
  operations: Real48 rounding depends on it, and so does the order of the `Random` calls.
