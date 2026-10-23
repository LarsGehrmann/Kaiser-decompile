{ The menu actions of the main window (segments 8 and 9, Do_*) and their
  dialog types. A dialog type's methods (TDialogLogic descendants, registered
  by the constructor name the action passes to UI.Dialog) work on D.Data,
  laid out like the original object; they reach the controls through
  TDlgControls. Differential tests: the original's own dialog objects run
  in the emulator (tools/emu/dlg_driver.py) with the same user events. }
unit Actions;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI, Turn, War, Game;

{ Land handeln (1040:7e4b): LANDDLG on a copy of all players; on OK the
  copy is taken over and buildings that no longer fit are lost }
procedure Do_LandHandeln(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ Gebaeude (1040:6cff): INVESTDLG on a copy of the player; a palace or
  cathedral finished (or lost) changes the fame, finishing one is news }
procedure Do_Gebaeude(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ Steuern festsetzen (1040:669d): STEUERDLG on a copy of the player; HWnd
  is the main window's handle (for the help) }
procedure Do_SteuernFestsetzen(Parent: Pointer; HWnd: Word; var P: TPlayer);
{ Handel mit Guetern (1040:1439): GUETERHANDELDLG on a copy of the player,
  the Prokurist (PROKURADLG) from its button 601 }
procedure Do_HandelMitGuetern(Parent: Pointer; var P: TPlayer);
{ Hofschmiede (1040:6bab): SCHMIEDEDLG, the smithies' output }
procedure Do_Hofschmiede(Parent: Pointer; var P: TPlayer);
{ Demographische Daten (1040:62f8): BEVDLG on a copy of the player }
procedure Do_DemographischeDaten(Parent: Pointer; HWnd: Word; P: TPlayer);
{ Finanzhaushalt (1040:5b3a): HAUSHALTSDLG, the budget of the coming year
  (computes the player's rates and happiness first, like the year end) }
procedure Do_Finanzhaushalt(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ Internationaler Vergleich (1040:5f7f): RANGLISTENDLG, the players by score }
procedure Do_InternationalerVergleich(Parent: Pointer; var Players: TPlayers; NumPlayers: Byte);
{ Karriereberatung (1040:3a9d): KARRIEREDLG with the promotion criteria, or
  KARRIEREOKDLG when the next title is reached }
procedure Do_Karriereberatung(Parent: Pointer; P: TPlayer);
{ Manoever abhalten (1040:4ede): costs money (and an initiative point),
  every unit of the Heer gains 1..5 experience }
procedure Do_ManoeverAbhalten(Parent: Pointer; var P: TPlayer; Unused: Word);
{ Wirtschaft (CmWirtschaft 1000:1cf0): WIRTSTATDLG, the running totals }
procedure Do_Wirtschaft(Parent: Pointer; const P: TPlayer);
{ Militaer (CmMilitaer 1000:1c91): MILSTATDLG, battles and losses }
procedure Do_Militaer(Parent: Pointer; const P: TPlayer; Year: Word);
{ Laendernamen (1040:02d5): LAENDERNAMENDLG edits the country names and
  adjectives (DS:63a8 / DS:6696) }
procedure Do_Laendernamen(Parent: Pointer);
{ Spiel (CmSpiel 1000:1d4b): the scenario's title, author and description }
procedure Do_Spiel(Parent: Pointer);
{ the player to deal with (1038:1a12): Mode 1 gift, 5 treaty, 2 tribute,
  -1 sabotage; -1 when cancelled or when that player has a message from Me
  waiting (NOAUSWAHLDLG, not for sabotage) }
function ChooseDiplomacyTarget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Mode: ShortInt): SmallInt;
{ Abkommen (1038:1e35): offer peace for 5..50 years, offer or cancel trade }
procedure Do_Abkommen(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ Tribut fordern (1038:2ca5): demand Taler, land, people, a trade agreement
  or peace from another player }
procedure Do_TributFordern(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ Sabotage (1038:3564): SABOTAGEBUDGETDLG on a copy of all players }
procedure Do_Sabotage(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ 'Zuschlagen!' against Target (1038:35bf): SABOTAGEWAHLDLG, SabotageAction
  and its report }
procedure SabotageStrike(Parent: Pointer; var Players: TPlayers; Me, NumPlayers, Target: Byte);
{ the war declaration (1038:40e8): title, army and initiative checks, the
  target (GEGNERDLG); True when the war is on, Target the enemy }
function DeclareWar(Parent: Pointer; var Players: TPlayers; Me: Byte; var Target: Byte;
  NumPlayers: Byte; Year: Word): Boolean;
{ Krieg fuehren (CmKriegFuehren 1000:193f): declare, arrange the Heer,
  fight (a second battle at the city if the field battle opened it), news;
  the e-mail game hand-over is not ported }
procedure Do_KriegFuehren(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
{ Demissionieren (CmDemissionieren 1000:16d0): after the confirmation a
  computer ruler takes over, the next player moves (the e-mail hand-over is
  not ported) }
procedure Do_Demissionieren(Parent: Pointer; HWnd: Word; var Players: TPlayers);
{ Korn verteilen (1040:8551): KORNDLG on a copy of the player; Mode 1 (the
  turn start) proposes the need }
procedure Do_KornVerteilen(Parent: Pointer; var P: TPlayer; Mode: Byte);

type
  PPlayers = ^TPlayers;
  PReal48 = ^TReal48;

  { LANDDLG (VMT DS:1cec, 1040:7f10): all players at +0x34, me +0x4486,
    the number of players +0x4487; buttons 101..105 sell, 106..110 buy
    10000 .. 1 Hufen }
  TLandDlg = class(TDialogLogic)
  public
    function Players: PPlayers;
    function Me: PPlayer;
    procedure SetupWindow; override;
    procedure UpdateLabels;
    procedure Buy(N: LongInt);
    procedure Sell(N: LongInt);
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { INVESTDLG (VMT DS:2986, 1040:6e6d, a HelpDlg): the player at +0x62,
    buy mode +0x737 (0 = sell), the step +0x738 (1 or -1), the prices
    +0x73c; buttons 201..209 buy or sell markets, mills, a palace part, a
    cathedral part, granaries, warehouses, a university part, taverns,
    smithies; 501 switches the mode }
  TInvestDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    function Step: LongInt;
    function Price(K: Integer): LongInt;
    procedure SetupWindow; override;
    procedure Update;
    procedure Pay(K: Integer);
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { STEUERDLG (VMT DS:1d64, 1040:6728, a HelpDlg): the player at +0x64;
    sliders 101..103 tax rate, justice, asylum law in percent, statics
    201..203, checkbox 301 Einnahmen maximieren }
  TTaxDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    procedure SetPositions;
    procedure SetupWindow; override;
    procedure UpdateLabels;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { GUETERHANDELDLG (VMT DS:1ab8, 1040:14a9, a HelpDlg): the player at
    +0x34, sold this time +0x709 (4 longints); scroll bars 301..304 sell
    salt, beer, wine, weapons; statics 101..104 prices, 201..204 stock,
    401..404 sold, 501 free warehouse space, 502 Taler; 601 Prokurist }
  TGoodsDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    function Sold(I: Integer): PLongInt;
    procedure SetupWindow; override;
    procedure UpdateLabels;
    procedure SellGood(I: Integer);
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { PROKURADLG (VMT DS:1a3a, 1040:1a39, a HelpDlg): the player at +0x34;
    scroll bars 301..304 the minimum prices (ranges DS:22b6), statics
    101..104, check boxes 201..204 sell automatically }
  TProkuristDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    procedure SetupWindow; override;
    procedure Update;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { BEVDLG (VMT DS:1dbc, 1040:6385, a HelpDlg): the player at +0x36, the
    happiness +0x70b; statics 101..107 }
  TDemographyDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { HAUSHALTSDLG (VMT DS:27ce, 1040:5d7d, a HelpDlg): the budget lines
    +0x34 .. +0x54 (longints); statics 101..109 }
  TBudgetDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { RANGLISTENDLG (VMT DS:2834, 1040:5fc7): the number of players +0x2e,
    all players at +0x2f; statics 301+i rank, 101+i title and name, 201+i
    score }
  TRankingDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { KARRIEREDLG (VMT DS:1ed8, 1040:3bd1, a HelpDlg): the player at +0x34;
    check boxes 101..107 population, happiness, land, army, palace,
    cathedral, Taler }
  TCareerDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { WIRTSTATDLG (VMT DS:1b64, 1040:2997): the player at +0x2e; statics
    101..119 }
  TEconomyStatsDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { MILSTATDLG (VMT DS:1b10, 1040:2e64): the year +0x703, the player at
    +0x2e; statics 101..118 }
  TMilitaryStatsDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { LAENDERNAMENDLG (VMT DS:2072, 1040:0314): edits 101..110 names, 201..210
    adjectives, button 200 the built-in names }
  TCountryNamesDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { SZENARIENINFODLG (VMT DS:18f2, 1040:0002): statics 101, 102, edit 103 }
  TScenarioInfoDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { SPENDE/TRADE/TRIBUT/SABOAUSWAHLDLG (VMT DS:357a, 1058:06d2): combo box
    101 of the players but Exclude; the chosen player +0x32, the number of
    players +0x33, Exclude +0x34, the entries' players +0x35, their names
    +0x3f (0x33 bytes each). Args: Parent, Name, @Players, Num, Exclude }
  TPlayerSelectDlg = class(TDialogLogic)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
  end;

  { ABFRAGETALER/LAND/SKLAVEN/ZEITDLG (VMT DS:0ffa, 1038:1b8c): the player
    at +0x2e, scroll bar 101, static 102, the value +0x70b, the mode +0x70f
    (0 Taler, 1 land in 100s, 3 people, 4 years) }
  TAmountDlg = class(TDialogLogic)
  public
    function Value: PLongInt;
    procedure SetupWindow; override;
    procedure ShowValue;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { ABKOMMENDLG (VMT DS:0f94, 1038:2107, a HelpDlg): the choice +0x34, peace
    +0x35, trade +0x36, the partner's name +0x3b; static 101, radios
    201..203 peace, offer trade, cancel trade }
  TAbkommenDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    procedure UpdateRadios;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { TRIBUTDLG (VMT DS:0f22, 1038:31fe, a HelpDlg): the choice +0x34, the
    target at +0x35, the disabled flags +0x70e (5), the target's name
    +0x713; static 101, radios 201..205 Taler, land, people, trade, peace }
  TTributDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    procedure UpdateRadios;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { SABOTAGEBUDGETDLG (VMT DS:13d2, 1038:38ef, a HelpDlg): all players at
    +0x34, Me +0x4486, the number of players +0x4487, the other players
    +0x4488; per row i: statics 101+i country, 201+i agents, 401+i budget,
    601+i years to the next strike, scroll bar 301+i budget, 501+i strike }
  TSabotageBudgetDlg = class(TDialogLogic)
  public
    function Players: PPlayers;
    function Me: PPlayer;
    function Row(I: Integer): Byte;
    procedure SetupWindow; override;
    procedure UpdateRows;
    procedure ShowYears(I: Integer; Empty: Word);
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { SABOTAGEWAHLDLG (VMT DS:1306, 1038:3411, a HelpDlg): the target's name
    +0x34; buttons 201..205 end with 1..5, 206 with 0 }
  TSabotageWahlDlg = class(TDialogLogic)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { GEGNERDLG (VMT DS:1498, 1038:4379): combo box 101, statics 201 own
    initiative, 202 the attack's cost; the target +0x3a, the number of
    players +0x3b, Me +0x3c, the count +0x3d, the targets +0x3e, all
    players at +0x48, country -> player +0x449a, names +0x44a4 (0x33 each) }
  TGegnerDlg = class(TDialogLogic)
  public
    function Players: PPlayers;
    procedure Init; override;
    procedure SetupWindow; override;
    procedure UpdateCost;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { KORNDLG (VMT DS:1c50, 1040:8638): the player at +0x34, the capacity
    +0x709, the credit reserve +0x70d, the rounded minimum / need / maximum
    +0x711 / +0x715 / +0x719, the mode +0x71d; slider 301 in 100 Scheffel,
    buttons 101..104 sell and 107..110 buy 100000 .. 100 Scheffel, 105/106
    sell down to, 111/112 buy up to need / maximum, 401..403 distribute
    minimum / need / maximum, 501 Bier brauen }
  TGrainDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    function L(Off: Integer): PLongInt;
    procedure SetupWindow; override;
    procedure Update;
    procedure Trade(N: LongInt);
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

implementation

{ the number as the original's IntToStr (1068:6b29) writes it }
procedure SetNumber(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

{ -- Do_LandHandeln ------------------------------------------------------- }

procedure Do_LandHandeln(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  L: TLandLoss;
  Shown: TLandLoss;
begin
  D := UI.Dialog('LandDlg', $1CEC, [APtr(Parent), AStr(DSText($2B46))]);
  Move(Players, D.Data[$34], $4452);
  D.Data[$4486] := Me;
  D.Data[$4487] := NumPlayers;
  if UI.Execute(D) = 1 then
  begin
    Move(D.Data[$34], Players, $4452);
    FillChar(L, SizeOf(L), 0);
    BuildingsLostForLand(Players[Me], L);
    if L.Total > 0 then
    begin
      Shown := L;
      Shown.Unused4 := 0;
      UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText($2B4E)), ARec(@Shown, SizeOf(Shown)),
        AByte(0)]);
    end;
  end;
  UI.Done(D, 1);
end;

{ -- LANDDLG -------------------------------------------------------------- }

function TLandDlg.Players: PPlayers;
begin
  Result := PPlayers(@D.Data[$34]);
end;

function TLandDlg.Me: PPlayer;
begin
  Result := @Players^[D.Data[$4486]];
end;

procedure TLandDlg.SetupWindow;
begin
  SetNumber(C, 203, Me^.LandPrice);
  UpdateLabels;
end;

procedure TLandDlg.UpdateLabels;
var
  Unclaimed, Reserve, Amt: LongInt;
  K: Integer;
begin
  { treasury, land, unclaimed land; a purchase needs unclaimed land and
    must leave the treasury above the credit limit, a sale leaves 2000
    Hufen of farmland }
  SetNumber(C, 201, Me^.Taler);
  SetNumber(C, 202, Me^.Land);
  SetNumber(C, 204, UnclaimedLand(Players^, D.Data[$4487]));
  Unclaimed := UnclaimedLand(Players^, D.Data[$4487]);
  Reserve := -CreditLimit(Me^);
  for K := 0 to 4 do
  begin
    Amt := DS.LandTradeAmounts[K];
    C.Enable(106 + K, not ((Amt > Unclaimed) or
      (LongInt(Me^.Taler - LongInt(Int64(Me^.LandPrice) * Amt) div 10) < Reserve)));
    C.Enable(101 + K, not (LongInt(Amt + 2000) > LongInt(Me^.Land - Me^.LandUsed)));
  end;
end;

procedure TLandDlg.Buy(N: LongInt);
var
  Cost: LongInt;
begin
  UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  Me^.Land := Me^.Land + N;
  Cost := LongInt(Int64(Me^.LandPrice) * N) div 10;
  if N > 0 then
    Inc(Cost);
  if Cost = 0 then
    Cost := 1;
  Me^.Taler := Me^.Taler - Cost;
  Me^.TotalLandTrade := Me^.TotalLandTrade - Cost;
  UpdateLabels;
end;

procedure TLandDlg.Sell(N: LongInt);
var
  Gain: LongInt;
begin
  UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  Me^.Land := Me^.Land - N;
  Gain := LongInt(Int64(Me^.LandPrice - 1) * N) div 10;
  Me^.Taler := Me^.Taler + Gain;
  Me^.TotalLandTrade := Me^.TotalLandTrade + Gain;
  UpdateLabels;
end;

function TLandDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    101..105: Sell(DS.LandTradeAmounts[Id - 101]);
    106..110: Buy(DS.LandTradeAmounts[Id - 106]);
  else
    Result := False;
  end;
end;

{ -- Do_Gebaeude ------------------------------------------------------------ }

procedure Do_Gebaeude(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  Q: PPlayer;
begin
  D := UI.Dialog('InvestDlg', $2986, [APtr(Parent), AStr(DSText($2B04))]);
  Move(Players[Me], D.Data[$62], SizeOf(TPlayer));
  D.Data[$737] := 1;
  if UI.Execute(D) = 1 then
  begin
    Q := PPlayer(@D.Data[$62]);
    if (Q^.PalaceParts = 12) and (Players[Me].PalaceParts < 12) then
    begin
      GainFame(Q^.Fame, 10);
      AddNews(Players, NumPlayers, Me, Me, $0E);
    end;
    if (Q^.CathedralParts = 12) and (Players[Me].CathedralParts < 12) then
    begin
      GainFame(Q^.Fame, 20);
      AddNews(Players, NumPlayers, Me, Me, $0F);
    end;
    if (Q^.PalaceParts < 12) and (Players[Me].PalaceParts = 12) then
      LoseFame(Q^.Fame, 10);
    if (Q^.CathedralParts < 12) and (Players[Me].CathedralParts = 12) then
      LoseFame(Q^.Fame, 20);
    Move(Q^, Players[Me], SizeOf(TPlayer));
  end;
  UI.Done(D, 1);
end;

{ -- INVESTDLG ------------------------------------------------------------- }

function TInvestDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$62]);
end;

function TInvestDlg.Step: LongInt;
begin
  Result := PLongInt(@D.Data[$738])^;
end;

function TInvestDlg.Price(K: Integer): LongInt;
begin
  Result := PLongInt(@D.Data[$73C + 4 * K])^;
end;

procedure TInvestDlg.SetupWindow;
begin
  SetNumber(C, 402, LongInt(Me^.Land - Me^.LandUsed));
  Update;
end;

procedure TInvestDlg.Update;
var
  K: Integer;
  V, Farm: LongInt;
  Buf: array[0..23] of Char;
  P: PPlayer;

  { room for one more: a building per 1000 Hufen of farmland }
  function Room(N: LongInt): Boolean;
  begin
    Result := LongInt(Farm - LongInt(Int64(N) * 1000)) >= 1000;
  end;

begin
  P := Me;
  for K := 0 to 8 do
  begin
    if D.Data[$737] = 0 then
    begin
      C.SetItemCaption(201 + K, DSText($2B2D));
      V := DS.BuildingPrices[K] div 4;
    end
    else
    begin
      C.SetItemCaption(201 + K, DSText($2B0E));
      V := DS.BuildingPrices[K];
      if P^.Spell = 6 then                             { Ferengicharme }
        V := LongInt(Int64(V) * 3) div 4;
    end;
    PLongInt(@D.Data[$73C + 4 * K])^ := V;
    IntToPChar(Buf, V);
    StrCat(Buf, DSText($2B19));
    C.SetText(301 + K, Buf);
  end;
  if D.Data[$737] = 0 then
  begin
    PLongInt(@D.Data[$738])^ := -1;
    C.SetItemCaption(501, DSText($2B3B));
  end
  else
  begin
    PLongInt(@D.Data[$738])^ := 1;
    C.SetItemCaption(501, DSText($2B20));
  end;
  SetNumber(C, 101, P^.Markets);
  SetNumber(C, 102, P^.Mills);
  SetNumber(C, 103, P^.PalaceParts);
  SetNumber(C, 104, P^.CathedralParts);
  SetNumber(C, 105, P^.Granaries);
  SetNumber(C, 106, P^.Warehouses);
  SetNumber(C, 107, P^.UniversityParts);
  SetNumber(C, 108, P^.Taverns);
  SetNumber(C, 109, P^.Smithies);
  SetNumber(C, 401, P^.Taler);
  if D.Data[$737] = 0 then
  begin
    C.Enable(201, P^.Markets > 0);
    C.Enable(202, P^.Mills > 0);
    C.Enable(203, P^.PalaceParts <> 0);
    C.Enable(204, P^.CathedralParts <> 0);
    C.Enable(205, P^.Granaries > 0);
    C.Enable(206, (DS.Game.GoodsTradeEnabled <> 0) and (P^.Warehouses > 0));
    C.Enable(207, P^.UniversityParts <> 0);
    C.Enable(208, P^.Taverns > 0);
    C.Enable(209, P^.Smithies > 0);
    Exit;
  end;
  Farm := LongInt(P^.Land - P^.LandUsed);
  C.Enable(201, Room(P^.Markets));
  C.Enable(202, Room(P^.Mills));
  C.Enable(203, (P^.PalaceBuiltThisTurn = 0) and (P^.PalaceParts < 12) and Room(P^.PalaceParts));
  C.Enable(204, (P^.Title = 9) and (P^.CathedralBuiltThisTurn = 0) and (P^.CathedralParts < 12) and
    Room(P^.CathedralParts));
  C.Enable(205, Room(P^.Granaries));
  C.Enable(206, (DS.Game.GoodsTradeEnabled <> 0) and (P^.Warehouses <= 29) and Room(P^.Warehouses));
  C.Enable(207, (P^.UniversityBuiltThisTurn = 0) and (P^.UniversityParts < 12) and
    Room(P^.UniversityParts));
  C.Enable(208, Room(P^.Taverns));
  C.Enable(209, Room(P^.Smithies));
end;

{ the price of K times the step (negative: a sale) }
procedure TInvestDlg.Pay(K: Integer);
var
  Cost: LongInt;
begin
  Cost := LongInt(Int64(Price(K)) * Step);
  Me^.Taler := LongInt(Me^.Taler - Cost);
  Me^.BuildingBalance := LongInt(Me^.BuildingBalance - Cost);
end;

function TInvestDlg.Handle(Id: SmallInt): Boolean;
var
  P: PPlayer;
  Buying: Boolean;
begin
  P := Me;
  Buying := D.Data[$737] <> 0;
  Result := True;
  if (Id >= 201) and (Id <= 209) then
    UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  case Id of
    201: begin P^.Markets := LongInt(P^.Markets + Step); Pay(0); end;
    202: begin P^.Mills := LongInt(P^.Mills + Step); Pay(1); end;
    203:
      begin
        P^.PalaceParts := Byte(P^.PalaceParts + Byte(Step));
        Pay(2);
        if Buying then
          P^.PalaceBuiltThisTurn := 1;
      end;
    204:
      begin
        P^.CathedralParts := Byte(P^.CathedralParts + Byte(Step));
        Pay(3);
        if Buying then
          P^.CathedralBuiltThisTurn := 1;
      end;
    205:
      begin
        if Buying then
          P^.Granaries := LongInt(P^.Granaries + 1)
        else
          RemoveGranaries(P^, 1);
        Pay(4);
      end;
    206:
      begin
        if Buying then
          P^.Warehouses := LongInt(P^.Warehouses + 1)
        else
          RemoveWarehouses(P^, 1);
        Pay(5);
      end;
    207:
      begin
        P^.UniversityParts := Byte(P^.UniversityParts + Byte(Step));
        Pay(6);
        if Buying then
          P^.UniversityBuiltThisTurn := 1;
      end;
    208: begin P^.Taverns := LongInt(P^.Taverns + Step); Pay(7); end;
    209: begin P^.Smithies := LongInt(P^.Smithies + Step); Pay(8); end;
    501:
      begin
        D.Data[$737] := Ord(D.Data[$737] = 0);
        PLongInt(@D.Data[$738])^ := LongInt(Int64(Step) * -1);
      end;
  else
    Exit(False);
  end;
  Update;
end;

{ -- Do_SteuernFestsetzen ---------------------------------------------------- }

procedure Do_SteuernFestsetzen(Parent: Pointer; HWnd: Word; var P: TPlayer);
var
  D: TDialog;
begin
  if P.MaximizeTaxes <> 0 then
    MaximizeTaxes(P);
  D := UI.Dialog('TaxDlg', $1D64, [APtr(Parent), AStr(DSText($2938))]);
  Move(P, D.Data[$64], SizeOf(TPlayer));
  PWord(@D.Data[$34])^ := HWnd;
  if UI.Execute(D) = 1 then
    Move(D.Data[$64], P, SizeOf(TPlayer));
  UI.Done(D, 1);
end;

{ -- STEUERDLG ------------------------------------------------------------- }

const
  Hundred: TReal48 = ($87, 0, 0, 0, 0, $48);

function Percent(const R: TReal48): LongInt;
begin
  Result := R48Round(R48Mul(R, Hundred));
end;

function TTaxDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$64]);
end;

procedure TTaxDlg.SetPositions;
begin
  C.SetPosition(101, SmallInt(Percent(Me^.TaxRate)));
  C.SetPosition(102, SmallInt(Percent(Me^.Justice)));
  C.SetPosition(103, SmallInt(Percent(Me^.AsylumLaw)));
end;

procedure TTaxDlg.SetupWindow;
var
  K: Integer;
begin
  for K := 0 to 2 do
    C.SetRange(101 + K, 0, 100);
  SetPositions;
  UpdateLabels;
end;

procedure TTaxDlg.UpdateLabels;
begin
  C.SetCheck(301, Ord(Me^.MaximizeTaxes <> 0));
  SetNumber(C, 201, Percent(Me^.TaxRate));
  SetNumber(C, 202, Percent(Me^.Justice));
  SetNumber(C, 203, Percent(Me^.AsylumLaw));
end;

function TTaxDlg.Handle(Id: SmallInt): Boolean;
var
  P: PPlayer;
begin
  P := Me;
  Result := True;
  case Id of
    101..103:
      begin
        { moving a slider ends the automatic maximum }
        PReal48(@PByte(@P^.TaxRate)[6 * (Id - 101)])^ :=
          R48Div(R48FromLong(C.GetPosition(Id)), Hundred);
        P^.MaximizeTaxes := 0;
      end;
    301:
      begin
        P^.MaximizeTaxes := Ord(P^.MaximizeTaxes = 0);
        if P^.MaximizeTaxes <> 0 then
        begin
          MaximizeTaxes(P^);
          SetPositions;
        end;
      end;
  else
    Exit(False);
  end;
  UpdateLabels;
end;

{ -- Do_HandelMitGuetern ----------------------------------------------------- }

procedure Do_HandelMitGuetern(Parent: Pointer; var P: TPlayer);
var
  D: TDialog;
begin
  D := UI.Dialog('GoodsDlg', $1AB8, [APtr(Parent), AStr(DSText($229A))]);
  Move(P, D.Data[$34], SizeOf(TPlayer));
  if UI.Execute(D) = 1 then
    Move(D.Data[$34], P, SizeOf(TPlayer));
  UI.Done(D, 1);
end;

{ -- GUETERHANDELDLG ------------------------------------------------------- }

{ good I = 1..4 (salt, beer, wine, weapons): stock and price }
function GoodStock(P: PPlayer; I: Integer): PLongInt;
begin
  Result := PLongInt(@PByte(@P^.Salt)[4 * (I - 1)]);
end;

function GoodPrice(P: PPlayer; I: Integer): LongInt;
begin
  Result := PLongInt(@PByte(@P^.PriceSalt)[4 * (I - 1)])^;
end;

function TGoodsDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$34]);
end;

