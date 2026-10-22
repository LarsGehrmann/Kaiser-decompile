# Segment 8 (Ghidra 1038:xxxx) – diplomacy, intelligence, war target, census editor, troop dialog

All 149 functions of segment 8. Names come from `tools/ghidra/names/*.csv` (later files win);
names marked `*` are new in `92_seg08.csv`. Dialog types are named after their VMT in DS
(see `docs/owl-tables.md`); for every type here VMT slot 12 (+38h) is `SetupWindow`, slot 13
(+3Ch) `CanClose`, +4Ch `Execute`, +08h `Done`. Dialog objects hold copies of player records:
GEHEIMDLG and SABOTAGEBUDGETDLG at +0x34, CENSUSDLG, UNITEDITDLG and the amount dialog at
+0x2e, GEGNERDLG at +0x48, ANORDNENDLG at +0x34 (subtract to get the TPlayer offset).

Common helpers used here (other segments): `1058:01bb` dialog-with-help-button constructor
(help context id), `1058:004a` base SetupWindow, `1058:06d2` player-choice dialog (type DS:357a),
`1068:6b29` long → string, `1060:03d9` "title name von country" string of a player.

### Intelligence – GEHEIMDLG (type DS:10ca)

| Address | Name | Purpose |
|---|---|---|
| 1038:0002 | `Do_Geheimdienst` | Menu Geheimdienst: runs GEHEIMDLG, then copies the player records back |
| 1038:0060 | `GeheimDlg::Init` * | Constructor (type DS:10ca): player copies, 4 dossier columns, precomputed estimates |
| 1038:090e | `GeheimDlg::SetupWindow` * | SetupWindow (VMT slot 12) -> ShowPage |
| 1038:092a | `GeheimDlg::ShowPage` * | Fills the 4 visible dossier columns; distorts other players' figures for non-Ambassadors |
| 1038:16ab | `GeheimDlg::CopyPlayersBack` * | Copies the dialog's player records back to the game |
| 1038:1704 | `T10ca::IdCtl601` | "<-": page one player left |
| 1038:171a | `T10ca::IdCtl602` | "->": page one player right |
| 1038:1730 | `T10ca::IdCtl501` | Army button of column 1: Do_TruppenAufstellen mode 0 (own) / 5 (view other); enabled for self or Ambassador |
| 1038:1772 | `T10ca::IdCtl502` | Army button of column 2: Do_TruppenAufstellen mode 0 (own) / 5 (view other); enabled for self or Ambassador |
| 1038:17be | `T10ca::IdCtl503` | Army button of column 3: Do_TruppenAufstellen mode 0 (own) / 5 (view other); enabled for self or Ambassador |
| 1038:180c | `T10ca::IdCtl504` | Army button of column 4: Do_TruppenAufstellen mode 0 (own) / 5 (view other); enabled for self or Ambassador |
| 1038:185c | `T10ca::IdCtl701` | Sabotage button of column 1: own column -> Do_Sabotage (budget), other -> SabotageStrike |
| 1038:18bf | `T10ca::IdCtl702` | Sabotage button of column 2: own column -> Do_Sabotage (budget), other -> SabotageStrike |
| 1038:192e | `T10ca::IdCtl703` | Sabotage button of column 3: own column -> Do_Sabotage (budget), other -> SabotageStrike |
| 1038:199f | `T10ca::IdCtl704` | Sabotage button of column 4: own column -> Do_Sabotage (budget), other -> SabotageStrike |

### Shared diplomacy helpers – recipient choice and ABFRAGE*DLG amount dialog (type DS:0ffa)

| Address | Name | Purpose |
|---|---|---|
| 1038:1a12 | `ChooseDiplomacyTarget` * | Choose recipient (SPENDE/TRADE/TRIBUT/SABOAUSWAHLDLG); refuses when the mailbox slot is used (NOAUSWAHLDLG) |
| 1038:1b8c | `AmountDlg::Init` * | Constructor of the ABFRAGE*DLG amount dialog (type DS:0ffa) |
| 1038:1bfb | `AmountDlg::SetupWindow` * | SetupWindow: scroll range per mode (Taler/land/people/years) |
| 1038:1d40 | `AmountDlg::ShowValue` * | Shows the current amount |
| 1038:1dc4 | `AmountDlg::CanClose` * | CanClose: scales Taler/land by 100 |
| 1038:1e0a | `T0ffa::IdCtl101` | Scrollbar 101 moved -> ShowValue |

