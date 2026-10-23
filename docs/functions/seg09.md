# Segment 9 (Ghidra 1040:xxxx) – economy, statistics, new game, high scores, recruiting

All 194 functions of segment 9. Names come from `tools/ghidra/names/*.csv` (later files win);
names marked `*` are new in `93_seg09.csv`. Dialog types are named after their VMT in DS
(see `docs/owl-tables.md`); for every type here VMT slot 12 (+38h) is `SetupWindow`, slot 13
(+3Ch) `CanClose`, slot 0 (+08h) `Done`, +4Ch `Execute`, +54h `SetHelpContext` (1058:0210,
sets +0x2e). Player-record copies inside the dialog objects: GUETERHANDELDLG, PROKURADLG,
KARRIEREDLG, REKRUTDLG, KORNDLG, UNITLOOKDLG (unit) at +0x34; WIRTSTATDLG, MILSTATDLG at
+0x2e; DemographyDlg (BEVDLG) at +0x36; caravan at +0x5c; INVESTDLG at +0x62; STEUERDLG at
+0x64; LANDDLG and RANGLISTENDLG hold all players from +0x34 / +0x2f (subtract to get the
TPlayer offset).

Common helpers used here (other segments): `1058:0002` (`Do_Info`, really the base dialog
constructor), `1058:01bb` dialog-with-help-button constructor (help id at +0x2e, button 999),
`1058:004a` base SetupWindow (centres the dialog), `1058:0166` base Done, `1068:6b29` long →
string, `1068:6b58` long → string with thousands separators, `1060:03d9` "title name von
country" string of a player, `1068:0ae8` CanAfford(cost) = taler − cost ≥ −CreditLimit,
`1068:1df2` (`GrainCost_q`) = credit limit, `1068:12fe` player score.

### Scenario info – SZENARIENINFODLG (type DS:18f2)

| Address | Name | Purpose |
|---|---|---|
| 1040:0002 | `ScenarioInfoDlg::Init` * | Constructor; opened by CmSpiel when the header holds a scenario title (else SZENARIENINFONODLG) |
| 1040:008e | `ScenarioInfoDlg::SetupWindow` * | Shows header+0x52 (title), "von " + header+0x7b (author), header+0x94 (description, 512 chars) |

### Unit pay – SOLDDLG (type DS:2008)

Ported: `port/src/troops.pas` (`ShowPayDlg`, `TPayDlg`).

| Address | Name | Purpose |
|---|---|---|
| 1040:00f7 | `ShowPayDlg` * | Called by TroopDlg_Pay: runs SOLDDLG for one unit |
| 1040:013c | `PayDlg::Init` * | Constructor: unit pointer, current pay and base pay |
| 1040:01f4 | `PayDlg::SetupWindow` * | Unit name; slider range base_pay/2 … base_pay×2 |
| 1040:0247 | `PayDlg::UpdatePayLabel` * | Slider position and pay label |
| 1040:0288 | `PayDlg::CanClose` * | Writes the new pay to the unit (+0x2b), clears unit+0x37 |
| 1040:02b2 | `T2008::IdCtl101` | Slider moved: new pay → UpdatePayLabel |

### Country names – LAENDERNAMENDLG (type DS:2072)

| Address | Name | Purpose |
|---|---|---|
| 1040:02d5 | `Do_Laendernamen` | Menu Ländernamen: runs the dialog |
| 1040:0314 | `CountryNamesDlg::Init` * | Constructor: 10 name edits (101–110), 10 adjective edits (201–210), button 200 |
| 1040:03e2 | `CountryNamesDlg::SetupWindow` * | Fills the edits from DS:63a8 (names) / DS:6696 (adjectives) |
| 1040:044f | `T2072::IdCtl200` | "Voreinstellung": restores the default names (CountryNames, DS:4878) |
| 1040:04f7 | `CountryNamesDlg::CanClose` * | Stores the edits back into DS:63a8 / DS:6696 |

### Building losses – VERLUSTDLG & co. (type DS:20d6)

| Address | Name | Purpose |
|---|---|---|
| 1040:0565 | `ShowBuildingLossDlg` * | Shows a loss record (money + 9 building counts) in VERLUSTDLG, BANKPFANDDLG, KAPUTTDLG, BRANDDLG …; 10 callers |
| 1040:05ae | `BuildingLossDlg::Init` * | Constructor: copies the 0x37-byte record; static 201 only with the money flag |
| 1040:066f | `BuildingLossDlg::SetupWindow` * | Fills statics 101–109 (and 201) |

