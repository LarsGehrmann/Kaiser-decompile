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
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI;

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
end.
