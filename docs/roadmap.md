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
| 2 | Grain, population, happiness, events | `PlayerTurnStart`, `UpdateBirthDeathRates`, `UpdateHappiness`, `RollYearlyEvent` — `docs/rules/population-grain.md`, `events.md` | ✅ formulas, validated on saves |
| 3 | Land, market, goods | `UpdateMarketPrices`, `ProduceGoods`, `Prokurist`, `InitPlayers` — `docs/rules/land-market.md` | ✅ formulas, prices validated |
| 4 | Buildings | `Do_Gebaeude`, `InvestDlg_Update` — `docs/rules/buildings.md` | ✅ (university has no effect) |
| 5 | Taxes & finances | `TaxIncome`, `JusticeIncome`, `TradeAgreementIncome`, `ArmyPay`, `Interest`, `MaximizeTaxes` — `docs/rules/finances.md` | ✅ validated |
| 6 | Titles, promotion, revolution | `CanBePromoted`, `PromotionCheck`, `RevolutionCheck` — `docs/rules/titles.md` | ✅ requirement tables |
| 7 | Military & battles | unit tables, recruitment, war — `docs/rules/military.md`; tactical battle → `battle.md` (in progress) | ✅ / battle in progress |
| 8 | Diplomacy & sabotage | mailbox protocol, treaties, `SabotageAction` — `docs/rules/diplomacy.md` | ✅ protocol + sabotage effects; costs open |
| 9 | Computer players (AI) | `Ai_Turn` and policies — `docs/rules/ai.md` | ✅ structure + main heuristics |
| 10 | Hidden commands | cm 612, 801 (`b` key), 802 (Ctrl+P), 803 (Ctrl+L) and `Debug=an` | |

## Phase 3 – reimplementation (later)

Language decision, then a port validated by loading the same savegame in both versions and
comparing the next turn.