### Caravans and warehouses (caravan dialog type DS:2152)

| Address | Name | Purpose |
|---|---|---|
| 1040:081e | `AskWarehousesFull` | LAGERVOLLDLG: warehouses full, choose what to do |
| 1040:08a2 | `TradeCaravan` | Random salt/beer/wine/weapons caravan: intro (Ja/Nein), offer dialog, payment, or "_III" farewell |
| 1040:1070 | `CaravanDlg::Init` * | Constructor of *KARAWANEDLG_II: 3 radio buttons, 5 statics |
| 1040:1179 | `CaravanDlg::SetupWindow` * | Offer texts, disables unaffordable / too large offers, free space and treasury |
| 1040:1341 | `CaravanDlg::CanClose` * | Takes the chosen offer; price per Last minus 0/1/2 |
| 1040:139b | `CaravanDlg::UpdateRadioButtons` * | Checks the chosen offer's radio button |
| 1040:13f4 | `T2152::IdCtl101` | Choose offer 1 |
| 1040:140b | `T2152::IdCtl102` | Choose offer 2 |
| 1040:1422 | `T2152::IdCtl103` | Choose offer 3 |

### Goods trade – GUETERHANDELDLG (type DS:1ab8) and Prokurist – PROKURADLG (type DS:1a3a)

| Address | Name | Purpose |
|---|---|---|
| 1040:1439 | `Do_HandelMitGuetern` | Menu Handel mit Gütern: runs GUETERHANDELDLG on a player copy, copies back on OK |
| 1040:14a9 | `GoodsDlg::Init` * | Constructor: 4 sliders (301–304), stock/price/sold labels, Prokurist button 601 |
| 1040:165b | `GoodsDlg::SetupWindow` * | Slider ranges 0…stock, prices; Prokurist only with warehouses |
| 1040:1777 | `GoodsDlg::UpdateLabels` * | Stock, sold amounts, free warehouse space, treasury |
| 1040:1868 | `GoodsDlg::CanClose` * | Always True |
| 1040:1877 | `GoodsDlg::SellGood` * | Slider of good i moved: sells/unsells the difference at the current price |
| 1040:1987 | `T1ab8::IdCtl301` | Salt slider → SellGood(1) |
| 1040:199a | `T1ab8::IdCtl302` | Beer slider → SellGood(2) |
| 1040:19ad | `T1ab8::IdCtl303` | Wine slider → SellGood(3) |
| 1040:19c0 | `T1ab8::IdCtl304` | Weapons slider → SellGood(4) |
| 1040:19d3 | `T1ab8::IdCtl601` | "Prokurist": runs PROKURADLG on the dialog's player copy |
| 1040:1a39 | `ProkuristDlg::Init` * | Constructor: 4 min-price sliders, labels, 4 enable checkboxes |
| 1040:1b55 | `ProkuristDlg::SetupWindow` * | Slider ranges 0…100/200/500/1000 (DS:22b6), positions = minimum prices |
| 1040:1bd2 | `ProkuristDlg::Update` * | Reads sliders into prokurist_min_*, syncs checkboxes / slider enable |
| 1040:1cd0 | `T1a3a::IdCtl301` | Salt min-price slider → Update |
| 1040:1ce1 | `T1a3a::IdCtl302` | Beer min-price slider → Update |
| 1040:1cf2 | `T1a3a::IdCtl303` | Wine min-price slider → Update |
| 1040:1d03 | `T1a3a::IdCtl304` | Weapons min-price slider → Update |
| 1040:1d14 | `T1a3a::IdCtl201` | Toggle prokurist_salt → Update |
| 1040:1d35 | `T1a3a::IdCtl202` | Toggle prokurist_beer → Update |
| 1040:1d56 | `T1a3a::IdCtl203` | Toggle prokurist_wine → Update |
| 1040:1d77 | `T1a3a::IdCtl204` | Toggle prokurist_weapons → Update |

### New game – SPIELERZAHLDLG (DS:22e4), COMPUTERZAHLDLG (DS:2362), SPIELERNAMEDLG (DS:195a), EMAILNAMEDLG (DS:19ae)

