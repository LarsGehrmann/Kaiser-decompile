# Computer players (AI)

Status: structure complete; decision heuristics summarised from segment 2 (`1008`) and its
helpers in segment 7 (`1030`). Thresholds are given where read; details of the helper
ratings (`1030:xxxx`) are still open.

## When the AI plays

Computer players (`cpu_level` ≠ 0) move inside `NextPlayer`, between the human turns
(turn-loop.md): `CpuTurn` = `Ai_Turn` (1008:0002) → `Ai_ChooseWarTarget` (1008:24eb) →
`Ai_EndTurn` (1008:29ea).

## The AI year – Ai_Turn (1008:0002)

The AI obeys the same rules as humans – it calls the same rule functions – but makes its
own decisions:

| Step | Function | What it does |
|---|---|---|
| ageing | – | `lifetime − 1`; < 1 → eliminated (news 16) like humans |
| first year | 1008:3088 | hero / army setup |
| events | `RollYearlyEvent` | same 23 events; bandits (17) fought by auto-battle `1030:0fe9` |
| simulation | 1008:01fd | harvest, goods, grain price, initiative, experience |
| sabotage | `SabotageEnd` | ends operations |
| diplomacy | `Ai_Diplomacy` 1008:0843 | offers peace / trade / tribute / cancellations via the mailbox |
| population | 1008:0ff7 | `UpdateBirthDeathRates`, `UpdateHappiness`, migration |
| budget | 1008:1131 | the same income items as humans |
| grain | 1008:13b9 | distribution policy (below) |
| land | 1008:1594 | buys/sells land depending on unclaimed land and prices |
| buildings | 1008:18ca | building policy (below) |
| military | 1008:2006 | recruiting, sabotage against others (`SabotageAction`) |
| end | – | sabotage flags cleared |

Computer players also get +0.15 happiness for free (population-grain.md) and may start
stronger in game mode 4 (land-market.md).

## Grain policy – 1008:13b9

```
r = rating(player)                    ; 1030:0002 (compares two record values)
r < 6:   distribute Random between minimum and needed
6..10:   distribute Random between needed and maximum
r > 10:  distribute the maximum
very large population: limited to "needed"
missing grain is bought at grain_price; surplus is sold with chance 1/(cpu_level + 1)
```

## Building policy – 1008:18ca (only with Taler > 0)

Same prices as humans (Ferengicharme 3/4). Palace part (title ≥ Fürst) and cathedral part
(König) whenever affordable, one per turn; a granary when the grain capacity falls below the
population's need; warehouses (goods trade); then markets and mills.

## War – Ai_ChooseWarTarget (1008:24eb)

For every other player b, the AI considers war only if it has initiative > 0, an army,
title ≥ Graf and no peace treaty with b. Weight: `w = 100` if b is human, otherwise
`(7 − ai_aggression) × 5` (field 0x1f, random 1–6 at game start; low = aggressive).
Reasons:

- b is hated (`attitude[b] < 10`) and beatable (strength comparison `1030:08ba`):
  chance `(7 − ai_aggression) × 3` %;
- b is König or higher (about to become Kaiser) and the AI judges it can win (`1030:04ab`):
  same chance;
- no unclaimed land is left and the AI is König but lacks land/Taler for the Kaiser title:
  attack for land.

Then `Chance(w)` and – if b is a trade partner – an extra 50 % roll. The chosen target is
attacked via `ResolveWar` (turn-loop.md); in e-mail games a human target receives the
battle as a hand-over.

## Fields

`cpu_level` 0x1e (0 human, 3–6 computer): also changes how often surplus grain is sold.
`ai_aggression_q` 0x1f: aggression trait, Random(6) + 1.
`attitude_q` 0x6c1: per-player word, 100 at start; < 10 makes war likely.