### Treaties – ABKOMMENDLG (type DS:0f94)

| Address | Name | Purpose |
|---|---|---|
| 1038:1e35 | `Do_Abkommen` | Menu Abkommen: peace offer (type 9, years), trade offer (5) or cancel trade (6, -2 fame); KURIERDLG |
| 1038:2107 | `AbkommenDlg::Init` * | Constructor of ABKOMMENDLG (type DS:0f94) |
| 1038:21a1 | `AbkommenDlg::SetupWindow` * | SetupWindow: disables impossible treaty options |
| 1038:222c | `AbkommenDlg::UpdateRadios` * | Updates the radio buttons |
| 1038:2284 | `T0f94::IdCtl201` | Radio 201: choice 0 (Friedensvertrag) |
| 1038:229a | `T0f94::IdCtl202` | Radio 202: choice 1 (Handelsvertrag) |
| 1038:22b0 | `T0f94::IdCtl203` | Radio 203: choice 2 (Handelsvertrag kuendigen) |
| 1038:22c6 | `AbkommenDlg::CanClose` * | CanClose: True |

### Aid – SPENDENDLG (type DS:0ea4)

| Address | Name | Purpose |
|---|---|---|
| 1038:22d5 | `Do_Entwicklungshilfe` | Menu Entwicklungshilfe: Taler, land, troops or people to another player (mailbox type 1) |
| 1038:2ad6 | `SpendenDlg::Init` * | Constructor of SPENDENDLG (type DS:0ea4) |
| 1038:2b72 | `SpendenDlg::SetupWindow` * | SetupWindow: disables options that are not possible |
| 1038:2bf5 | `SpendenDlg::UpdateRadios` * | Updates the radio buttons |
| 1038:2c4d | `T0ea4::IdCtl201` | Radio 201: choice 0 (Taler) |
| 1038:2c63 | `T0ea4::IdCtl202` | Radio 202: choice 1 (Laendereien) |
| 1038:2c79 | `T0ea4::IdCtl203` | Radio 203: choice 2 (Truppen) |
| 1038:2c8f | `T0ea4::IdCtl204` | Radio 204: choice 3 (Sklaven) |
| 1038:6a93 | `ChooseUnitToGive` * | "Truppen": ANORDNENDLG mode 4 to pick the unit to give away |

### Tribute – TRIBUTDLG (type DS:0f22)

| Address | Name | Purpose |
|---|---|---|
| 1038:2ca5 | `Do_TributFordern` | Menu Tribut fordern: Taler, land, people, trade agreement or peace (mailbox type 2); -1 fame unless Ambassador |
| 1038:31fe | `TributDlg::Init` * | Constructor of TRIBUTDLG (type DS:0f22) |
| 1038:329a | `TributDlg::SetupWindow` * | SetupWindow: disables impossible demands |
| 1038:3310 | `TributDlg::UpdateRadios` * | Updates the radio buttons |
| 1038:3368 | `T0f22::IdCtl201` | Radio 201: choice 0 (Taler) |
| 1038:337e | `T0f22::IdCtl202` | Radio 202: choice 1 (Laendereien) |
| 1038:3394 | `T0f22::IdCtl203` | Radio 203: choice 2 (Sklaven) |
| 1038:33aa | `T0f22::IdCtl204` | Radio 204: choice 3 (Handelsvertrag) |
| 1038:33c0 | `T0f22::IdCtl205` | Radio 205: choice 4 (Frieden) |
| 1038:33d6 | `TributDlg::CanClose` * | CanClose: maps the choice to the mailbox sub-type |

### Sabotage – SABOTAGEWAHLDLG (DS:1306), SABOTAGEBUDGETDLG (DS:13d2)

