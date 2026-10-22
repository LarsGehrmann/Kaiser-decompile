# Rule library and AI – segments 2–7 and 14 (1008, 1010, 1018, 1020, 1028, 1030, 1068)

All 212 functions of segments 2–7 and 14. Names come from `tools/ghidra/names/*.csv` (later
files win). `*` marks a name new in `94_rules_ai.csv` (98 functions that were `FUN_`); `†` marks
an existing name that `94_rules_ai.csv` confirms or corrects (list below). Dialog types are named
after their resource; VMT slot +0x38 is `SetupWindow`, +0x3c `CanClose`. Evidence for every new
name is in the CSV comment.

Conventions: `R(n)` = Borland `Random(n)` (0..n-1). Results block = the 0x37-byte battle results
(+0 deported/civilians shown, +4 civilians killed, +8 markets, +0xc mills, +0x10 palace, +0x14
cathedral, +0x18 granaries, +0x1c warehouses, +0x20 university, +0x24 taverns, +0x28 smithies,
+0x2c land plundered, +0x30 Taler plundered, +0x34 plunder choice 10..13).

## Corrections and confirmations of existing names

| Address | Old | New | Evidence |
|---|---|---|---|
| 1068:1df2 | `GrainCost_q` | `CreditLimit` | returns (title+7)·1000; Bankruptcy fires at taler ≤ −CreditLimit; manual: debt limit depends on title |
| 1030:0002 | `Ai_GrainRating_q` | `Ai_FarmlandPerCapita` | Round(clamp((land − land_used)/population, 0, 100)) |
| 1030:08ba | `Ai_StrengthComparison_q` | `Ai_StrengthRatio` | ArmyStrength(1, self) / Σ(atk+def) of target's Heer (if at home) + Garde; 10.0 if target has none |
| 1028:0eaf | `PlunderDialog_q` | `PlunderDialog` | LOOTDLG/LOOT2DLG, codes 10..13, applies the results block |
| 1028:0d46 | `PlunderAuto_q` | `Ai_PlunderChoice` | random choice for a computer winner (see Findings) |
| 1068:56bc | `AvengerJoinsWeaker_q` | `AvengerJoinsWeaker` | thresholds now known (2/3, see Findings) |
| 1010:22d4 | `ArmyTurnStart_q` | `OfferUnitsAtTurnStart` | it is the SOELDNERDLG/HEALDLG/SCOUTDLG/PALADINDLG/VAMPIRDLG/BLACKDLG offer logic; no vampire multiplication there |
| 1010:288d | `YearSummary_q` | `HarvestReport` | shows dialog 100+harvest_quality (KORNERNTE 101..105) with the rotten-grain % |
| 1068:31c7 | `IsFirstKing_q` | `IsFirstKing` | true if no other player has title 9 or first_king_bonus |
| 1068:2850 | `ManoeuvreCost` | (same, comment updated) | exact formula, see Findings |
| 1028:138d..13c9 | `T0d60::IdCtl201..204` | `LootDlg::IdPlunder/IdBurn/IdMassacre/IdMercy` | EndDlg(10/11/12/13) |

Also note (not renamed): the label `PromotionTaler` at DS:581c is the base of a `[1..10]`
array, so `*(DS:581c)` itself is `PromotionLand[10]` = 100000. Code that the decompiler shows as
"land vs PromotionTaler" (1030:04ab, 1068:6cb4, Ai_ChooseWarTarget) compares land with 100000.

## Findings

### Plunder, burning, massacre (segment 6)

- **When:** after every won battle (codes 11/13, field *and* city; `param` = city flag) and also
  in `BattleSetup` when the defender chooses the city: the attacker then plunders the
  countryside first (LOOT2DLG "Die Verteidiger haben sich in ihrer Burg verschanzt …", field
  amounts), then fights the city battle. The manual only mentions plunder after the city battle.
  Two-human e-mail games use EmailGameStep instead.
- **Plündern** (`PlunderTalerAndLand` 1028:09c8 + `TransferLand` 1068:41d5): Taler =
  loser.taler·(5+R(20))% **only after a city battle** (0 after a field battle or if taler ≤ 0);
  land only if `AttackInitiativeCost ≤ 2` (neighbouring countries – always when the initiative
  option is off): land·(5+R(13))% (city) / (3+R(6))% (field); the loser keeps ≥ 12000 Hufen.
  The loser's land_used shrinks proportionally; buildings that no longer fit are lost and the
  winner receives (lost − 1) markets, mills, granaries, warehouses each (warehouses capped at 30).
- **Brandschatzen** (`BurnBuildings` 1028:057e), share of each stock destroyed:

  | | markets | mills | palace | cathedral | granaries | warehouses | university | taverns | smithies | civilians |
  |---|---|---|---|---|---|---|---|---|---|---|
  | city | 20–49 % | 10–29 % | 20–49 % | 20–49 % | 20–59 % | 20–49 % | 20–49 % | 10–29 % | 20–49 % | 1–5 % |
  | field | 10–19 % | 10–29 % | – | – | 10–29 % | 10–19 % | – | – | – | 1–3 % |