function TGoodsDlg.Sold(I: Integer): PLongInt;
begin
  Result := PLongInt(@D.Data[$705 + 4 * I]);
end;

procedure TGoodsDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 1 to 4 do
  begin
    if GoodStock(Me, I)^ = 0 then
      C.Enable(300 + I, False)
    else
      C.SetRange(300 + I, 0, SmallInt(GoodStock(Me, I)^));
    SetNumber(C, 100 + I, GoodPrice(Me, I));
    Sold(I)^ := 0;
  end;
  C.Enable(601, Me^.Warehouses > 0);
  UpdateLabels;
end;

procedure TGoodsDlg.UpdateLabels;
var
  I: Integer;
begin
  for I := 1 to 4 do
  begin
    SetNumber(C, 200 + I, GoodStock(Me, I)^);
    SetNumber(C, 400 + I, Sold(I)^);
  end;
  SetNumber(C, 501, WarehouseFreeSpace(Me^));
  SetNumber(C, 502, Me^.Taler);
end;

{ the scroll bar of good I says how much is sold in all }
procedure TGoodsDlg.SellGood(I: Integer);
var
  Delta, Gain: LongInt;
begin
  Delta := LongInt(C.GetPosition(300 + I) - Sold(I)^);
  GoodStock(Me, I)^ := LongInt(GoodStock(Me, I)^ - Delta);
  Gain := LongInt(Int64(GoodPrice(Me, I)) * Delta);
  Me^.Taler := LongInt(Me^.Taler + Gain);
  Me^.TotalGoodsSales := LongInt(Me^.TotalGoodsSales + Gain);
  Sold(I)^ := LongInt(Sold(I)^ + Delta);
  UpdateLabels;