| Address | Name | Purpose |
|---|---|---|
| 1040:1d98 | `NewGame_AskPlayerCounts` * | CmNeuesSpiel: humans, options, computers and level; sets header counts; asks player data |
| 1040:1f2a | `NewGame_AskPlayerData` * | SPIELERNAMEDLG for every human: name, sex, country |
| 1040:2017 | `HumanCountDlg::Init` * | Constructor: slider, count label, option checkboxes 301–304 |
| 1040:20cb | `HumanCountDlg::SetupWindow` * | Range 1–10, default options (E-Mail off, Unsterblichkeit off, Warenhandel on, Initiativpunkte on) |
| 1040:215f | `HumanCountDlg::UpdateLabels` * | Count label; E-Mail checkbox only with ≥ 2 humans |
| 1040:21c6 | `T22e4::IdCtl301` | Toggle "Spiel per E-Mail" |
| 1040:2202 | `T22e4::IdCtl302` | Toggle "Unsterblichkeit" |
| 1040:223e | `T22e4::IdCtl303` | Toggle "Warenhandel" |
| 1040:227a | `T22e4::IdCtl304` | Toggle "Initiativpunkte" |
| 1040:22b6 | `T22e4::IdCtl101` | Slider → count, UpdateLabels |
| 1040:22d9 | `HumanCountDlg::CanClose` * | Writes the four options to the game header (0x0b, 0x12, 0x13, 0x14) |
| 1040:234c | `ComputerCountDlg::Init` * | Constructor: slider, count label, level radios 201–204 |
| 1040:2408 | `ComputerCountDlg::SetupWindow` * | Range (1 if one human, else 0) … 10 − humans |
| 1040:2466 | `ComputerCountDlg::UpdateCountLabel` * | Count label |
| 1040:2498 | `ComputerCountDlg::UpdateLevelRadios` * | Checks the level radio button |
| 1040:24ee | `T2362::IdCtl101` | Slider → count label |
| 1040:2511 | `T2362::IdCtl201` | Level Dorftrottel |
| 1040:2527 | `T2362::IdCtl202` | Level Schultheiß |
| 1040:253d | `T2362::IdCtl203` | Level Souverän |
| 1040:2553 | `T2362::IdCtl204` | Level Absolutist |
| 1040:2569 | `PlayerDataDlg::Init` * | Constructor: name edit, sex radios, country combo without countries already taken |
| 1040:26de | `PlayerDataDlg::SetupWindow` * | Fills the combo, default name, player number |
| 1040:2799 | `PlayerDataDlg::CanClose` * | Reads name/sex/country; refuses an empty name |
| 1040:2815 | `T195a::IdCtl102` | Toggle the sex radio buttons |
| 1040:2871 | `T195a::IdCtl103` | Inherited handler (_DMTCall) |
| 1040:288d | `EmailPlayerDlg::Init` * | PlayerDataDlg plus password + confirmation edits (e-mail games, from 1020:0002) |
| 1040:2909 | `EmailPlayerDlg::CanClose` * | Also requires two equal non-empty passwords |

### Statistics – WIRTSTATDLG (DS:1b64), MILSTATDLG (DS:1b10)

| Address | Name | Purpose |
|---|---|---|
| 1040:2997 | `Do_Wirtschaft` | Constructor of WIRTSTATDLG (called by CmWirtschaft), 19 statics, player copy |
| 1040:2a23 | `EconomyStatsDlg::SetupWindow` * | All running income/expense totals, group sums, balance |
| 1040:2e64 | `Do_Militaer` | Constructor of MILSTATDLG (called by CmMilitaer with the year), 18 statics |
| 1040:2efe | `MilitaryStatsDlg::SetupWindow` * | Battles won/lost/quota, own losses, enemy losses, manoeuvres per year |

### Unit view – UNITLOOKDLG (type DS:1f9c)

| Address | Name | Purpose |
|---|---|---|
| 1040:330f | `ShowUnitLookDlg` * | Click on an army icon: shows unit i of Heer or Garde |
| 1040:339c | `UnitLookDlg::Init` * | Constructor: 11 statics |
| 1040:341b | `UnitLookDlg::SetupWindow` * | Unit data, help context, starts a 400 ms timer |
| 1040:363c | `T1f9c::WMPaint` | Repaint → DrawUnitPicture |
| 1040:367b | `UnitLookDlg::DrawUnitPicture` * | Unit bitmap 1100+type / 1300+type (blink frame), heroes 50+portrait |
| 1040:37d9 | `T1f9c::WMTimer` | 1 in 4 ticks shows the blink frame |
| 1040:3817 | `UnitLookDlg::Done` * | Destructor: kills the timer |

