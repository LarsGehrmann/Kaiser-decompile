# Kaiser Remastered (branch `remastered`)

The branch `main` keeps the faithful port: the same behaviour as the original, checked by the
differential tests. The branch `remastered` builds a modernised game on top of it.

## Decisions (2026-10-24)

- **Graphics:** a pixel-art scaler computed by the game when a picture is first needed
  (xBRZ-style edge blending; ScaleNx and plain big pixels to choose): sharp at any size, the
  original look, no external tools.
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
| R6 | A better scaler (xBRZ-style edge detection) replacing ScaleNx; quality settings | ✅ `port/src/xbrz.pas` (2×–4×, larger factors in exact big pixels on top); patterns scaled seamlessly (3×3 tiles); Windows-transparent bitmaps keyed first; menu "Grafik" (weich / scharf / Pixel), INI key `Grafik` |
| R7 | The Windows build of the remastered game; packaging | ✅ built (`port/build-win.sh`, `port/package-win.sh` with `scaletest` and `fixtest`); not yet run on Windows |

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

## Visual review (2026-10-24)

The main window, the dialogs and the battle were captured at 1×, ~1.2×, 1.5×, 2× and in odd
window shapes (letterboxed wide / tall, live resizing, the 1024×768 layout). Found and fixed:

| Seen | Fix |
|---|---|
| The panel photos (castle, cathedral) blotchy from the pixel-art scaler | pictures of more than 64 colours are scaled smoothly (`IsPhoto`, `ScaleSmooth`) |
| A lighter box around the troop grids at fractional scales | the dialog colour keyed out before the painted parts are stretched |
| "Asylrecht:" cut off at 1.2× | the dialog base units unrounded when scaled |
| Push buttons: macOS keeps the rounded button 21 pt high, the scaled caption ran out of it | `TFlexButton` (`macappearance.pas`): the square bezel, which fills the template's rectangle like Windows' button, set again whenever LCL re-creates the native button |
| The spin buttons of SABOTAGEBUDGETDLG stayed tiny (macOS' stepper has fixed sizes) | on macOS a `TWinScrollBar` in spin mode (two arrows) |
| SS_ICON "BOMBE" showed the 16-pixel bitmap of that name | SS_ICON loads the icon first, as Windows does (BOMBE, LAGER) |
| The menu "Hilfe" handed `docs/manual.md` to another program (none on Windows for .md) | the help window shows the contents; topics with their links, "Inhalt" / "Zurück", scaled like the dialogs |

Seen and kept: the dark bars when the window's shape differs from the game's; the battle window's
7-pixel strip under the status panels (the original's window size); the original's texts
("erkärte", "verfübar") and layouts.

Test hooks: `KAISER_WINDOWSIZE=WxH` (start size), `KAISER_RESIZE=WxH` (resized after 3 s),
`KAISER_STAY=1` (the window stays open after the autopilot, also the help window).