| Address | Name | Purpose |
|---|---|---|
| 1038:3411 | `SabotageWahlDlg::Init` * | Constructor of SABOTAGEWAHLDLG (type DS:1306) |
| 1038:34c3 | `SabotageWahlDlg::SetupWindow` * | SetupWindow: target name |
| 1038:34ec | `T1306::IdCtl201` | Category button 201 (Zuendeln und Kokeln): EndDlg(1) |
| 1038:3500 | `T1306::IdCtl202` | Category button 202 (Diffamieren): EndDlg(2) |
| 1038:3514 | `T1306::IdCtl203` | Category button 203 (Kampfkraft zersetzen): EndDlg(3) |
| 1038:3528 | `T1306::IdCtl204` | Category button 204 (Ruinieren): EndDlg(4) |
| 1038:353c | `T1306::IdCtl205` | Category button 205 (Anschlag auf Leib und Leben): EndDlg(5) |
| 1038:3550 | `T1306::IdCtl206` | "Lieber doch nichts!": EndDlg(0) |
| 1038:3564 | `Do_Sabotage` | Menu Sabotage: SABOTAGEBUDGETDLG, copies the players back |
| 1038:35bf | `SabotageStrike` * | One sabotage operation: category -> random SabotageAction type, result dialogs |
| 1038:38ef | `SabotageBudgetDlg::Init` * | Constructor of SABOTAGEBUDGETDLG (type DS:13d2) |
| 1038:3aef | `SabotageBudgetDlg::SetupWindow` * | SetupWindow: countries, budget scrollbars 0..(title+1)*500 Taler |
| 1038:3c4a | `SabotageBudgetDlg::UpdateRows` * | Refreshes agents, budget, years and Zuschlagen buttons |
| 1038:3e13 | `SabotageBudgetDlg::BudgetScrolled` * | Budget scrollbar of a row moved |
| 1038:3f38 | `SabotageBudgetDlg::CopyPlayersBack` * | Copies the dialog's player records back to the game |
| 1038:3f55 | `SabotageBudgetDlg::Strike` * | Zuschlagen of a row -> SabotageStrike |
| 1038:3f92 | `T13d2::IdCtl301` | Budget scrollbar 301 -> BudgetScrolled(0) |
| 1038:3fa5 | `T13d2::IdCtl302` | Budget scrollbar 302 -> BudgetScrolled(1) |
| 1038:3fb8 | `T13d2::IdCtl303` | Budget scrollbar 303 -> BudgetScrolled(2) |
| 1038:3fcb | `T13d2::IdCtl304` | Budget scrollbar 304 -> BudgetScrolled(3) |
| 1038:3fde | `T13d2::IdCtl305` | Budget scrollbar 305 -> BudgetScrolled(4) |
| 1038:3ff1 | `T13d2::IdCtl306` | Budget scrollbar 306 -> BudgetScrolled(5) |
| 1038:4004 | `T13d2::IdCtl307` | Budget scrollbar 307 -> BudgetScrolled(6) |
| 1038:4017 | `T13d2::IdCtl308` | Budget scrollbar 308 -> BudgetScrolled(7) |
| 1038:402a | `T13d2::IdCtl309` | Budget scrollbar 309 -> BudgetScrolled(8) |
| 1038:403d | `T13d2::IdCtl501` | "Zuschlagen!" 501 -> Strike(0) |
| 1038:4050 | `T13d2::IdCtl502` | "Zuschlagen!" 502 -> Strike(1) |
| 1038:4063 | `T13d2::IdCtl503` | "Zuschlagen!" 503 -> Strike(2) |
| 1038:4076 | `T13d2::IdCtl504` | "Zuschlagen!" 504 -> Strike(3) |
| 1038:4089 | `T13d2::IdCtl505` | "Zuschlagen!" 505 -> Strike(4) |
| 1038:409c | `T13d2::IdCtl506` | "Zuschlagen!" 506 -> Strike(5) |
| 1038:40af | `T13d2::IdCtl507` | "Zuschlagen!" 507 -> Strike(6) |
| 1038:40c2 | `T13d2::IdCtl508` | "Zuschlagen!" 508 -> Strike(7) |
| 1038:40d5 | `T13d2::IdCtl509` | "Zuschlagen!" 509 -> Strike(8) |

### War target – GEGNERDLG (type DS:1498)

| Address | Name | Purpose |
|---|---|---|
| 1038:40e8 | `DeclareWar` | Krieg fuehren: checks (title, Heer, initiative), GEGNERDLG, breaking peace costs 50 fame |
| 1038:4379 | `GegnerDlg::Init` * | Constructor of GEGNERDLG (type DS:1498) |
| 1038:452f | `GegnerDlg::SetupWindow` * | SetupWindow: target list, own initiative |
| 1038:45e7 | `T1498::WMPaint` | WM_PAINT -> DrawMap |
| 1038:4620 | `GegnerDlg::IsValidTarget` * | Target filter, always True |
| 1038:462f | `GegnerDlg::DrawMap` * | Draws the country map coloured by attack cost vs. initiative |
| 1038:4b8d | `GegnerDlg::UpdateCost` * | Shows the initiative cost of the selected target |
| 1038:4c03 | `GegnerDlg::CanClose` * | CanClose: confirm peace breach / army wintering abroad |
| 1038:4d27 | `GegnerDlg::GetTarget` * | Returns the chosen target |
| 1038:4d3c | `T1498::IdCtl101` | Combo 101 changed -> UpdateCost |

