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

## Regenerating everything

```sh
tools/bin/helpdeco ../../Kaiser/KAISER.HLP      # run inside extracted/help/
python3 -I tools/help_to_md.py extracted/help/KAISER.rtf docs/manual.md
python3 -I tools/ne_info.py Kaiser/kaiser.exe > docs/ne-layout.md
tools/.venv/bin/python -I tools/ne_resources.py Kaiser/kaiser.exe extracted/res --png

tools/ghidra/import.sh                          # fresh import + auto-analysis (only when starting over)
tools/.venv/bin/python -I tools/ghidra/fixup_analysis.py
tools/.venv/bin/python -I tools/ghidra/apply_names.py
tools/.venv/bin/python -I tools/ghidra/export_all.py

python3 -I tools/ksr.py --check Kaiser/*.KSR Kaiser/*.ksr
```

Always run Python with `-I`: the project folder `ghidra/` would otherwise shadow
the `ghidra` Java package inside PyGhidra.

## Status

- Resources, help file and NE layout fully extracted.
- Ghidra: 1440 functions, all decompile; entry point and main program identified.
- Library code named (353 names: System, Strings, WinDos, Objects, OWindows, ODialogs,
  OMemory, Validate). Segments 19–26 are library; the ~850 unnamed functions in
  segments 1–18 are the game itself. Segment → unit map in `docs/segments.md`.
- Savegame container + anti-cheat checksums decoded and verified on all 30 saves.
- Not yet: running the game (needs Windows 3.11 in DOSBox-X), field-level savegame map,
  game logic.