### Hero level-up – HEROMADELEVELDLG (type DS:1f34)

| Address | Name | Purpose |
|---|---|---|
| 1040:384b | `ShowHeroLevelUp` * | Shows a hero promotion (0x20-byte record); called after battles, manoeuvres, recruiting |
| 1040:38b3 | `HeroLevelUpDlg::Init` * | Constructor: 8 statics |
| 1040:3927 | `FormatPlusNumber` * | "+" + n |
| 1040:3962 | `HeroLevelUpDlg::SetupWindow` * | Name, new rank, six "+n" increments |

### Career advice – KARRIEREDLG (type DS:1ed8)

| Address | Name | Purpose |
|---|---|---|
| 1040:3a9d | `Do_Karriereberatung` | Menu Karriereberatung: KARRIEREOKDLG when CanBePromoted, else the KARRIEREDLG checklist |
| 1040:3bd1 | `CareerDlg::Init` * | Constructor: 7 checkboxes |
| 1040:3c47 | `CareerDlg::SetupWindow` * | Ticks the met promotion criteria for title + 1 |
| 1040:3e62 | `CareerDlg::PaintGrayBackground` * | Own virtual (+58h): fills the client area light gray; no caller found |
| 1040:3f2c | `T1ed8::WMPaint` | Only DefWndProc |

### High scores – HIGHSCOREDLG (type DS:248c)

| Address | Name | Purpose |
|---|---|---|
| 1040:3f44 | `ShowHighScoreDlg` * | Shows the 5 tables, saves the buffer afterwards (Löschen may have cleared a table) |
| 1040:3fc4 | `AddHighScore` * | Victory: inserts the winner into the table of the computer level, once per game id |
| 1040:40f8 | `HighScoreDlg::Init` * | Constructor: title, 4 × 10 statics, buttons ">>" and "Löschen" |
| 1040:4281 | `HighScoreDlg::SetupWindow` * | → ShowTable |
| 1040:429c | `HighScoreDlg::ShowTable` * | Table title and its 10 entries |
| 1040:44a2 | `T248c::IdCtl501` | ">>": next table (mod 5) |
| 1040:44c7 | `T248c::IdCtl701` | "Löschen": clears the shown table |

### Records – REKORDDLG (type DS:1e76)

| Address | Name | Purpose |
|---|---|---|
| 1040:44f8 | `ShowRecordsDlg` * | CmRekorde: REKORDDLG, then writes the records file |
| 1040:4557 | `UpdateRecords` * | Victory: updates the five all-time records |
| 1040:484f | `RecordsDlg::Init` * | Constructor: 9 statics |
| 1040:48c6 | `RecordsDlg::SetupWindow` * | Builds the record sentences |

### Coronation – KROENUNGSDLG / KROENCOMPDLG (type DS:1e22)

| Address | Name | Purpose |
|---|---|---|
| 1040:4bc7 | `ShowCoronation` | Coronation dialog (human / computer variant), date line and title, sound 13 |
| 1040:4cd7 | `CoronationDlg::Init` * | Constructor: 2 statics |
| 1040:4d4c | `CoronationDlg::SetupWindow` * | Sets the two texts |
| 1040:4d8c | `T1e22::WMPaint` | Paints the coronation picture |

### Manoeuvre and recruiting – REKRUTDLG (type DS:2730)

Ported: `port/src/troops.pas` (`RecruitDialog`, `TRecruitDlg`; the picture is a UI call).

| Address | Name | Purpose |
|---|---|---|
| 1040:4ede | `Do_ManoeverAbhalten` | Menu Manöver abhalten: cost dialog, booking, experience for the Heer |
| 1040:5108 | `RecruitDialog` | Recruit into Heer/Garde (NOREKRUTDLG for Herr), cost, weapons, hero (REKHELDDLG) |
| 1040:5397 | `RecruitDlg::Init` * | Constructor: free-mode flag, 9 statics, unit combo, OK button |
| 1040:545f | `RecruitDlg::SetupWindow` * | Fills the unit-type combo (title-dependent), info, timer |
| 1040:5576 | `T2730::WMPaint` | Repaint → DrawUnitPicture |
| 1040:55b5 | `RecruitDlg::DrawUnitPicture` * | Unit bitmap, blink frame |
| 1040:5760 | `T2730::WMTimer` | 1 in 3 ticks shows the blink frame |
| 1040:579e | `RecruitDlg::Done` * | Destructor: kills the timer |
| 1040:57d2 | `RecruitDlg::UpdateUnitInfo` * | Weapons needed, unit stats, pay and price; OK disabled without weapons |
| 1040:5adf | `T2730::IdCtl201` | Unit type chosen → help context, info, picture |