end;

function TGoodsDlg.Handle(Id: SmallInt): Boolean;
var
  E: TDialog;
begin
  Result := True;
  case Id of
    301..304: SellGood(Id - 300);
    601:
      begin
        E := UI.Dialog('ProkuristDlg', $1A3A, [APtr(D), AStr(DSText($22AA))]);
        Move(D.Data[$34], E.Data[$34], SizeOf(TPlayer));
        if UI.Execute(E) = 1 then
          Move(E.Data[$34], D.Data[$34], SizeOf(TPlayer));
        UI.Done(E, 1);
      end;
  else
    Result := False;
  end;
end;

{ -- PROKURADLG ------------------------------------------------------------ }

function TProkuristDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$34]);
end;

procedure TProkuristDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 1 to 4 do
  begin
    C.SetRange(300 + I, 0, DS.ProkuristRanges[I]);
    C.SetPosition(300 + I, PSmallInt(@PByte(@Me^.ProkuristMinSalt)[2 * (I - 1)])^);
  end;
  Update;
end;

procedure TProkuristDlg.Update;
var
  I: Integer;
  MinPrice: PSmallInt;
begin
  for I := 1 to 4 do
  begin
    MinPrice := PSmallInt(@PByte(@Me^.ProkuristMinSalt)[2 * (I - 1)]);
    MinPrice^ := C.GetPosition(300 + I);
    SetNumber(C, 100 + I, MinPrice^);
    if PByte(@Me^.ProkuristSalt)[I - 1] = 0 then
    begin
      C.SetCheck(200 + I, 0);
      C.Enable(300 + I, False);
    end
    else
    begin
      C.SetCheck(200 + I, 1);
      C.Enable(300 + I, True);
    end;
  end;
