# Kaiser – the port

**Kaiser** (v1.23, © Stefan Maday 1997–2005) is a German turn-based strategy game for
Windows 3.x in the tradition of the C64 classic *Kaiser*: up to ten players, human or computer,
grow a medieval principality with grain, land, buildings, trade, armies and diplomacy, and
compete to be crowned emperor. Wars are fought out on a tactical battle map.

This repository reverse engineers the original 16-bit program (Borland Pascal 7 with
ObjectWindows) and ports it to Free Pascal, so it runs on today's macOS and Windows:

- **Kaiser Classic** (branch `main`): the faithful port. The rules, the computer players and
  the battles behave like the original down to the random numbers; differential tests run the
  original's code in an emulator and compare (see [Status](#status)).
- **Kaiser Remastered** (branch `remastered`): the same game in a freely resizable window,
  with the graphics upscaled by a pixel-art scaler, scaled dialogs and fonts, an in-game help
  window, and crashes and clear bugs of the original fixed. The rules and savegames stay the
  same. Details: [docs/remastered.md](docs/remastered.md).

The game itself is in German.

## Download and play

Get the zip for your system from the
[Releases page](https://github.com/LarsGehrmann/Kaiser-decompile/releases):

| File | System |
|---|---|
| `Kaiser-Remastered-<version>-macOS-arm64.zip` | macOS 11 or newer on Apple Silicon (M1 and later) |
| `Kaiser-Remastered-<version>-Windows-x64.zip` | Windows 10 / 11, 64-bit |
| `Kaiser-Classic-<version>-macOS-arm64.zip` | as above, the faithful port |
| `Kaiser-Classic-<version>-Windows-x64.zip` | as above, the faithful port |

The downloads contain everything needed to play, including the files of the original game
that the port reads its graphics, dialogs and music from.

**macOS.** Unzip and move `Kaiser Remastered.app` to *Applications*. The app is not notarized
by Apple, so the first start is refused: open *System Settings → Privacy & Security* and click
*Open Anyway* below the message about Kaiser (or, in Terminal:
`xattr -dr com.apple.quarantine "/Applications/Kaiser Remastered.app"`). Intel Macs are not
supported yet.

**Windows.** Unzip the whole folder and start `Kaiser Remastered.exe`; keep the `Kaiser` and
`docs` folders next to it. SmartScreen may warn about an unknown publisher: *More info → Run
anyway*. The Windows builds are cross-compiled on a Mac and have not been tested on a real
Windows machine yet; please [open an issue](https://github.com/LarsGehrmann/Kaiser-decompile/issues)
if something does not work.

**Playing.** *Datei → Neues Spiel* starts a game; *Hilfe* opens the original manual
(German), also reachable from the "?" button of every dialog. The rules are documented in
English in [docs/rules/](docs/rules/). Settings, high scores and the autosave are kept in
`~/Library/Application Support/Kaiser` (macOS) or `%APPDATA%\Kaiser` (Windows); savegames
(`*.ksr`) go wherever you save them and are compatible with the original game.

## Building from source

The repository does not contain the original game. To build and run the port, copy your
Kaiser 1.23 folder (with `kaiser.exe`, `kaiser.mid` and, for the tests, savegames) to
`Kaiser/` at the top of the repository; it is ignored by git.

Requirements on macOS (Apple Silicon):

```sh
brew install fpc                                  # Free Pascal 3.2.2
git clone --depth 1 --branch lazarus_3_6 https://gitlab.com/freepascal.org/lazarus/lazarus.git tools/lazarus
make -C tools/lazarus lazbuild
make -C tools/lazarus lcl LCL_PLATFORM=cocoa
```

Then:

```sh
port/build.sh                       # the command-line tools and test programs (port/bin/)
port/gui/build.sh                   # the game: port/bin/Kaiser.app
port/package-mac.sh Remastered 1.0  # the macOS download (port/bin/release/)
```

The Windows build is cross-compiled from macOS with a Free Pascal cross compiler and the LCL
built for win64 (setup in [docs/phase3.md](docs/phase3.md#the-windows-build-milestone-8)):
`port/build-win.sh`, then `port/package-win.sh Remastered 1.0`.

Tests (they need the original's savegames in `Kaiser/`):

```sh
port/bin/real48test port/tests/real48.vec        # the Real48 runtime vs. the original
port/bin/ruletest Kaiser port/tests/rules.vec     # the rules vs. the original
port/bin/ruletest Kaiser port/tests/turn.vec     # turn processing, AI, turn loop
```

All test sets and tools are described in [docs/phase3.md](docs/phase3.md#running).

## Repository layout

| Path | Contents |
|---|---|
| `port/src/` | the game logic, ported from the original (tested against it) |
| `port/gui/` | the user interface on the Lazarus LCL (Cocoa on macOS, win32 on Windows) |
| `port/tests/` | test programs and the recorded test vectors of the original |
| `tools/` | reverse-engineering scripts (Python 3), Ghidra scripts and symbol names, the x86 emulator harness that runs the original's code |
| `docs/` | findings: the rules (`rules/`), savegame format, data tables, the port's design (`phase3.md`), the converted manual (`manual.md`) |
| `Kaiser/` | the original game files and savegames (local only, not in git) |
| `extracted/`, `ghidra_out/` | resources and Ghidra exports generated from `kaiser.exe` (local only, not in git) |

## Reverse engineering

Kaiser is a 16-bit **Windows 3.x NE** program written in **Borland Pascal 7 with
ObjectWindows (OWL)**. The analysis uses Ghidra (headless with PyGhidra), the original's
resources and help file, savegame diffs and an x86 emulator (Unicorn) that calls the
original's functions directly.

Setup (macOS arm64):

```sh
brew install ghidra icoutils          # ghidra pulls in openjdk
tools/ghidra/build_natives.sh         # Homebrew's Ghidra lacks the arm64 decompiler; re-run after brew upgrade
python3 -m venv tools/.venv
tools/.venv/bin/pip install pillow construct unicorn
tools/.venv/bin/pip install --no-index -f /opt/homebrew/opt/ghidra/libexec/Ghidra/Features/PyGhidra/pypkg/dist pyghidra
# helpdeco: built from https://github.com/pmachapman/helpdeco into tools/bin/
```

Regenerating the extracted data from your `Kaiser/` folder:

```sh
mkdir -p extracted/help && (cd extracted/help && ../../tools/bin/helpdeco ../../Kaiser/KAISER.HLP)
python3 -I tools/help_to_md.py extracted/help/KAISER.rtf docs/manual.md
python3 -I tools/ne_info.py Kaiser/kaiser.exe > docs/ne-layout.md
tools/.venv/bin/python -I tools/ne_resources.py Kaiser/kaiser.exe extracted/res --png

tools/ghidra/import.sh                          # fresh import + auto-analysis
tools/.venv/bin/python -I tools/ghidra/fixup_analysis.py
python3 -I tools/owl_tables.py Kaiser/kaiser.exe docs/owl-tables.md tools/ghidra/names/25_handlers.csv
python3 -I tools/ghidra/derive_actions.py       # needs a previous export_all run
tools/.venv/bin/python -I tools/ghidra/apply_names.py
tools/.venv/bin/python -I tools/ghidra/apply_structs.py   # types from tools/kaiser_structs.py
tools/.venv/bin/python -I tools/ghidra/export_all.py      # ghidra_out/
python3 -I tools/field_index.py > docs/field-index.md

python3 -I tools/ksr.py --check Kaiser/*.KSR Kaiser/*.ksr
```

Always run Python with `-I`: the project folder `ghidra/` would otherwise shadow the `ghidra`
Java package inside PyGhidra. Reading code: `python3 -I tools/fn.py <address|name> --brief`
prints a decompiled function; `tools/.venv/bin/python -I tools/ghidra/disasm.py <address>`
prints annotated disassembly with decoded Real48 constants.

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
[docs/ksr-format.md](docs/ksr-format.md); data tables in [docs/data-tables.md](docs/data-tables.md).

## Status

- The whole game is ported: turn loop, economy, events, computer players, diplomacy, sabotage,
  all menu dialogs, the battle window, coronation, annals and records. Not ported: the e-mail
  game.
- Differential tests: about 45,000 test vectors run the original's functions in the emulator
  and the port on the same inputs, all identical; 334 whole AI battles and 34 games over 30
  turns identical; the game logic segments of the original run to 98–99 % in these tests
  ([docs/phase3.md](docs/phase3.md#how-much-of-the-original-the-tests-run)).
- Windows builds: not yet tested on Windows.

## License

The port's code, the tools and the documentation of this repository are released under the
[MIT License](LICENSE). This does not cover the original game: *Kaiser* and its graphics,
texts, music and manual are © Stefan Maday. The original game
files are not part of this repository. This is a non-commercial fan project to keep the game
playable on current systems; if you are the rights holder and object, please open an issue.