### Budget, ranking, demography – HAUSHALTSDLG (DS:27ce), RANGLISTENDLG (DS:2834), BEVDLG (DS:1dbc)

| Address | Name | Purpose |
|---|---|---|
| 1040:5b3a | `Do_Finanzhaushalt` | Menu Finanzhaushalt: forecasts next year's income/expenses into HAUSHALTSDLG |
| 1040:5d7d | `BudgetDlg::Init` * | Constructor: 9 statics |
| 1040:5df3 | `BudgetDlg::SetupWindow` * | Shows the 9 forecast lines |
| 1040:5f7f | `Do_InternationalerVergleich` | Menu Internationaler Vergleich: runs RANGLISTENDLG |
| 1040:5fc7 | `RankingDlg::Init` * | Constructor: copies all players, 3 statics per player |
| 1040:60e8 | `RankingDlg::SetupWindow` * | Score per player (1068:12fe), sorted list |
| 1040:62f8 | `Do_DemographischeDaten` | Menu Demographische Daten: BEVDLG on a player copy (MaximizeTaxes first) |
| 1040:6385 | `DemographyDlg::Init` * | Constructor: 7 statics |
| 1040:63fd | `DemographyDlg::SetupWindow` * | Happiness, rates, mood text, population |

### Taxes – STEUERDLG (type DS:1d64)

| Address | Name | Purpose |
|---|---|---|
| 1040:669d | `Do_SteuernFestsetzen` | Menu Steuern festsetzen: runs STEUERDLG, copies back on OK |
| 1040:6728 | `TaxDlg::Init` * | Constructor: 3 sliders, 3 labels, "Einnahmen maximieren" checkbox |
| 1040:680a | `TaxDlg::SetupWindow` * | Slider ranges 0–100, positions from the rates |
| 1040:68ee | `TaxDlg::UpdateLabels` * | Checkbox and percentage labels |
| 1040:69ee | `TaxDlg::CanClose` * | Always True |
| 1040:69fd | `T1d64::IdCtl101` | Tax slider → tax_rate, clears maximize_taxes |
| 1040:6a45 | `T1d64::IdCtl102` | Justice slider → justice, clears maximize_taxes |
| 1040:6a8d | `T1d64::IdCtl103` | Asylum slider → asylum_law, clears maximize_taxes |
| 1040:6ad5 | `T1d64::IdCtl301` | Toggle "Einnahmen maximieren": MaximizeTaxes and slider update |

### Smithy and buildings – INVESTDLG (type DS:2986)

| Address | Name | Purpose |
|---|---|---|
| 1040:6bab | `Do_Hofschmiede` | Menu Hofschmiede: SCHMIEDEDLG text with smithy count and yearly weapon output |
| 1040:6cff | `Do_Gebaeude` | Menu Gebäude: INVESTDLG; fame ±10/±20 and news 14/15 for completing/losing palace/cathedral |
| 1040:6e6d | `InvestDlg::Init` * | Constructor: player copy, 9 counts, 9 buy buttons, sell toggle, 9 prices, 2 labels |
| 1040:6ffc | `InvestDlg::SetupWindow` * | Farmland label, then InvestDlg_Update |
| 1040:704f | `InvestDlg_Update` | Prices and buy-button enabling |
| 1040:797b | `InvestDlg_ToggleSell` | Button 501: buy / sell mode |
| 1040:79be | `InvestDlg_BuyMarket` | Button 201 |
| 1040:7a38 | `InvestDlg_BuyMill` | Button 202 |
| 1040:7ab2 | `InvestDlg_BuyPalacePart` | Button 203 |
| 1040:7b33 | `InvestDlg_BuyCathedralPart` | Button 204 |
| 1040:7bb4 | `InvestDlg_BuyGranary` | Button 205 |
| 1040:7c45 | `InvestDlg_BuyWarehouse` | Button 206 |
| 1040:7cd6 | `InvestDlg_BuyUniversityPart` | Button 207 |
| 1040:7d57 | `InvestDlg_BuyTavern` | Button 208 |
| 1040:7dd1 | `InvestDlg_BuySmithy` | Button 209 |