### Census editor – PASSWORDDLG (DS:155a), CENSUSDLG (DS:15ec), SZENARIENDLG (DS:1640), UNITEDITDLG (DS:16ae)

| Address | Name | Purpose |
|---|---|---|
| 1038:4d68 | `CensusEditor` | Ctrl+P: PASSWORDDLG (hero name), then CENSUSDLG if census_editor_enabled |
| 1038:4e45 | `Do_SzenarioDlg` * | Runs SZENARIENDLG (scenario year, title, description, author) |
| 1038:4e84 | `SzenarioDlg::Init` * | Constructor of SZENARIENDLG (type DS:1640) |
| 1038:4f31 | `SzenarioDlg::SetupWindow` * | SetupWindow: fills the four edits from the header |
| 1038:4fa0 | `SzenarioDlg::CanClose` * | CanClose: writes year, title, description, author to the header |
| 1038:503d | `Do_UnitEditDlg` * | Runs UNITEDITDLG "Trainingscenter" for one unit (census mode) |
| 1038:50a0 | `UnitEditDlg::Init` * | Constructor of UNITEDITDLG (type DS:16ae) |
| 1038:51e3 | `UnitEditDlg::SetupWindow` * | SetupWindow: hero portrait range, ability list |
| 1038:527d | `UnitEditDlg::CanClose` * | CanClose: ApplyValues |
| 1038:5296 | `UnitEditDlg::ShowValues` * | Shows the unit's values |
| 1038:5423 | `UnitEditDlg::ApplyValues` * | Writes the edited values back to the unit |
| 1038:56b9 | `UnitEditDlg::DrawPortrait` * | Draws the unit/hero bitmap |
| 1038:5872 | `T16ae::WMPaint` | WM_PAINT -> DrawPortrait |
| 1038:58ab | `T16ae::IdCtl103` | Portrait scrollbar moved (heroes) |
| 1038:58d0 | `T16ae::IdCtl105` | "Befoerderung": UnitGainExperience(level*2+10) = one promotion |
| 1038:590a | `CensusDlg::Init` * | Constructor of CENSUSDLG (type DS:15ec) |
| 1038:5b52 | `CensusDlg::SetupWindow` * | SetupWindow: combos, KI/aggression ranges |
| 1038:5bec | `CensusDlg::CanClose` * | CanClose: ApplyPlayer |
| 1038:5c05 | `CensusDlg::ShowPlayer` * | Shows the current player's values |
| 1038:60c6 | `CensusDlg::ApplyPlayer` * | Writes the edited values back |
| 1038:6800 | `T15ec::IdCtl501` | Radio XY (male) |
| 1038:6829 | `T15ec::IdCtl502` | Radio XX (female) |
| 1038:6852 | `T15ec::IdCtl601` | KI scrollbar moved: show value |
| 1038:688a | `T15ec::IdCtl701` | Aggression scrollbar moved: show value |
| 1038:68c2 | `T15ec::IdCtl301` | "->": next player |
| 1038:690b | `T15ec::IdCtl302` | "<-": previous player |
| 1038:6947 | `T15ec::IdCtl303` | "Uebernehmen": ApplyPlayer |
| 1038:6958 | `T15ec::IdCtl401` | "Armee": Do_TruppenAufstellen mode 6 for the shown player |
| 1038:697e | `T15ec::IdCtl402` | "Spieldaten": Do_SzenarioDlg |
| 1038:698d | `PasswordDlg::Init` * | Constructor of PASSWORDDLG (type DS:155a) |
| 1038:69dc | `PasswordDlg::SetupWindow` * | SetupWindow (base only) |
| 1038:69ed | `PasswordDlg::CanClose` * | CanClose: reads the password text |
| 1038:6a15 | `PasswordDlg::GetPassword` * | Returns the entered password |

### Troop dialog – ANORDNENDLG (type DS:1776)