- **Massaker** (`Massacre` 1028:020a): killed = pop·(10+R(15))% (city) / (1+R(5))% (field),
  deported = pop·(5+R(5))% / (1+R(5))%; the loser keeps ≥ 50 people; deported people join the
  winner's population; winner −30 fame; title "Schlächter(in) von <country>" in MASSAKERDLG.
- **Gnade:** winner +2 fame.
- **Computer winner** (`Ai_PlunderChoice`): R(100) 0–50 plunder (51 %), 51–80 burn (30 %),
  81–89 mercy (9 %), 90 nothing (1 %), 91–99 massacre (9 %).
- **Quirks (from code, not verified in game):** (1) with a computer winner the burn results are
  only displayed (BRANDDLG) – the apply step (buildings −= results, RemoveGranaries/Warehouses)
  exists only in `PlunderDialog`, so a computer's Brandschatzen destroys nothing. (2) In
  `PlunderDialog` the population is reduced by results+4 again (`pop = max(pop − results+4, pop/2)`)
  although `Massacre` already subtracted it, and results+4 also holds the city-battle casualties
  that `GetResults` already subtracted – apparent double counting, capped at half the population.
- **Retreat** (`RetreatLosses` 1028:011c, human attacker code 12 and fleeing from raiders): each
  Heer unit is lost with probability 1/5, except the Held, units with Fortune (ability 9), and
  all units if the player has the spell **Karma** (not Fortune alone as battle.md guessed).
  Units removed during the loop shift down, so the next unit escapes the roll (bug). A computer
  attacker loses nothing extra.

### Computer-vs-computer wars are auto-resolved (contradicts battle.md §1)

battle.md says every battle opens the battle window. `Ai_ChooseWarTarget` only hands **human**
targets to `ResolveWar`; a computer target is fought by `Ai_AutoBattle` (1030:1062):
rating = (Σ atk+def + 2·Σ level of the Heer + [defender] 2·(8 − units)·(pop div 4000 + 1)) ×
1.0/1.05/1.15 (no/ranged/Sprengpulver artillery) × 1.25 (defender) × 1.2 (has a Vampire) ×
1.15 (has Knochenflicker). The attacker wins only if its rating is strictly higher. Each Heer unit
then dies if R(k + (atk+def) div 10 + level) = 0 (Held: 10 instead of the atk+def term), k = 3 for
the winner, 2 for the loser. The winner's units get +8 XP, news 8/9, initiative cost as usual –
no fame changes and no plunder. The Reisiger Rächer record gains R(3)+2 XP per such war.
Bandit events for computers (`Ai_BanditBattle`) use the same rating and loss rule.

### Unit creation and heroes (1068)

- `RecruitUnit` (5439): table stats; pay = FameDiscount(UnitPay) × (bonus+1), FameDiscount =
  value − value·fame/200; Schwarze Ritter pay ÷ 3 with Terror; **Kreuzritter get a random ability:
  Regeneration, Drachenschild or Fortune** (military.md lists none); Lindwurm starts at level 6;
  with **Heldentum every new unit gets +10 XP** (= Offizier, as the manual says).
- `InitUnit` (598d) is used for offers: a "+n" unit (name suffix "+n", stored in +0x1a) gets n
  level-ups of stat gains, then level and XP are reset to 0, and its pay is multiplied by n+1.
  `RecruitUnit`'s own bonus loop levels the wrong unit (last Heer unit) but every caller passes 0.
- `CreateHero` (5f0c): Held 7/7/7, 2 steps, range 1; portrait R(18)+1 fixes ability and tweaks:
  1 Glanz und Gloria; 2 Drachentöter (+2 att); 3 Vergiftete Klinge (−2 att); 4 Mithrilharnisch
  (+1 def); 5 Entertainer; 6 Güldene Brünne (+2 def); 7 Samuraischwert (−2 att); 8 Regeneration
  (−1 def, −2 HP); 9 Charme (+1 HP); 10 Fortune; 11 Drachenschild (+1 def); 12 Wurfaxt (+1 range,
  −1 att, +1 ammo); 13 Morgenstern (−1 def); 14 Heilkräfte (−1 att, −1 def, −2 HP, +2 ammo);
  15 Heilige Lanze (−1 def); 16 Finesse (−1 att); 17 Lehrmeister; 18 Duckmäuser. Name: given, or
  string resource 101 + R(220). (Census-enabled easter egg: hero name "guams dlo" → a Lindwurm.)
- Lindwurm slain (`RaiderVictoryReward` mode 2): +100000 Taler event money, fame +20 and **every
  Heer unit +3 defence** ("Bad im Blut der Bestie"); marauders: title·(1000+R(1500)) Taler.
- Year 0 (`MarriageDowry`): one of nine wedding gifts (dialogs 201–209 / 251–259), e.g. 1200 Hf +
  Wachen, mill + 5000 grain, 2 markets + Bogenschützen; dowry units have pay 0.
