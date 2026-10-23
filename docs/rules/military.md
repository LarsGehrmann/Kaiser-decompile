# Military: units, armies, recruitment, war

Status: unit type data read directly from the data segment (matches the manual's tables);
army rules from the troop, war and manoeuvre code. The tactical battle itself is in
[battle.md](battle.md).

## Armies

Each player has two armies of up to 8 units (`TUnit`, 0x3d bytes, see `tools/kaiser_structs.py`):

- **Heer** (army 1, `army1_count` 0x137, units at 0xfc + i·0x3d) – the field army; attacks,
  fights field battles, hunts bandits.
- **Garde** (army 2, `army2_count` 0x138, units at 0x321 + i·0x3d) – stays in the capital;
  defends it in a city battle (topped up with Miliz to 8 units).

`ArmyStrength(player, mode)` (1068:5c3c) = Σ (attack + defence) of the Heer units, plus the
Garde with mode 1. Used for promotion (titles.md: Kaiser needs 120).

## Unit types (data segment, index = unit type 0..35)

| Table | Address | | Table | Address |
|---|---|---|---|---|
| names | DS:4ac2 + 25·(type+10) | | cost (longint, standard troops) | DS:5174 |
| attack | DS:509c | | weapons needed | DS:5204 |
| defence | DS:50c0 | | title needed | DS:4f64 |
| hit points | DS:50e4 | | pay (word) | DS:5228 |
| steps | DS:5108 | | default ability (word, 1-based) | DS:5270 |
| range | DS:512c | | flags (unknown) | DS:52b8, DS:52dc |
| ammunition | DS:5150 | | Real48 per type (unknown) | DS:5300 |

| # | Unit | Atk | Def | HP | Steps | Range | Ammo | Weapons | Title | Pay | Cost | Ability |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Miliz | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | – | – |
| 1 | Kämpfer | 3 | 3 | 3 | 1 | 1 | 0 | 1 | 1 | 100 | 500 | – |
| 2 | Bogenschützen | 3 | 2 | 2 | 1 | 3 | 3 | 1 | 2 | 500 | 2500 | – |
| 3 | Infanterie | 4 | 4 | 4 | 1 | 1 | 0 | 2 | 3 | 800 | 4000 | – |
| 4 | Musketiere | 5 | 2 | 2 | 1 | 3 | 4 | 2 | 4 | 900 | 4500 | – |
| 5 | Kavallerie | 5 | 4 | 4 | 1 | 1 | 0 | 2 | 5 | 1000 | 5000 | – |
| 6 | Artillerie | 6 | 1 | 1 | 1 | 4 | 4 | 3 | 6 | 4000 | 15000 | Sprengpulver |
| 7 | Ritter | 6 | 5 | 6 | 2 | 1 | 0 | 3 | 7 | 6000 | 21000 | – |
| 8 | Kreuzritter | 7 | 7 | 7 | 2 | 1 | 0 | 4 | 8 | 12000 | 32000 | – |
| 9 | Held | 7 | 7 | 7 | 2 | 1 | 0 | 1 | 9 | 0 | 100000 | – |
| 10 | Vampire | 7 | 5 | 6 | 2 | 1 | 0 | 0 | 0 | 0 | – | Infektion |
| 11 | Paladine | 8 | 8 | 8 | 2 | 1 | 0 | 0 | 7 | 0 | – | Heilige Lanze |
| 12 | Lindwurm | 32 | 24 | 60 | 3 | 1 | 0 | 0 | 10 | 0 | – | Flammenstoß |
| 13 | Reisiger Rächer | 8 | 4 | 6 | 2 | 5 | 10 | 0 | 10 | 0 | – | Camouflage |
| 14 | Samurai | 7 | 7 | 7 | 1 | 1 | 0 | 0 | 6 | 2400 | – | Samuraischwert |
| 15 | Sarazenen | 7 | 4 | 6 | 2 | 1 | 0 | 0 | 5 | 2100 | – | Fortune |
| 16 | Schützen | 4 | 2 | 2 | 1 | 4 | 4 | 0 | 1 | 300 | – | Armbrust |
| 17 | Waldläufer | 4 | 4 | 3 | 1 | 4 | 5 | 0 | 4 | 500 | – | Regeneration |
| 18 | Schwarze Ritter | 7 | 7 | 7 | 2 | 1 | 0 | 0 | 7 | 6000 | – | Morgenstern |
| 19 | Wölfe | 4 | 3 | 3 | 2 | 1 | 0 | 0 | 1 | 20 | – | Raserei |
| 20 | Walküren | 7 | 6 | 6 | 2 | 1 | 0 | 0 | 7 | 3600 | – | Charme |
| 21 | Knochenflicker | 1 | 1 | 2 | 1 | 1 | 3 | 0 | 3 | 400 | – | Heilkräfte |
| 22 | Alchimisten | 2 | 1 | 1 | 1 | 3 | 2 | 0 | 4 | 800 | – | Sprengpulver |
| 23 | Brandschützen | 3 | 2 | 2 | 1 | 3 | 3 | 0 | 2 | 180 | – | Pechpfeile |
| 24 | Kriegsknechte | 5 | 4 | 4 | 1 | 1 | 0 | 0 | 2 | 60 | – | – |
| 25 | Tataren | 6 | 5 | 5 | 2 | 1 | 0 | 0 | 4 | 2700 | – | Raserei |
| 26 | Nordmänner | 8 | 7 | 8 | 1 | 2 | 2 | 0 | 8 | 7200 | – | Wurfaxt |
| 27 | Bukaniere | 6 | 5 | 6 | 2 | 1 | 0 | 0 | 4 | 2600 | – | Schwimmer |
| 28 | Berserker | 9 | 4 | 6 | 1 | 1 | 0 | 0 | 5 | 4000 | – | Raserei |
| 29 | Templer | 8 | 7 | 7 | 2 | 1 | 0 | 0 | 7 | 6400 | – | Fortune |
| 30 | Nomaden | 5 | 3 | 5 | 2 | 1 | 0 | 0 | 4 | 960 | – | Fortune |
| 31 | Randaleure | 2 | 2 | 2 | 1 | 1 | 0 | 0 | 1 | 120 | – | Demontage |
| 32 | Mönche | 5 | 7 | 4 | 1 | 1 | 0 | 0 | 4 | 1400 | – | Kampfstab |
| 33 | Wachen | 2 | 2 | 2 | 1 | 1 | 0 | 0 | 0 | 50 | – | – |
| 34 | Knappen | 4 | 4 | 4 | 1 | 1 | 0 | 0 | 3 | 600 | – | Diensteifer |
| 35 | Assassinen | 6 | 4 | 5 | 1 | 1 | 0 | 0 | 5 | 960 | – | Vergiftete Klinge |

Types 0–9 are the standard troops (recruitable, with a price); 10–13 special units
(Vampire with Terror, Paladine with Pietät, Lindwurm = the beast of event 19, Reisiger
Rächer); 14–35 mercenaries (they offer their services; pay only). The manual lists pay at
fame 0 – at fame 100 it is halved (`base_pay` vs `pay`).

## Experience – UnitGainExperience (1068:4671)

```
experience += amount
if experience >= level × 2 + 10 and level < max_level: level up
max_level = 2 normally (Fuchs → Offizier → Haudegen), 3 with Heldentum (Elite),
            105 for Held and Reisiger Rächer (hero ranks Lehrling … Halbgott+99)
```

Stat gains per level by class: melee troops +1 max HP and +1 attack/defence alternately;
archers/musketeers/Brandschützen +1 range (max 6), +3 ammo, HP or attack; cavalry types
(Kavallerie, Tataren, Nomaden) +1 HP and +1 steps up to 4, then attack; Artillerie range
then HP, +3 ammo; Berserker HP and attack; heroes get level-dependent gains and ability bonuses.
Sources of experience: manoeuvres (Random(5) + 1 per unit), fiefs (+24), battles, turn-start
training (+1, +2 with a Lehrmeister in the Heer).

## Troop dialog – ANORDNENDLG (Do_TruppenAufstellen 1038:6a30, type DS:1776)

Ported in `port/src/troops.pas` (`TTroopDlg`, with the recruiting dialog `TRecruitDlg` and
the pay dialog `TPayDlg`), identical to the original on the vectors of `port/tests/troops.vec`.

The dialog works on a copy of the player; **Fertig** takes it over, **Abbrechen** discards
everything done in the dialog (recruits already paid included). Units are selected by
clicking into the two painted grids – the Heer as 2 columns × 5 rows of 32-pixel cells, the
Garde as 3 × 3 cells inside an 8-pixel wall (slot of a cell: DS:105e / DS:107c; the grids
scale with the window, designed for 440 × 401 pixels). A click toggles a unit; at most two
are selected. The selection decides what the buttons do:

| Selection | <=> (101) | Entlassen (102), Sold (107), Spezial (103) |
|---|---|---|
| none | – | – (Alle tauschen 106 instead: Heer and Garde change places) |
| one Heer unit | "=>" into the Garde (Garde < 8, Heer at home) | for that unit |
| one Garde unit | "<=" into the Heer (Heer < 8, Heer at home) | for that unit |
| two units | exchange their places (Heer ↔ Garde only with the Heer at home) | – |

- **Entlassen** (102): the unit's weapons (DS:5204) go back to the stock (`AddGoodsCapped`),
  `units_given_or_dismissed` + 1. A Held cannot be dismissed (in the census editor only from
  the Heer).
- **Sold** (107, SOLDDLG 1040:00f7): only in mode 0, for a unit with pay > 0 whose byte
  +0x37 is set (the turn start sets it): the new pay is chosen between `base_pay / 2` and
  `base_pay × 2`; accepting clears +0x37, so the pay can be changed once a year.
- **Spezial** (103): enabled for a knight type (DS:4f40: Ritter, Kreuzritter, Held,
  Paladine, Reisiger Rächer, Schwarze Ritter, Templer) of rank ≥ 2 that still gets pay,
  if the free land (`land − land_used`) covers the fief; for a Knappe (type 34) of rank ≥ 2;
  in the census editor for any unit (the unit editor UNITEDITDLG).
  - **Fief** – Lehnswesen (BELEIHENDLG "n Hufen werden die … zu Lehnsnehmern"):
    `land_used += FiefSize` = `base_pay div 100 × 100` Hufen (halved with Chevalerie, spell
    3), the unit's pay becomes 0, it gains 24 experience *as with Heldentum* (so it can rise
    to Elite), fame + 2; buildings that no longer fit are lost (VERLUSTDLG). Fief land
    yields no harvest, cannot be sold or built on.
  - **Knighting** (RITTERSCHLAGDLG, `KnightSquire` 1068:5b8b).
