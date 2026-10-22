# Yearly events – RollYearlyEvent (1010:2ce5)

Every turn the player gets at most one event, stored in `TPlayer.event` (0x24).
Humans see dialog resource `300 + event` (texts in `extracted/res/dialogs.txt`).

```
event = Random(23) + 1
if population > 100000 and Random(4) = 0: event = 6     (plague)
k = 2 with spell Karma (10), else 1     ; bad events need Random(n·k) = 0
```

Each event then has its own extra condition; if it fails the event becomes 0 (nothing).
"Karma" below means the extra roll is easier (good events) or harder (bad events) with Karma.

| # | Dialog title | Condition (after the roll) | Effect |
|---|---|---|---|
| 1 | Babyboom! | always | birth_rate × 2 |
| 2 | Tod & Verderben! (cholera) | pop < 50000: Random(3k) = 0 | death_rate + 0.15 |
| 3 | Erbschaft! (land) | Random(3 − Karma) = 0 | land + min(500 + Random((title+1)·1000), available land) |
| 4 | Brandkatastrophe! (mill) | Random(2k) = 0, mills > 0 | mills − 1 |
| 5 | Erbschaft! (money) | Random(3 − Karma) = 0 | event_money + 1000 + Random(5000) |
| 6 | Pestilenz! | pop < 50000: Random(10k) = 0 | death_rate + 0.3, lifetime − Random(2), news 4 |
| 7 | Spende! (markets) | free market slots (1 per 1000 ha farmland), Random(4 − Karma) = 0 | markets + min(2 + Random(fame/10), free slots) |
| 8 | Schändlicher Verrat! | Random(2k) = 0, > 2 units, not Heldentum | a random unit deserts; deserted_units + 1 |
| 9 | Gesundheit! | Random(2 − Karma) ≠ 0 | lifetime + 1, death_rate / 5 |
| 10 | Tod & Zerstörung! | Random(8k) = 0 | random share of every building type destroyed (fame loss for finished palace/cathedral), lifetime − Random(2), news 3 |
| 11 | Asyl! | Random(4) = 0 | refugees: immigration rate + 0.05, happiness − 0.1 |
| 12 | Hochwasser! | Random(6k) = 0 | relief fund: event_money − (amount from population) |
| 13 | Obulus! | Random(5k) = 0, not Pietät | event_money − title × 1000 (donation to Rome) |
| 14 | Spende! (mills) | free mill slots, Random(4 − Karma) = 0 | mills + min(2 + Random(fame/10), free slots) |
| 15 | Fahndungserfolg! | Random(4 − Karma) = 0 | event_money + (RandomReal + 0.5 + justice + 0.01) × 50000 |
| 16 | Ratten im Gemäuer! | Random(2k) = 0 | grain stock replaced by this year's harvest |
| 17 | Banditen! | Random(2) ≠ 0 | bandit battle (1018:0c5f); lost → news 7; death + 0.05, happiness − 0.2, money − title × (500 + Random(1000)) |
| 18 | Brandkatastrophe! (granary) | Random(2k) = 0, granaries > 1 | granaries − 1 |
| 19 | Merkwürdig! (beast) | Random(100) = 0 | battle against a wild beast (1018:0c5f mode 2); death + 0.08, happiness − 0.2 |
| 20 | Brandkatastrophe! (warehouse) | warehouses > 0, Random(3k) = 0 | warehouses − 1 (goods inside lost) |
| 21 | Hokuspokus (good) | year > 39, lifetime ≥ 5 | fortune teller reads the remaining lifetime |
| 22 | Hokuspokus (bad) | year > 39, lifetime < 5 | fortune teller: death is near |
| 23 | Heldentat | a hero is present (0x584), hero found | hero +2·level+10 (experience), fame + 8 |

Events 21–22 need header `flag_12` = 0, like elimination by old age, which suggests
`flag_12` disables ageing.

Open: exact amount for event 12, the battle details of 17/19 (military subsystem).