### Land – LANDDLG (type DS:1cec)

| Address | Name | Purpose |
|---|---|---|
| 1040:7e4b | `Do_LandHandeln` | Menu Land handeln: LANDDLG on all players, then BuildingsLostForLand / VERLUSTDLG |
| 1040:7f10 | `LandDlg::Init` * | Constructor: 4 labels, 5 sell + 5 buy buttons |
| 1040:8046 | `LandDlg::SetupWindow` * | Price label → UpdateLabels |
| 1040:809a | `LandDlg::UpdateLabels` * | Treasury, land, unclaimed land; enables the buttons |
| 1040:82ed | `LandDlg::Buy` * | Buy n Hufe |
| 1040:83c5 | `LandDlg_Trade` | Sell n Hufe (comment in 60_buildings/55_market is slightly off, see Findings) |
| 1040:847b | `T1cec::IdCtl101` | Sell 10000 |
| 1040:8491 | `T1cec::IdCtl102` | Sell 1000 |
| 1040:84a7 | `T1cec::IdCtl103` | Sell 100 |
| 1040:84bc | `T1cec::IdCtl104` | Sell 10 |
| 1040:84d1 | `T1cec::IdCtl105` | Sell 1 |
| 1040:84e6 | `T1cec::IdCtl106` | Buy 10000 |
| 1040:84fc | `T1cec::IdCtl107` | Buy 1000 |
| 1040:8512 | `T1cec::IdCtl108` | Buy 100 |
| 1040:8527 | `T1cec::IdCtl109` | Buy 10 |
| 1040:853c | `T1cec::IdCtl110` | Buy 1 |

### Grain – KORNDLG (type DS:1c50)

| Address | Name | Purpose |
|---|---|---|
| 1040:8551 | `Do_KornVerteilen` | Menu Korn verteilen (and turn start with "auto = needed"): KORNDLG on a player copy |
| 1040:85cc | `GrainDlg::Init` * | Constructor: slider 301, 10 labels, buttons 101–112 / 401–403, "Bier brauen" |
| 1040:8854 | `GrainDlg::SetupWindow` * | Capacity, credit, need levels, labels, slider, beer checkbox |
| 1040:8bc9 | `GrainDlg::Trade` * | Buy (+n) / sell (−n) grain at grain_price per gross (144) |
| 1040:8c64 | `T1c50::WMPaint` | Repaint → DrawGrainGauge |
| 1040:8c9d | `GrainDlg::Update` * | Button enabling, distribution clamp, slider, labels, gauge |
| 1040:9081 | `GrainDlg::DrawGrainGauge` * | Bar of grain stock relative to the needed amount |
| 1040:93cf | `T1c50::IdCtl301` | Slider → grain_distributed (×100, ≤ stock) |
| 1040:94a4 | `GrainDlg::CanClose` * | KORNERRORDLG when more is distributed than in stock |
| 1040:9505 | `T1c50::IdCtl401` | "Minimum": distribution := minimum |
| 1040:952a | `T1c50::IdCtl402` | "benötigt": distribution := needed |
| 1040:954f | `T1c50::IdCtl403` | "Maximum": distribution := maximum |
| 1040:9574 | `T1c50::IdCtl101` | Sell 100000 |
| 1040:958a | `T1c50::IdCtl102` | Sell 10000 |
| 1040:95a1 | `T1c50::IdCtl103` | Sell 1000 |
| 1040:95b7 | `T1c50::IdCtl104` | Sell 100 |
| 1040:95cc | `T1c50::IdCtl105` | ">benötigt": sell down to the needed amount |
| 1040:95f3 | `T1c50::IdCtl106` | ">Maximum": sell down to the maximum |
| 1040:961a | `T1c50::IdCtl107` | Buy 100000 |
| 1040:9630 | `T1c50::IdCtl108` | Buy 10000 |
| 1040:9646 | `T1c50::IdCtl109` | Buy 1000 |
| 1040:965c | `T1c50::IdCtl110` | Buy 100 |
| 1040:9671 | `T1c50::IdCtl111` | "benötigt": distribution := needed, buy up to it |
| 1040:96ac | `T1c50::IdCtl112` | "Maximum": distribution := maximum, buy up to it |
| 1040:96e7 | `T1c50::IdCtl501` | Toggle "Bier brauen" (brew_beer) |

### Unit initialisation