- **Rekrutieren** (104 Heer while it is at home and < 8, 105 Garde ≤ 8; `RecruitDialog`
  1040:5108, REKRUTDLG): impossible as Herr (title 0, NOREKRUTDLG). The combo box offers the
  unit types 1 … title (a Koenig who has a Held already: 1 … 8). Price = UnitCost (DS:5174,
  × 3/4 with Ferengicharme) reduced by fame (`FameDiscount`); the weapons of DS:5204 are
  needed (Kaufen is disabled without them) and taken from the stock; the price is also
  subtracted from `total_recruiting`. A Held gets a name (REKHELDDLG; with Heldentum he
  gains 10 experience at once) – or the dialog's Lindwurm flag gives the Lindwurm (type 12).
  In the census editor every type 1 … 35 is free and needs no weapons.
- **Taler, Waffen, Sold** (the yearly `ArmyPay`) are shown in modes 0 and 6.

**Modes** (the caller passes them; +0x709):

| Mode | Opened by | Allowed |
|---|---|---|
| 0 | menu Truppen aufstellen, after units join at the turn start | everything; Fertig refused with a Garde of 9 (MUSTDISMISSDLG: one must go) |
| 1 | the attacker before a battle (War) | no recruiting, no Sold, no Abbrechen; Fertig refused (NOHEERDLG) with an empty Heer but a Garde |
| 2 | the defender before a field battle | the same |
| 3 | the defender before a city battle ("… stellt Eure GARDE auf") | no recruiting, no Sold, no Abbrechen; an empty Garde with the Heer at home asks first (MILIZDLG: the Miliz defends) |
| 4 | Entwicklungshilfe "Truppen" (`ChooseUnitToGive` 1038:6a93, "Wählt eine Einheit zum Verschenken:") | no Entlassen, Sold, recruiting; **Abschicken** (OK) only for one selected unit whose type can desert (DS:52b8: not Miliz, the knights Ritter, Kreuzritter, Schwarze Ritter, Templer, not the Held and the special units 10–13) |
| 5 | another player's armies ("Truppenübersicht …") | nothing, not even selecting |
| 6 | the census editor (INI Debug) | like 0, plus the unit editor; recruiting is free |

