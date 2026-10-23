# Diplomacy, treaties and sabotage

Status: message protocol, the handlers of both sides and the sabotage executor exact (ported
and verified bit for bit). The computer players' decisions (segment 2) are in ai.md. Open:
intelligence visibility.

## Per-player diplomacy fields (TPlayer)

| Offset | Field | |
|---|---|---|
| 0x671 | mailbox: 6 bytes per *sender* (`type`, sub-type, 2 words of data) | |
| 0x6ad | `trade_agreement[10]` – 1 = agreement with that player | income: finances.md |
| 0x6b7 | `peace_years[10]` – years left on a peace treaty | counts down each turn |
| 0x6c1 | `attitude_q[10]` – word per player, 100 at game start; only computer players use it (ai.md) | |

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

Computer players use the same mailbox (offers from `1008:0843`). **Aid is transferred
immediately** (Taler, land, units); only the message waits for the recipient's turn. Given
people are added to the recipient's immigrants when the message is read. A tribute demand
costs the demander 1 fame (not with Ambassador). Running totals: `total_aid` (0x9f),
`total_tribute` (0xa7).

### Slot layout and the human side (exact)

A slot is `kind` (byte), `sub` (byte), `data` (longint). The receiver answers by writing into
the **sender's** mailbox at its own index and clears its own slot. `DiplomacyTurnStart`
first counts down the peace treaties (`peace_years > 0`: at 1 the `PEACEENDDLG`, then − 1),
then handles the slots of all players in index order:

| Kind | Handler | Effect for the human |
|---|---|---|
| 1 | `Msg_ReceiveAid` 1010:0467 | sub 0 Taler, 1 land, 2 a unit (data = type), 3 settlers: `MSGSPENDENDLG`; only settlers change anything here (immigrants + data), the rest arrived with the sending. Other sub values leave the slot untouched |
| 2 | `Msg_TributeDemand` 1010:0ead | `MSGTRIBUTDLG`; *pay* answers 4, *refuse* 3 (with the same sub and data). Taler: taler and `total_tribute` − data, the demander + data; land: at least 2000 free land is kept (data is cut), `TransferLand`, buildings lost on the way show `VERLUSTDLG`; workers: at least 50 people are kept, emigrants + data; peace: data years (+ 1 if the demander moves earlier); trade agreement: nothing yet. Paying costs 5 fame. Then `KURIERDLG` |
| 3 / 4 | `Msg_TributeAnswer` 1010:17c6 | `MSGTRIBUTNODLG` / `MSGTRIBUTOKDLG`; paid workers arrive as immigrants, a paid trade agreement is set on both sides, paid peace years are set |
| 5 | `Msg_Negotiation` 1010:06f6 | `MSGTRADEDLG`: accept → answer 7, decline → 8; `KURIERDLG` |
| 6 | | `MSGTRADEENDDLG`: own agreement flag cleared |
| 7 / 8 | | `MSGTRADEOKDLG` (both flags, fame + 2, news 6) / `MSGTRADENODLG` (both flags cleared) |
| 9 | | `MSGPEACEDLG` with the years: accept → answer 10 with the years, fame + (years div 5 + 1), lifetime + Random(2), `peace_years` = years (+ 1 if the receiver moves after the sender); decline → 11 |
| 10 / 11 | | `MSGPEACEOKDLG` "until year …" (`peace_years`, news 5, fame + years div 5, lifetime + Random(2)) / `MSGPEACENODLG` |

A tribute demand with an unknown sub frees an uninitialised dialog pointer (crash in the
original); the senders never write one.

## Treaties

- **Trade agreement**: both sides get `TradeAgreementIncome` (finances.md) every year.
  Cancelling costs 2 fame. War between the two cancels it.
- **Peace treaty**: `peace_years[other] > 0`; decremented at every turn start; when it runs
  out the players are told (`PEACEENDDLG`). It cannot be cancelled. Declaring war despite a
  treaty costs the attacker **50 fame** and clears the treaty on both sides (`DeclareWar`).

## Sabotage – Do_Sabotage (1038:3564), SabotageAction (1068:36ef), SabotageEnd (1010:192f)

Sabotage is bought from the "Gilde der Randaleure" and needs at least one tavern. Per target
the player sets a yearly budget (`sabotage_budget`, × 100 Taler, at most (title + 1) × 500) and
has agents (`sabotage_agents`); the budget is paid every year (`total_sabotage` 0xab).