- Computer first King (`Ai_FirstKingReward`): hero with 3 level-ups if none, else R(3): hero
  +1 att/def/HP, Heer pay halved, or a mercenary (Schwarze Ritter, Knappen, Nordmänner,
  Berserker, Templer, bonus 0/1/2/0/1).

### Mercenary offers – `OfferUnitsAtTurnStart` (1010:22d4)

Spell offers are rolled first (title must reach UnitTitle of the type):

| Spell | Unit | Chance per turn |
|---|---|---|
| Chevalerie | Knappen | 1/(30 − fame/5) |
| Heilende Hände | Knochenflicker | 1/(30 − fame/5) (manual: 3 % / 10 % ✓) |
| Gaias Segen | Waldläufer | 1/(30 − fame/5) |
| Pietät | Paladine | 1/((Paladine+1)·15 − fame/10) (manual 7 % / 20 % ✓) |
| Terror | Vampire if none yet (certain); else Schwarze Ritter 1/(30 − fame/5) | |

Otherwise the general SOELDNERDLG offer: chance 1/(14 − fame/10) = 7 % at fame 0, 25 % at fame
100; with **Karma** 1/(12 − fame/10) = 8 % / 50 % (exactly the manual's Karma figures). Type =
R(22)+14 re-rolled until its title requirement ≤ own title. Bonus: R(10) 0–6 none, 7–8 "+1",
9 "+2". A human accepts into the Heer (if < 8 units and at home) else the Garde; the AI always
accepts into the Heer and trims later (`Ai_DropWeakestHeerUnit`).

### Manoeuvre cost – `ManoeuvreCost` (1068:2850)

`FameDiscount(Σ over Heer units: Held 2000; unit below max level (level+1)·500; unit at max level
(Haudegen, Elite with Heldentum) 0, fame)`. The computer's manoeuvre (`Ai_HoldManoeuvre`) is free:
if ai_aggression ≤ title, every Heer unit gets R(5)+1 XP for 1 IP.

### Reisiger Rächer – `AvengerJoinsWeaker` (1068:56bc)

Runs in `BattleSetup` for every battle (not only computer-vs-computer as battle.md says; skipped
only for e-mail field battles). He joins the attacker (Heer, if < 8 units) when the attacker's
`ComputeScore` **and** `ArmyStrength(1)` are both below 2/3 of the defender's; in the reverse case
the defender (Heer, or Garde if the Heer is full). Score = ArmyStrength(1)/50 + taler/100000 +
land/20000 + pop/2000 + title + fame/20 (the high-score formula). `AvengerLeaves` copies him back
to the header record (keeping XP); if he died he is re-created fresh (`InitAvenger`).

### Sabotage cost (1068:3386, 35c1, 32b2)

The yearly budget per target (`+0x598[j]`, units of 100 Taler, capped at (own title+1)·5) only
flows if the saboteur owns ≥ 1 tavern. Each year (`SabotageEnd`) budget·100 Taler are paid into
the savings `+0x5a1[j]`; every (target title + 1)·1000 Taler (700 with Ambassador) buy one
operation (`+0x586[j]`). Agents marked as returning (`+0x58f[j]`) are added back next year.
The sabotage dialog shows max(1, round((cost − savings)/(budget·100))) years until the next
operation. Victims get report records (+0x616 count, +0x617.., max 15) read in SabotageEnd. AI
budgets: (title+1)·(6 − ai_aggression) div 2 against every player with attitude < 50.

### Skipped year and revolution

`SkipTurnLosses` (1068:438c): land, Taler, population, markets and mills each lose
t·(1 + RandomReal) with t = 0.3 normally (30–60 %!) or 0.1 when the skip was caused by sabotage
(human: flag 0x200, which also costs 1 year of lifetime and sets skip_turn – the "effect not yet
found" of sabotage 10 in diplomacy.md); land ≥ 2000, population ≥ 50. For computer players
`Ai_EndTurn` tests flag **0x80** instead (sabotage 8 forces a skip and gives the mild rate, while
a sabotage-10 skip gets the 30–60 % rate) – probably a bug. AI revolution (`Ai_RevolutionRoll`):
happiness < 0.25 (humans 0.3); exile costs only 1 year of lifetime (humans 2).

### Other rules found

- `CreateComputerPlayers`: cpu_level by difficulty (header byte 9) 1 → 5–6, 2 → 3–4, 3 → 1–2,
  4 → 1; a successor ruler (`InitComputerRuler`, after resignation, game end or death) gets
  cpu_level 1–6, a new spell 1–12 and aggression 1–6. ai.md's "cpu_level 3–6" is too narrow.
- `Ai_IsMuchRicher` (1030:04ab) is a wealth test (taler + 5·(land − 100000)⁺ above 1.5× own),
  not a "can win" test as ai.md describes; the strength part is `Ai_StrengthRatio`.
- AI recruiting caps (DS:0e60): Kämpfer 8, Bogenschützen 8, Infanterie 2, Musketiere 4,
  Kavallerie 4, Artillerie 4, Ritter 12, Kreuzritter 12, Held 1; from title 6 the AI recruits
  only Artillerie until it has 2. AI knights Knappen with 5 % per turn (50 % Chevalerie).
- AI sells all salt/beer/wine when the price reaches 10/45/100 (`Ai_SellGoods`).
- `SortArmy` only sorts when both armies are non-empty, so `Ai_AutoBattleLosses` can leave
  cleared units in place when the Garde is empty (quirk).

## All functions

### Turn processing, reports and start-of-game dialogs (segment 3, 1010)

| Address | Name | Purpose |
|---|---|---|
| 1010:0002 | `ShowStartTurnDialog`  | Start of turn: STARTTURNDLG / STARTTURNFEMDLG |
| 1010:1bf0 | `Report_Gossip`  | Turn-start report, report_flags bit 0 (Klatsch und Tratsch) |
| 1010:22d4 | `OfferUnitsAtTurnStart` † | Mercenary / special unit offers (SOELDNERDLG etc.) |
| 1010:263f | `Report_Budget`  | Turn-start report, report_flags bit 2 (Staatshaushalt) |
| 1010:27c9 | `Report_Population`  | Turn-start report, report_flags bit 1 (Bevoelkerungsentwicklung) |
| 1010:288d | `HarvestReport` † | KORNERNTE dialog 100+harvest_quality |
| 1010:2924 | `MarriageDowry` * | Year 0: wedding dialog 200+n / 250+n and its dowry |
| 1010:2c50 | `GrantFirstHero`  | Game start: HELDDLG, the first hero |
| 1010:2ce5 | `RollYearlyEvent`  | event = Random(23)+1 (pop > 100000: 1/4 chance plague) |
| 1010:372a | `WitchChoosesSpell`  | Game start (year 0): HEXENDLG, the witch offers the spells |
| 1010:3777 | `RulerFallsIll`  | KRANKDLG when lifetime < 1 |
| 1010:37b6 | `PlayerTurnStart`  | Start-of-turn processing for the current player (4 KB, 66 calls) |
| 1010:47b1 | `GrainShortageWarning`  | End of turn: ZUWENIGKORNDLG if less grain than needed is distributed |
| 1010:4891 | `LandLossCheck`  | End of turn: BuildingsLostForLand |
| 1010:48fc | `PromotionCheck`  | End of turn: if CanBePromoted: lifetime+1, title+1, fame+10, promotion dialog |
| 1010:4f9f | `Bankruptcy`  | Sells buildings at the price table DS:5b10 until the debt is covered (dialog BANKPFANDDLG), fame -7 |
| 1010:55bb | `RevolutionCheck`  | End of turn: happiness < 0.3 -> uprising |
| 1010:5707 | `SkipTurnCheck`  | End of turn: AUSSETZDLG, sets skip_turn |
| 1010:57b2 | `PlayerTurnEnd`  | End-of-turn processing for the current player, called first in CmBeenden |
| 1010:58d3 | `PromotionDlg::Init` * | Constructor of BEFDLG / FEMBEFDLG |
| 1010:5949 | `PromotionDlg::SetupWindow` * | Year, player, new title in capitals |
| 1010:59ef | `StartFinanzDlg::Init` * | Constructor of STARTFINANZDLG |
| 1010:5a65 | `StartFinanzDlg::SetupWindow` * | Writes the ten budget lines |
| 1010:5c1a | `StartPopDlg::Init` * | Constructor of STARTPOPDLG |
| 1010:5c8e | `StartPopDlg::SetupWindow` * | Population report lines |
| 1010:5e43 | `HexenDlg::Init` * | Constructor of HEXENDLG (spell choice) |
| 1010:5e96 | `HexenDlg::SetupWindow` * | Fills the 13 spell names |
| 1010:5ef6 | `T0598::IdCtl101`  | DMT handler: id 101 (tools/owl_tables.py) |
| 1010:5f1a | `HexenDlg::CanClose` * | Stores the chosen spell |
| 1010:5f3e | `Seg3_UnitInit` * | Empty unit-initialisation stub |
| 1068:438c | `SkipTurnLosses` * | Losses of a year away (AUSSETZDLG) |

### Diplomacy messages

| Address | Name | Purpose |
|---|---|---|
| 1010:00e5 | `DiplomacyTurnStart`  | Turn start: peace_years countdown (PEACEENDDLG), then handles the mailbox player+0x671+sender*6, types 1..11 |
| 1010:0467 | `Msg_ReceiveAid`  | Mailbox type 1: aid arrives |
| 1010:06f6 | `Msg_Negotiation`  | Mailbox types 5..11: trade/peace offers and their answers (sends 7/8, 10/11) |
| 1010:0ead | `Msg_TributeDemand`  | Mailbox type 2: tribute demand |
| 1010:17c6 | `Msg_TributeAnswer`  | Mailbox type 3/4 (mode 0/1): answer to a tribute demand |
| 1068:68b0 | `ClearMailboxSlot` * | Zero a 6-byte mailbox slot |

### Sabotage

| Address | Name | Purpose |
|---|---|---|
| 1010:192f | `SabotageEnd`  | SABOTAGEENDEDLG: a sabotage operation ends |
| 1068:32b2 | `SabotageYearlyCost` * | Yearly sabotage spending |
| 1068:3386 | `SabotageFunding` * | Yearly sabotage funding and new operations |
| 1068:35c1 | `SabotageYearsToNextOp` * | Years until the next operation is paid for |
| 1068:36ef | `SabotageAction`  | Executes sabotage type 1..14 against a target: condition per type, sets target flags_5bd bits (0x40, 0x80, 0x100, 0x200, 0x400, 0x800 granary poiso... |
| 1068:696f | `LogSabotageReport` * | Queue a sabotage report for the victim |

### Computer players (segment 2 1008, segment 7 1030)

| Address | Name | Purpose |
|---|---|---|
| 1008:0002 | `Ai_Turn`  | The computer player's year: ageing, events, simulation, diplomacy, population, budget, grain, land, buildings, military (renamed from Ai_Economy) |
| 1008:01fd | `Ai_YearlySimulation`  | Harvest, goods, grain price, initiative, experience for a computer player |
| 1008:0843 | `Ai_Diplomacy`  | Computer player sends offers (types 2, 5, 6, 9) |
| 1008:0ff7 | `Ai_PopulationModel`  | Birth/death rates, happiness, migration |
| 1008:1131 | `Ai_Budget`  | Income items like PlayerTurnStart |
| 1008:13b9 | `Ai_GrainPolicy`  | Distribution band from rating 1030:0002 (<6 min..need, 6-10 need..max, >10 max) |
| 1008:1594 | `Ai_LandPolicy`  | Land trading |
| 1008:17a5 | `Ai_SellGoods` * | Sells salt (price >= 10), beer (>= 45), wine (>= 100) completely |
| 1008:18ca | `Ai_BuildingPolicy`  | Palace/cathedral parts, granaries, warehouses, markets, mills |
| 1008:2006 | `Ai_MilitaryPolicy`  | Recruiting and sabotage |
| 1008:24eb | `Ai_ChooseWarTarget`  | CpuTurn: returns true + target player index when the computer declares war |
| 1008:296c | `Ai_HoldManoeuvre` * | Free AI manoeuvre: Heer +Random(5)+1 XP each, initiative -1 |
| 1008:29ea | `Ai_EndTurn`  | Last step of CpuTurn |
| 1008:2e1a | `Ai_FirstKingReward` * | First-King bonus for a computer player |
| 1008:3088 | `Ai_FirstYear`  | Year 0 setup for a computer player |
| 1008:33ad | `Ai_ReceiveAid` * | Mailbox type 1 for a computer player: aid raises attitude |
| 1008:34f4 | `Ai_AnswerTrade`  | Computer answer to a trade offer (7/8) |
| 1008:37a5 | `Ai_AnswerPeace`  | Computer answer to a peace offer (10/11) |
| 1008:3abb | `Ai_AnswerTribute`  | Computer answer to a tribute demand (3/4) |
| 1008:42d6 | `Seg2_UnitInit` * | Empty unit-initialisation stub |
| 1030:0002 | `Ai_FarmlandPerCapita` † | (land - land_used) / pop, 0..100 |
| 1030:00c7 | `Ai_LandPriceMargin` * | Acceptable land price minus current price |
| 1030:01de | `Ai_SurplusLand` * | Farmland not needed for buildings |
| 1030:0301 | `Ai_LandToSellForPromotion` * | Land a Koenig sells to reach the Taler requirement |
| 1030:04ab | `Ai_IsMuchRicher` * | Wealth comparison (factor 1.5) |
| 1030:059b | `Ai_RevolutionRoll` * | AI uprising check (happiness < 0.25) |
| 1030:060f | `Ai_SetSabotageBudgets` * | Sabotage budgets against disliked players |
| 1030:06d9 | `Ai_CanRecruitType` * | May the AI recruit this standard type? |
| 1030:075a | `Ai_KnightSquires` * | Knights AI Knappen (5 %, 50 % Chevalerie) |
| 1030:0844 | `Ai_DropWeakestHeerUnit` * | Last Heer unit to the Garde, or dismissed |
| 1030:08ba | `Ai_StrengthRatio` † | Own ArmyStrength / target's available strength |
| 1030:09f2 | `Ai_AutoBattleRating` * | Army rating for auto-resolved battles |
| 1030:0bda | `Ai_AutoBattleLosses` * | Unit losses after an auto battle |
| 1030:0cc0 | `Ai_UnitValue` * | attack+defence+range (+10 Sprengpulver) |
| 1030:0d02 | `Ai_ArrangeArmies` * | Best 8 units to the Heer (or the Garde for a city battle) |
| 1030:0fe9 | `Ai_BanditBattle`  | Auto-resolved battle against bandits (event 17) |
| 1030:1062 | `Ai_AutoBattle` * | Computer-vs-computer war without battle window |
| 1030:1116 | `Seg7_UnitInit` * | Empty unit-initialisation stub |

### Battle entry points and battle helpers (segment 4 1018, parts of 1068)

| Address | Name | Purpose |
|---|---|---|
| 1018:0002 | `BattleEmail`  | E-mail variant of Battle: game_state 8 runs BattleSetup + BattleWnd::Init, state 3 resumes via BattleWnd::InitResume |
| 1018:0225 | `BattleSetup`  | Fills the 0x192-byte battle info: city/field choice (1028:0002 or computer rule), trade agreement cancelled (NOTRADEDLG), Garde swap + Miliz, ArmyS... |
| 1018:0558 | `Battle`  | Battle between current player and target |
| 1018:0664 | `BattleAftermath`  | By result code: weapons loot (1068:2d4a, results+0x35/+0x36), KAPUTTDLG, plunder 1028:0eaf/0d46, retreat 1028:011c, initiative cost 1068:3282, Mili... |
| 1018:094a | `BattleFameAndXp`  | Fame table by code 10..13 and strength/title comparison |
| 1018:0c5f | `FightRaiders`  | Event 17 (mode 1 marauders, 1068:4d7c) or 19 (mode 2 Lindwurm, 1068:506a) battle |
| 1018:11a5 | `Seg4_UnitInit` * | Empty unit-initialisation stub |
| 1068:4b22 | `FillWithMilitia`  | Fills army1 to 8 with Miliz: att 1+pop/3500, def 1+pop/4500, hp 1+pop/3000 (max 6) |
| 1068:4d7c | `GenerateMarauders`  | Marauder record: count Random(n)+3 (n = strength/8), tiers from DS:57a7.. |
| 1068:506a | `GenerateLindwurm`  | Monster record with one Lindwurm (type 12) |
| 1068:51da | `RemoveMilitia`  | Truncates army1 at the first Miliz (type 0) |
| 1068:56bc | `AvengerJoinsWeaker` † | Reisiger Raecher joins the clearly weaker side |
| 1068:5835 | `AvengerLeaves`  | After battle: removes the type-13 unit (Reisiger Raecher) again |
| 1068:666b | `Distance`  | Round(sqrt(dx^2+dy^2)) |
| 1068:66af | `RaiderVictoryReward` * | Reward for beating marauders / the Lindwurm |

### After the battle: plunder, burning, massacre, retreat (segment 6, 1028)

| Address | Name | Purpose |
|---|---|---|
| 1028:0002 | `AskBattlefield` * | Human defender chooses field or city |
| 1028:011c | `RetreatLosses` * | Losses of a fleeing human army (FLUCHTDLG) |
| 1028:020a | `Massacre` * | Massaker: kill and deport civilians |
| 1028:038e | `ShowMassacre` * | MASSAKERDLG with the Schlaechter epithet |
| 1028:0461 | `MassacreDlg::Init` * | Constructor of MASSAKERDLG |
| 1028:04d5 | `MassacreDlg::SetupWindow` * | Killed, deported, epithet |
| 1028:057e | `BurnBuildings` * | Brandschatzen: building losses into the results block |
| 1028:0996 | `ShowBurnResult` * | BRANDDLG |
| 1028:09c8 | `PlunderTalerAndLand` * | Pluendern: Taler and land |
| 1028:0b6b | `ShowPlunderResult` * | PLUENDERNDLG |
| 1028:0c00 | `PlunderResultDlg::Init` * | Constructor of PLUENDERNDLG |
| 1028:0c74 | `PlunderResultDlg::SetupWindow` * | Taler, land, civilians |
| 1028:0d46 | `Ai_PlunderChoice` † | Computer winner: random plunder choice |
| 1028:0eaf | `PlunderDialog` † | Human winner: LOOTDLG/LOOT2DLG choice and apply |
| 1028:1290 | `LootDlg::Init` * | Constructor of LOOTDLG / LOOT2DLG |
| 1028:134c | `LootDlg::SetupWindow` * | Winner and loser names |
| 1028:138d | `LootDlg::IdPlunder` † | Button 201: EndDlg(10) |
| 1028:13a1 | `LootDlg::IdBurn` † | Button 202: EndDlg(11) |
| 1028:13b5 | `LootDlg::IdMassacre` † | Button 203: EndDlg(12) |
| 1028:13c9 | `LootDlg::IdMercy` † | Button 204: EndDlg(13) |

### E-mail game helpers (segment 5, 1020)

| Address | Name | Purpose |
|---|---|---|
| 1020:0002 | `Email_EnterPlayerData` * | EMAILNAMEDLG for a new human in an e-mail game |
| 1020:00e9 | `Email_VerifyPlayer` * | Password check at the start of an e-mail turn |
| 1020:014e | `Email_AskPassword` * | Up to 3 password attempts |
| 1020:0216 | `ShowPasswordFail` * | PASSWORDFAILDLG |
| 1020:0255 | `EmailTurnDlg::Init` * | Constructor of the password start-turn dialog |
| 1020:02b3 | `EmailTurnDlg::CanClose` * | Reads the password edit |
| 1020:02ee | `ShowEmailHandOver` * | EMAILUNTERBRECHENDLG: saved as <file>, next player |

### Game and player setup (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:0002 | `CreateComputerPlayers` * | Computer player records with level and free country |
| 1068:01c1 | `InitPlayers`  | New game: initial values for all players (humans: title 0, 1000 Taler, 10000 ha, 1000 people |
| 1068:0788 | `InitComputerRuler` * | A computer ruler takes over a country |

### Population, grain, fame (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:0885 | `GrainCapacity`  | mills*500 + granaries*10000 + 1000 |
| 1068:0900 | `RemoveGranaries`  | granaries -= n (fire, catastrophe, bankruptcy) |
| 1068:09b4 | `RemoveWarehouses`  | warehouses -= n (fire, catastrophe, bankruptcy) |
| 1068:0b2c | `GrainNeedMinMax`  | needed = pop*5, min = needed*0.11, max = needed*1.06 |
| 1068:0ee4 | `UpdateBirthDeathRates`  | surplus = grain_distributed/5 - population |
| 1068:13a8 | `UpdateHappiness`  | happiness = 0.25 + fame*0.003 + asylum/3 + 2*birth + title*0.01 + units*0.005 + taverns*0.00025 - tax - justice - 1.5*death - pop/2.5e6 + modifiers |
| 1068:17f3 | `ImmigrationRate`  | (1 - asylum_law) * happiness / 7.5 - pop/5e6 (+0.05 in event 11), >= 0 |
| 1068:18fa | `EmigrationRate`  | (justice + 0.1) * (1 - happiness) / 7.5 + pop/5e6 |
| 1068:298f | `ComputeHarvest`  | round((land - land_used) * 5 * quality / (30 + Random(10))) |
| 1068:3040 | `GainFame`  | fame += n (Glanz und Gloria 1, tournament 8) |
| 1068:305b | `LoseFame`  | fame -= n (bankruptcy 7, finished palace part 10, cathedral part 20) |
| 1068:3238 | `UpdateInitiative`  | initiative (+0x583) += fame/50 + 2, +1 with Feldmarschall |

### Economy, land and finances (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:08d5 | `WarehouseCapacity` * | warehouses * 1000 |
| 1068:0ae8 | `CanAffordWithCredit` * | taler - amount >= -CreditLimit |
| 1068:0bd3 | `SmithyOutput`  | min(population div 2000, land div 20000) + 1 |
| 1068:0c22 | `ProduceGoods`  | Yearly salt (north) or wine (south) by country, beer from grain if brew_beer, weapons from smithies |
| 1068:19bd | `IncomeFromBuildings`  | markets*(77+R155) + mills*(165+R330) + taverns*(100+R200), * happiness, *1.25 with Bienenfleiss |
| 1068:1b26 | `TradeAgreementIncome`  | Sum over partners with a trade agreement (flag player+0x6ad+partner): (partner.mills*330 + partner.markets*155) / (num_players + 6) |
| 1068:1bf9 | `Prokurist`  | Auto-sell: for each good with prokurist_on and price >= minimum, sell the whole stock |
| 1068:1cd8 | `TaxIncome`  | min(round(pop * (tax_rate - 0.09) * 11), pop * 2) |
| 1068:1d60 | `JusticeIncome`  | min(round(pop * (justice - 0.06) * 7), pop * 3/2) |
| 1068:1df2 | `CreditLimit` † | Debt limit (title+7)*1000 |
| 1068:1e29 | `MaximizeTaxes`  | Called each turn when maximize_taxes is set |
| 1068:22c0 | `BuildingsLostForLand`  | After selling land: buildings that no longer fit (dialog VERLUSTDLG) |
| 1068:27ac | `ArmyPay`  | Sum of unit pay (TUnit+0x2b) over both armies |
| 1068:290e | `Interest`  | taler > 0: +2.5 % |
| 1068:2a08 | `UpdateGrainPrice`  | grain_price = round((RandomReal*20+20) * (6 - harvest_quality) / 3 + 30) |
| 1068:2a77 | `UpdateMarketPrices`  | Yearly prices of land (per 10 Hf), salt, beer, wine, weapons for one player |
| 1068:2ce7 | `WarehouseFreeSpace`  | warehouses*1000 - (salt + beer + wine + weapons) |
| 1068:2d4a | `AddGoodsCapped`  | Goods slot n (4 = weapons) += amount, capped by WarehouseFreeSpace, only with goods trade |
| 1068:2da4 | `WarehouseRent`  | WarehouseFreeSpace / 10 |
| 1068:2e4c | `FreeBuildingLand`  | (land - land_used) - 1000 * max(count of any building type) |
| 1068:2f86 | `UnclaimedLand`  | max(0, num_players*100000 - total land of all players) |
| 1068:41d5 | `TransferLand` * | Moves land (and lost buildings) between players |

### Titles and score (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:12fe | `ComputeScore` * | Score: army, Taler, land, people, title, fame |
| 1068:3076 | `CanBePromoted`  | next title t = title+1: land >= DS:57f4[t], taler >= DS:581c[t], pop >= DS:5844[t], palace_parts >= DS:586f[t], cathedral_parts >= DS:5879[t], Army... |
| 1068:31c7 | `IsFirstKing` † | No other player is or was Koenig |
| 1068:5c3c | `ArmyStrength`  | Strength of the army (mode 1 used for promotion) |

### Units and armies (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:2850 | `ManoeuvreCost` † | Manoeuvre price |
| 1068:3003 | `FameDiscount` * | value - value*fame/200 |
| 1068:3282 | `AttackInitiativeCost`  | DS:4256[defender_country*10 + attacker_country] (2..4) if the initiative option is on, else 0 |
| 1068:4620 | `FiefSize`  | base_pay * 100 Hufen, halved with Chevalerie |
| 1068:4671 | `UnitGainExperience`  | xp += n |
| 1068:50c5 | `ClearUnit` * | Zero a unit record, type 0xff |
| 1068:50e2 | `RemoveArmy1Unit`  | Deletes army1 unit i, shifts the rest, count -1 |
| 1068:515e | `RemoveArmy2Unit` * | Delete Garde unit i |
| 1068:5222 | `SwapArmies`  | Swaps army1 and army2 (city garrison fights) |
| 1068:53a4 | `MakeUnitName` * | Unit name: type name or <country> Ritter, +n |
| 1068:5439 | `RecruitUnit` * | Create a new unit of a type in Heer or Garde |
| 1068:5638 | `InitAvenger` * | Fresh Reisiger Raecher record |
| 1068:598d | `InitUnit` * | Fill a unit record (mercenary offers, knighting) |
| 1068:5b06 | `AddUnitToArmy` * | Append a unit to Heer or Garde |
| 1068:5b8b | `KnightSquire`  | Ritterschlag: Knappe becomes a knight |
| 1068:5c15 | `HasAnyUnits` * | army1_count or army2_count > 0 |
| 1068:5d18 | `UnitLess` * | Comparator by key |
| 1068:5db8 | `SortUnits` * | Insertion sort of units, descending |
| 1068:5e85 | `SortArmy` * | Sort Heer/Garde by max HP, then attack+defence |
| 1068:5f0c | `CreateHero` * | New Held with portrait-dependent ability |
| 1068:6122 | `HeroRankName` * | Hero rank text for a level |
| 1068:6199 | `RandomMercenaryType` * | Random mercenary type allowed by the title |
| 1068:61db | `UnitRankName` * | Rank text of a unit |
| 1068:6290 | `HasHero` * | A Held in either army |
| 1068:6323 | `FindHero`  | Returns the player's hero unit (mode 1: army1 only?) |
| 1068:63e4 | `Army1HasAbility`  | true if a unit in army1 has the given ability (1-based, DS:53f1) |
| 1068:643b | `CountUnitsOfType`  | used with type 10 (Vampire) for Terror |
| 1068:64d6 | `ArtilleryClass` * | 0 none, 1 ranged units, 2 Sprengpulver |
| 1068:65c2 | `HasDesertableUnit` * | A unit whose type may desert |
| 1068:674b | `MakeVampire`  | Copies a unit as a Vampire: type 10, full HP, range 1, level/xp/pay 0, ability DS:5284 |

### News, texts, formatting and utilities (1068)

| Address | Name | Purpose |
|---|---|---|
| 1068:2dcc | `ReduceByFraction` * | x -= round(x*f), at least 1 |
| 1068:67c5 | `ClearHighScores` * | Zero the 0xabe-byte score table |
| 1068:67db | `SortHighScoreTable` * | Sort 11 entries by score |
| 1068:68c5 | `AddNews`  | News / Klatsch-und-Tratsch entry: (kind, player, other, num_players, players). kinds seen: 8 war won, 9 war lost, 0x10 eliminated |
| 1068:69f1 | `MaxLong`  | max of two longints |
| 1068:6a2b | `MinLong`  | min of two longints |
| 1068:6a65 | `Chance`  | true with probability n percent (Random(100) < n) |
| 1068:6aa5 | `FormatPercent` * | round(part/total*100) + % |
| 1068:6b29 | `IntToStr` * | Longint to PChar |
| 1068:6b58 | `FormatThousands` * | Number with digit groups |
| 1068:6c36 | `BuildingProgressText` * | Palace/cathedral progress text |
| 1068:6cb4 | `RealmName` * | Realm name by land size |
| 1068:6d8b | `FameText` * | Fame in words |
| 1068:6e30 | `MagnitudeText` * | Rough size of a number |
| 1068:6eec | `SetBit` * | byte /= 1 << bit |
| 1068:6f23 | `ClearBit` * | byte &= ~(1 << bit) |
| 1068:6f52 | `TestBit`  | (mask >> bit) & 1 |
| 1068:6f82 | `Seg14_UnitInit` * | Empty unit-initialisation stub |