Abbrechen is also disabled with a Garde of 9 (a gift can leave 9 units: the 9th lies over
`army_away` and the following fields of the player record).

Original quirks and bugs (the port keeps them):

- **Abschicken stays enabled.** In mode 4 the OK button is only updated while one unit is
  selected; deselecting it (or moving it with <=>) leaves "Abschicken" enabled with nothing
  selected, and `ChooseUnitToGive` then returns Garde slot 0. Do_Entwicklungshilfe gives away
  the unused record before the Garde (player bytes 0x321..0x35d) and calls
  `RemoveArmy2Unit(0)`, which moves the first Garde unit into that hidden slot (it is lost);
  with an empty Garde its loop runs 0 … 255 and overwrites the following players (army2_count
  becomes 255).
- Spezial and Alle tauschen work in every mode but 5: a knight can be enfeoffed in the
  gift dialog or right before a battle, and units can be dismissed before a battle.
- The recruiting dialog is never freed, and while it is open its 400-ms timer calls
  `Random(3)` (the picture blinks): how long the player looks at it changes `RandSeed`. The
  differential tests send no timer messages (the port: `TRecruitDlg.Timer`).
- Recruit type 36 (one past the table) reads its price from the weapons table; type 0 (not
  selectable) would read it from the combo box pointer.

## Manoeuvre – Do_ManoeverAbhalten (1040:4ede)

