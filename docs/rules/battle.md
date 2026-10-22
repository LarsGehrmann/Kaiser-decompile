# Tactical battle

Status: battle flow, duel, movement, ranged combat, terrain, the abilities used in combat,
motivation, desertion, experience/fame and the result codes are confirmed from the code
(segment 10 `1048:xxxx`, segment 4 `1018:xxxx`). The computer opponent (AI) is described in
outline only. Anything marked **unconfirmed** is a guess.

Conventions: `Random(n)` is Borland `Random`, which returns 0..n-1. `Chance(p)` (1068:6a65)
is true with probability p %. `Round` is Borland `Round`. "lvl" means `min(unit.level, 3)`.
Dist(a,b) = `Round(sqrt(dx² + dy²))` (1068:666b), so all 8 neighbours are at distance 1,
(2,1) is at distance 2 and (2,2) is at distance 3.
Unit field names are listed in [Field updates](#field-updates).

## 1. Entry points

| Caller | Function | What it does |
|---|---|---|
| War (`ResolveWar` 1000:37c0 for the computer, menu handler near seg01 line 1231 for humans) | `Battle` 1018:0558 | `Battle(second, def_idx, att_idx, defender, attacker)` |
| Yearly event 17 / 19 (seg03, PlayerTurnStart) | `FightRaiders` 1018:0c5f | mode 1 = marauders (event 17), mode 2 = Lindwurm (event 19) |
| E-mail game, game_state 8 / 3 | `BattleEmail` 1018:0002 | same as `Battle`, but it can stop and resume (result 14) |

`Battle` (1018:0558):
```
BattleSetup(second, def_idx, att_idx, info, defender, attacker)      1018:0225
PlaySound(8)
wnd := BattleWnd::Init(city = info[0], mode 0, side0 = defender, side1 = attacker)   1048:0002
code := wnd.Execute()                     modal dialog "KRIEG", VMT +0x4c
BattleWnd::GetResults(results, defender, attacker)                    1048:0e12
BattleFameAndXp(code, info, defender, attacker)                       1018:094a
BattleAftermath(code, results, info, defender, attacker)              1018:0664
return 2 for code 10/12 (lost), for code 11/13 return 3 after a field battle, 1 after a city battle
```
A result of 3 makes the caller ask the human (dialog DS:043e; the computer always advances)
whether to march on the capital. If yes, it calls `Battle(1, …)` again. This is the second battle,
and it is always fought at the city (seg01 lines 1231-1250, 2493-2500). Result 1 posts news item 8
(war won). Any other result posts item 9.

**There is no automatic resolution.** Every battle, including computer against computer, opens
the battle window. A side whose player record has `cpu_level != 0` is played by the AI from the
window timer (§10). Header byte 0x14 (`initiative_enabled`) only switches the initiative-point
costs on or off (1068:3282 returns 0 when it is clear).

## 2. Setup – `BattleSetup` 1018:0225

The info block `info` is 0x192 bytes, the same size as the e-mail `extra_block`:

| Offset | Meaning |
|---|---|
| +0x00 | 1 = city battle ("Stadtkampf"), 0 = field battle |
| +0x01 | second battle (march on the capital) |
| +0x02 | the defender has no units in either army (`army1_count = army2_count = 0`) |
| +0x03 | winter (e-mail copy of window +0xf93) |
| +0x05 | longint `ArmyStrength(0, attacker)` |
| +0x09 | longint `ArmyStrength(0, defender)` |
| +0x0d / +0x0e | attacker index / defender index |
| +0x0f, +0x10.., +0x47, +0x48, +0xed | e-mail resume data: current side, results, last code, 2 maps (1048:0ed6 / 07c9) |

Steps:
1. **Trade agreement.** If the attacker is human, this is not an e-mail game and the attacker has a
   trade agreement with the defender (`+0x6ad[def]` = 1), then `NOTRADEDLG` is shown and the
   agreement is cancelled on both sides (`+0x6ad`, `+0x6c1[att]` = 0).
2. **Battlefield choice** (first battle only):
   - human defender: dialog 1028:0002 (segment 6), "Schlachtfeld" or "Stadt".
   - computer defender: field battle only if its army is at home (`+0x584` = 0), it has
     `army1_count + army2_count >= 8` and `Chance(5 × that total)` succeeds. Otherwise city.
   - second battle: always city. A human defender gets `CITYATTACKDLG`.
   - For a city battle (not e-mail), 1028:0eaf (human attacker) or 1028:0d46 (computer attacker) is
     called with empty results (segment 6, out of scope).
3. A computer-vs-computer mercenary check runs (1068:56bc, header record DS:611d): the
   **Reisiger Rächer** (unit type 13) joins a side that is clearly weaker on two strength measures
   (1068:12fe and `ArmyStrength`). The thresholds are **unconfirmed**. 1068:5835 removes him again
   after the battle.
4. The defender lines up its units. A human uses `Do_TruppenAufstellen` (mode 2 = field / Heer,
   mode 3 = city / Garde). The computer uses 1030:0d02 (mode 1 / 2).
5. **City battle:** `SwapArmies` 1068:5222 swaps army1 and army2, so the *Garde* fights. Then
   `FillWithMilitia` 1068:4b22 fills the army up to 8 units with **Miliz**:
   attack = 1 + pop/3500, defence = 1 + pop/4500, HP = 1 + pop/3000 (each capped at 6),
   1 step, range 1, no ammo, no ability, no pay. `+0x585` remembers the swap.
6. `info+5/+9` = army strengths. They are used for fame (§11).

Only **army1** (player `+0x137`, units `+0xfc + i·0x3d`) ever takes part in a battle. Before a war
the attacker chooses its army with `Do_TruppenAufstellen(1)`.

## 3. The battle window (VMT DS:2d2c, object 0xfa7 bytes)

`BattleWnd::Init` 1048:0002 copies both player records into the window. Side 0 is at +0x2e and
side 1 at +0x703. **Side 0 = defender** (or the marauders / Lindwurm), **side 1 = attacker**
(or the human who meets the marauders).
Unit i of side s lies at `obj + s·0x6d5 + 0x12a + i·0x3d`.

| VMT slot | Address | Name |
|---|---|---|
| +0x08 | 1048:9a57 | Done (destructor: cursors, timer) |
| +0x38 | 1048:0bc3 | SetupWindow (cursors, buttons, timer) |
| +0x4c / +0x50 | 1098:014f / 1098:023d | Execute / EndDlg (OWL). `EndBattle` 1048:8ff5 calls EndDlg(code) |
| +0x54 | 1048:1068 | DrawMap |
| +0x58 | 1048:3d78 | CanMoveTo |
| +0x5c | 1048:455c | CanAttack |
| +0x60 | 1048:4944 | Duel |
| +0x64 | 1048:54ed | AttackObject (buildings, walls, trees) |
| +0x68 | 1048:631a | EndAction (after a human action) |

Message handlers are listed in docs/owl-tables.md. The buttons are 101 `&Warten`, 102 `&Fertig` and
103 `&Aufgeben`.

Init sequence:
- `InitMorale` 1048:0966 (§8). Winter: `+0xf93 := Random(6) = 0` (probability 1/6).
- `ResetSide` 1048:8ac4 for both sides: HP, steps and ammo set to their maximum; blind,
  unconscious and stance set to 0. The same reset runs again after the battle (§11).
- Start positions are set (table below) and the map is built (§4).
- AI parameters: `+0xe2e` defender tactic = `Random(4)` (0 in winter); `+0xe2f` cautious hero =
  `Random(2)`; `+0xf82` = 0.
- **Side 0 moves first** (`+0xf7f` = 0, `+0xf80` = unit 1). `StartSideTurn` is run for both sides.

Start positions (byte tables, index 1..8 = army slot). x is the column (0..14, left→right),
y is the row (0..10):

| Who | x table | y table | Positions |
|---|---|---|---|
| attacker, field | DS:2ba4 | DS:2bac | x 4,4,4,4,4,3,3,3; y 5,4,6,3,7,5,4,6 |
| attacker, city | DS:2b94 | DS:2b9c | x 5,5,5,5,5,4,4,4; y as above |
| defender, field | DS:2bc4 | DS:2bcc | x 10,10,10,10,10,11,11,11; y 5,4,6,3,7,5,4,6 |
| defender, city | DS:2bb4 | DS:2bbc | x 11,11,11,12,12,12,13,13; y 5,4,6,5,4,6,4,6 (inside the walls) |
| marauders / Lindwurm | random | | x = 7+Random(5), y = 2+Random(7), on a cell that is free or has a tree (the tree is removed) |

## 4. Battlefield and terrain (MAPDATA)

`LoadMapData` 1050:1212 loads resource `MAPDATA` with id n+1 and copies **165 bytes = 15 columns ×
11 rows, column-major** (`cell = x·11 + y`). The files in extracted/res/mapdata are 256 bytes long,
and only the first 165 bytes are used.
- city battle: n = defender's country → resources 1..10
- field battle: n = country + 10 → resources 11..20. Marauder fights use the human's country.

The window keeps two grids. `+0xed6` is the terrain, `+0xe31` is the terrain plus units (what is
drawn and tested). A cell is 32×32 pixels and the map is 480×352.

| Code | Meaning | Bitmap |
|---|---|---|
| 0 | open ground | background pattern `LAND` / `SCHNEE` |
| 2 market, 3 mill, 4 palace, 5 cathedral, 6 granary, 7 warehouse, 11 university, 12 tavern, 13 smithy | buildings (city battle only) | 1000+code |
| 8, 9 | trees | 1008/1009 |
| 10 | "hit" overlay used during animation only | 1010 |
| 0x33..0x40 | river pieces | 1051..1064 |
| 0x5b..0x63 | city wall pieces | 1091..1099 |
| 0x6f..0x76 / 0x79..0x80 | unit i of side 1 (0x6e+i) / side 0 (0x78+i) | 1100+type / 1200+type (hero: +50+portrait) |

In winter, codes 2..13 and the rivers use the snow bitmaps (+20).

**City layout** (1048:0002, fixed cells of the terrain grid). The walls form the box x 10..14,
y 3..7. The **gate** is the open cell (10,5). The inside is **x 11..13, y 4..6** (`IsInCity`
1048:347c). Buildings: up to 4 markets at (11,4),(11,5),(11,6),(12,5); up to 8 mills **outside**
the walls (DS:2bd4/2bdc); tavern (12,4), smithy (12,6), palace (13,4), university (13,5),
cathedral (13,6), granary (14,2), warehouse (14,8). A building is drawn only if the defender owns
at least one.

## 5. Turn structure

```
StartSideTurn(side)                           1048:85e0
repeat for the current unit (+0xf80):
    the human clicks (WMLButtonDown 1048:900d) or the AI acts (AiStep 1048:65a8, timer)
    after each action: EndAction 1048:631a / end of AiStep:
        if army1 of side 1 is empty -> EndBattle(10); if side 0 is empty -> EndBattle(11)
        if the unit has 0 steps left:
            DesertionCheck 1048:5dc0
            next unit := NextUnit 1048:8f08   (cyclic; needs steps > 0, stance 0, not unconscious)
            no unit left -> the other side's turn: StartSideTurn(other side)
                            (e-mail game with two humans: EndBattle(14))
```
- `Warten` (101) jumps to the next ready unit. The waiting unit keeps its steps and comes back
  later. `Fertig` (102) sets steps to 0.
- There is **no round limit**. A battle ends only by annihilation (10/11), surrender or AI
  retreat (12/13), or an e-mail hand-over (14).

**StartSideTurn** 1048:85e0, for every unit of the side:
- **Steps** := max steps. In winter it is `max(max_steps-1, 1)`, except for Lindwurm and units with
  Samuraischwert or Kampfstab.
- **Regeneration points** r = Heilende Hände (spell 8) + Regeneration (ability 7) + stance
  "Heilen". If HP < max: `Chance(50·r)` gives +1 HP (so 2 sources = certain).
- **Blind** and **unconscious** counters each drop by r+1, to a minimum of 0.
- **Computer** units end their stance by themselves. "Heilen" ends when HP is full or the unit is
  threatened (`IsThreatened` 1048:34b7). "Eingraben" ends when the AI is in attack mode or an
  enemy is adjacent.
- If no unit of the side is active (all have stance 1/2), every stance is reset to 0.
  This is the manual's "until it is the last unit".

## 6. Movement – `CanMoveTo` 1048:3d78, `MoveUnit` 1048:3fc0

- A move goes to one of the 8 neighbours (distance < 2) inside 0..14 × 0..10 and costs **1 step**.
- Passable cells:
  - open ground (0);
  - trees (8/9): only units with flag DS:2cc4 (only the Lindwurm);
  - rivers: in winter (frozen), with **Schwimmer** (ability 23) or with the DS:2cc4 flag;
  - the defender (side 0) may also enter its own buildings (2..7, 11..13);
  - walls never. A destroyed wall or tree becomes 0.
- **En passant** (1048:3fc0): before the move, every enemy in the 8 cells around the *start* cell
  strikes the moving unit. The enemy must be active (stance 0), conscious and melee-capable
  (DS:2ca0). The strike is a normal duel with the en-passant flag, so the striker spends no steps.
  **Duckmäuser** (ability 27): each strike happens only with `Chance(50)`.
  If the moving unit dies, the move is cancelled. If it is knocked out, its steps become 0.
  - Not in the manual: the code does not check whether the *destination* is still next to the
    enemy, so any step out of a cell next to an enemy triggers the strikes.
  - Quirk: `InBounds` 1048:390b accepts only x 1..14 and y 1..10, so enemies in column 0 or
    row 0 never strike en passant.
- Moving to x > 7 sets `+0xf82` (the enemy has crossed the middle; used by AI tactic 2).

## 7. Attacks

### 7.1 What can be attacked – `CanAttack` 1048:455c (d = Dist, range = unit+0x1f)

| Target | Condition |
|---|---|
| enemy unit at d = 1 | the attacker is melee-capable (DS:2ca0) **or** has ammo > 0 |
| enemy unit at d > 1 | d ≤ range and ammo > 0 |
| building (attacker side only) | d = 1: melee-capable; d > 1: d ≤ range and ammo > 0 |
| city wall | d ≤ range and (Sprengpulver (10) with ammo > 0, or Demontage (25)) |
| tree | Demontage (25) and d ≤ range |

There is no line-of-sight check. Melee-incapable types (DS:2ca0 = 0) are Artillerie and
Alchimisten. They may shoot at point-blank range as long as ammo > 0, but such shots do not use
ammo (see 7.3).
Apparent bug: a human click on a tree that the unit may attack calls `AttackUnit` instead of
`AttackObject` (1048:9133 to 917b). The in-game effect is unverified.

### 7.2 The duel – `Duel` 1048:4944 (A = attacker, D = defender)

`AttackUnit` 1048:5055 prepares three flags:
- `knappen`: A is a knight type (DS:4f40: Ritter, Kreuzritter, Held, Paladine, Reisiger Rächer,
  Schwarze Ritter, Templer) and a friendly **Knappen** unit (type 34, conscious, stance 0) is
  adjacent (1048:37c1). This is the manual's *Diensteifer*, but the code checks the unit type,
  not ability 28.
- `surrounded`: ≥ 4 melee-capable enemies of D adjacent to D (`CountAdjacentEnemies` 1048:36c6).
- `en_passant`: from §6.

**Phase 1 – effective values.** The modifiers are applied in this order:
```
atk = A.attack × A.motivation
def = D.defence                                   (motivation does not affect defence)
A blind:                      atk /= A.blind + 1
D blind:                      def /= D.blind + 1
D unconscious:                def /= 2
(D in city and A not) or D dug in:   def ×= 2     (only once, not cumulative)
d > 1 and D has Drachenschild (4):   atk /= 2
A Raserei (14) and A.hp < A.max_hp:  atk ×= 2
D Charme (16) and A's type charmable (DS:2c58):  atk /= 2
A Heilige Lanze (19) and D's type heathen (DS:2c7c = 0):  atk ×= 1.5
surrounded:                   def /= 2
D stance "Heilen":            def /= 2
knappen:                      atk += 1
D not in city, D Camouflage (29), d > 1:  def ×= 2
```
**Phase 2 – hit:** `a = Random(Round(atk+1))` (0..atk), `b = Random(Round(def+1))` (0..def).
**Hit if a ≥ b.** On a tie the attacker hits; the manual says "higher".

**Phase 3 – damage** (on a hit). The base is A's **unmodified** attack:
```
m = A.attack / 3
D unconscious:                                   m ×= 2;  then D.unconscious := 0, D.stance := 0
A Vergiftete Klinge (3), Random(10-lvlA) = 0, D not Fortune:  m := 50
A Sprengpulver (10) or Flammenstoß (26), D not Fortune, Random(6-lvlA) = 0:
                                                 D.blind += lvlA + 3 - lvlD
any attack, D not Fortune, Random(lvlD + 12 - lvlA) = 0:
                                                 D.unconscious := Random(6 - lvlD) + 1
A Morgenstern (15), D not Fortune, Random(6-lvlA) = 0:
                                                 D.unconscious += lvlA + 4 - lvlD
A Heilige Lanze (19) and D is a Vampire:         m ×= 2
A Raserei (14), Random(5-lvlA) = 0, D not Fortune:  m ×= 2   (the target does not have to be wounded)
A Armbrust (12) and d > 1:                       m ×= 2
A Drachentöter (1) and D is the Lindwurm:        m ×= 3
D Drachenschild (4) and A is the Lindwurm:       m /= 2
damage = Random(Round(m)) + 1;   D.hp -= damage
```
Any hit also ends D's stance ("Eingraben" / "Heilen").

**Side-0-human bonus.** If the side-0 player (the defender) is human (`+0xe2b`), every duel in
that battle has two extra 50 % effects, whoever attacks: `Chance(50)` doubles the attack roll `a`,
and on a hit `Chance(50)` sets damage := `Round(m)` (the maximum). The code is clear
(1048:4c89, 4f9e); why it exists is unknown. Raider fights do not have it, because the marauder
record has `cpu_level` 1.

Typical damage dice: attack 1-4 → 1; 5-7 → 1..2; 8-10 → 1..3; Lindwurm (32) → 1..11.

### 7.3 Costs of an attack (also in `Duel`, skipped for en-passant strikes)
- Samuraischwert (6) or Kampfstab (11): steps −1 (several attacks per turn).
- Finesse (22): with `Chance(50)` **and** `Round(atk) ≥ 4·Round(def)` the steps stay unchanged.
  Otherwise steps := 0.
- Any other unit: steps := 0.
- **Ammo −1 only when d > 1.** Point-blank shots by Artillerie or Alchimisten use no ammo.

### 7.4 Kill (`AttackUnit` 1048:5055, D.hp < 1)
- A.kills (+0x27) +1, **A.experience +1** (direct, no level check until the end), attacker
  player `+0x5d5` +1, victim player `+0x5cf` +1, kill counter `results+0x35` (side 0 lost) or
  `+0x36` (side 1 lost) +1.
- An Entertainer that dies cancels its side's +0.25 motivation.
- **Infektion:** if A is a Vampire, A's army has < 8 units, D is not a Vampire and D does not have
  Fortune, then D becomes a new Vampire on A's side (`MakeVampire` 1068:674b). It keeps
  attack/defence/max HP/steps, has full HP, range 1, level 0, xp 0, no pay, ability 13, and
  0 steps this turn.
- Otherwise the unit is removed (`RemoveArmy1Unit` 1068:50e2; later units move up one slot).

### 7.5 Buildings, walls, trees – `AttackObject` 1048:54ed
`roll = Random(A.attack)` (base attack). Blind: roll /= 2. Pechpfeile (20) at d > 1: roll ×= 3.
The object is destroyed if `roll ≥ Random(hardness)` or if A has Demontage (25) or Flammenstoß
(26). Hardness (DS:2b83): wall 5, market 5, mill 4, palace 8, cathedral 10, granary 3,
warehouse 5, tree 1, university 7, tavern 5, smithy 5.
Each destruction adds 1 to a results counter (+0x08 markets, +0x0c mills, +0x10 palace parts,
+0x14 cathedral parts, +0x18 granaries, +0x1c warehouses, +0x20 university parts, +0x24 taverns,
+0x28 smithies). Palace and cathedral cells disappear only when the count reaches the number of
parts owned. Step and ammo costs are as in 7.3, except that Finesse does not apply.
The counters are shown in `KAPUTTDLG` (1040:0565) and are applied by the segment 6 routines
(1028:0eaf / 0d46). It is **unconfirmed** whether they are also applied when the attacker loses.

### 7.6 Healing – `CanHeal` 1048:5b56, `DoHeal` 1048:5cce, `HealUnit` 1048:5c60
Ability Heilkräfte (17), ammo ("Salven") > 0, target = own unit at d ≤ 1 (the healer itself
counts). Effect: +`Random(lvl+1)+1` HP (1..lvl+1, up to max HP; 0 for a Vampire patient).
Blind and unconscious are cleared. The healer's steps become 0 and its ammo drops by 1.

## 8. Motivation (TUnit +0x30, Real) – `ComputeMotivation` 1048:3ae4

```
mot = side_base + balance + level/10 + DS:5300[type] − DS:52dc[type]·fear[side]
      + (pay > 0 ? pay/base_pay − 1 : 0)  + 0.25·Entertainer[side]
mot := clamp(mot, 0.5, 1.1)
```
- `side_base` (1048:0966) = player happiness (+0x3a) + fame/300.
- `balance` (`StrengthBalance` 1048:3938) = (own − enemy)/(own + enemy), where each side's
  value is Σ(attack + defence) over its *living* units. It changes as the battle goes on.
- `fear[side]` = 0.2 if the *enemy* has the spell Terror (12) and this side does not.
  The attacker (side 1) gets another **+0.2 in winter**. DS:52dc = 1 for most troops. It is 0
  (immune) for Miliz, Kreuzritter, Held, Vampire, Paladine, Lindwurm, Reisiger Rächer,
  Schwarze Ritter, Wölfe, Berserker and Templer.
- DS:5300 (type bonus): 0.5 Miliz, 0.2 standard troops, 0.3 Ritter / Berserker, 0.5 Kreuzritter /
  Paladine, 2.0 Held, 1.0 Lindwurm / Reisiger Rächer, −0.1 Kriegsknechte, 0 for the others.
- Entertainer (ability 18) is checked once at the start (`Army1HasAbility`).
- The value is recomputed only when the unit's status panel is drawn (1048:1a60). In practice
  that happens every time the unit becomes the active unit, or when the mouse moves over it.
- Effect: the attack value is multiplied by it (§7.2). Status icon: 50-79 % `UNHAPPY`,
  80-99 % `MODERATE`, 100-110 % `HAPPY`.

**Desertion** (`DesertionCheck` 1048:5dc0), when a unit's activation ends: only types with
DS:52b8 = 1 can desert. All of them do except Miliz, Ritter, Kreuzritter, Held, Vampire, Paladine,
Lindwurm, Reisiger Rächer, Schwarze Ritter and Templer. The unit deserts if
`RandomReal·0.6 > mot`. Because mot ≥ 0.5, the chance is at most 1/6, at mot = 0.5.
If the enemy army has < 8 units, the unit **changes sides** (`UEBERLAUFDLG`); otherwise it leaves
(`DESERTDLG`). The player's `+0x5d1` is increased by 1.

## 9. Abilities in battle (ability = unit+0x2f, 1-based into DS:53f1)

| # | Ability | Effect in code (manual differences in *italics*) |
|---|---|---|
| 1 | Drachentöter | damage ×3 against the Lindwurm (*manual: +100 %*). The +2 attack is given when the hero is created, not in battle |
| 3 | Vergiftete Klinge | 1/(10−lvl): damage die 50 (*not "infinite"*); 1/8 at lvl 2 = the manual's 12 % |
| 4 | Drachenschild | ranged attacks against it: attack /2; Lindwurm damage /2 |
| 6 | Samuraischwert | attack costs 1 step; no winter step loss |
| 7 | Regeneration | +1 regeneration point (§5) |
| 9 | Fortune | immune to blinding, KO, Morgenstern, poison, the extra Raserei damage and infection |
| 10 | Sprengpulver | can attack walls (ammo); blinding 1/(6−lvl), +lvlA+3−lvlD rounds |
| 11 | Kampfstab | as Samuraischwert |
| 12 | Armbrust | damage ×2 at d > 1 (*the manual text says "defence halved"; its table says +100 % damage*) |
| 13 | Infektion | §7.4 |
| 14 | Raserei | attack ×2 when wounded; also 1/(5−lvl) double damage, whether wounded or not |
| 15 | Morgenstern | extra KO 1/(6−lvl), +lvlA+4−lvlD rounds |
| 16 | Charme | attackers whose type is charmable (DS:2c58) have attack /2. *No distance check: the type table decides* |
| 17 | Heilkräfte | §7.6 |
| 18 | Entertainer | +0.25 motivation for the whole side until it dies |
| 19 | Heilige Lanze | attack ×1.5 against heathen types (Vampire, Lindwurm, Samurai, Sarazenen, Wölfe, Tataren, Nordmänner, Berserker, Nomaden); damage ×2 against Vampires |
| 20 | Pechpfeile | roll ×3 against buildings at d > 1; cannot target walls |
| 22 | Finesse | §7.3 |
| 23 | Schwimmer | may cross rivers |
| 25 | Demontage | may attack trees and walls; always destroys |
| 26 | Flammenstoß (Lindwurm, not in the manual) | blinds like Sprengpulver; always destroys objects |
| 27 | Duckmäuser | each en-passant strike only 50 % |
| 29 | Camouflage (Reisiger Rächer) | defence ×2 against ranged attacks outside the city; not drawn on the map outside the city (1048:1068, 6192) |
| 28 | Diensteifer | not checked in battle. The Knappen *type* gives the +1 (§7.2) |

Abilities 2, 5, 8, 21 and 24 (Güldene Brünne, Mithrilharnisch, Wurfaxt, Glanz und Gloria,
Lehrmeister) do nothing in the battle code. Their effects are in the unit stats or happen outside
battle.

## 10. Player commands and AI

**Human** (`WMLButtonDown` 1048:900d). The click is tested in this order: move (VMT +0x58),
heal, attack (VMT +0x5c) → `AttackObject` or `AttackUnit`. A right click on an own active unit
opens `KAMPFOPTDLG` (`CombatOptionsMenu` 1048:8c92):
- Eingraben: stance 1, steps 0.
- Heilen: stance 2, steps 0.
- Eingraben and Heilen are only enabled when the unit is active, has steps left and the side has
  more than 1 active unit (1048:8c19).
- Aktivieren: stance 0.
- Warten / Fertig.
A right click on terrain opens WinHelp (topic 400+code).
**Aufgeben** (103, `IdCtl103` 1048:9967) asks `RUECKZUGDLG` (for the defender in a city:
`KAPDLG`). Confirming ends the battle with 12 (attacker) or 13 (defender).

**Status panel** (`DrawUnitStatus` 1048:1a60). It shows the effective attack/defence
(the phase-1 modifiers that do not depend on the opponent). An enemy's numbers are shown only if
the current unit has level ≥ 1; its HP bar, state icons and morale only if level ≥ 2.

**AI** (`AiStep` 1048:65a8, one action per timer tick, after a 3-tick start delay):
1. `AiShouldRetreat` 1048:84ad, with r = `StrengthBalance` of the current side:
   - hero: HP < 20 % and threatened, and r < −0.2;
   - a non-Lindwurm unit of the attacker, or of anyone in a city battle: r < −0.33 and `Chance(90)`;
   - the field defender: r < −0.5 and `Chance(40)`.
   On retreat → EndBattle(12 for side 1, 13 for side 0). The Lindwurm never retreats.
2. `AiTryAttack` 1048:7d3d. It picks a target by unit type (`AiChooseTarget` 1048:7725):
   - Held / Reisiger: hero, healer target or a helpless unit;
   - Artillerie / Alchimisten: wall gaps, healing units, Sprengpulver units, Vampires;
   - fast units: fast units;
   - Vampire / Schwarze Ritter / Berserker: the lowest-HP enemy;
   - Kreuzritter / Paladine: Vampires.
   If that target cannot be attacked: `Chance(15)` to hit an adjacent building (attacker in a
   city), otherwise the nearest enemy.
3. Otherwise it moves (`AiMove` 1048:81a3, one step toward the target, `AiStepToward` 1048:7b12)
   or takes a stance (`AiChooseStance` 1048:808b):
   - a wounded, unthreatened defender heals;
   - a defensive field defender with no adjacent enemy digs in.
   - In a city battle the defensive defender only moves inside the walls.
   - With `+0xe2f` a computer hero moves only one step per turn.
   - Attack mode (`AiChooseAggressive` 1048:68fe): always for the attacker; never for a city
     defender; for a field defender it depends on tactic `+0xe2e`: 0 = once in melee;
     1 = when outgunned (1048:69d4) or in melee; 2 = after the enemy crosses x > 7 or in melee;
     3 = always. It is also on whenever r > 0.5. Once on, it stays on (tactic := 2). On the first
     turn a computer defender is always defensive (1048:0bc3).

## 11. End of battle and results

| Code | Meaning | Set by |
|---|---|---|
| 10 | side 1 (attacker / the human against marauders) has no units left → attacker lost | 1048:631a, 65a8, 3fc0, 5dc0, 7d3d |
| 11 | side 0 has no units left → attacker won | same |
| 12 | attacker retreated (button or AI) | 1048:9967, 65a8 |
| 13 | defender retreated / capitulated | same |
| 14 | e-mail hand-over (two humans) | 1048:631a |

`GetResults` 1048:0e12:
- **City battle:** civilians killed = `min(pop − 50, side-0 units killed × pop / 50)`, which is
  2 % of the population per defender unit lost. It is stored in `results+4` and subtracted from
  population at once. `KAPUTTDLG` prints `results+0`, which the battle code never sets; possibly
  a bug (**unconfirmed**).
- Both sides get `ResetSide` (all wounds, blindness and KO are healed).
- Both player records are copied back, so dead units are gone for good.

The results block (0x37 bytes, window +0xdd8) holds +0x04 civilians, +0x08..+0x28 buildings,
+0x35/+0x36 units killed of side 0/1, and +0x2c.. (segment 6 data, **unconfirmed**).

`BattleFameAndXp` 1018:094a. Code 12 is handled like 10 and code 13 like 11, with the values in
brackets. "Stronger" compares `info+5` and `info+9`.

| | attacker | defender |
|---|---|---|
| 10 (12) attacker lost, attacker was stronger | −10 (−5) | +10 (+5) |
| 10 (12) attacker lost, otherwise | −3 (−2) | +7 (+4) |
| 11 (13) attacker won, attacker was weaker | +3 | −7 |
| 11 (13) attacker won, otherwise | +1 | +1 |

In all cases, for fame:
- 10/12: the defender gets +2 (+1) if its title is lower than the attacker's.
- 11/13: the attacker gets +1 if its title is lower; the defender loses another −3 (−2) and
  its ruler loses `Random(2)` years of lifetime (+0x22).
- The attacker loses 5 if it was stronger, 4 if the defender's title is lower, and 20 if the
  defender had no army.
- The defender gains 3 if it fought in the field.
- Fame is clamped by GainFame / LoseFame.

Counters: attacker `+0x5c1` wars won / `+0x5c3` wars lost; defender `+0x5c5` defences won /
`+0x5c7` defences lost.

**Experience:** every army1 unit gets **+8 XP** through `UnitGainExperience` 1068:4671. Level-ups
happen there, including those from kill XP.
- Attacker: only if human and the code is not 12.
- Defender: if the code is not 13.
- After an annihilation the loser has no units left, so in practice only the winner (or a side
  that did not retreat) gains XP.
- Per kill: +1 (§7.4).

`BattleAftermath` 1018:0664:
- **Weapons loot:** the winner's goods slot 4 (weapons) increases by the number of enemy units
  killed (`results+0x35` for the attacker on 11/13, `+0x36` for the defender on 10/12),
  through `AddGoodsCapped` 1068:2d4a. This happens only with goods trade enabled and is capped
  by free warehouse space.
- 10/12 after a city battle: `KAPUTTDLG`.
- 11/13: plunder / burn / massacre choice (1028:0eaf human, 1028:0d46 computer; segment 6).
- 12: a human attacker gets 1028:011c (retreat; probably unit losses, which Fortune protects
  against, **unconfirmed**). A computer attacker's retreat is announced with `ATKCOMPFLEDDLG`.
- 13: a computer defender's capitulation is announced with `DEFCOMPLOSTDLG`.
- **Initiative:** the first battle costs the attacker DS:4256[attacker][defender] (2-4 IP,
  symmetric table), only if header 0x14 is set. If initiative < 0, `+0x584` = 1 and the army stays
  abroad.
- The Reisiger Rächer leaves (1068:5835). After a city battle the Miliz is removed
  (`RemoveMilitia` 1068:51da) and the armies are swapped back.

## 12. Marauders and Lindwurm – `FightRaiders` 1018:0c5f

- Without an army at home (`+0x584`) or with an empty army1: fame −7, `NOUNITSDLG`, then
  `BARBLOOSEDLG` / `LINDWURMDLG_I`. Otherwise the human sets up army1 and the fight is a field
  battle on the player's country map. The player is side 1 and moves second.
- Enemy (side 0, random positions):
  - Mode 1: `GenerateMarauders` 1068:4d7c, name "Marodeure", n = ArmyStrength(1)/8, count =
    `Random(n)+3` (8 if n ≥ 7), at most 8. Each unit has tier `Random(n)+1` (≤ 9) from the tables
    at DS:57a7.., named "Diebe" … "Raubritter" (DS:53f1 entries 29-37).
  - Mode 2: `GenerateLindwurm` 1068:506a, one Lindwurm (type 12: 32/24/60 HP, 3 steps,
    Flammenstoß).
- Results:
  - 10: fame −5, `+0x5cb` +1.
  - 12: fame −7 and 1028:011c.
  - 11/13: fame +5, `+0x5c9` +1, weapons loot, +8 XP for army1, and the caller calls
    1068:66af (reward, out of scope).
  - Dialogs: `BARBWINDLG` / `MAROFLEDDLG` / `LINDWURMDLG_II`.
  - It costs 1 IP when header 0x14 is set.
  - No fame table from §11 applies.

## 13. Per-type tables used by the battle (index = unit type 0..35)

| Table | Meaning |
|---|---|
| DS:2ca0 | melee-capable (0: Artillerie, Alchimisten) |
| DS:2cc4 | can enter trees and rivers, no winter step loss (only the Lindwurm) |
| DS:2c58 | can be charmed |
| DS:2c7c | 1 = Christian; 0 = heathen for Heilige Lanze |
| DS:4f40 | knight (receives the Knappen bonus) |
| DS:52b8 | can desert |
| DS:52dc | affected by fear (Terror, winter) |
| DS:5300 | motivation bonus (Real48) |
| DS:2bec / 2c10 / 2c34 | attack / move / death sound |
| DS:2b83 | object hardness (by map code) |
| DS:2e8e / 2e9e | dx / dy of the 8 neighbours |

## Field updates

TUnit (0x3d bytes), confirmed from code and savegames:

| Offset | Type | Name | Evidence |
|---|---|---|---|
| +0x1a | u8 | hero_portrait | heroes: bitmap 1200/1100 + 50 + n (1048:1068); savegames 1..18. Other types: 0/1, meaning unconfirmed |
| +0x1b / +0x1c | u8 | attack / defence | Duel |
| +0x1d / +0x1e | s8 | max_hp / hp | |
| +0x1f | u8 | range | CanAttack |
| +0x20 / +0x21 | u8 | max_steps / steps | StartSideTurn |
| +0x22 / +0x23 | u8 | max_ammo / ammo ("Salven", also healing uses) | |
| +0x24 | u8 | level | |
| +0x25 | u16 | experience (+1 per kill) | 1048:5055 |
| +0x27 | s32 | **kills** ("Siege"), +1 per kill | 1048:5055 (`+0x151/+0x153`). **Not** a Real 1.1 |
| +0x2b / +0x2d | s16 | pay / base_pay; pay/base_pay − 1 goes into motivation | 1048:3ae4 |
| +0x2f | u8 | ability | |
| +0x30 | Real48 | **motivation**, 0.5..1.1 (saves: 1.1) | 1048:3ae4, 4944 |
| +0x36 | s8 | blind rounds | Duel, StartSideTurn |
| +0x37 | s8 | unconscious rounds in battle. Outside battle it is 1 in many saves (kaiser_structs: "set to 1 at turn start"); reset by 1048:8ac4 | |
| +0x38 | u8 | stance: 0 active, 1 Eingraben, 2 Heilen | 1048:8c92 |
| +0x39 / +0x3b | s16 | battlefield x (column 0..14) / y (row 0..10); kept after the battle (city garrison in saves: x 11..13, y 4..6) | 1048:3fc0 |

TPlayer:

| Offset | Name |
|---|---|
| +0x584 | army_abroad (initiative < 0) |
| +0x585 | garrison_swapped |
| +0x5c1 / +0x5c3 | attacks won / lost |
| +0x5c5 / +0x5c7 | defences won / lost |
| +0x5c9 / +0x5cb | raider fights won / lost |
| +0x5cf | own units killed |
| +0x5d1 | deserted (also counts battle desertion) |
| +0x5d5 | enemy units killed |
| +0x6c1 | s16[10], cleared together with a trade agreement (meaning unconfirmed) |

Header 0x14 (`initiative_enabled`) only switches IP costs on or off. It does **not** switch
between tactical and automatic battles.

Battle window (VMT DS:2d2c):

| Offset | Meaning |
|---|---|
| +0x2e / +0x703 | side 0 / side 1 player copies |
| +0xdd8 | results |
| +0xe0f / +0xe15 | morale base per side (Real) |
| +0xe1b / +0xe1c | Heilende Hände flag per side |
| +0xe1d / +0xe1e | Entertainer flag per side |
| +0xe1f / +0xe25 | fear per side (Real) |
| +0xe2b / +0xe2c | side is human |
| +0xe2d | mode (0 war, 1 marauders, 2 Lindwurm) |
| +0xe2e | AI tactic |
| +0xe2f | cautious hero |
| +0xe30 | map country |
| +0xe31 | occupancy grid |
| +0xed6 | terrain grid |
| +0xf7f | current side |
| +0xf80 | current unit |
| +0xf81 | AI attack mode |
| +0xf82 | enemy crossed the middle |
| +0xf8f | timer id |
| +0xf91 | blink state |
| +0xf92 | city battle |
| +0xf93 | winter |

## Corrections from the full function pass

- **Computer against computer is resolved automatically**, without the battle window:
  `Ai_ChooseWarTarget` calls `Ai_AutoBattle` (1030:1062) for a computer target. The attacker
  wins if `Ai_AutoBattleRating(attacker) > Ai_AutoBattleRating(defender, at home)`
  (1030:09f2: Σ attack+defence + 2·Σ level, home bonus, ×1.25 at home, artillery, Vampire and
  Knochenflicker factors); each Heer unit then dies with chance 1/(k + d + level)
  (`Ai_AutoBattleLosses` 1030:0bda, k = 3 winner / 2 loser). No fame change, no plunder.
  The tactical battle above is used whenever a human is involved.
- The Reisiger Rächer check (`AvengerJoinsWeaker` 1068:56bc) runs in all battles: he joins a
  side whose score and army strength are both below 2/3 of the opponent's.
- Plunder, burning, massacre and retreat losses after the battle: see military.md.
