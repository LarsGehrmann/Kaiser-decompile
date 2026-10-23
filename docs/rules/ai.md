# Computer players (AI)

Status: exact. Segments 2 (`1008`, the AI year) and 7 (`1030`, its helpers) are ported to
`port/src/ai.pas` and verified bit for bit against the original (differential tests, see
phase3.md). Numbers below are from the code; "chance" means `Chance(n)` = Random(100) < n.

## When the AI plays

Computer players (`cpu_level` 1–6) move inside `NextPlayer` (turn-loop.md), between the human
turns: `CpuTurn` = `Ai_Turn` → `Ai_ChooseWarTarget` → (war with a human: `ResolveWar`) →
`Ai_EndTurn`.

## The AI year – Ai_Turn (1008:0002)

```
lifetime − 1
skip_turn set → nothing else (NextPlayer clears the flag)
year 0:  Ai_FirstYear, Ai_Diplomacy
else:    RollYearlyEvent, Ai_YearlySimulation, SabotageEnd, Ai_SetSabotageBudgets, Ai_Diplomacy,
         event 17 (raiders): Ai_BanditBattle → won: RaiderVictoryReward(1), lost: news 7
         Ai_PopulationModel, Ai_Budget
always:  Ai_GrainPolicy, Ai_LandPolicy, Ai_BuildingPolicy
year > 0: Ai_MilitaryPolicy
lifetime ≤ 0 (no immortality) → news 16, a new ruler (InitComputerRuler)
sabotage flags (+0x5bd) cleared
```

The AI obeys the same rules functions as humans but has its own simulation:

| Step | AI (segment 2) | Human (PlayerTurnStart) |
|---|---|---|
| taxes | tax 10 %, justice 8 % set every year | the player's sliders |
| grain loss | grain / (10 + 90·random) | 5–15 % |
| poisoned granaries | flag **0x1000** halves the grain (a bug: 0x1000 is "Ruinieren"; poisoning is 0x800) | flag 0x800 |
| grain cap | applied *before* the harvest is added | after |
| budget | no army pay, no warehouse rent; a positive net income × `DS:0500[cpu_level]` (1.5, 1.3, 1.1, 0.8, 0.7, 0.6); a negative one is ignored | everything |
| running totals | not kept | kept |
| goods | `Ai_SellGoods`: all salt (price ≥ 10), beer (≥ 45), wine (≥ 100) sold | Prokurist |
| experience | every unit + 1 (heroes too) | heroes + 1, others + 1 (Feldmarschall + 2) |
| happiness bonus | + 0.15 (population-grain.md) | – |

`Ai_YearlySimulation` (1008:01fd) also: initiative update, harvest (Gaias Segen 3–5),
`UpdateMarketPrices`, `army_away` cleared when initiative ≥ 0, fame + 1 with chance 30 % if the
Heer has ability 21, and the attitudes:

```
for each news item "war won/lost" (8, 9) whose actor has a peace treaty with us: attitude[victim] := 0
for every player i (also the AI itself):
    peace_years[i] > 0: − 1, attitude[i] + 3
    trade agreement:    attitude[i] + 2
    attitude[i] − Random(10 − aggression)
```

Attitudes change with `GainFame`/`LoseFame` (capped like fame).

## First year – Ai_FirstYear (1008:3088)

A random spell 1–12; a hero; from Fürst (7) on the hero gains 33–52 experience and the Heer
gets two units of type 6, one of 2–4, one each of 5, 3, 4 (all + 22 experience); with
Heldentum (9) all units + 10. A dowry (Random 1–8): 1 land + 1200 and a unit of type 1;
2 a mill and 5000 grain; 3 two markets and a unit of type 3; 4 land + 1000, grain + 3000;
5 grain + 1000 and two units of type 2; 6 land + 1500, Taler + 2000; 7 two mills,
Taler + 1000; 8 Taler + 3000 and a unit of type 1.

## Population – Ai_PopulationModel (1008:0ff7)

As for humans: births/deaths from the rates, immigrants/emigrants added, population at least 50.

## Grain – Ai_GrainPolicy (1008:13b9)

```
(low, need, high) = GrainNeedMinMax
r = Ai_FarmlandPerCapita = round(clamp((land − land_used) / population, 0, 100))
r ≤ 5:  distribute low + Random(need − low)
r ≤ 10: distribute need + Random(high − need)
else:   distribute high
population > cpu_level × 500 + 10000: distribute need
missing grain bought at grain_price per 144; then, with chance 1/(cpu_level + 1),
half of the surplus is sold at the same price
```

## Land – Ai_LandPolicy (1008:1594)

The AI values land with `Ai_LandPriceMargin` (1030:00c7):

```
u = unclaimed land / num_players / 100000
v = clamp(round(1 / (u⁴ + 0.01)) + 15 − FreeBuildingLand div 2000, 17, 60)
margin = byte(v + 15 − land_price)
```

