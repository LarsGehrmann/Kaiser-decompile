# Kaiser v1.23 – reverse engineering

Kaiser (© Stefan Maday 1997–2005) is a 16-bit **Windows 3.x NE** program written in
**Borland Pascal 7 with ObjectWindows (OWL)**. Goal: fully reverse engineer it.

## Layout

| Path | Contents |
|---|---|
| `Kaiser/` | original game files, read-only, never modified |
| `tools/` | our scripts (Python 3, run with `python3 -I`) |
| `tools/ghidra/` | Ghidra import + PyGhidra scripts; `names/*.csv` = hand-maintained symbol names |
| `extracted/help/` | `KAISER.HLP` decompiled by helpdeco (RTF + help bitmaps) |
| `extracted/res/` | all exe resources: strings, dialogs, menus, accelerators, bitmaps (+PNG), icons, WAV sounds, MAPDATA, TOOLBARDATA |
| `ghidra/` | Ghidra project `Kaiser.gpr` (not in git) |
| `ghidra_out/` | text exports of the Ghidra project: `functions.csv`, `strings.csv`, `decomp/segNN.c` |
| `docs/` | findings: `manual.md` (rules), `ne-layout.md`, `segments.md`, `ksr-format.md`, `glossary.md` |

## Setup (macOS arm64)

```sh
brew install ghidra icoutils          # ghidra pulls in openjdk@25
tools/ghidra/build_natives.sh         # Homebrew's Ghidra lacks the arm64 decompiler; re-run after brew upgrade
python3 -m venv tools/.venv
tools/.venv/bin/pip install pillow construct
tools/.venv/bin/pip install --no-index -f /opt/homebrew/opt/ghidra/libexec/Ghidra/Features/PyGhidra/pypkg/dist pyghidra
# helpdeco: built from https://github.com/pmachapman/helpdeco into tools/bin/
```

Open the project in the GUI with `ghidraRun` → File → Open Project → `ghidra/Kaiser.gpr`.
**Close the GUI before running any PyGhidra script** (Ghidra locks the project).

## Running the game (DOSBox-X + Windows 3.11)

`win311/` (not in git) is the emulated PC: `win311/C/` is drive C: with `WINDOWS\`, `KAISER\`
(a writable copy of the game) and `INSTALL\` (setup files).

```sh
win311/run.sh          # Windows 3.11 + Kaiser
win311/run.sh --win    # Windows only
```

- Saves written by the game appear directly in `win311/C/KAISER/`, ready for `tools/ksr.py`.
- The game reads `KAISER.INI` from `C:\WINDOWS` (GetPrivateProfileString without a path).
- Display: Super VGA 800×600×16. Sound: Sound Blaster 1.5 (wave) + Ad Lib FM (MIDI), set up in `SYSTEM.INI`.
- Reinstall from scratch: delete `win311/C/WINDOWS`, then `win311/install.sh` (unattended `SETUP /H:KAISER.SHH`).
- Click into the window to capture the mouse; Ctrl+F10 releases it.

## Regenerating everything

```sh
tools/bin/helpdeco ../../Kaiser/KAISER.HLP      # run inside extracted/help/
python3 -I tools/help_to_md.py extracted/help/KAISER.rtf docs/manual.md
python3 -I tools/ne_info.py Kaiser/kaiser.exe > docs/ne-layout.md
tools/.venv/bin/python -I tools/ne_resources.py Kaiser/kaiser.exe extracted/res --png

tools/ghidra/import.sh                          # fresh import + auto-analysis (only when starting over)
tools/.venv/bin/python -I tools/ghidra/fixup_analysis.py
python3 -I tools/owl_tables.py Kaiser/kaiser.exe docs/owl-tables.md tools/ghidra/names/25_handlers.csv
python3 -I tools/ghidra/derive_actions.py       # needs a previous export_all run
tools/.venv/bin/python -I tools/ghidra/apply_names.py
tools/.venv/bin/python -I tools/ghidra/apply_structs.py   # types from tools/kaiser_structs.py
tools/.venv/bin/python -I tools/ghidra/export_all.py
python3 -I tools/field_index.py > docs/field-index.md

python3 -I tools/ksr.py --check Kaiser/*.KSR Kaiser/*.ksr
```

Always run Python with `-I`: the project folder `ghidra/` would otherwise shadow
the `ghidra` Java package inside PyGhidra.

Reading code: `python3 -I tools/fn.py <address|name> --brief` prints a decompiled function;
`tools/.venv/bin/python -I tools/ghidra/disasm.py <address>` prints annotated disassembly
with decoded Real48 constants (the decompiler drops them). Text dumps of all game segments
are in `ghidra_out/disasm_seg*.txt`.

## Game rules (docs/rules/)

| Document | Contents |
|---|---|
| [turn-loop.md](docs/rules/turn-loop.md) | year structure, human/computer turns, victory, game states |
| [population-grain.md](docs/rules/population-grain.md) | births, deaths, migration, happiness, harvest, grain |
| [events.md](docs/rules/events.md) | the 23 yearly events |
| [land-market.md](docs/rules/land-market.md) | land price, goods, Prokurist, caravans, game start |
| [buildings.md](docs/rules/buildings.md) | building types, costs, limits |
| [finances.md](docs/rules/finances.md) | taxes, justice, trade, army pay, interest |
| [titles.md](docs/rules/titles.md) | promotion requirements, first king, revolution |
| [military.md](docs/rules/military.md) | unit tables, armies, recruiting, fiefs, war, initiative |
| [battle.md](docs/rules/battle.md) | tactical battle |
| [diplomacy.md](docs/rules/diplomacy.md) | message protocol, treaties, sabotage |
| [ai.md](docs/rules/ai.md) | computer players |
| [hidden-features.md](docs/rules/hidden-features.md) | boss key, Census Editor, Debug mode |

Data layouts: `tools/kaiser_structs.py` (TGameHeader, TPlayer, TUnit) and
[docs/ksr-format.md](docs/ksr-format.md); data tables in [docs/data-tables.md](docs/data-tables.md);
roadmap in [docs/roadmap.md](docs/roadmap.md).

## Status

- Resources, help file and NE layout fully extracted; library code named.
- Game logic: all ten subsystems mapped (see the table above); ~800 names applied.
- Savegame: ~100 player fields identified; all formulas that can be checked against the
  30 saves were (most match exactly).
- Running: Windows 3.11 + Kaiser in DOSBox-X (`win311/run.sh`).
- Open: remaining unnamed helpers, a few formulas marked "unconfirmed" in the rules,
  reimplementation (phase 3).
