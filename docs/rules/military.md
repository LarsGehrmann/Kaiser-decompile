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

Buttons: swap a unit between Heer and Garde (101), swap all (106), dismiss (102),
pay (107), **Spezial** (103), recruit into Heer (104) / Garde (105).

- **Recruiting** (`1040:5108`): impossible as Herr (title 0, `NOREKRUTDLG`). Standard
  troops cost DS:5174 Taler (Ferengicharme cheaper) and the weapons in DS:5204, taken from
  the `weapons` stock; the unit type needs the title in DS:4f64. A Held gets the
  hero-creation dialog `REKHELDDLG`.
- **Fief (Spezial on a knight)** – Lehnswesen: `land_used += base_pay × 100` Hufen
  (halved with Chevalerie, spell 3), the unit's pay becomes 0, it gains 24 experience,
  fame + 2; buildings that no longer fit are lost. Fief land yields no harvest, cannot be
  sold or built on.
- **Spezial on a Knappe** (type 34): knighting (`RITTERSCHLAGDLG`, 1068:5b8b).

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