| Address | Name | Purpose |
|---|---|---|
| 1040:9738 | `InitDialogLogFont` * | Segment init (from entry 1000:3a3c): LOGFONT DS:603a = Comic Sans MS, height −11, bold |

## Findings

New facts or corrections to `docs/rules/*.md` (addresses = evidence).

**Credit limit.** `1068:1df2` (named `GrainCost_q`) returns `(title + 7) × 1000`. Grain
purchases (8c9d), land purchases (809a) and caravan offers (`1068:0ae8`, used at 08a2/1179)
are allowed while `taler − cost ≥ −(title + 7) × 1000`, i.e. the treasury may go that far
into debt. Suggested rename: `CreditLimit`.

**Grain trade (KORNDLG, 8bc9).** "Preis a gros" is literal: `cost = n × grain_price / 144`
(integer). Buying adds 1 Taler (rounding up); any trade costs at least 1 Taler (so selling
fewer than 144/price units costs 1 Taler instead of paying). Taler and the running total
player+0x8b ("Korn" in WIRTSTATDLG) change by the same amount. Buy buttons (+100 … +100000)
need the credit check and `grain + n ≤ GrainCapacity`; sell buttons need `grain ≥ n`. The
dialog rounds minimum and needed **down** and the maximum **up** (`(max + 100) div 100 × 100`,
8854) – `population-grain.md` says all three are rounded down. The distribution is clamped
to the grain stock (8c9d); "Minimum/benötigt/Maximum" are only enabled when the stock covers
them. Called with the auto flag (+0x71d) the distribution is preset to "needed".

**Land trade (LANDDLG).** Buying and selling are separate functions with different prices
(contradicts `land-market.md`, "negative amount = buy"):
- sell n (83c5, `LandDlg_Trade`): `taler += n × (land_price − 1) / 10` (the existing name
  comment says `land_price`);
- buy n (82ed): `taler −= n × land_price / 10 + 1` (minimum 1);
- both book into player+0x8f (`total_land_trade`, which is a running total shown as "Land"
  in WIRTSTATDLG, not a yearly value).
Sell n is enabled only if `land − land_used ≥ n + 2000`; buy n only if `n ≤ UnclaimedLand`
and the credit check passes (809a). Steps 1/10/100/1000/10000 Hufe (DS:1bc8).

**Caravans (TradeCaravan 08a2, CaravanDlg 1070–139b).** `Random(10)`: 0–2 salt, 3–5 beer,
6–8 wine, 9 weapons. After "Ja", per-Last price and three offers (R(n) = Random(n)):

| Good | Price per Last | Offer 1 | Offer 2 | Offer 3 |
|---|---|---|---|---|
| Salt | 7 + R(5) | 50 + 10·R(11) | 300 + 100·R(11) | 2000 + 500·R(11) |
| Beer | 35 + R(15) | 20 + 5·R(11) | 100 + 50·R(11) | 700 + 200·R(11) |
| Wine | 80 + R(20) | 10 + 4·R(11) | 50 + 20·R(11) | 300 + 100·R(11) |
| Weapons | 400 + R(100) | 1 + R(2) | 3 + R(2) | 5 + R(2) |

Offers 2 and 3 are 1 resp. 2 Taler cheaper per Last (1341). The offer dialog only appears if
offer 1 fits into the free warehouse space and is affordable; otherwise the "_III" farewell
dialog. Each offer is disabled when unaffordable or larger than the free space. Payment:
`taler −= price × amount`, `total_goods_sales −= same`, `AddGoodsCapped`.

**Goods dialog / Prokurist.** Goods are sold with sliders; moving a slider back undoes the
sale within the dialog (1877). The Prokurist button needs ≥ 1 warehouse (165b). Prokurist
minimum-price sliders go up to 100 (salt), 200 (beer), 500 (wine), 1000 (weapons) (DS:22b6).

**Unit pay (SOLDDLG).** New pay is chosen between `base_pay / 2` and `base_pay × 2` (01f4);
accepting also sets unit+0x37 to 0.

**New-game options (SPIELERZAHLDLG / COMPUTERZAHLDLG).** Header 0x12 (`immortality`) is the
checkbox **"Unsterblichkeit"** (22d9); 0x0b E-Mail (only with ≥ 2 humans), 0x13 Warenhandel,
0x14 Initiativpunkte; defaults off/off/on/on. 1–10 humans, 0 … 10 − humans computers (≥ 1
with a single human). Header 0x09 = computer level 1–4 (Dorftrottel, Schultheiß, Souverän,
Absolutist), 0 without computer players (1d98). Header 0x0c = random game id (1 + Random,
set at game start in seg01) used to keep one high-score/record entry per game. The country
list for each human leaves out countries already chosen (2569). Header 0x52/0x7b/0x94 hold
scenario title (40), author (24) and description (512) for SZENARIENINFODLG.

