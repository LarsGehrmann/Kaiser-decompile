# Diplomacy, treaties and sabotage

Status: message protocol, treaty fields and the sabotage executor from the code. The
computer players' decisions (segment 2) are in ai.md. Partly open: exact amounts in the
reply handlers, sabotage costs, intelligence visibility.

## Per-player diplomacy fields (TPlayer)

| Offset | Field | |
|---|---|---|
| 0x671 | mailbox: 6 bytes per *sender* (`type`, sub-type, 2 words of data) | |
| 0x6ad | `trade_agreement[10]` – 1 = agreement with that player | income: finances.md |
| 0x6b7 | `peace_years[10]` – years left on a peace treaty | counts down each turn |
| 0x6c1 | `attitude_q[10]` – word per player, 100 at game start | |

## Message protocol (mailbox)

A diplomatic action writes into the **recipient's** record at `0x671 + sender × 6`
and shows the courier dialog (`KURIERDLG`). The recipient's turn start
(`DiplomacyTurnStart` 1010:00e5) handles every non-empty slot:

| Type | Meaning | Sent by |
|---|---|---|
| 1 | aid (Entwicklungshilfe): Taler, land (neighbours only) or "Sklaven" (people) | `Do_Entwicklungshilfe` 1038:22d5 (`SPENDENDLG`, `ABFRAGE*DLG`) |
| 2 | tribute demand: Taler, land, people, or a treaty | `Do_TributFordern` 1038:2ca5 (`TRIBUTDLG`) |
| 3 / 4 | answer to a tribute demand (refused / paid) | 1010:0ead (humans), AI 1008:3abb |
| 5 | trade agreement offer | `Do_Abkommen` 1038:1e35 (`ABKOMMENDLG`) |
| 6 | trade agreement cancelled (sender loses 2 fame) | `Do_Abkommen` |
| 7 / 8 | answer to a trade agreement offer | 1010:06f6, AI 1008:34f4 |
| 9 | peace offer with a duration in years (`ABFRAGEZEITDLG`) | `Do_Abkommen` |
| 10 / 11 | answer to a peace offer | 1010:06f6, AI 1008:37a5 |

Computer players use the same mailbox (offers from `1008:0843`). Aid arrives at the start
of the recipient's next turn and cannot be refused (manual).

## Treaties

- **Trade agreement**: both sides get `TradeAgreementIncome` (finances.md) every year.
  Cancelling costs 2 fame. War between the two cancels it.
- **Peace treaty**: `peace_years[other] > 0`; decremented at every turn start; when it runs
  out the players are told (`PEACEENDDLG`). It cannot be cancelled. Declaring war despite a
  treaty costs the attacker **50 fame** and clears the treaty on both sides (`DeclareWar`).

## Sabotage – Do_Sabotage (1038:3564), SabotageAction (1068:36ef), SabotageEnd (1010:192f)

Sabotage is bought from the "Gilde der Randaleure" with a yearly budget per target country
(`SABOTAGEBUDGETDLG`: agents, years, budget); during the turn each operation is triggered
with "Zuschlagen!". `SabotageAction(type, target, saboteur)`:

```
success chance = max(1, DS:42ba[type] − round(<Real48 term, likely the target's justice> × k)) %
(a second roll with the same chance decides an extra outcome – probably whether the agent escapes)
```

| # | Base % | Condition on the target | Effect |
|---|---|---|---|
| 1 | 50 | ≥ 11 mills | a share of the mills burns (Karma: less) |
| 2 | 35 | ≥ 2 palace parts | 1–5 palace parts destroyed (Karma: 1–3) |
| 3 | 60 | warehouses > 0 | one warehouse (and its goods) burns |
| 4 | 40 | – | all non-hero units lose their experience |
| 5 | 35 | Heer at home | a unit deserts |
| 6 | 25 | Heer at home | a unit defects into the saboteur's Garde |
| 7 | 40 | – | flag 0x40: happiness − 0.18 this turn |
| 8 | 60 | – | flag 0x80: happiness − 0.09 |
| 9 | 35 | title > 0 | flag 0x100: happiness − 0.07, fame − (3…7) (rumours) |
| 10 | 20 | – | flag 0x200 (effect not yet found) |
| 11 | 30 | hero with HP > 5 | the hero is wounded (attack, defence, steps or HP reduced) |
| 12 | 35 | – | flag 0x800: granaries poisoned (grain loss, death rate + 0.03…0.05) |
| 13 | 25 | taler > 5000 | flag 0x1000, Taler stolen |
| 14 | 35 | – | flag 0x2000 (effect not yet found) |

`flags_5bd` (0x5bd) holds these effects for one turn and is cleared in `PlayerTurnEnd`.
Prices: higher for higher-titled victims, lower with Ambassador (manual); the formula is open.

## Intelligence – Do_Geheimdienst (1038:0002)

Shows trade agreements, active saboteurs, treasury and army strength of the others; only the
Ambassador (spell 1) always sees everything (manual). Also opened automatically at turn start
with `report_flags` bit 3.