end;

function TProkuristDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    301..304: Update;
    201..204:
      begin
        PByte(@Me^.ProkuristSalt)[Id - 201] := Ord(PByte(@Me^.ProkuristSalt)[Id - 201] = 0);
        Update;
      end;
  else
    Result := False;
  end;
end;

{ -- Do_Hofschmiede ---------------------------------------------------------- }

procedure Do_Hofschmiede(Parent: Pointer; var P: TPlayer);
var
  Output: LongInt;
  S1, S2: array[0..255] of Char;
  Num: array[0..11] of Char;
  D: TDialog;
begin
  { "we can make N loads of weapons a year in your M smithies"; the second
    line: iron is short (fewer than one load per smithy), more smithies
    would help, or both match }
  Output := SmithyOutput(P);
  StrCopy(S1, DSText($29DE));
  IntToPChar(Num, P.Smithies);
  StrCat(S1, Num);
  StrCat(S1, DSText($29FE));
  IntToPChar(Num, MinLong(P.Smithies, Output));
  StrCat(S1, Num);
  StrCat(S1, DSText($2A13));
  if Output < P.Smithies then
    StrCopy(S2, DSText($2A2E))
  else if Output > P.Smithies then
    StrCopy(S2, DSText($2A70))
  else
    StrCopy(S2, DSText($2AB8));
  D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($2AF7)), AStr(S1), AStr(S2)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- Do_DemographischeDaten -------------------------------------------------- }

procedure Do_DemographischeDaten(Parent: Pointer; HWnd: Word; P: TPlayer);
var
  D: TDialog;
begin
  if P.MaximizeTaxes <> 0 then
    MaximizeTaxes(P);
  D := UI.Dialog('DemographyDlg', $1DBC, [APtr(Parent), AStr(DSText($2896))]);
  Move(P, D.Data[$36], SizeOf(TPlayer));
  PWord(@D.Data[$34])^ := HWnd;
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- BEVDLG ---------------------------------------------------------------- }

{ Str(R * 100:4:1) }
procedure SetPercent(C: TDlgControls; Id: SmallInt; const R: TReal48);
var
  Buf: array[0..255] of Char;
begin
  StrPCopy(Buf, R48Str(R48Mul(R, Hundred), 4, 1));
  C.SetText(Id, Buf);
end;

procedure TDemographyDlg.SetupWindow;
var
  P: PPlayer;
  H: SmallInt;
  Buf: array[0..255] of Char;
  Mood: Word;
begin
  P := PPlayer(@D.Data[$36]);
  UpdateBirthDeathRates(P^);
  H := SmallInt(UpdateHappiness(P^));
  PSmallInt(@D.Data[$70B])^ := H;
  StrPCopy(Buf, IntToStr(H));
  C.SetText(101, Buf);
  SetPercent(C, 102, P^.BirthRate);
  SetPercent(C, 103, P^.DeathRate);
  SetPercent(C, 104, ImmigrationRate(P^));
  SetPercent(C, 105, EmigrationRate(P^));
  { the mood by happiness: critical .. euphoric }
  case H of
    0..29: Mood := $289E;
    30..49: Mood := $28BA;
    50..69: Mood := $28D9;
    70..89: Mood := $28F5;
  else
    Mood := $2916;
  end;
  C.SetText(106, DSText(Mood));
  SetNumber(C, 107, P^.Population);
end;

{ -- Do_Finanzhaushalt ------------------------------------------------------- }

procedure Do_Finanzhaushalt(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  P: PPlayer;

  function L(Off: Integer): PLongInt;
  begin
    Result := PLongInt(@D.Data[Off]);
  end;

begin
  D := UI.Dialog('BudgetDlg', $27CE, [APtr(Parent), AStr(DSText($2826))]);
  P := @Players[Me];
  if P^.MaximizeTaxes <> 0 then
    MaximizeTaxes(P^);
  UpdateBirthDeathRates(P^);
  UpdateHappiness(P^);
  L($34)^ := IncomeFromBuildings(P^);
  L($38)^ := TaxIncome(P^);
  L($3C)^ := JusticeIncome(P^);
  L($40)^ := ArmyPay(P^);
  L($44)^ := LongInt(WarehouseRent(P^) + Interest(P^));
  L($50)^ := TradeAgreementIncome(Players, Me, NumPlayers);
  L($54)^ := SabotageYearlyCost(Players, Me, NumPlayers);
  L($48)^ := LongInt(L($34)^ + L($50)^ + L($38)^ + L($3C)^ - L($40)^ + L($44)^ - L($54)^);
  L($4C)^ := LongInt(P^.Taler + L($48)^);
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- HAUSHALTSDLG ---------------------------------------------------------- }

procedure TBudgetDlg.SetupWindow;
const
  Lines: array[0..8] of Integer = ($34, $38, $3C, $40, $44, $48, $4C, $50, $54);
var
  K: Integer;
  V: LongInt;
begin
  { income from buildings, taxes, justice, - army pay, rent and interest,
    the total, the new treasury, trade agreements, - sabotage }
  for K := 0 to 8 do
  begin
    V := PLongInt(@D.Data[Lines[K]])^;
    if (K = 3) or (K = 8) then
      V := LongInt(-V);
    SetNumber(C, 101 + K, V);
  end;
end;

{ -- Do_InternationalerVergleich --------------------------------------------- }

procedure Do_InternationalerVergleich(Parent: Pointer; var Players: TPlayers; NumPlayers: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('RankingDlg', $2834, [APtr(Parent), AStr(DSText($2888))]);
  Move(Players, D.Data[$2F], SizeOf(TPlayers));
  D.Data[$2E] := NumPlayers;
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- RANGLISTENDLG --------------------------------------------------------- }

procedure TRankingDlg.SetupWindow;
var
  Players: PPlayers;
  Order: array[0..255] of Byte;
  Score: array[0..255] of LongInt;
  Last, I, J, V: Byte;
  Buf: array[0..119] of Char;
begin
  Players := PPlayers(@D.Data[$2F]);
  Last := Byte(D.Data[$2E] - 1);
  for I := 0 to Last do
  begin
    Order[I] := I;
    Score[I] := ComputeScore(Players^[I], 0, 0);
  end;
  { insertion sort, best first; ties keep their order }
  if Last >= 1 then
    for I := 1 to Last do
    begin
      J := I;
      V := Order[I];
      while J <> 0 do
      begin
        if Score[V] <= Score[Order[J - 1]] then
          Break;
        Order[J] := Order[J - 1];
        Dec(J);
      end;
      Order[J] := V;
    end;
  for I := 0 to Last do
  begin
    SetNumber(C, 301 + I, I + 1);
    FormatPlayerTitle(Players^[Order[I]], Buf, 0, 0);
    C.SetText(101 + I, Buf);
    SetNumber(C, 201 + I, Score[Order[I]]);
  end;
end;

{ -- Do_Karriereberatung ---------------------------------------------------- }

procedure Do_Karriereberatung(Parent: Pointer; P: TPlayer);
var
  D: TDialog;
  S: array[0..79] of Char;
  T: Word;
begin
  if not CanBePromoted(P) then
  begin
    D := UI.Dialog('CareerDlg', $1ED8, [APtr(Parent), AStr(DSText($246B))]);
    Move(P, D.Data[$34], SizeOf(TPlayer));
    UI.Execute(D);
    UI.Done(D, 1);
    Exit;
  end;
  { "... you may now call yourself <next title>" }
  T := Word(Byte(P.Title + 1));
  StrCopy(S, DSText($2442));
  if P.IsFemale = 0 then
  begin
    StrCat(S, DSText($2453));
    StrCat(S, DSText(T * 25 + $58E8));
  end
  else
  begin
    StrCat(S, DSText($2458));
    StrCat(S, DSText(T * 25 + $59FC));
  end;
  D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($245D)), AStr(S)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- KARRIEREDLG ----------------------------------------------------------- }

procedure TCareerDlg.SetupWindow;
var
  P: PPlayer;
  T: Byte;
begin
  P := PPlayer(@D.Data[$34]);
  T := Byte(P^.Title + 1);
  C.SetCheck(101, Ord(P^.Population >= DS.PromotionPopulation[T]));
  C.SetCheck(102, Ord(R48Cmp(DS.PromotionHappiness[T], P^.Happiness) <= 0));
  C.SetCheck(103, Ord(P^.Land >= DS.PromotionLand[T]));
  C.SetCheck(104, Ord(ArmyStrength(P^, 1) >= DS.PromotionArmyStrength[T]));
  C.SetCheck(105, Ord(P^.PalaceParts >= DS.PromotionPalaceParts[T]));
  C.SetCheck(106, Ord(P^.CathedralParts >= DS.PromotionCathedralParts[T]));
  C.SetCheck(107, Ord(P^.Taler >= DS.PromotionTaler[T]));
end;

{ -- Do_ManoeverAbhalten ----------------------------------------------------- }

procedure Do_ManoeverAbhalten(Parent: Pointer; var P: TPlayer; Unused: Word);
var
  D: TDialog;
  Cost: LongInt;
  Num: array[0..11] of Char;
  S: array[0..79] of Char;
  WithIp: Byte;
  Last, I: Byte;
  Gains: THeroGains;
