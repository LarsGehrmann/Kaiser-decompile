# Buildings

Status: from the building dialog code (`INVESTDLG`, type DS:2986) and the rule functions.

## Types

| Building | Field | Price | Effect |
|---|---|---|---|
| Marktplatz | `markets` 0xd7 | 1000 | income 77 + Random(155) per year, × happiness (× 1.25 Bienenfleiß) |
| Kornmühle | `mills` 0xdb | 2000 | income 165 + Random(330), × happiness; stores 500 grain |
| Palastteil | `palace_parts` 0xdf | 5000 | 12 parts = palace (needed for König, see titles); completing: fame + 10 |
| Kathedralenteil | `cathedral_parts` 0xe1 | 9000 | only for König (title 9); 12 parts needed for Kaiser; completing: fame + 20 |
| Kornspeicher | `granaries` 0xe3 | 2500 | stores 10000 grain |
| Lagerhalle | `warehouses` 0xe7 | 4000 | 1000 units of goods; only with goods trade; max 30 |
| Universitätsteil | `university_parts` 0xeb | 4000 | **no effect found in v1.23** (only drawn on the map, lost in disasters) |
| Wirtshaus | `taverns` 0xed | 2000 | income 100 + Random(200), × happiness; happiness + 0.00025 each; sabotage budget (diplomacy) |
| Schmiede | `smithies` 0xf1 | 2500 | weapons + min(smithies, min(pop div 2000, land div 20000) + 1) per year |

Prices: table `BuildingPrices` (DS:5b10). Grain storage: `GrainCapacity = mills × 500 + granaries × 10000 + 1000`.

## Building – INVESTDLG (Do_Gebaeude 1040:6cff, update 1040:704f)

- Price per building = list price, **× 3/4 with Ferengicharme** (spell 6).
- One building of each type per 1000 ha of farmland:
  `(land − land_used) − count × 1000 ≥ 1000` to build another.
- Palace, cathedral and university: at most one part per turn
  (flags `palace_built_this_turn` 0xe0, `cathedral_built_this_turn` 0xe2,
  `university_built_this_turn` 0xec, cleared in PlayerTurnStart), at most 12 parts.
- Cathedral parts only with title 9 (König).
- Warehouses only with `goods_trade_enabled`, at most 30.
- Cost: `taler −= price`, also booked to `building_balance` (0x93, which also receives the
  yearly building income).

## Selling ("Verkauf" button)

Selling returns **1/4 of the list price** per building. Losing a part of a *finished*
palace / cathedral (12 parts) costs fame 10 / 20 – also when parts are destroyed by
catastrophes, battles or bankruptcy.

## Losing buildings

- Selling land: `BuildingsLostForLand` (1068:22c0) removes what no longer fits (`VERLUSTDLG`).
- Events 4, 10, 18, 20 (fires, catastrophe), plunder after battles, bankruptcy
  (`Bankruptcy` sells at list price until the debt is covered).