**Score (`1068:12fe`, used by RANGLISTENDLG 60e8 and the high score 3fc4).**
`ArmyStrength(Heer) div 50 + taler div 100000 + land div 20000 + population div 2000 + title + fame div 20`.

**High scores (3fc4, 3f44, 429c).** Five tables of 10 (0x226 bytes each: name "Titel Name von
Land", spell, score, year + 1400, game id): table = computer level, titled "Menschen unter
sich", "unter den Dorftrotteln", "der Schultheiß-Liga", "der Königs-Klasse", "der
Kaiser-Klasse". Victory (1000:3459) adds an entry only for a human winner **and** when
Unsterblichkeit is off, Initiativpunkte are on and the census editor is off (`turn-loop.md`
mentions only the census editor).

**Records (4557).** Fastest coronation (fewest years), most land, most population, most
Taler, best hero (`level × 3 + kills`), each with date and the winner's title string.

**WIRTSTATDLG reveals running totals in TPlayer (2a23):** 0x8b grain trade, 0x8f land trade,
0x93 buildings, 0x9b taxes+justice, **0x9f development aid**, 0xa3 trade agreements, **0xa7
tributes**, **0xab sabotage**, **0xaf recruiting costs** (RecruitDialog books here), 0xb3 pay,
0xb7 manoeuvres, **0xbb war loot**, 0xbf interest/rent, 0xc3 surprises (events), 0x97 goods;
"Bilanz" = sum of all. Bold = not yet in `kaiser_structs.py`.

**MILSTATDLG (2efe):** new field player+0x5d3 = units dismissed ("Entlassen"); "Manöver pro
Jahr" = `manoeuvres_held / year` (year 0 counts as 1); quotas = won / (won + lost).

**Budget forecast (Do_Finanzhaushalt 5b3a):** buildings + trade agreements + tax + justice −
army pay + (warehouse rent + interest) − sabotage; events and goods sales are not forecast.
Sabotage cost (`1068:32b2`) = 100 × Σ byte[player+0x598+other] over the other players, only
computed when player+0xed (taverns) ≠ 0.

**Demography (63fd):** mood text by happiness %: < 30 "Kritisch! Revolution droht!", 30–49
"Ärger! Die Volksseele brodelt!", 50–69 "Gedämpft! Wirtschaft lahmt!", 70–89 "Gut! Wohlstand
für die Mehrheit!", 90–100 "Euphorisch! Das Volk liebt Euch!".

**Recruiting (5108, 545f, 57d2):** a Herr (title 0) gets NOREKRUTDLG. Offered unit types =
1 … title (a König with a hero already gets 8); free mode (TroopDlg+0x709 = 6) offers all 35
types at cost 0 without weapon check. Price = UnitCost (× 3/4 with Ferengicharme) adjusted by
fame (`1068:3003`); weapons `UnitWeapons[type]` are consumed and the OK button is disabled when
they are missing.

**Buildings (6cff):** confirms fame +10 / +20 and news 14 / 15 for completing palace /
cathedral, −10 / −20 when a completed one drops below 12 parts in the dialog.

### Suggested renames of existing names (not changed)

| Address | Current | Suggested | Evidence |
|---|---|---|---|
| 1040:2997 | `Do_Wirtschaft` | `EconomyStatsDlg::Init` | Constructor (`_Construct`, `Do_Info` base init, VMT DS:1b64 passed by CmWirtschaft) |
| 1040:2e64 | `Do_Militaer` | `MilitaryStatsDlg::Init` | Constructor of VMT DS:1b10 (MILSTATDLG), stores the year at +0x703 |
| 1058:0002 | `Do_Info` | `KaiserDlg::Init` | Base dialog constructor (TDialog.Init + style flag 0x40) used by almost every dialog |
| 1068:1df2 | `GrainCost_q` | `CreditLimit` | Returns `(title + 7) × 1000`; used as overdraft limit for grain, land and caravans |
| 1068:12fe | `FUN_1068_12fe` | `PlayerScore` | Score formula above (outside this segment) |