begin
  if (DS.Game.InitiativeEnabled <> 0) and (P.Initiative <= 0) then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($26B2))]);   { no initiative }
    UI.Execute(D);
    UI.Done(D, 1);
    Exit;
  end;
  if (P.Army1Count = 0) or (P.ArmyAway <> 0) then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($26BA))]);   { MANOEVERNODLG }
    UI.Execute(D);
    UI.Done(D, 1);
    Exit;
  end;
  Cost := ManoeuvreCost(P);
  IntToPChar(Num, Cost);
  if DS.Game.InitiativeEnabled = 0 then
  begin
    StrCopy(S, DSText($26EC));
    StrCat(S, Num);
    StrCat(S, DSText($26FD));
    D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($2705)), AStr(S)]);
    WithIp := 0;
  end
  else
  begin
    StrCopy(S, DSText($26C8));
    StrCat(S, Num);
    StrCat(S, DSText($26D5));
    D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($26E0)), AStr(S)]);
    WithIp := 1;
  end;
  if UI.Execute(D) = 1 then
  begin
    P.Taler := LongInt(P.Taler - Cost);
    P.TotalMilitarySpendingQ := LongInt(P.TotalMilitarySpendingQ - Cost);
    Inc(P.ManoeuvresHeld);
    P.Initiative := ShortInt(P.Initiative - WithIp);
    FillChar(Gains, SizeOf(Gains), 0);
    Last := P.Army1Count;
    if Last <> 0 then
      for I := 1 to Last do
        if UnitGainExperience(P.Army1[I], Gains, Random(5) + 1, P.Spell) then
          UI.Call('ShowHeroLevelUp', [APtr(Parent), ARec(@Gains, SizeOf(Gains))]);
  end;
  UI.Done(D, 1);
end;

{ -- Wirtschaft, Militaer --------------------------------------------------- }

procedure Do_Wirtschaft(Parent: Pointer; const P: TPlayer);
var
  D: TDialog;
begin
  D := UI.Dialog('EconomyStatsDlg', $1B64, [APtr(Parent), AStr(DSText($0454))]);
  Move(P, D.Data[$2E], SizeOf(TPlayer));
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure Do_Militaer(Parent: Pointer; const P: TPlayer; Year: Word);
var
  D: TDialog;
begin
  D := UI.Dialog('MilitaryStatsDlg', $1B10, [APtr(Parent), AStr(DSText($0448))]);
  Move(P, D.Data[$2E], SizeOf(TPlayer));
  PWord(@D.Data[$703])^ := Year;
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure SetThousands(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..255] of Char;
begin
  FormatThousands(Buf, V);
  C.SetText(Id, Buf);
end;

procedure TEconomyStatsDlg.SetupWindow;
var
  Base: PByte;
  G1, G2, G3, Total: LongInt;
  K: Integer;

  { a running total at player offset Off }
  function T(Off: Integer): LongInt;
  begin
    Result := PLongInt(@Base[Off])^;
  end;

begin
  Base := @D.Data[$2E];
  G1 := LongInt(T($8B) + T($8F) + T($93) + T($9B));
  G2 := LongInt(T($9F) + T($A3) + T($A7) + T($AB));
  G3 := LongInt(T($AF) + T($B3) + T($B7) + T($BB));
  Total := LongInt(G1 + G3 + G2 + T($BF) + T($C3) + T($97));
  for K := 0 to 13 do
    if K < 3 then
      SetThousands(C, 101 + K, T($8B + 4 * K))
    else
      SetThousands(C, 101 + K, T($9B + 4 * (K - 3)));
  SetThousands(C, 115, Total);
  SetThousands(C, 116, G1);
  SetThousands(C, 117, G3);
  SetThousands(C, 118, G2);
  SetThousands(C, 119, T($97));
end;

procedure TMilitaryStatsDlg.SetupWindow;
var
  P: PPlayer;
  Buf: array[0..255] of Char;
  W, L: SmallInt;
  Year: PWord;

  procedure Line(Id: SmallInt; Won, Lost: SmallInt);
  begin
    SetNumber(C, Id, Won);
    SetNumber(C, Id + 1, Lost);
    FormatPercent(Buf, Won, SmallInt(Won + Lost));
    C.SetText(Id + 2, Buf);
  end;

begin
  P := PPlayer(@D.Data[$2E]);
  Line(101, P^.AttacksWon, P^.AttacksLost);
  Line(104, P^.DefencesWon, P^.DefencesLost);
  Line(107, P^.RaiderFightsWon, P^.RaiderFightsLost);
  W := SmallInt(P^.AttacksWon + P^.DefencesWon + P^.RaiderFightsWon);
  L := SmallInt(P^.AttacksLost + P^.DefencesLost + P^.RaiderFightsLost);
  SetNumber(C, 110, W);
  SetNumber(C, 111, L);
  FormatPercent(Buf, W, LongInt(W) + L);
  C.SetText(112, Buf);
  SetNumber(C, 113, SmallInt(P^.OwnUnitsKilled + P^.DesertedUnits + P^.UnitsGivenOrDismissed));
  SetNumber(C, 114, P^.OwnUnitsKilled);
  SetNumber(C, 115, P^.DesertedUnits);
  SetNumber(C, 116, P^.UnitsGivenOrDismissed);
  SetNumber(C, 117, P^.EnemyUnitsKilled);
  { manoeuvres per year }
  Year := PWord(@D.Data[$703]);
  if Year^ = 0 then
    Year^ := 1;
  StrPCopy(Buf, R48Str(R48Div(R48FromLong(P^.ManoeuvresHeld), R48FromLong(Year^)), 4, 2));
  C.SetText(118, Buf);
end;

{ -- Do_Laendernamen -------------------------------------------------------- }

procedure Do_Laendernamen(Parent: Pointer);
var
  D: TDialog;
begin
  D := UI.Dialog('CountryNamesDlg', $2072, [APtr(Parent), AStr(DSText($20C6))]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TCountryNamesDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 0 to 9 do
  begin
    C.SetText(101 + I, DS.CountryNamesRt[I]);
    C.SetText(201 + I, DS.CountryAdjectives[I]);
  end;
end;

function TCountryNamesDlg.Handle(Id: SmallInt): Boolean;
var
  I: Integer;
begin
  if Id <> 200 then
    Exit(False);
  for I := 0 to 9 do
  begin
    StrCopy(DS.CountryNamesRt[I], DS.CountryNames[I]);
    C.SetText(101 + I, DS.CountryNamesRt[I]);
    StrCopy(DS.CountryAdjectives[I], DS.CountryNames[10 + I]);
    C.SetText(201 + I, DS.CountryAdjectives[I]);
  end;
  Result := True;
end;

function TCountryNamesDlg.CanClose: Boolean;
var
  I: Integer;
begin
  for I := 0 to 9 do
  begin
    C.GetText(101 + I, DS.CountryNamesRt[I], 13);
    C.GetText(201 + I, DS.CountryAdjectives[I], 17);
  end;
  Result := True;
end;

{ -- Spiel ------------------------------------------------------------------ }

procedure Do_Spiel(Parent: Pointer);
var
  D: TDialog;
begin
  if StrLen(DS.Game.ScenarioTitle) = 0 then
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($0460))])   { no scenario }
  else
    D := UI.Dialog('ScenarioInfoDlg', $18F2, [APtr(Parent), AStr(DSText($0473))]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TScenarioInfoDlg.SetupWindow;
var
  Buf: array[0..41] of Char;
begin
  C.SetText(101, DS.Game.ScenarioTitle);
  StrCopy(Buf, DSText($1FF4));                    { 'von ' }
  StrCat(Buf, DS.Game.ScenarioAuthor);
  C.SetText(102, Buf);
  C.SetText(103, PChar(@DS.Game.ScenarioDescription));
end;

{ -- player selection ------------------------------------------------------- }

procedure TPlayerSelectDlg.Init;
var
  Players: PPlayers;
  I, K, Last: Byte;
begin
  Players := PPlayers(Args[2].P);
  D.Data[$34] := Byte(Args[4].V);
  D.Data[$33] := Byte(Args[3].V);
  K := 0;
  D.Data[$32] := 0;
  Last := Byte(D.Data[$33] - 1);
  I := 0;
  repeat
    if I <> D.Data[$34] then
    begin
      D.Data[$35 + K] := I;
      FormatPlayerTitle(Players^[I], PChar(@D.Data[$3F + K * $33]), 0, 0);
      Inc(K);
    end;
    if I = Last then
      Break;
    Inc(I);
  until False;
end;

procedure TPlayerSelectDlg.SetupWindow;
var
  I, Last: Byte;
begin
  { the names of all players but one (num - 1 entries) }
  Last := Byte(D.Data[$33] - 2);
  I := 0;
  repeat
    C.AddString(101, PChar(@D.Data[$3F + I * $33]));
    if I = Last then
      Break;
    Inc(I);
  until False;
  C.ComboSetText(101, PChar(@D.Data[$3F + D.Data[$32] * $33]));
end;

function TPlayerSelectDlg.CanClose: Boolean;
begin
  { no selection (-1) reads +0x34: Exclude itself }
  D.Data[$32] := D.Data[$35 + C.GetSelIndex(101)];
  Result := True;
end;

function ChooseDiplomacyTarget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Mode: ShortInt): SmallInt;
var
  D, E: TDialog;
  Name: Word;
  T: Byte;
begin
  case Mode of
    1: Name := $11A2;                 { SPENDEAUSWAHLDLG }
    5: Name := $11B3;                 { TRADEAUSWAHLDLG }
    2: Name := $11C3;                 { TRIBUTAUSWAHLDLG }
  else
    Name := $11D4;                    { SABOAUSWAHLDLG }
  end;
  D := UI.Dialog('PlayerSelectDlg', $357A, [APtr(Parent), AStr(DSText(Name)), APtr(@Players),
    AByte(NumPlayers), AByte(Me)]);
  if UI.Execute(D) = 1 then
  begin
    T := D.Data[$32];
    if (Players[T].Mailbox[Me * 6] = 0) or (Mode = -1) then
      Result := T
    else
    begin
      E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($11E3))]);   { NOAUSWAHLDLG }
      UI.Execute(E);
      UI.Done(E, 1);
      Result := -1;
    end;
  end
  else
    Result := -1;
  UI.Done(D, 1);
end;

{ -- AmountDlg ---------------------------------------------------------------- }

function TAmountDlg.Value: PLongInt;
begin
  Result := PLongInt(@D.Data[$70B]);
end;

procedure TAmountDlg.SetupWindow;
var
  P: PPlayer;
