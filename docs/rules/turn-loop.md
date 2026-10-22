# Turn loop

Status: structure confirmed from the code; the processing inside `PlayerTurnStart` and
`PlayerTurnEnd` is the next subsystem.

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
    elif v22 < 1 (and not flag_12)  -> player eliminated:
                                       message, AddNews(0x10), human_players -= 1
    NextPlayer
    BeginHumanTurn of the next human (or hand over in e-mail mode)
```

## NextPlayer (1000:35ad)

```
if current is human: last_human := current
current := current + 1; if current = num_players: current := 0, year := year + 1
loop:
    human,    skip_turn set   -> clear skip_turn, continue with the next player
    human,    skip_turn clear -> stop: it is this human's turn
    computer, skip_turn set   -> clear skip_turn, continue
    computer, skip_turn clear -> CpuTurn; stop on game over or title 10 (Victory)
    advance current (wrap -> year + 1, plus a yearly call 1068:4671 on header+0x15)
```

So computer players run inside `NextPlayer`, between the human turns, and a skipped
year (`skip_turn`, dialog `AUSSETZDLG`) costs exactly one turn.

## Computer turn – CpuTurn (1000:36d2)

```
Ai_Economy(year, num_players, current, players)        ; 1008:0002
if Ai_ChooseWarTarget(&target, ...):                   ; 1008:24eb
    e-mail game with a human target -> save, hand over (game_state 2)
    otherwise                         -> ResolveWar(target)
Ai_EndTurn(num_players, current, players)               ; 1008:29ea
```

## War – ResolveWar (1000:37c0)

`Battle(current, target)` (1018:0558); result 3 means "try again once". Result 1 posts
news item 8 (war won), anything else item 9 (war lost).

## End of the game

- **Victory** (1000:3459) when a player's `title` reaches 10 (Kaiser): coronation dialog
  (`KROENUNGSDLG` / `KROENCOMPDLG`). Humans also get a high-score / records entry,
  but only if `census_editor_enabled` is 0.
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