**Buying agents** (`SabotageFunding` 1068:3386, every year): returning agents
(`sabotage_agents_returning_q`) rejoin; with at least one tavern the budget is capped at
(title + 1) × 5, paid from the treasury and added to `sabotage_funds` (+0x5a1, word per
target). Each time the funds reach (target title + 1) × 1000 Taler (700 with the spell
Ambassador) one agent is bought and that amount is deducted (at most one per year).
`SabotageYearsToNextOp` (1068:35c1) shows max(1, round((cost − funds) / budget)) years until
the next agent. `SabotageYearlyCost` (1068:32b2) is the sum of all budgets × 100 (0 without a
tavern). All per-target arrays are indexed by the target's player index.

During the turn the player picks a **category** with "Zuschlagen!" and the concrete type is random:

| Category | Types |
|---|---|
| Zündeln und Kokeln | 2 (if the target has ≥ 2 palace parts), else 1 / 3 / 4 |
| Diffamieren | 7 / 8 / 9 |
| Kampfkraft zersetzen | 4 / 5 / 6 / 11 |
| Ruinieren | 13 (1 in 5), else 14 |
| Anschlag auf Leib und Leben | 10 / 11 / 12 |

Every strike uses up one agent against that target (agents are bought from the yearly
budget, see above). `SabotageAction(players, ?, saboteur, target, type, var amount, var caught)`
(exact, verified bit for bit by the port):

```
p = max(1, DS:42ba[type] - round(target.justice * 100))      % (16-bit)
success = precondition and Chance(p)         (Chance only rolled if the precondition holds)
caught  = Chance(p)                          (always rolled, independent)
```

| # | Base % | Precondition on the target | Effect on success (`amount` = reported value) |
|---|---|---|---|
| 1 | 50 | mills > 10 | mills − (mills div 10) × (1..3) (Karma: × 1..2) |
| 2 | 35 | palace parts > 1 | palace parts − min(parts, 1..5) (Karma: 1..3) |
| 3 | 60 | warehouses > 0 | `RemoveWarehouses(1)`: goods shrink in proportion |
| 4 | 40 | – | every unit without the ability Fortune (9) loses its experience |
| 5 | 35 | Heer not empty, not away, has a unit that can desert | a random such unit deserts (`deserted_units` + 1, amount = its type) |
| 6 | 25 | as 5 | as 5, and the unit joins the saboteur's Garde (becomes type 5 if that Garde has more than 8 units) |
| 7 | 40 | flag 0x40 not set | flag 0x40: happiness − 0.18 this turn |
| 8 | 60 | flag 0x80 not set | flag 0x80: happiness − 0.09 |
| 9 | 35 | title > 0, flag 0x100 not set | flag 0x100: happiness − 0.07; fame − (3..7) |
| 10 | 20 | flag 0x200 not set | flag 0x200: the victim **skips a turn** (see turn-loop.md) |
| 11 | 30 | a hero (Heer or Garde) with max HP > 5, flag 0x400 not set | one of: attack − 1 (if > 7) and max HP − 1; defence − 1 (if > 7) and max HP − 1; max steps − 1 (if > 2) and max HP − 1; max HP − 2. Then HP = max HP |
| 12 | 35 | flag 0x800 not set | flag 0x800: granaries poisoned (grain loss, death rate + 0.03..0.05) |
| 13 | 25 | flag 0x1000 not set, taler > 5000 | flag 0x1000; amount = taler div (5..10) (the loss itself is applied later through the flag) |
| 14 | 35 | flag 0x2000 not set, taler > 1000 | flag 0x2000; taler div (15..30) moves at once to the saboteur (`total_sabotage` +) |

The base chances are DS:42ba (`sabotage_chance`). A success is written to the target's
`sabotage_log` (+0x617, 15 entries of attacker, type, amount; count at +0x616). A caught agent
adds an entry with type 0 and goes to `sabotage_agents_returning_q`. On failure the agent either
escapes (`SABOTAGEVERSAGT1DLG`) or is caught (`…2DLG`). Flags 0x40–0x2000 live in the longint
at +0x5bd and are cleared in `PlayerTurnEnd`.

## Intelligence – Do_Geheimdienst (1038:0002)

Shows trade agreements, active saboteurs, treasury and army strength of the others; only the
Ambassador (spell 1) always sees everything (manual). Also opened automatically at turn start
with `report_flags` bit 3.
