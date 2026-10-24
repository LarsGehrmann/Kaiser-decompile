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
| R1 | Branch, this plan; the scaler (`port/gui/pixelscale.pas`: Scale2x/3x/4x on sprite + mask as RGBA) with tests; the scaled canvas | unit test of the scaler; a sprite sheet rendered at 1×–4× looks right |
| R2 | The main window resizable and full screen: title screen, map, status panel, toolbar through the scaled canvas; mouse mapping | the window at 640×480 … 4K shows the same picture, crisp; clicks hit as before |
| R3 | The dialogs scaled: template layout and fonts × `s`, the painted parts (troop grids, unit card, portraits, the war map, the crown) through the scaled canvas | every dialog of the autopilot sweep at 1× and 2× |
| R4 | The battle window scaled (map, units, status panels, buttons, cursors) | autopilot battles at 1× and 2× |
| R5 | The original's bugs fixed (list below), each with a test; the differential tests stay green where the rules are untouched | the list done; ruletest suites pass |
| R6 | A better scaler (xBRZ-style edge detection) replacing ScaleNx; quality settings | side-by-side shots |
| R7 | The Windows build of the remastered game; packaging | the zip like `main`'s |

## The original's bugs to fix (R5)

From the reverse engineering (docs/phase3.md, docs/rules/*):

- `Ai_ArrangeArmies` sorts all units in a 16-entry local array: a computer player with 17 units
  (sabotage action 6 lets a deserter join a full Garde; a human with an overfull Garde who
  becomes a computer player) overruns the stack and crashes.
- KORNDLG with fewer than 20 inhabitants: the gauge divides by 0 (runtime error 200).
- GUETERHANDELDLG: an 11-byte label buffer next to the loop counter (a number below
  −999,999,999 makes an endless loop).
- GEHEIMDLG: the Landausbau row divides by the player's land (runtime error 200 without land).
- CENSUSDLG: "zurück" at the first player shows player 255 (heap garbage); a sex byte other
  than 0/1 picks a garbage radio button.
- UNITEDITDLG on an empty army slot: `UnitRankName` overflows a 26-byte buffer.
- The text dialogs of segment 12 copy their texts unchecked into 81-byte buffers (and
  PromotionDlg, MassacreDlg, PlunderChoiceDlg into theirs).
- ButtonChoiceDlg: 0 or more than 10 buttons write past the object.
- `FormatThousands`: numbers of 10 digits are shown empty (and written 11,520 bytes off).
- The battle: `StopTimer` → `AiStep` endless recursion (docs/rules/battle.md).
- 1024×768: the toolbar enables tools up to index 72 (runtime error 213).
- More as they turn up (each documented here with its fix).
