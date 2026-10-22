# Hidden commands and debug features

Commands without a menu entry (from the main window's handler table, `docs/owl-tables.md`,
and the accelerator table `MENUKEYS`):

| Command | Key | Function | What it does |
|---|---|---|---|
| 801 | `b` | `CmBossKey` 1000:3944 | **Boss key**: saves the running game to `boss.ksr` and closes Kaiser immediately |
| 802 | Ctrl+P | `CensusEditor` 1038:4d68 | Password dialog, then the **Census Editor** (see below) |
| 803 | Ctrl+L | `CmLoadLastGame` 1000:1292 | Loads the last savegame named in `KAISER.INI` (`Letzter Pfad`) and resumes the turn |
| 612 | – | `CmResolution1024` 1000:1fc8 | Third, hidden window size: **1024×768** (resolution table DS:4536/453c: 640/800/1024 × 480/600/768) |

## Debug mode and the Census Editor

- `KAISER.INI`, section `[Kaiser]`, key **`Debug=an`** sets the global DS:63a1. When a
  new game starts it is copied into the savegame header (`census_editor_enabled`, byte 0x04).
- **Census Editor** (Ctrl+P): asks for a password (`PASSWORDDLG`). The password is the
  **name of the player's own hero** (looked up with `FindHero` 1068:6323). If it matches and
  the game has `census_editor_enabled`, `CENSUSDLG` lets you edit the records of all ten
  players.
- **Cheat start**: in such a game, a human player named `Alchimisten` or `Berserker` starts
  as König with 999,000 Taler (`InitPlayers`).
- High scores and records are not saved for games with `census_editor_enabled`.

The savegames in `Kaiser/` were created with `Debug=an` (header byte 0x04 = 1).

## Other INI keys (KAISER.INI)

`Letzter Pfad`, `Letzte Datei` (Ctrl+L), `Geschichtsschreibung` (autosave),
`Krach & Geschrei` (sound effects), `Schalmeienklänge` (music), `Auflösung`,
`Hintergrund rot/grün/blau` (background colour), `Delta X`, `Delta Y` (window offset),
`Schlacht-Timer` (battle speed), the ten country names and adjectives, `Spieler0..9`
(last human names), `*Otto*` … `*Friedrich*` (computer player names), `Debug`.
