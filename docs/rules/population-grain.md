# Population, grain and happiness

Status: formulas recovered from the code (constants decoded from the Real48 operands with
`tools/ghidra/disasm.py`) and checked against the 30 savegames where noted.
Field names refer to `tools/kaiser_structs.py` (`TPlayer`).

## Order of the yearly update – PlayerTurnStart (1010:37b6)

At the start of each of the player's turns (one turn = one year):

1. `UpdateInitiative`; `lifetime -= 1`.
2. `1010:0002` (returns false → game over; not analysed yet).
3. Year 0 only: special first-year handling (Heldentum promotes all units), then jump to the reports.
4. Reset this year's counters (immigrants, emigrants, event money, …).
5. `year_factor = RandomReal × 1.5 + 0.5`.
6. `RollYearlyEvent` → `event` (see [events.md](events.md)).
7. `UpdateBirthDeathRates`, `UpdateHappiness`.
8. **Population** update (below).
9. **Finances**: income items, `net_income`, `taler += net_income` (see the finances subsystem).
10. **Grain**: harvest, losses, storage cap (below).
11. Unit experience, events 17/19 battles, reports selected in `report_flags`.

`PlayerTurnEnd` (1010:57b2, from "Runde beenden") runs `UpdateBirthDeathRates` and
`UpdateHappiness` again, with the grain distribution chosen during the turn, then
bankruptcy (`Bankruptcy` 1010:4f9f) and clears the temporary effect flags `flags_5bd`.

## Grain need and distribution

`GrainNeedMinMax` (1068:0b2c), shown in the grain dialog `KORNDLG`:

```
needed  = population × 5
minimum = round(needed × 0.11)
maximum = round(needed × 1.06)        (all three rounded down to multiples of 100)
```

The slider sets `grain_distributed`, which is taken from the stock at the start of the next turn.

## Birth and death rates – UpdateBirthDeathRates (1068:0ee4)

```
surplus = grain_distributed / 5 − population          (people fed beyond need)

if population <= 0:   birth = 0.07, death = 0, asylum_law = 1, tax_rate = 0, justice = 0
elif surplus >= 0:    birth = min(0.07, surplus / population + 0.01);  death = 0.01
else:                 birth = 0.01;  death = min(0.9, |surplus| / population + 0.01)

death /= 2                         spell Heilende Hände (8)
death /= 5                         event 9 "Gesundheit"
birth *= 2                         event 1 "Babyboom"
death += 0.15 | 0.30 | 0.08 | 0.05 | 0.08    events 2 | 6 | 10 | 17 | 19
death += RandomReal / 50 + 0.03    flags_5bd bit 0x800
death = min(death, 0.9)
```

So distributing the maximum (needed × 1.06) gives exactly the cap birth rate 0.07;
anything below "needed" raises the death rate instead of lowering births.
Checked: 189 of 203 player records match exactly (the rest are the edited cheat saves).

## Population – in PlayerTurnStart

```
births     = round(population × birth_rate)
deaths     = round(population × death_rate)
immigrants += round(population × ImmigrationRate)     ; 1068:17f3
emigrants  += round(population × EmigrationRate)      ; 1068:18fa
population = max(50, population + births − deaths + immigrants − emigrants)

ImmigrationRate = max(0, (1 − asylum_law) × happiness / 7.5 − population / 5,000,000 (+0.05 in event 11))
EmigrationRate  = (justice + 0.1) × (1 − happiness) / 7.5 + population / 5,000,000
```

## Happiness – UpdateHappiness (1068:13a8)

```
happiness = 0.25 + fame × 0.003
          + asylum_law / 3 + birth_rate × 2 + title × 0.01
          + (army1_count + army2_count) × 0.005 + taverns × 0.00025
          − tax_rate − justice − death_rate × 1.5 − population / 2,500,000
+0.15  computer player (cpu_level ≠ 0)
+0.15  spell Engelszungen (4);   +0.05 spell Pietät (11)
−0.015 × number of Vampire units, spell Terror (12)
−0.1   event 11;   −0.2 events 17, 19
−0.18 / −0.09 / −0.07   flags_5bd bits 0x40 / 0x80 / 0x100
clamped to 0..1
```

Matches the manual's description (title, armies and a strict asylum law raise happiness;
taxes and harsh justice lower it). Checked: 165 of 188 records match within 0.0005
(Terror players excluded; misses are cheat saves and records saved between updates).

Happiness feeds back into building income (× happiness), immigration and emigration.

## Grain stock – in PlayerTurnStart

```
harvest_quality = Random(5) + 1            (Random(3) + 3 with Gaias Segen, spell 7)
harvest = round((land − land_used) × 5 × harvest_quality / (30 + Random(10)))   ; ComputeHarvest
grain   = max(grain − grain_distributed, 0)
loss    = RandomReal / 10 + 0.05            (5–15 %, rats)
grain  -= round(grain × loss);  flags_5bd bit 0x800: grain = grain div k
grain   = harvest if event 16 (rats) else grain + harvest
grain   = min(grain, GrainCapacity)          ; mills × 500 + granaries × 10000 + 1000
grain   = grain rounded to a multiple
```

Harvest checked: 167 of 203 records lie in the formula's random range; the others changed
`land` after the harvest (land is traded during the turn).

## Fields involved

`population` 0x2a, `birth_rate` 0x2e, `death_rate` 0x34, `happiness` 0x3a, `births` 0x40,
`deaths` 0x44, `immigrants` 0x48, `emigrants` 0x4c, `tax_rate` 0x58, `justice` 0x5e,
`asylum_law` 0x64, `grain` 0x121, `grain_distributed` 0x125, `harvest_quality` 0x12d,
`harvest` 0x12e, `land` 0xcb, `land_used` 0xcf, `lifetime` 0x22, `fame` 0x1a, `spell` 0x1c.