Needs the Heer at home and ≥ 1 initiative point (if initiative is enabled). Costs
`1068:2850(player)` Taler (based on the Heer's levels, ×500, fame-adjusted – details
unconfirmed) plus 1 IP; each Heer unit gains Random(5) + 1 experience; `manoeuvres_held` + 1.

## War – CmKriegFuehren (1000:193f), DeclareWar (1038:40e8)

```
title ≥ 2 (Graf)                         else GEGNERERRORDLG
Heer present and not army_away           else NOHEERDLG
initiative ≥ 1 (if initiative enabled)
choose target (GEGNERDLG); target without troops → HASNOTROOPSDLG
peace treaty with the target (peace_years > 0): fame − 50, treaty cancelled on both sides
attacker sets up the Heer, then
    result = Battle(0 = field battle, target, attacker)
    result 3 (field battle won) → ask, then Battle(1 = city battle)
news 8 (won) / 9 (lost)
```

**Initiative cost** of an attack = `DS:4256[defender country × 10 + attacker country]`
(2–4 points, 0 without the initiative option); if initiative drops below 0, the Heer
winters abroad (`army_away` = 1) – exactly as the manual says. Initiative per turn:
`fame / 50 + 2` (+1 Feldmarschall).

| | Sa | Ho | He | By | Pr | Ba | Th | We | Bö | Fr |
|---|---|---|---|---|---|---|---|---|---|---|
| Sachsen | 0 | 2 | 2 | 3 | 2 | 3 | 2 | 2 | 2 | 3 |
| Holstein | 2 | 0 | 3 | 4 | 2 | 3 | 3 | 2 | 3 | 3 |
| Hessen | 2 | 3 | 0 | 3 | 3 | 2 | 2 | 2 | 3 | 3 |
| Bayern | 3 | 4 | 3 | 0 | 3 | 2 | 3 | 3 | 3 | 2 |
| Preußen | 2 | 2 | 3 | 3 | 0 | 3 | 2 | 3 | 2 | 3 |
| Baden | 3 | 3 | 2 | 2 | 3 | 0 | 2 | 3 | 3 | 2 |
| Thüringen | 2 | 3 | 2 | 3 | 2 | 2 | 0 | 2 | 2 | 2 |
| Westfalen | 2 | 2 | 2 | 3 | 3 | 3 | 2 | 0 | 3 | 3 |
| Böhmen | 2 | 3 | 3 | 3 | 2 | 3 | 2 | 3 | 0 | 2 |
| Franken | 3 | 3 | 3 | 2 | 3 | 2 | 2 | 3 | 2 | 0 |

After a won battle the winner may plunder or burn (`1028:0eaf` for humans, `1028:0d46`
for computer players; segment 6) – see the plunder section in battle.md / open.

## Open

The unit-type tables DS:52b8 / DS:52dc / DS:5300 are now known from the battle code as
`UnitCanDesert`, `UnitFearSusceptible` and `UnitMoraleBonus` (battle.md).

## After the battle (segment 6)

- **Plündern** (`PlunderTalerAndLand` 1028:09c8): Taler = loser.taler × (5 + Random(20)) % —
  only after a **city** battle; land only from neighbouring countries (attack cost ≤ 2):
  (5 + Random(13)) % (city) / (3 + Random(6)) % (field); the loser keeps ≥ 12000 Hufen,
  the winner also receives buildings that no longer fit the loser's land.
- **Brandschatzen** (`BurnBuildings` 1028:057e): a random share of each building type and
  1–5 % of the civilians are destroyed (table in `docs/functions/rules-ai.md`).
- **Massaker** (`Massacre` 1028:020a): (10 + Random(15)) % of the people killed in the city
  (1–5 % in the field) plus some deported to the winner; winner − 30 fame.
- **Gnade**: winner + 2 fame.
- A computer winner chooses randomly: plunder 51 %, burn 30 %, mercy 9 %, massacre 9 %,
  nothing 1 %. (From the code: a computer's burning is only displayed, nothing is destroyed.)
- **Retreat** (`RetreatLosses` 1028:011c): each fleeing Heer unit is lost with chance 1/5,
  except the Held, units with Fortune, and all units with the spell Karma.

## Mercenaries and other details (full function pass)

- **Mercenary offers** (`OfferUnitsAtTurnStart` 1010:22d4, `SOELDNERDLG` …): chance per turn
  `1 / (14 − fame / 10)`, with Karma `1 / (12 − fame / 10)` – matches the manual's figures.
- **Manoeuvre cost** (`ManoeuvreCost` 1068:2850): 2000 Taler per Held plus (level + 1) × 500 per
  unit below its maximum level, reduced by fame; computer players train for free.
- Kreuzritter get a random special ability; with Heldentum every new unit starts with +10 XP.
- `units_given_or_dismissed` (0x5d3) counts units given away or dismissed.
