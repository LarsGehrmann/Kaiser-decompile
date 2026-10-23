# Turn loop

Status: exact. `NextPlayer`, `CpuTurn`, `ResolveWar` (port: `port/src/game.pas`) and
`PlayerTurnStart`/`PlayerTurnEnd` (`turn.pas`) are ported and verified against the original.

## One year

All players move in index order `0 .. num_players-1`; one pass over all players is one year.

```
BeginHumanTurn (1000:33c0)
    game_state := 6
    ok := PlayerTurnStart(year, num_players, current_player, players)   ; 1010:37b6, the yearly report
    game_state := ok ? 1 : 0                                            ; 0 = game over
    if Opt_Autosave and not email_game: SaveGame -> autosave.ksr

... the human uses the menu (all actions need game_state = 1) ...

CmBeenden "Runde beenden" (1000:2476)
    PlayerTurnEnd(year, num_players, current_player, players)           ; 1010:57b2
    if player.title = 10            -> Victory
    elif lifetime < 1 (no immortality) -> the ruler dies (dialog TOD / TODFEM with the year):
                                       a computer ruler takes the country over (InitComputerRuler),
                                       human_players - 1, last_human := current, news 16
    NextPlayer
    BeginHumanTurn of the next human (or hand over in e-mail mode)
```

If no human is left, `NextPlayer` never stops (computers only) until someone is crowned.

## New game – CmNeuesSpiel (1000:0ce6)

```
running game: "Es läuft bereits ein Spiel! Trotzdem ein neues beginnen?" (yes/no)
SPIELERZAHLDLG: number of humans and the options (e-mail, Unsterblichkeit, Warenhandel,
                Initiativpunkte -> header 0x0b, 0x12, 0x13, 0x14); all 10 player records cleared
COMPUTERZAHLDLG (fewer than 10 humans): number of computers and their level 1..4
SPIELERNAMEDLG per human: name, sex, country (names also kept at DS:659c)
CreateComputerPlayers; fewer than 2 players: no game
current 0, year 0, Randomize, game id := Random(65535) + 1, InitAvenger,
census editor := INI Debug, InitPlayers, BeginHumanTurn
```

## NextPlayer (1000:35ad)

```
if current is human: last_human := current
current := current + 1; if current = num_players: current := 0, year := year + 1
loop:
    human,    skip_turn set   -> clear skip_turn, continue with the next player
    human,    skip_turn clear -> stop: it is this human's turn
    computer, skip_turn set   -> clear skip_turn, continue
    computer, skip_turn clear -> CpuTurn; stop on game_state 0 (EndGame) or title 10 (Victory)
    advance current (wrap -> year + 1, and the Avenger (header+0x15) gains 2 experience;
    the first advance above does not give it)
```

So computer players run inside `NextPlayer`, between the human turns, and a skipped
year (`skip_turn`, dialog `AUSSETZDLG`) costs exactly one turn.

## Computer turn – CpuTurn (1000:36d2)

```
Ai_Turn(year, num_players, current, players)            ; 1008:0002, the AI year (ai.md)
if Ai_ChooseWarTarget(&target, ...):                   ; 1008:24eb
    e-mail game with a human target -> save, hand over (game_state 2)
    otherwise                         -> ResolveWar(target)
Ai_EndTurn(num_players, current, players)               ; 1008:29ea
```

## War – ResolveWar (1000:37c0)

game_state 2, the attacker's armies sorted (`Ai_ArrangeArmies` mode 1), then
`Battle(current, target)` (1018:0558); result 3 means "try again once" (second call with
flag 1). Result 1 posts news item 8 (war won), anything else item 9, both with the defender as
actor; game_state 1 again.

## The human turn in detail

`PlayerTurnStart` (1010:37b6):