| Address | Name | Purpose |
|---|---|---|
| 1038:6a30 | `Do_TruppenAufstellen` | Menu Truppen aufstellen / generic troop dialog in a given mode; copies the player back on OK |
| 1038:6b38 | `TroopDlg::Init` * | Constructor of ANORDNENDLG (type DS:1776), mode 0..6 |
| 1038:6dcf | `TroopDlg::SetupWindow` * | SetupWindow: caption by mode, layout |
| 1038:718e | `TroopDlg::CanClose` * | CanClose: Garde too big / no Heer / militia warnings |
| 1038:72bf | `TroopDlg::UpdateButtons` * | Enables the buttons for the current selection |
| 1038:7992 | `TroopDlg::ShowTreasury` * | Shows Taler, weapons and yearly pay |
| 1038:7a70 | `TroopDlg::UpdateSelState` * | Derives the selection state |
| 1038:7ae5 | `TroopDlg::CountSelected` * | Counts selected units |
| 1038:7b2c | `TroopDlg::ToggleHeerUnit` * | Click on a Heer slot |
| 1038:7bf8 | `TroopDlg::ToggleGardeUnit` * | Click on a Garde slot |
| 1038:7cc4 | `TroopDlg_Swap` | <=>: swap/move selected units between Heer and Garde |
| 1038:7fac | `TroopDlg_Dismiss` | Entlassen: dismiss the selected unit |
| 1038:80cb | `TroopDlg_Special` | Spezial: fief (BELEIHENDLG), knighting (RITTERSCHLAGDLG) or unit editor (mode 6) |
| 1038:8315 | `TroopDlg_RecruitHeer` | Recruit into the Heer |
| 1038:837d | `TroopDlg_RecruitGarde` | Recruit into the Garde |
| 1038:83e5 | `TroopDlg_SwapAll` | Swap whole Heer and Garde |
| 1038:843d | `TroopDlg_Pay` | Sold: pay the selected unit |
| 1038:84a1 | `TroopDlg::DrawHeer` * | Draws the Heer grid |
| 1038:8699 | `TroopDlg::DrawGarde` * | Draws the Garde grid |
| 1038:8921 | `TroopDlg::DrawUnitInfo` * | Draws the info card of the hovered unit |
| 1038:8f5a | `T1776::WMPaint` | WM_PAINT: grids and info card |
| 1038:8fc8 | `T1776::WMLButtonDown` | WM_LBUTTONDOWN: select units in the grids |
| 1038:91ff | `T1776::WMMouseMove` | WM_MOUSEMOVE: hover unit -> DrawUnitInfo |

### Segment initialisation

| Address | Name | Purpose |
|---|---|---|
| 1038:9504 | `Seg8_UnitInit` * | Empty unit-initialisation stub (called from entry) |

## Findings

New rules / data, or corrections to `docs/rules/*.md` and `tools/kaiser_structs.py`:

1. **`year_factor_q` (TPlayer 0x5f0) is the intelligence inaccuracy factor.** Its only reader
   is `GeheimDlg::ShowPage` (1038:092a, e.g. 1038:0da0). Unless the viewer is the
   Ambassador (spell 1; `GeheimDlg::Init` stores 0 instead of the year in +0x448b) the
   dossier of another player shows *value × viewer's year_factor* (0.5 … 2.0) for:
   population when (player + year) is odd, land when it is even, net income unless
   (player + year) mod 3 = 1, treasury unless it is 2. Treasury and income are rounded down
   to 1000 (1038:076e), population is rounded up to the next 200 (below 2000) or 1000 (1038:0de2). So the manual's "only the Ambassador
   sees everything" is implemented as random distortion, not hidden fields.
2. **Dossier details** (1038:0060/092a): army class from `ArmyStrength` < 30 bäuerlich,
   < 60 tüchtig, < 100 fürstlich, else königlich; "Landausbau" = max(markets, mills) ×
   100000 / land (rounded to 10, %); "Handelsvolumen" = (markets × 155 + mills × 330) /
   (num_players + 6) (same as TradeAgreementIncome); "Frieden: bis <year>". The troop
   button is enabled for oneself and for the Ambassador only; it opens the troop dialog in
   view mode 5.
3. **New TPlayer fields**: 0x586 `sabotage_agents[10]` (byte per target, shown as
   "Agenten" and as caption of the Geheimdienst sabotage button; strikes need > 0),
   0x598 `sabotage_budget[10]` (byte per target, × 100 Taler; scrollbar range
   0 … (title + 1) × 5, i.e. at most (title + 1) × 500 Taler; `SabotageBudgetDlg`
   1038:3aef/3e13), 0x5d3 `units_given_away` (+1 per unit given as aid, 1038:22d5),
   0x09f `aid_balance_q` (running total, − Taler given / + Taler received, 1038:22d5).