begin
  P := PPlayer(@D.Data[$2E]);
  case D.Data[$70F] of
    0:
      begin
        C.SetRange(101, 1, SmallInt(P^.Taler div 100));
        Value^ := 1;
      end;
    1:
      begin
        C.SetRange(101, 1, SmallInt(LongInt(P^.Land - P^.LandUsed - 12000) div 100));
        Value^ := 1;
      end;
    3:
      begin
        if LongInt(P^.Population - 50) > 10000 then
          C.SetRange(101, 1, 10000)
        else
          C.SetRange(101, 1, SmallInt(P^.Population - 50));
        Value^ := 1;
      end;
    4:
      begin
        C.SetRange(101, 5, 50);
        Value^ := 5;
      end;
  end;
  ShowValue;
end;

procedure TAmountDlg.ShowValue;
var
  Buf: array[0..11] of Char;
begin
  C.SetPosition(101, SmallInt(Value^));
  case D.Data[$70F] of
    0, 1: IntToPChar(Buf, LongInt(Int64(Value^) * 100));
    3, 4: IntToPChar(Buf, Value^);
  else
    Buf[0] := #0;
  end;
  C.SetText(102, Buf);
end;

function TAmountDlg.Handle(Id: SmallInt): Boolean;
begin
  if Id <> 101 then
    Exit(False);
  Value^ := C.GetPosition(101);
  ShowValue;
  Result := True;
end;

function TAmountDlg.CanClose: Boolean;
begin
  if D.Data[$70F] in [0, 1] then
    Value^ := LongInt(Int64(Value^) * 100);
  Result := True;
end;

{ -- Do_Abkommen -------------------------------------------------------------- }

procedure TAbkommenDlg.SetupWindow;
begin
  D.Data[$34] := 0;
  C.SetText(101, PChar(@D.Data[$3B]));
  if D.Data[$35] <> 0 then
  begin
    C.Enable(201, False);                   { peace already }
    D.Data[$34] := 1;
  end;
  if D.Data[$36] = 0 then
    C.Enable(203, False)                    { no trade to cancel }
  else
  begin
    C.Enable(202, False);
    if D.Data[$34] = 1 then
      D.Data[$34] := 2;
  end;
  UpdateRadios;
end;

procedure TAbkommenDlg.UpdateRadios;
var
  I: Integer;
begin
  for I := 0 to 2 do
    C.SetCheck(201 + I, Ord(I = D.Data[$34]));
end;

function TAbkommenDlg.Handle(Id: SmallInt): Boolean;
begin
  if (Id < 201) or (Id > 203) then
    Exit(False);
  D.Data[$34] := Id - 201;
  UpdateRadios;
  Result := True;
end;

{ the message of kind Kind from Me in the mailbox of player T }
procedure PostMessage(var Players: TPlayers; T, Me, Kind: Byte; Data: LongInt);
var
  M: PByte;
begin
  M := @Players[T].Mailbox[Me * 6];
  M[0] := Kind;
  M[1] := 0;
  PLongInt(@M[2])^ := Data;
end;

procedure Do_Abkommen(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  T: SmallInt;
  D, A, E: TDialog;
  Sent: Boolean;
  Buf: array[0..81] of Char;
begin
  Sent := False;
  T := ChooseDiplomacyTarget(Parent, Players, Me, NumPlayers, 5);
  if T < 0 then
    Exit;
  D := UI.Dialog('AbkommenDlg', $0F94, [APtr(Parent), AStr(DSText($11F0))]);
  FormatPlayerTitle(Players[T], Buf, 0, 0);
  StrCopy(PChar(@D.Data[$3B]), Buf);
  D.Data[$35] := Ord(ShortInt(Players[Me].PeaceYears[T]) >= 1);
  D.Data[$36] := Ord(Players[Me].TradeAgreement[T] = 1);
  if UI.Execute(D) = 1 then
    case D.Data[$34] of
      0:
        begin
          { peace for 5..50 years }
          A := UI.Dialog('AmountDlg', $0FFA, [APtr(Parent), AStr(DSText($11FC))]);
          Move(Players[Me], A.Data[$2E], SizeOf(TPlayer));
          A.Data[$70F] := 4;
          Sent := UI.Execute(A) = 1;
          if Sent then
            PostMessage(Players, T, Me, 9, PLongInt(@A.Data[$70B])^);
          UI.Done(A, 1);
        end;
      1:
        begin
          PostMessage(Players, T, Me, 5, 0);           { a trade agreement }
          Sent := True;
        end;
      2:
        begin
          E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($120B))]);   { TRADEALREADYDLG }
          if UI.Execute(E) = 1 then
          begin
            Players[Me].TradeAgreement[T] := 0;
            LoseFame(Players[Me].Fame, 2);
            PostMessage(Players, T, Me, 6, 0);
            Sent := True;
          end;
        end;
    end;
  UI.Done(D, 1);
  if Sent then
  begin
    E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($121B))]);   { KURIERDLG }
    UI.Execute(E);
    UI.Done(E, 1);
  end;
end;

{ -- Do_TributFordern ---------------------------------------------------------- }

procedure TTributDlg.SetupWindow;
var
  I: Integer;
begin
  D.Data[$34] := 0;
  for I := 0 to 4 do
    if D.Data[$70E + I] <> 0 then
      C.Enable(201 + I, False);
  C.SetText(101, PChar(@D.Data[$713]));
  UpdateRadios;
end;

procedure TTributDlg.UpdateRadios;
var
  I: Integer;
begin
  for I := 0 to 4 do
    C.SetCheck(201 + I, Ord(I = D.Data[$34]));
end;

function TTributDlg.Handle(Id: SmallInt): Boolean;
begin
  if (Id < 201) or (Id > 205) then
    Exit(False);
  D.Data[$34] := Id - 201;
  UpdateRadios;
  Result := True;
end;

function TTributDlg.CanClose: Boolean;
begin
  { the radio -> the mailbox sub-kind: people 3, trade 5, peace 4 }
  case D.Data[$34] of
    2: D.Data[$34] := 3;
    3: D.Data[$34] := 5;
    4: D.Data[$34] := 4;
  end;
  Result := True;
end;

procedure Do_TributFordern(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  T: SmallInt;
  D, A, E: TDialog;
  Sent: Boolean;
  Buf: array[0..80] of Char;
  Q: PPlayer;
  Sub: Byte;

  { ask for the amount (AmountDlg in Mode on the target's data) }
  procedure Ask(Name: Word; Mode: Byte);
  begin
    A := UI.Dialog('AmountDlg', $0FFA, [APtr(Parent), AStr(DSText(Name))]);
    Move(Players[T], A.Data[$2E], SizeOf(TPlayer));
    A.Data[$70F] := Mode;
    Sent := UI.Execute(A) = 1;
    if Sent then
      PostMessage(Players, T, Me, 2, PLongInt(@A.Data[$70B])^);
    if Sent then
      Players[T].Mailbox[Me * 6 + 1] := Sub;
    UI.Done(A, 1);
  end;

begin
  Sent := False;
  T := ChooseDiplomacyTarget(Parent, Players, Me, NumPlayers, 2);
  if T < 0 then
    Exit;
  D := UI.Dialog('TributDlg', $0F22, [APtr(Parent), AStr(DSText($1286))]);
  FormatPlayerTitle(Players[T], Buf, 0, 0);
  StrCopy(PChar(@D.Data[$713]), Buf);
  Move(Players[T], D.Data[$35], SizeOf(TPlayer));
  D.Data[$70E] := 0;
  Q := @Players[T];
  { land only from a neighbour with 12000 Hufen to spare }
  if (LongInt(LongInt(Q^.Land - Q^.LandUsed) - 100) > 12000) and
     (AttackInitiativeCost(Players[Me].Country, Q^.Country) < 3) then
    D.Data[$70F] := 0
  else
    D.Data[$70F] := 1;
  D.Data[$710] := Ord(Q^.Population <= 50);
  D.Data[$711] := Ord(Q^.TradeAgreement[Me] <> 0);
  D.Data[$712] := Ord(ShortInt(Q^.PeaceYears[Me]) >= 1);
  if UI.Execute(D) = 1 then
  begin
    Sub := D.Data[$34];
    case Sub of
      0: Ask($1290, 0);                          { ABFRAGETALERDLG }
      1: Ask($12A0, 1);                          { ABFRAGELANDDLG }
      3: Ask($12AF, 3);                          { ABFRAGESKLAVENDLG }
      5:
        begin
          Sent := True;
          PostMessage(Players, T, Me, 2, 0);
          Players[T].Mailbox[Me * 6 + 1] := 5;
        end;
      4: Ask($12C1, 4);                          { ABFRAGEZEITDLG }
    end;
  end;
  UI.Done(D, 1);
  if Sent then
  begin
    E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($12D0))]);   { KURIERDLG }
    UI.Execute(E);
    UI.Done(E, 1);
    if Players[Me].Spell <> 1 then
      LoseFame(Players[Me].Fame, 1);
  end;
end;

{ -- Sabotage --------------------------------------------------------------- }

function ResId(Id: Word): PChar; inline;
begin
  Result := PChar(PtrUInt(Id));
end;

