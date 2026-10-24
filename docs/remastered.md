# Kaiser Remastered (branch `remastered`)

The branch `main` keeps the faithful port: the same behaviour as the original, checked by the
differential tests. The branch `remastered` builds a modernised game on top of it.

## Decisions (2026-10-24)

- **Graphics:** a pixel-art scaler computed by the game at start (ScaleNx now, xBRZ-style edge
  scaling later): sharp at any size, the original look, no external tools.
- **Game:** crashes and clear bugs of the original are fixed; the rules and the balance stay the
  original's, and savegames stay compatible both ways.
- **Windows:** freely resizable (and full screen): the main window, the battle and the dialogs
  scale to any size with crisp fonts and the upscaled graphics; the layout stays the original's.

## How the scaling works

- Every screen keeps its original logical layout (the main window by the chosen resolution
  640×480 / 800×600 / 1024×768, the battle window, each dialog by its template).
- The scale `s` = window size / logical size (the aspect kept, the rest a dark border).
- Drawing goes through a scaled canvas (`port/gui/rcanvas.pas`): logical coordinates, multiplied
  by an integer render factor `N` = ⌈`s` × the screen's backing scale⌉; sprites and pictures come
  from the scaler at factor `N`, fonts at `N` times their size, lines `N` pixels wide. The
  frame then goes to the window, smoothly scaled from `N` down to `s` (never up: no blur).
- Mouse positions are divided by `s` back to logical coordinates, so all game logic and the
  original's hit tests stay as they are.

## Milestones

| # | Content | Done when |
|---|---|---|
| R1 | Branch, this plan; the scaler (`port/gui/pixelscale.pas`: Scale2x/3x/4x on sprite + mask as RGBA) with tests; the scaled canvas | unit test of the scaler; a sprite sheet rendered at 1×–4× looks right ✅ |
| R2 | The main window resizable and full screen: title screen, map, status panel, toolbar through the scaled canvas; mouse mapping | the window at 640×480 … 4K shows the same picture, crisp; clicks hit as before ✅ |
| R3 | The dialogs scaled: template layout and fonts × `s`, the painted parts (troop grids, unit card, portraits, the war map, the crown) through the scaled canvas | every dialog of the autopilot sweep at 1× and 2× ✅ |
| R4 | The battle window scaled (map, units, status panels, buttons, cursors) | autopilot battles at 1× and 2× ✅ |
| R5 | The original's bugs fixed (list below), each with a test; the differential tests stay green where the rules are untouched | ✅ |
| R6 | A better scaler (xBRZ-style edge detection) replacing ScaleNx; quality settings | side-by-side shots |
| R7 | The Windows build of the remastered game; packaging | the zip like `main`'s |

## The original's bugs (R5)

Fixed in the remastered game (`port/tests/fixtest.pas` checks the first three; the rest are
guards where the original wrote past its buffers or looped):

| Bug of the original | Fix |
|---|---|
| `Ai_ArrangeArmies` sorts into a 16-entry array: 17 units (8 Heer, 9 Garde, e.g. after sabotage action 6) overran the stack and crashed | room for 17 (`port/src/ai.pas`) |
| `FormatThousands`: numbers of 10 digits shown empty (and written 11,520 bytes off) | grouped like the others; also −2,147,483,648 |
| `UnitRankName` on an empty army slot read past the 11 rank names and overflowed 26 bytes | levels beyond Elite count as Elite |
| The battle: `StopTimer` → `AiStep` recursed endlessly for a certain retreat (a fleeing hero) | no new WM_TIMER from inside the one `StopTimer` sent (`port/src/battle.pas`) |
| The text dialogs of segment 12 copied their texts unchecked into 81-byte buffers | at most 80 characters (`CopyArg`); PromotionDlg too |
| PlunderChoiceDlg: long titles ran past its 51-byte texts | at most 50 |
| ButtonChoiceDlg: 0 buttons made a 256-turn byte loop | 1..10 buttons |
| CENSUSDLG: a sex byte other than 0/1 picked a garbage radio button | non-zero counts as female |

Already safe in the port (no change needed): KORNDLG's gauge (the GUI draws no gauge),
GUETERHANDELDLG's 11-byte labels (16-byte buffers), GEHEIMDLG's division by the land (0 %),
CENSUSDLG's "zurück" at the first player (within the ten players), the 1024×768 toolbar index
(clamped).

The differential tests stay as on `main` except for two vectors that hit a fixed bug
(`UnitRankName` / `Do_UnitEditDlg` with a garbage level: the original showed an empty name),
removed from `rules.vec` / `actions.vec`.