4. **New header fields** (scenario editor, 1038:4f31/4fa0): header+0x52 `scenario_title`
   (char[40], DS:615a), +0x7b `scenario_author` (char[24], DS:6183), +0x94
   `scenario_description` (char[512], DS:619c – ends exactly at the header size 0x295).
5. **Sabotage categories** (`SabotageStrike` 1038:35bf; SABOTAGEWAHLDLG): the player picks a
   category, the concrete `SabotageAction` type is random: Zündeln und Kokeln → 2 (palace)
   if the target has ≥ 2 palace parts, else one of 1 (mills) / 3 (warehouse) / 4;
   Diffamieren → 7 / 8 / 9; Kampfkraft zersetzen → 4 / 5 / 6 / 11; Ruinieren → 13 (1 in 5)
   else 14; Anschlag auf Leib und Leben → 10 / 11 / 12. Failure: SABOTAGEVERSAGT1DLG (agent
   escaped) or SABOTAGEVERSAGT2DLG (caught); success text is string 700 + type (escaped) or
   750 + type.
6. **Aid is transferred at once, not at the recipient's next turn** (contradicts
   diplomacy.md "Aid arrives at the start of the recipient's next turn"): `Do_Entwicklungshilfe`
   moves Taler and land (`1068:41d5`, lost buildings → VERLUSTDLG) and the unit immediately;
   only the message waits in the mailbox. People ("Sklaven") are removed from the donor at
   once and added to the recipient's immigrants when the message is read
   (`Msg_ReceiveAid` 1010:0467 sub-type 3).
   Limits: Taler ≥ 100, in steps of 100; land only to neighbours (attack cost ≤ 2) and
   only if free land (land − land_used) ≥ 12100, at most (free − 12000) / 100 × 100 Hufen;
   people need pop ≥ 51, at most min(pop − 50, 10000); troops only unit types with
   `UnitCanDesert` and only if the recipient has room (Heer if < 8 and at home, else Garde);
   a Heldentum (spell 9) recipient promotes a level-0 gift unit.
7. **Tribute demand costs the demander 1 fame** unless he is the Ambassador (1038:2ca5, end).
   Land can only be demanded from a neighbour with free land > 12100; peace years 5 … 50
   (`AmountDlg` mode 4, also for peace offers in `Do_Abkommen`). Mailbox sub-types of type
   2: 0 Taler, 1 land, 3 people, 4 peace (years), 5 trade agreement.
8. **One message per sender and recipient**: `ChooseDiplomacyTarget` (1038:1a12) refuses a
   recipient whose mailbox slot for this sender is still occupied (NOAUSWAHLDLG). Its
   SABOAUSWAHLDLG branch (mode −1) has no caller – dead code.
9. **War target dialog**: `GegnerDlg::CanClose` (1038:4c03) asks for confirmation when the
   attack cost exceeds the remaining initiative (HEERWEGDLG – the Heer will winter abroad)
   and when a peace treaty would be broken (CONFIRMPEACEBUSTDLG). The map (1038:462f)
   colours own country yellow, affordable targets green, too expensive ones red.
10. **Troop dialog modes** (`TroopDlg::Init` +0x709): 0 own troops (menu), 1/2 set up the Heer
    before a field battle, 3 set up the Garde for the city battle (MILIZDLG warning when the
    Heer is home but the Garde empty), 4 choose a unit to give away, 5 view another player's
    troops (Geheimdienst), 6 census editor (Spezial opens UNITEDITDLG "Trainingscenter").
    Closing with more than 8 Garde units is refused (MUSTDISMISSDLG).
11. **Census editor**: KI scrollbar 0 … 6 = `cpu_level`, "Agressivität" 1 … 6 =
    `ai_aggression_q`; "Mä und Mü" shows max(markets, mills) and writes the value into
    both. "Beförderung" in the unit editor gives exactly one promotion
    (UnitGainExperience with level × 2 + 10).

Existing name that looks wrong (outside this segment, not changed): `Do_Info` (1058:0002) is
not a menu action but the constructor every game dialog is built on (it calls
`OWL::TDialog_Init` and sets a flag bit 0x40); it is called 24 times in this segment, as base constructor of the dialog types and with
VMT DS:3364 for simple message dialogs. Suggested name: `KaiserDlg::Init`.
