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
  `port/tests` test programs; `tools/gen_pascal_types.py` generates the record types from
  `tools/kaiser_structs.py`; the emulator harness lives in `tools/emu/`.

## Milestones

| # | Milestone | Validation | Status |
|---|---|---|---|
| 1 | Data layer: `TGameHeader`, `TPlayer`, `TUnit`, load/save `.KSR` | all 30 saves round-trip byte-identically | ✅ |
| 2 | Runtime: `Random`, `RandomReal`, Real48 add/sub/mul/div/compare/round/trunc/from-longint | differential test against segment 26 in the emulator | ✅ 300,000 / 300,000 bit-identical |
| 3 | Rule library: segment 14 functions (rates, happiness, income, harvest, prices, …) | per-function differential tests | in progress: 17 functions (`port/src/rules.pas`), 51,000 / 51,000 identical |
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
- `port/bin/ruletest SAVEDIR VECTORS` replays each line on the port and compares all three.
  `port/tests/rules.vec` (300 per function) is the checked-in set; larger sets are generated on
  demand with another seed.
- The port transliterates each function from the disassembly in the original order of
  operations: Real48 rounding depends on it, and so does the order of the `Random` calls.
