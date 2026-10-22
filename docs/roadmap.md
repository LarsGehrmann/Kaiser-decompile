# Roadmap

## Phase 1 – groundwork (done)

Tools, extraction (manual, resources, NE layout), Ghidra baseline, library code named,
savegame container + checksums, Windows 3.11 runtime in DOSBox-X.

## Phase 2 – game logic mapping (in progress)

Goal: every game function named, every field of `TGameHeader` and `TPlayer` known,
the turn simulation understood well enough to write it down as rules.

### Method

1. **Entry points** – OWL handler tables (`tools/owl_tables.py`): every menu command of the
   main window mapped to its handler, and the single subsystem function behind it named
   `Do_<Command>` (`tools/ghidra/derive_actions.py`). ✅
2. **Types** – record layouts live in `tools/kaiser_structs.py` (single source of truth for
   `ksr.py`, the field index and Ghidra). `apply_structs.py` creates `TGameHeader`
   (placed at DS:6108), `TPlayer`, `KaiserWindow` and types `Self` in its methods. ✅
3. **Field naming loop**, per subsystem:
   read the `Do_*` function and its dialog → name fields in `kaiser_structs.py` and
   functions in a names CSV → re-run apply + export → check against the running game
   (change one value in the dialog, save, `tools/ksr.py` diff).
4. **Write the rules down** in `docs/rules/<subsystem>.md` with formulas and the
   functions they come from.

### Subsystem order

| # | Subsystem | Entry points | Status |
|---|---|---|---|
| 1 | Turn loop / game state machine | `CmBeenden`, `NextPlayer`, `CpuTurn`, `Victory`, `EmailGameStep` — see `docs/rules/turn-loop.md` | ✅ structure; yearly processing → #2 |
| 2 | Grain & population | `Do_KornVerteilen` 1040:8551, `Do_DemographischeDaten` 1040:62f8 | |
| 3 | Land & market | `Do_LandHandeln` 1040:7e4b, `Do_HandelMitGuetern` 1040:1439 | |
| 4 | Buildings | `Do_Gebaeude` 1040:6cff | |
| 5 | Taxes & finances | `Do_SteuernFestsetzen` 1040:669d, `Do_Finanzhaushalt` 1040:5b3a | |
| 6 | Titles / promotion / revolution | `Do_Karriereberatung` 1040:3a9d, victory 1000:3459 | |
| 7 | Military & battles | `Do_TruppenAufstellen` 1038:6a30, `Do_ManoeverAbhalten` 1040:4ede, `CmKriegFuehren` 1000:193f, MAPDATA | |
| 8 | Diplomacy & sabotage | `Do_Entwicklungshilfe`, `Do_Abkommen`, `Do_TributFordern`, `Do_Sabotage` (seg 8) | |
| 9 | Computer players (AI) | turn loop, segments 2–7 and 14 (no API imports) | |
| 10 | Hidden commands | cm 612, 801 (`b` key), 802 (Ctrl+P), 803 (Ctrl+L) and `Debug=an` | |

## Phase 3 – reimplementation (later)

Language decision, then a port validated by loading the same savegame in both versions and
comparing the next turn.