| margin | action |
|---|---|
| 0–5 (price high) | sell down to 12–17 Hufen per head: min(land − (12 + Random 6) × population, Ai_SurplusLand) |
| 6–9 | with chance 1/(r div 3) buy affordable ÷ (1..4) |
| 10–15 (cheap) | buy affordable ÷ cpu_level |

"affordable" = min(taler div (land_price div 10), unclaimed land) when the treasury is
positive. `Ai_SurplusLand` (1030:01de) = free land beyond 1000 per market, mill, palace or
cathedral part (of the largest count, at least 2).

## Buildings – Ai_BuildingPolicy (1008:18ca), only with Taler > 0

Prices as for humans (`DS:5b10`, Ferengicharme 3/4). In this order:

1. a palace part from Fürst (7) on, one per turn (news 14 when complete);
2. a cathedral part as König (9), one per turn (news 15);
3. a granary while the storage is below 6 per head and Taler > 3 granary prices;
4. (goods trade) a warehouse per 3000 people while Taler > 2 × the full warehouse price;
5. the first tavern is free from Ritter (2) on; then one per 1000 free land while Taler > 2
   tavern prices;
6. a smithy while `SmithyOutput` exceeds the smithies and Taler > its price (pays half);
7. stop if Taler < 0; as many mills as markets: buy the missing kind;
8. stop if Taler < 0 or more than 100 markets or mills; then k = n/2 + Random(n/2) + 1 pairs of
   market and mill, n = min(Taler div pair price, Ai_SurplusLand div 1000).

## Military – Ai_MilitaryPolicy (1008:2006), from the second year

1. `OfferUnitsAtTurnStart` (the offers of the human turn start; the AI always takes them into
   the Heer), a ninth Heer unit moves to the Garde (`Ai_DropWeakestHeerUnit`), knights
   (type 34) get a squire with chance 5 % (spell 3: 50 %), all units are sorted by value
   (`Ai_ArrangeArmies`: attack + defence + range, +10 for ability 10; best eight in the Heer,
   mode 2 then swaps Heer and Garde).
2. **Recruiting** while `ArmyStrength` < s + s div (2 × aggression), s = `PromotionArmyStrength`
   of the next title: the highest affordable type ≤ title that `Ai_CanRecruitType` allows
   (from Fürst on only types with default ability 10 until there are two of type 6; at most
   `DS:0e60[type]` of a type; weapons in stock), until the strength reaches s or the Heer has
   nine units. A hero (type 9) costs nothing.
3. **Fiefs** (not with Heldentum): every Garde unit with the knight bonus (`DS:4f40`), type ≥ 8,
   rank Haudegen and pay > 0, with chance 50 %, if surplus land > 3000 and land_used + 3000 <
   land / 20: land_used + 3000, pay 0, + 24 experience.
4. **Sabotage** (with a tavern): against every other player, with chance 20 div (aggression + 1)
   %, if agents are there and the target is much richer (`Ai_IsMuchRicher`): a random action
   1–14 (`SabotageAction`, diplomacy.md). The budgets are set by `Ai_SetSabotageBudgets`
   (1030:060f): (6 − aggression) × (title + 1) / 2 for every player with attitude < 50.

`Ai_IsMuchRicher(a, b)` (1030:04ab): wealth = Taler + 5 per Hufe beyond the Kaiser's land
requirement; true when b has more than 1.5 × the wealth of a.

## Diplomacy – Ai_Diplomacy (1008:0843)

First the messages in the AI's mailbox (1: `Ai_ReceiveAid`, 2–4: `Ai_AnswerTribute`,
5–8: `Ai_AnswerTrade`, 9–11: `Ai_AnswerPeace`), then at most one proposal per other player
whose mailbox slot from us is empty:

| Proposal | Condition |
|---|---|
| trade agreement (5) | no agreement, attitude > 30, chance attitude − 30, the other's title < 6, and (spell Ambassador or the other earns more from buildings) |
| cancel trade (6, data 5–25) | agreement, the other's title > 6, and (earns less: chance 10 %, or attitude < 30: chance 50 − attitude) |
| peace (9, 5–25 years) | no treaty, the other's title < 9 and earns less, chance aggression × 5, and (`Ai_StrengthRatio` < 0.8 or attitude > 80) |
| tribute (2) | no treaty, chance (7 − aggression) × 5, strength ratio > 2: Random 3 → land (sub 1, 100 + Random(min(their free land − 12000, 30000) − 100), only if the way costs ≤ 2 initiative), workers (sub 3, 1 + Random(min(population − 50, 1000))), Taler (sub 0, their Taler / (2..6), or Random(10000) if they are in debt); costs 1 fame (not with Ambassador) |

