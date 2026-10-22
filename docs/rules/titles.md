# Titles, promotion and revolution

Status: from the code; the requirement tables are read directly from the data segment.
The Kaiser row matches the manual exactly.

## Titles

`TPlayer.title` 0..10, names in `TitleNamesMale` (DS:4556) / `TitleNamesFemale` (DS:466a),
chosen by `is_female` (0x1d):

0 Herr/Frau · 1 Freiherr · 2 Graf · 3 Landgraf · 4 Markgraf · 5 Herzog · 6 Erzherzog ·
7 Fürst · 8 Kurfürst · 9 König · 10 Kaiser (= victory)

Effects of the title found so far: happiness + title × 0.01, event money scaled by title
(events 13, 17), unit types limited by title (see military), cathedral only for König.

## Promotion – CanBePromoted (1068:3076), PromotionCheck (1010:48fc)

Checked at the end of every turn ("Runde beenden"). For the next title t = title + 1 all of
these must hold (tables in the data segment):

| t | Title | Land (Hf) | Taler | Population | Palace parts | Cathedral parts | Happiness | Army strength |
|---|---|---|---|---|---|---|---|---|
| 1 | Freiherr | 5,000 | 0 | 500 | – | – | 40 % | 0 |
| 2 | Graf | 10,000 | 0 | 1,000 | – | – | 45 % | 10 |
| 3 | Landgraf | 12,000 | 0 | 1,200 | – | – | 50 % | 20 |
| 4 | Markgraf | 12,000 | 0 | 1,500 | – | – | 60 % | 30 |
| 5 | Herzog | 15,000 | 0 | 2,000 | – | – | 65 % | 40 |
| 6 | Erzherzog | 15,000 | 5,000 | 2,500 | – | – | 67 % | 50 |
| 7 | Fürst | 20,000 | 5,000 | 3,000 | – | – | 70 % | 60 |
| 8 | Kurfürst | 20,000 | 5,000 | 4,000 | – | – | 70 % | 80 |
| 9 | König | 50,000 | 10,000 | 5,000 | 12 | – | 80 % | 100 |
| 10 | Kaiser | 100,000 | 1,000,000 | 10,000 | 12 | 12 | 95 % | 120 |

Tables: `PromotionLand` DS:57f4, `PromotionTaler` DS:581c, `PromotionPopulation` DS:5844,
`PromotionPalaceParts` DS:586f, `PromotionCathedralParts` DS:5879, `PromotionHappiness`
DS:587e (Real48), `PromotionArmyStrength` DS:58bc. Army strength is `ArmyStrength(player, 1)`
(1068:5c3c, military subsystem); the manual equates 120 with "8 experienced Kreuzritter".
The check first re-runs MaximizeTaxes (if enabled), the birth/death rates and happiness.

On promotion: lifetime + 1, title + 1, fame + 10, promotion dialog (`BEFDLG` / `FEMBEFDLG`).
Reaching title 10 ends the game (Victory, see turn-loop.md).

**First king:** the first player to reach König gets news item 13, the flag
`first_king_bonus` (0x21) and a bonus (`FIRSTKINGDLG`): a hero if the player has none,
otherwise by chance an improved hero or the pay of all units halved.

## Revolution – RevolutionCheck (1010:55bb)

At the end of every turn:

```
if happiness < 0.3:
    uprising (AUFSTANDDLG)
    if Random(round(happiness × 10)) = 0:      ; 1/3 at 0.29 … certain below 0.05
        exile (EXILDLG): skip_turn = 1, title − 1 (if > 0), fame − 50, lifetime − 2
    else:
        crushed (GNADENDLG): fame − 10, lifetime − 1
```

## Other end-of-turn checks (PlayerTurnEnd 1010:57b2)

1. `GrainShortageWarning` – too little grain distributed (`ZUWENIGKORNDLG`).
2. Birth/death rates and happiness recomputed; fame − 2 if a Real comparison fails (not yet identified).
3. `LandLossCheck`, `PromotionCheck`, `Bankruptcy`, `RevolutionCheck`, `SkipTurnCheck`.
4. `flags_5bd` cleared.