procedure Do_Sabotage(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  I, K, Last: Byte;
begin
  D := UI.Dialog('SabotageBudgetDlg', $13D2, [APtr(Parent), AStr(DSText($142A))]);
  Move(Players, D.Data[$34], SizeOf(TPlayers));
  D.Data[$4486] := Me;
  D.Data[$4487] := NumPlayers;
  K := 0;
  Last := Byte(NumPlayers - 1);
  I := 0;
  repeat
    if I <> Me then
    begin
      D.Data[$4488 + K] := I;
      Inc(K);
    end;
    if I = Last then
      Break;
    Inc(I);
  until False;
  UI.Execute(D);
  Move(D.Data[$34], Players, SizeOf(TPlayers));
  UI.Done(D, 1);
end;

function TSabotageBudgetDlg.Players: PPlayers;
begin
  Result := PPlayers(@D.Data[$34]);
end;

function TSabotageBudgetDlg.Me: PPlayer;
begin
  Result := @Players^[D.Data[$4486]];
end;

function TSabotageBudgetDlg.Row(I: Integer): Byte;
begin
  Result := D.Data[$4488 + I];
end;

procedure TSabotageBudgetDlg.SetupWindow;
var
  I, Last: Byte;
begin
  Last := Byte(D.Data[$4487] - 2);
  I := 0;
  repeat
    C.SetText(101 + I, DS.CountryNamesRt[Players^[Row(I)].Country]);
    C.SetRange(301 + I, 0, (Me^.Title + 1) * 5);
    C.SetPosition(301 + I, PByte(@Me^.SabotageBudget)[Row(I)]);
    if I = Last then
      Break;
    Inc(I);
  until False;
  I := Byte(D.Data[$4487] - 1);
  if I <= 8 then
    repeat
      C.Show(301 + I, 0);                    { the unused rows' scroll bars }
      if I = 8 then
        Break;
      Inc(I);
    until False;
  UpdateRows;
end;

{ the years until the next strike is possible ('' when ready) }
procedure TSabotageBudgetDlg.ShowYears(I: Integer; Empty: Word);
var
  Buf: array[0..31] of Char;
  Y: SmallInt;
  M, T: Byte;
begin
  M := D.Data[$4486];
  T := Row(I);
  Y := SabotageYearsToNextOp(Players^, M, T);
  if Y < 1 then
    StrCopy(Buf, DSText(Empty))
  else
    IntToPChar(Buf, Y);
  C.SetText(601 + I, Buf);
end;

procedure TSabotageBudgetDlg.UpdateRows;
var
  I, Last: Byte;
  Buf: array[0..31] of Char;
begin
  Last := Byte(D.Data[$4487] - 2);
  I := 0;
  repeat
    SetNumber(C, 201 + I, PByte(@Me^.SabotageAgents)[Row(I)]);
    IntToPChar(Buf, PByte(@Me^.SabotageBudget)[Row(I)] * 100);
    StrCat(Buf, DSText($1474));                  { ' Taler' }
    C.SetText(401 + I, Buf);
    if PByte(@Me^.SabotageAgents)[Row(I)] = 0 then
      C.Show(501 + I, 0)
    else
      C.Show(501 + I, 5);
    ShowYears(I, $147A);
    if I = Last then
      Break;
    Inc(I);
  until False;
end;

function TSabotageBudgetDlg.Handle(Id: SmallInt): Boolean;
var
  I: Integer;
  Buf: array[0..31] of Char;
begin
  Result := True;
  case Id of
    301..309:
      begin
        I := Id - 301;
        PByte(@Me^.SabotageBudget)[Row(I)] := Byte(C.GetPosition(Id));
        IntToPChar(Buf, PByte(@Me^.SabotageBudget)[Row(I)] * 100);
        StrCat(Buf, DSText($147C));
        C.SetText(401 + I, Buf);
        ShowYears(I, $1482);
      end;
    501..509:
      begin
        SabotageStrike(D, Players^, D.Data[$4486], D.Data[$4487], Row(Id - 501));
        UpdateRows;
      end;
  else
    Result := False;
  end;
end;

procedure TSabotageWahlDlg.Init;
begin
  StrCopy(PChar(@D.Data[$34]), PChar(Args[2].P));
end;

procedure TSabotageWahlDlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$34]));
end;

function TSabotageWahlDlg.Handle(Id: SmallInt): Boolean;
begin
  case Id of
    201..205: C.EndDlg(Id - 200);
    206: C.EndDlg(0);
  else
    Exit(False);
  end;
  Result := True;
end;

procedure SabotageStrike(Parent: Pointer; var Players: TPlayers; Me, NumPlayers, Target: Byte);
var
  Name: array[0..127] of Char;
  D: TDialog;
  Code: SmallInt;
  Kind, Caught: Byte;
  Amount: LongInt;
  Ok: Boolean;
begin
  FormatPlayerTitle(Players[Target], Name, 0, 0);
  D := UI.Dialog('SabotageWahlDlg', $1306, [APtr(Parent), AStr(DSText($143C)), AStr(Name)]);
  Kind := 0;
  Code := UI.Execute(D);
  if Code = 0 then
    Exit;                                       { no Done: as the original }
  case Code of
    1:                                          { Zuendeln und Kokeln }
      if Players[Target].PalaceParts < 2 then
        case Random(3) of
          0: Kind := 1;
          1: Kind := 3;
          2: Kind := 4;
        end
      else
        Kind := 2;
    2:                                          { Diffamieren }
      case Random(3) of
        0: Kind := 7;
        1: Kind := 8;
        2: Kind := 9;
      end;
    3:                                          { Kampfkraft zersetzen }
      case Random(4) of
        0: Kind := 4;
        1: Kind := 5;
        2: Kind := 6;
        3: Kind := $0B;
      end;
    4:                                          { Ruinieren }
      if Random(5) = 0 then
        Kind := $0D
      else
        Kind := $0E;
    5:                                          { Anschlag auf Leib und Leben }
      case Random(3) of
        0: Kind := 10;
        1: Kind := $0B;
        2: Kind := $0C;
      end;
  end;
  UI.Done(D, 1);
  Ok := SabotageAction(Players, NumPlayers, Me, Target, Kind, Amount, Caught);
  if not Ok then
  begin
    if Caught = 0 then
      D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($1460))])   { VERSAGT1 }
    else
      D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($144C))]);  { VERSAGT2 }
  end
  else
  begin
    if Amount <= 0 then
      StrCopy(Name, DSText($144B))
    else if (Kind = 5) or (Kind = 6) then
      StrCopy(Name, DSText($4BBC + Amount * 25))          { a unit type }
    else
      IntToPChar(Name, Amount);
    if Caught = 0 then
      D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(ResId(700 + Kind)), AStr(Name)])
    else
      D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(ResId(750 + Kind)), AStr(Name)]);
  end;
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ -- Krieg ------------------------------------------------------------------ }

function TGegnerDlg.Players: PPlayers;
begin
  Result := PPlayers(@D.Data[$48]);
end;

procedure TGegnerDlg.Init;
var
  I, Last: Byte;
begin
  D.Data[$3D] := 0;
  D.Data[$3A] := 0;
  D.Data[$3C] := Byte(Args[3].V);
  D.Data[$3B] := Byte(Args[2].V);
  Move(PPlayers(Args[4].P)^, D.Data[$48], SizeOf(TPlayers));
  for I := 0 to 9 do
    D.Data[$449A + I] := $FF;
  Last := Byte(D.Data[$3B] - 1);
  I := 0;
  repeat
    D.Data[$449A + Players^[I].Country] := I;
    if I = Last then
      Break;
    Inc(I);
  until False;
  { every other player is a target (IsValidTarget 1038:4620 always agrees) }
  I := 0;
  repeat
    if I <> D.Data[$3C] then
    begin
      D.Data[$3E + D.Data[$3D]] := I;
      FormatPlayerTitle(Players^[I], PChar(@D.Data[$44A4 + D.Data[$3D] * $33]), 0, 0);
      Inc(D.Data[$3D]);
    end;
    if I = Last then
      Break;
    Inc(I);
  until False;
end;

procedure TGegnerDlg.SetupWindow;
var
  I, Last: Byte;
begin
  Last := Byte(D.Data[$3D] - 1);
  I := 0;
  repeat
    C.AddString(101, PChar(@D.Data[$44A4 + I * $33]));
    if I = Last then
      Break;
    Inc(I);
  until False;
  C.ComboSetText(101, PChar(@D.Data[$44A4 + D.Data[$3A] * $33]));
  SetNumber(C, 201, Players^[D.Data[$3C]].Initiative);
  UpdateCost;
end;

procedure TGegnerDlg.UpdateCost;
var
  M, T: Byte;
begin
  D.Data[$3A] := D.Data[$3E + C.GetSelIndex(101)];
  M := D.Data[$3C];
  T := D.Data[$3A];
  SetNumber(C, 202, AttackInitiativeCost(Players^[M].Country, Players^[T].Country));
end;

function TGegnerDlg.Handle(Id: SmallInt): Boolean;
begin
  if Id <> 101 then
    Exit(False);
  D.Data[$3A] := D.Data[$3E + C.GetSelIndex(101)];
  UpdateCost;
  Result := True;
end;

function TGegnerDlg.CanClose: Boolean;
var
  M, T: Byte;
  E: TDialog;
begin
  D.Data[$3A] := D.Data[$3E + C.GetSelIndex(101)];
  M := D.Data[$3C];
  T := D.Data[$3A];
  if ShortInt(Players^[M].PeaceYears[T]) >= 1 then
    E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($153A))])          { CONFIRMPEACEBUSTDLG }
  else if Players^[M].Initiative < AttackInitiativeCost(Players^[M].Country, Players^[T].Country) then
    E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($154E))])          { the Heer winters abroad }
  else
    Exit(True);
  Result := UI.Execute(E) = 1;
  UI.Done(E, 1);
end;

function DeclareWar(Parent: Pointer; var Players: TPlayers; Me: Byte; var Target: Byte;
  NumPlayers: Byte; Year: Word): Boolean;
var
  D, E: TDialog;
  P: PPlayer;
begin
  Result := False;
  P := @Players[Me];
  if P^.Title < 2 then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($14EC))]);    { GEGNERERRORDLG }
    UI.Execute(D);
    UI.Done(D, 1);
  end
  else if (P^.ArmyAway <> 0) or (P^.Army1Count = 0) then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($14FB))]);    { NOHEERDLG }
    UI.Execute(D);
    UI.Done(D, 1);
  end
  else if (P^.Initiative < 1) and (DS.Game.InitiativeEnabled <> 0) then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($1505))]);    { no initiative }
    UI.Execute(D);
    UI.Done(D, 1);
  end
  else
  begin
    D := UI.Dialog('GegnerDlg', $1498, [APtr(Parent), AStr(DSText($150D)), AByte(NumPlayers),
      AByte(Me), APtr(@Players)]);
    if UI.Execute(D) = 1 then
    begin
      Target := D.Data[$3A];
      if (Players[Target].Army1Count = 0) and (Players[Target].Army2Count = 0) then
      begin
        E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($1517))]);   { HASNOTROOPSDLG }
        if UI.Execute(E) <> 1 then
          Exit(False);                       { no Done of either dialog: as the original }
        UI.Done(E, 1);
      end;
      Result := True;
      if ShortInt(P^.PeaceYears[Target]) > 0 then
      begin
        { breaking the peace; the original clears the target's entry of
          itself instead of its treaty with Me }
        LoseFame(P^.Fame, 50);
        P^.PeaceYears[Target] := 0;
        Players[Target].PeaceYears[Target] := 0;
        Players[Target].Mailbox[Me * 6] := 0;
      end;
    end;
    UI.Done(D, 1);
  end;
