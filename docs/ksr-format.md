# Savegame format (`*.KSR`)

Status: container layout and checksums **confirmed**; ~100 player fields are now defined in `tools/kaiser_structs.py` (see `docs/rules/` for their meaning) (all 30 saves in `Kaiser/` pass
`python3 -I tools/ksr.py --check Kaiser/*.KSR Kaiser/*.ksr`). Most field meanings are still open.

## Where it comes from

| Routine | Address | Notes |
|---|---|---|
| Save game | `1050:058b` | called from the "Speichern unter" handler `1000:1427` (GetSaveFileName) |
| Load game | `1050:07ed` | called from the "Öffnen" handler `1000:0e3c` (GetOpenFileName) |
| Error box | `1050:12f8` | error code 1 = open failed, 2 = write failed, 3 = bad magic, 5 = short read / checksum mismatch |

Both routines use Pascal untyped files (`Assign`/`Rewrite`/`Reset` + `BlockWrite`/`BlockRead`,
with an `IOResult` check after each call). The file is a raw dump of in-memory records:

- **Header**: the global game record at `DS:6108`, size `0x295` (661) bytes.
- **Players**: an array inside the main window object at `Self+0x41`, record size `0x6d5` (1749) bytes.
  The game code indexes it as `Self + 0x41 + i*0x6d5` everywhere.
- **Extra block**: `0x192` (402) bytes at main window `Self+0x4493`, written only when
  `header[0x0b] != 0 && header[0x0a] == 3`. None of the existing saves contain it.

```
offset 0                 header (661 bytes)
offset 661 + i*1749      player i, for i = 0 .. header[1]-1
[optional]               extra block (402 bytes)
```

So file size = 661 + N × 1749 (+ 402), N = 2..10.

## Header (`DS:6108`, 0x295 bytes)

| Off | Type | Name | Evidence |
|---|---|---|---|
| 0x00 | byte | magic = `0x7B` (`'{'`, = 123 = v1.23) | written before saving; load rejects anything else (error 3) |
| 0x01 | byte | number of players | load loop runs `0 .. header[1]-1` |
| 0x02 | byte | number of human players | 2 in NILSLARS, 1 in solo saves; decremented when a human is eliminated |
| 0x03 | byte | current player | every menu handler indexes the player array with it |
| 0x05 | byte | last eliminated player? | set on elimination in `CmBeenden` |
| 0x07 | integer | year − 1400 | `CmBeenden` uses `year + 0x578`; saves hold e.g. 45 = 1445 |
| 0x0a | byte | game state | 1 = running (all menu handlers check it); 3 and 5 also used |
| 0x0b | byte | flag (e-mail game?) | when set: extra block, and `RandSeed` restored from 0x0e on load |
| 0x0e | longint | random seed | set to `Random($FFFF)` on save |

Unknown: 0x04, 0x06, 0x08–0x09, 0x0c–0x0d, 0x12–0x294. Field definitions are maintained in
`tools/kaiser_structs.py`; `docs/field-index.md` lists the functions touching each header byte. The bytes from 0x15 hold the zero-terminated
string "Reisiger Rächer" in every save (a unit or hero name default?).

## Player record (0x6d5 bytes)

| Off | Type | Name | Evidence |
|---|---|---|---|
| 0x000 | char[≈32], zero-padded | player name | "Nils", "Lars", CP names like `*Ludwig*` (INI keys `*Otto*` …) |
| 0x019 | byte | title rank? | `== 10` triggers the victory routine |
| 0x022 | integer | v22 (population?) | `< 1` eliminates the player; also the input of all three checksums |
| 0x026 | longint | check A = salt + (v54 − vCB) | recomputed on load |
| 0x054 | longint | **v54**, probably Taler | can be negative (debt) |
| 0x0c7 | longint | check C = (v54 + vCB) div 1000 | divisor `0x3e8` in the disassembly at `1050:074a` |
| 0x0cb | longint | **vCB**, probably Land (ha) | ~100000 for new players |
| 0x133 | longint | check B = salt + (vCB − v54) | recomputed on load |
| 0x139 | char[] | second name, e.g. "Castor" | names from the string table (ids 101–320) |
| 0x137 / 0x138 | bytes | unit counts of Heer / Garde | |
| 0x139 / 0x35e | 8 × TUnit (0x3d) each | Heer (army1) / Garde (army2) | layout in `tools/kaiser_structs.py` (UNIT) |

The checksums are anti-cheat: editing Taler or Land in a hex editor without fixing
checks A, B and C makes the game reject the save (error 5). `tools/ksr.py` verifies them.
Six-byte groups such as `7d c3 f5 28 5c 0f` are Borland **Real48** values (`ksr.real48()` decodes them).

## Next steps

- Find all readers/writers of the player fields in the game code (each field is accessed as
  `[Self + 0x41 + i*0x6d5 + off]`) and name them from the dialog they feed (e.g. the
  demographics dialog `BEVDLG`, the finance dialog).
- Define `TPlayer` (0x6d5) and `TGameHeader` (0x295) as Ghidra structs and apply them.
- Controlled save diffs once the game runs in DOSBox-X (change one value, save, compare).