```
UpdateInitiative, lifetime − 1
ShowStartTurnDialog (e-mail: password; false = wrong password, the game stops)
year 0: DiplomacyTurnStart, UpdateMarketPrices, MarriageDowry, a first hero (GrantFirstHero)
        unless one exists, WitchChoosesSpell; Heldentum: fame 0 and all Heer units + 10 experience
else:
    event money, immigrants, emigrants, built-this-turn flags cleared
    year factor := RandomReal × 1.5 + 0.5 (+0x5f0)
    from Ritter on (or Terror): OfferUnitsAtTurnStart
    SabotageEnd, DiplomacyTurnStart, gossip (report flag 0), RollYearlyEvent
    lifetime < 1 (no immortality): RulerFallsIll with chance 25 %
    event 17: FightRaiders(1) → won: RaiderVictoryReward(1), lost: news 7; event 19: FightRaiders(2)
    MaximizeTaxes if set; population: births, deaths, immigrants, emigrants, at least 50
    budget: income items, event money (5: + 1000..5999, 12: − 3 × population,
            15: + (justice + 0.01) × (0.5..1.5) × 50000, 13: − title × 1000,
            17: − title × (500..1499)), net income added to the Taler and the running totals
    harvest quality 1..5 (Gaias Segen 3..5), harvest, grain price, grain − distributed (≥ 0),
    goods, market prices; goods trade: Prokurist; warehouses full?
    grain − 5..15 %, poisoned (0x800): halved; event 16 replaces the stock by the harvest,
    else harvest added; capped by GrainCapacity, rounded down to 100
    goods trade: a caravan with chance 1 / (20 − fame div 10)
    army_away cleared when initiative ≥ 0
    experience: heroes + 1 (level-up dialog), others + 1 (Feldmarschall, ability 24: + 2);
    all units' field +0x37 := 1
    fame + 1 with chance 50 % if the Heer has ability 21
    reports by report_flags: 1 population, 2 budget, 3 intelligence; HarvestReport
both: goods trade with warehouses and report flag 4: goods dialog, else "warehouses full";
      report flags 5 grain, 6 land, 7 buildings
```

`PlayerTurnEnd` (1010:57b2): GrainShortageWarning, birth/death rates, happiness
(< 0.5: fame − 2), LandLossCheck, PromotionCheck, Bankruptcy, RevolutionCheck, SkipTurnCheck,
sabotage flags cleared.

## End of the game

- **Victory** (1000:3459) when a player's `title` reaches 10 (Kaiser): coronation dialog
  (`KROENUNGSDLG` / `KROENCOMPDLG`). A human winner also gets a high-score and records entry,
  but only if `census_editor_enabled` is 0, `immortality` is off and `initiative_enabled` is on.
  Score (`ComputeScore` 1068:12fe) = ArmyStrength/50 + taler/100000 + land/20000 +
  population/2000 + title + fame/20; KAISER.SCO keeps 5 tables (one per computer difficulty,
  header 0x09), one entry per game (header 0x0c game id); KAISER.REC holds the records
  (fastest coronation, most land/people/Taler, best hero).
- **Elimination** when `v22 < 1` at the end of the player's turn.
- `game_state = 0` after `PlayerTurnStart` returns false.

## game_state values

| Value | Meaning |
|---|---|
| 0 | no game / waiting (e-mail: saved for the next human) |
| 1 | running, human may act |
| 2 | war pending (e-mail hand-over) |
| 4 | new e-mail game: humans set up one after another |
| 5 | e-mail hand-over to the next human |
| 6 | start-of-turn processing running |
| 7 | e-mail: coronation seen by the other humans |
| 3, 8, 9, 0xb–0xe | e-mail battle phases (attack, result, plunder, burn) |

## Cheats

Hidden command 802 (Ctrl+P) asks for a password (`PASSWORDDLG`); if it matches and
`census_editor_enabled` (header 0x04) is set, the **Census Editor** (`CENSUSDLG`) edits all
ten player records directly.

## Skipped turns

A skipped year (`skip_turn`: exile after a revolution, sabotage type 10, `SkipTurnCheck`)
is not free: while away the player loses 30–60 % of land, Taler, people, markets and mills
("Was werdet Ihr wohl bei Eurer Rückkehr vorfinden?", `AUSSETZDLG`). The computer-player
code checks the wrong sabotage flag for this (0x80 instead of 0x200).