end;

procedure Do_KriegFuehren(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
var
  T, R: Byte;
  Title: array[0..101] of Char;
  D: TDialog;
begin
  if not DeclareWar(Parent, Players, Me, T, NumPlayers, Year) then
    Exit;
  UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(@Players[Me]), AByte(1)]);
  DS.Game.GameState := 2;
  R := Battle(Parent, Players[Me], Players[T], Me, T, 0);
  if R = 3 then
  begin
    { the field battle is won: on to the city? }
    FormatPlayerTitle(Players[Me], Title, 0, 0);
    D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($043E)), AStr(Title)]);
    if UI.Execute(D) = 1 then
      R := Battle(Parent, Players[Me], Players[T], Me, T, 1);
    UI.Done(D, 1);
  end;
  if R = 1 then
    AddNews(Players, NumPlayers, T, Me, 8)
  else
    AddNews(Players, NumPlayers, T, Me, 9);
  DS.Game.GameState := 1;
end;

{ -- Demissionieren --------------------------------------------------------- }

procedure Do_Demissionieren(Parent: Pointer; HWnd: Word; var Players: TPlayers);
var
  D: TDialog;
  R: SmallInt;
begin
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($0430))]);
  R := UI.Execute(D);
  UI.Done(D, 1);
  if R <> 1 then
    Exit;
  InitComputerRuler(Players, DS.Game.CurrentPlayer);
  Dec(DS.Game.HumanPlayers);
  DS.Game.LastHuman := DS.Game.CurrentPlayer;
  AddNews(Players, DS.Game.NumPlayers, DS.Game.CurrentPlayer, DS.Game.CurrentPlayer, $10);
  NextPlayer(Parent, HWnd, Players);
  if DS.Game.GameState = 1 then
    if (DS.Game.EmailGameQ = 0) or (DS.Game.CurrentPlayer = DS.Game.LastHuman) then
      BeginHumanTurn(Parent, HWnd, Players);
  if (DS.Game.EmailGameQ <> 0) and (DS.Game.HumanPlayers < 2) then
    DS.Game.EmailGameQ := 0;
end;

{ -- Do_KornVerteilen ------------------------------------------------------ }

procedure Do_KornVerteilen(Parent: Pointer; var P: TPlayer; Mode: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('GrainDlg', $1C50, [APtr(Parent), AStr(DSText($2B5A))]);
  Move(P, D.Data[$34], SizeOf(TPlayer));
  D.Data[$71D] := Mode;
  if UI.Execute(D) = 1 then
    Move(D.Data[$34], P, SizeOf(TPlayer));
  UI.Done(D, 1);
end;

{ -- KORNDLG -------------------------------------------------------------- }

const
  GrCapacity = $709;
  GrReserve = $70D;
  GrMin = $711;
  GrNeed = $715;
  GrMax = $719;

function TGrainDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$34]);
end;

function TGrainDlg.L(Off: Integer): PLongInt;
begin
  Result := PLongInt(@D.Data[Off]);
end;

procedure TGrainDlg.SetupWindow;
var
  Lo, Need, Hi: LongInt;
begin
  L(GrCapacity)^ := GrainCapacity(Me^);
  L(GrReserve)^ := -CreditLimit(Me^);
  GrainNeedMinMax(Me^, Lo, Need, Hi);
  L(GrMin)^ := Lo div 100 * 100;
  L(GrNeed)^ := Need div 100 * 100;
  L(GrMax)^ := (Hi + 100) div 100 * 100;
  SetNumber(C, 201, Me^.Population);
  SetNumber(C, 203, L(GrMin)^);
  SetNumber(C, 204, L(GrNeed)^);
  SetNumber(C, 205, L(GrMax)^);
  SetNumber(C, 207, Me^.GrainPrice);
  SetNumber(C, 208, L(GrCapacity)^);
  C.SetRange(301, SmallInt(L(GrMin)^ div 100), SmallInt(L(GrMax)^ div 100));
  C.SetLineStep(301, 10);
  if D.Data[$71D] <> 0 then
    Me^.GrainDistributed := L(GrNeed)^;
  if (Me^.GrainDistributed < L(GrMin)^) or (Me^.GrainDistributed > L(GrMax)^ + 100) then
    Me^.GrainDistributed := L(GrNeed)^;
  C.SetPosition(301, SmallInt(Me^.GrainDistributed div 100));
  SetNumber(C, 302, Me^.GrainDistributed);
  if DS.Game.GoodsTradeEnabled = 0 then
    C.Enable(501, False)
  else
    C.SetCheck(501, Ord(Me^.BrewBeer <> 0));
  Update;
end;

procedure TGrainDlg.Update;
var
  K: Integer;
  Amt: LongInt;
  G: LongInt;
begin
  SetNumber(C, 206, Me^.Taler);
  SetNumber(C, 202, Me^.Grain);
  G := Me^.Grain;
  C.Enable(401, G >= L(GrMin)^);
  C.Enable(402, G >= L(GrNeed)^);
  C.Enable(403, G >= L(GrMax)^);
  { a purchase must leave the treasury above the credit limit and fit into
    the granaries }
  for K := 0 to 3 do
  begin
    Amt := DS.GrainTradeAmounts[K];
    C.Enable(107 + K, not ((LongInt(Me^.Taler - LongInt(Int64(Amt) * Me^.GrainPrice) div 144) < L(GrReserve)^) or
      (LongInt(G + Amt) > L(GrCapacity)^)));
    C.Enable(101 + K, G >= Amt);
  end;
  C.Enable(105, G > L(GrNeed)^);
  C.Enable(106, G > L(GrMax)^);
  C.Enable(111, (G < L(GrNeed)^) and (L(GrNeed)^ <= L(GrCapacity)^));
  C.Enable(112, (G < L(GrMax)^) and (L(GrMax)^ <= L(GrCapacity)^));
  if Me^.GrainDistributed > G then
    Me^.GrainDistributed := G;
  C.SetPosition(301, SmallInt(Me^.GrainDistributed div 100));
  SetNumber(C, 302, Me^.GrainDistributed);
end;

procedure TGrainDlg.Trade(N: LongInt);
var
  Cost: LongInt;
begin
  UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  Me^.Grain := Me^.Grain + N;
  Cost := LongInt(Int64(N) * Me^.GrainPrice) div 144;
  if N > 0 then
    Inc(Cost);
  if Cost = 0 then
    Cost := 1;
  Me^.Taler := Me^.Taler - Cost;
  Me^.TotalGrainTrade := Me^.TotalGrainTrade - Cost;
  Update;
end;

function TGrainDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    301:
      begin
        Me^.GrainDistributed := LongInt(C.GetPosition(301)) * 100;
        if Me^.GrainDistributed > Me^.Grain then
          Me^.GrainDistributed := Me^.Grain div 100 * 100;
        C.SetPosition(301, SmallInt(Me^.GrainDistributed div 100));
        SetNumber(C, 302, Me^.GrainDistributed);
      end;
    401: begin Me^.GrainDistributed := L(GrMin)^; Update; end;
    402: begin Me^.GrainDistributed := L(GrNeed)^; Update; end;
    403: begin Me^.GrainDistributed := L(GrMax)^; Update; end;
    101..104: Trade(-DS.GrainTradeAmounts[Id - 101]);
    105: Trade(L(GrNeed)^ - Me^.Grain);
    106: Trade(L(GrMax)^ - Me^.Grain);
    107..110: Trade(DS.GrainTradeAmounts[Id - 107]);
    111: begin Me^.GrainDistributed := L(GrNeed)^; Trade(L(GrNeed)^ - Me^.Grain); end;
    112: begin Me^.GrainDistributed := L(GrMax)^; Trade(L(GrMax)^ - Me^.Grain); end;
    501:
      if C.GetCheck(501) = 1 then
      begin
        C.SetCheck(501, 0);
        Me^.BrewBeer := 0;
      end
      else
      begin
        C.SetCheck(501, 1);
        Me^.BrewBeer := 1;
      end;
  else
    Result := False;
  end;
end;

{ distributing more than the stock (KORNERRORDLG) }
function TGrainDlg.CanClose: Boolean;
var
  E: TDialog;
begin
  Result := True;
  if Me^.GrainDistributed > Me^.Grain then
  begin
    E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($2B68))]);
    UI.Execute(E);
    UI.Done(E, 0);
    Result := False;
  end;
end;

initialization
  RegisterDialogLogic('LandDlg', TLandDlg);
  RegisterDialogLogic('GrainDlg', TGrainDlg);
  RegisterDialogLogic('InvestDlg', TInvestDlg);
  RegisterDialogLogic('TaxDlg', TTaxDlg);
  RegisterDialogLogic('GoodsDlg', TGoodsDlg);
  RegisterDialogLogic('ProkuristDlg', TProkuristDlg);
  RegisterDialogLogic('DemographyDlg', TDemographyDlg);
  RegisterDialogLogic('BudgetDlg', TBudgetDlg);
  RegisterDialogLogic('RankingDlg', TRankingDlg);
  RegisterDialogLogic('CareerDlg', TCareerDlg);
  RegisterDialogLogic('EconomyStatsDlg', TEconomyStatsDlg);
  RegisterDialogLogic('MilitaryStatsDlg', TMilitaryStatsDlg);
  RegisterDialogLogic('CountryNamesDlg', TCountryNamesDlg);
  RegisterDialogLogic('ScenarioInfoDlg', TScenarioInfoDlg);
  RegisterDialogLogic('PlayerSelectDlg', TPlayerSelectDlg);
  RegisterDialogLogic('AmountDlg', TAmountDlg);
  RegisterDialogLogic('AbkommenDlg', TAbkommenDlg);
  RegisterDialogLogic('TributDlg', TTributDlg);
  RegisterDialogLogic('SabotageBudgetDlg', TSabotageBudgetDlg);
  RegisterDialogLogic('SabotageWahlDlg', TSabotageWahlDlg);
  RegisterDialogLogic('GegnerDlg', TGegnerDlg);
end.