`Ai_StrengthRatio(a, b)` (1030:08ba) = ArmyStrength(a) / (attack + defence of b's units;
b's Heer only when at home), 10 if b has none.

Answers:

- **Aid** (`Ai_ReceiveAid` 1008:33ad): attitude + Taler/1000, land/500, 5 for a unit,
  settlers/100 (settlers also become immigrants).
- **Trade** (`Ai_AnswerTrade` 1008:34f4): an offer is accepted if attitude ≥ 30 and chance
  attitude − 20, else if the offerer earns more from buildings and chance 50 %. Accepted:
  attitude + 10, fame + 1, news 6 (with a human). Cancelled by the other: attitude − 20;
  declined: attitude − 10.
- **Peace** (`Ai_AnswerPeace` 1008:37a5): accepted if the offerer is below König and
  (strength ratio < 0.75 and chance 80 − years, or attitude > 50 and chance attitude − years);
  then fame + 1, lifetime + 1. The answer "accepted": attitude + 30, fame + years/5,
  lifetime + Random(2), news 5 (with a human); "declined": attitude − 20.
- **Tribute** (`Ai_AnswerTribute` 1008:3abb): attitude − 20. Only a much weaker AI
  (strength ratio < 0.7) considers paying, and only with chance 50 %:
  Taler (if Taler > 0) / land (12000 free land kept) / workers (50 kept) with chance
  100 × (1 − demand / stock) %; a trade agreement 70 % (30 % if the demander has the spell
  Ambassador); peace years 60 − years %. Taler are taken from the **event money** (they still
  reach the demander). Paying costs 5 fame. Our own demand paid: attitude + 20 (workers become
  immigrants, treaties are set, news 6/5); refused: attitude − 40.

## War – Ai_ChooseWarTarget (1008:24eb)

For every other player b, while the AI has initiative > 0, an army, title ≥ Graf (2) and no
peace treaty with b (r = `Ai_StrengthRatio`):

1. b is a human of title ≥ König, r > 0.75, much richer, and chance (7 − aggression) × 3 %; or
2. attitude[b] < 10, r > 2, and chance (7 − aggression) × 3 %; or
3. no unclaimed land left, the AI is König, lacks the Kaiser's land but has his population and
   half his Taler, and r > 0.85.

Then chance w (100 for a human b, else (7 − aggression) × 5) and – with a trade agreement –
another 50 %. A **computer** b is fought at once with `Ai_AutoBattle` (1030:1062):

```
rating = (attack + defence + 2 × rank of the Heer [+ defender: (population/4000 + 1) × (8 − units) × 2])
         × artillery (1, 1.05, 1.15) × 1.25 (defender) × 1.2 (type 10 present) × 1.15 (type 21)
the higher rating wins; every Heer unit dies with chance 1 / (bonus + (attack + defence)/10 + rank)
(heroes count 10; bonus 3 for the winner, 2 for the loser); the Avenger (header +0x15) gains 2–4 experience
```

The winner's Heer gains 8 experience, news 8 (won) or 9 (lost), and the attack costs
initiative (`AttackInitiativeCost`; below 0 the Heer stays away). The first **human** b found
is returned and fought in a real battle (`ResolveWar`, turn-loop.md).

Raiders (event 17) are fought by `Ai_BanditBattle` (1030:0fe9): won if Random(rating) >
Random(ArmyStrength); losses as above (bonus 3/2); initiative − 1.

## End of the AI turn – Ai_EndTurn (1008:29ea)

```
manoeuvre (Ai_HoldManoeuvre): if title ≥ aggression and the Heer is home: units + 1..5 experience, initiative − 1
UpdateBirthDeathRates, UpdateHappiness
promotion: title + 1, fame + 10, lifetime + 1; first König: news 13 and Ai_FirstKingReward
else: from Herzog (8) on lower taxes and justice by 0.01 until happy enough for the next title;
      as König sell the land needed for the Kaiser's Taler (Ai_LandToSellForPromotion);
      promotion check again (no lifetime bonus)
buildings without land: a fifth of their price back, fame − 2
Taler < 0: fame − 1, Taler := 0; happiness < 0.5: fame − 1
Ai_RevolutionRoll (happiness < 0.25): 1 unrest (fame − 10, lifetime − 1, news 12),
    2 revolution (title − 1, fame − 50, lifetime − 1, skips the next turn)
sabotage flag 0x80 also makes it skip a turn (the human check uses 0x200)
skip: SkipTurnLosses (mode 0 with flag 0x80, else 1), news 11
```

`Ai_FirstKingReward` (1008:2e1a): without a hero a new one (+ 10, 12, 14 experience); else
Random 3: the first hero + 1 attack, defence and max HP; all Heer pay halved; or a unit of
type `DS:052a[k]` (18, 34, 26, 28, 29) with rank bonus `DS:0530[k]` and no pay.

## Fields

`cpu_level` 0x1e (0 human, 1–6 computer): income factor and grain selling chance.
`ai_aggression_q` 0x1f: Random(6) + 1 at game start; low = aggressive.
`attitude_q` 0x6c1: per-player word, 100 at start.

All functions of the AI segments are listed in `docs/functions/rules-ai.md`.
