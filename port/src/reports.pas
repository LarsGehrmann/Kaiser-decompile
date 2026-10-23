{ The remaining dialogs of segment 9 that the turn and the battles open:
  the building losses (VERLUSTDLG ...), the warehouses full question, the
  trade caravans, the hero's level-up and the look at a unit. The turn
  logic reaches them through UI calls (the tests stub them there); the GUI
  runs these. }
unit Reports;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI;

{ ShowBuildingLossDlg (1040:0565): the 0x37-byte loss record (counts at +8,
  the money at +0 when Money <> 0) on the template Name }
procedure ShowBuildingLossDlg(Parent: Pointer; Name: PChar; const Rec; Money: Byte);
{ AskWarehousesFull (1040:081e): LAGERVOLLDLG, then Gebaeude or Handel }
procedure AskWarehousesFull(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
{ TradeCaravan (1040:08a2): a caravan offers salt, beer, wine or weapons }
procedure TradeCaravan(Parent: Pointer; var P: TPlayer; Year: Word);
{ ShowHeroLevelUp (1040:384b): HEROMADELEVELDLG }
procedure ShowHeroLevelUp(Parent: Pointer; const Gains: THeroGains);
{ ShowUnitLookDlg (1040:330f): UNITLOOKDLG with unit I of army Army (1/2) }
procedure ShowUnitLookDlg(Parent: Pointer; const P: TPlayer; Army, I: Byte);

type
  { VERLUSTDLG ... (VMT DS:20d6, 1040:05ae): the record at +0x2e, the money
    flag +0x65; statics 101..109, 201 }
  TBuildingLossDlg = class(TDialogLogic)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { *KARAWANEDLG_II (VMT DS:2152, 1040:1070): the player at +0x5c, the
    price +0x731, the three offers +0x735 (longints), the choice +0x741;
    radios 101..103, statics 201..203 offers, 204 free space, 205 Taler }
  TCaravanDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    procedure UpdateRadioButtons;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { HEROMADELEVELDLG (VMT DS:1f34, 1040:38b3): the gains at +0x2e; statics
    101..108 }
  THeroLevelUpDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { UNITLOOKDLG (VMT DS:1f9c, 1040:339c, a HelpDlg): the unit at +0x34, the
    blink flag +0x9f; statics 101..111; a 400 ms timer }
  TUnitLookDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    { WMTimer (1040:37d9): the picture blinks now and then (Random(4)) }
    procedure Timer;
  end;

implementation

uses
  Actions;

procedure SetNum(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

{ -- building losses ---------------------------------------------------------- }

procedure ShowBuildingLossDlg(Parent: Pointer; Name: PChar; const Rec; Money: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('BuildingLossDlg', $20D6, [APtr(Parent), AStr(Name), APtr(@Rec), AByte(Money)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TBuildingLossDlg.Init;
begin
  Move(PByte(Args[2].P)^, D.Data[$2E], $37);
  D.Data[$65] := Byte(Args[3].V);
end;

procedure TBuildingLossDlg.SetupWindow;
var
  K: Integer;
begin
  for K := 0 to 8 do
    SetNum(C, 101 + K, PLongInt(@D.Data[$36 + 4 * K])^);
  if D.Data[$65] <> 0 then
    SetNum(C, 201, PLongInt(@D.Data[$2E])^);
end;

{ -- warehouses full ----------------------------------------------------------- }

procedure AskWarehousesFull(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  R: SmallInt;
begin
  D := UI.Dialog('Button2Dlg', $3652, [APtr(Parent), AStr(DSText($212A))]);
  R := UI.Execute(D);
  UI.Done(D, 1);
  if R = 101 then
    Do_Gebaeude(Parent, Players, Me, NumPlayers)
  else if R = 102 then
    Do_HandelMitGuetern(Parent, Players[Me]);
end;

{ -- caravans ------------------------------------------------------------------- }

procedure TradeCaravan(Parent: Pointer; var P: TPlayer; Year: Word);
var
  FreeSpace, Price, Amount: LongInt;
  Good: Byte;
  R: Word;
  D: TDialog;
  Done: Boolean;

  { the caravan of a good: the question, then the offers (price Base +
    Random(PriceRange); the first amount A0 + Random(11) * AStep; the others
    random too) when the first fits the warehouse and the money }
  procedure Offer(Good0: Byte; Ask, Offers: Word; PriceRange, PriceBase, AStep, ABase: SmallInt;
    BStep, BBase, CStep, CBase: SmallInt; BRange: Word);
  var
    E: TDialog;
    B, C: SmallInt;
  begin
    Good := Good0;
    E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText(Ask))]);
    R := Word(UI.Execute(E));
    UI.Done(E, 1);
    if R <> 1 then
      Exit;
    Price := Random(PriceRange) + PriceBase;
    Amount := LongInt(Random(BRange)) * AStep + ABase;
    if (FreeSpace < Amount) or not CanAffordWithCredit(P, LongInt(Int64(Price) * Amount)) then
      Exit;
    B := SmallInt(Random(BRange) * BStep + BBase);
    C := SmallInt(Random(BRange) * CStep + CBase);
    D := UI.Dialog('CaravanDlg', $2152, [APtr(Parent), AStr(DSText(Offers))]);
    Move(P, D.Data[$5C], SizeOf(TPlayer));
    PLongInt(@D.Data[$731])^ := Price;
    PLongInt(@D.Data[$735])^ := Amount;
    PLongInt(@D.Data[$739])^ := Word(B);
    PLongInt(@D.Data[$73D])^ := Word(C);
    Done := UI.Execute(D) = 1;
    if Done then
    begin
      Price := PLongInt(@D.Data[$731])^;
      Amount := PLongInt(@D.Data[$735])^;
    end;
    UI.Done(D, 1);
  end;

var
  E: TDialog;
  No: Word;
begin
  Done := False;
  Good := 0;
  FreeSpace := WarehouseFreeSpace(P);
  R := Random(10);
  { salt 0..2, beer 3..5, wine 6..8, weapons 9 }
  case R of
    0..2: Offer(1, $21A6, $21B6, 5, 7, 10, 50, 100, 300, 500, 2000, 11);
    3..5: Offer(2, $21C9, $21D9, 15, 35, 5, 20, 50, 100, 200, 700, 11);
    6..8: Offer(3, $21EC, $21FC, 20, 80, 4, 10, 20, 50, 100, 300, 11);
    9: Offer(4, $220F, $2221, 100, 400, 1, 1, 1, 3, 1, 5, 2);
  end;
  if Done then
  begin
    P.Taler := LongInt(P.Taler - LongInt(Int64(Price) * Amount));
    P.TotalGoodsSales := LongInt(P.TotalGoodsSales - LongInt(Int64(Price) * Amount));
    AddGoodsCapped(P, Good, Amount);
  end
  else
  begin
    case Good of
      1: No := $2236;
      2: No := $224A;
      3: No := $225E;
    else
      No := $2272;
    end;
    E := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText(No))]);
    UI.Execute(E);
    UI.Done(E, 1);
  end;
end;

procedure TCaravanDlg.SetupWindow;
var
  FreeSpace, Total, Amount: LongInt;
  K: Integer;
  S: array[0..101] of Char;
  N: array[0..11] of Char;
  P: PPlayer;
begin
  P := PPlayer(@D.Data[$5C]);
  FreeSpace := WarehouseFreeSpace(P^);
  for K := 0 to 2 do
  begin
    { "n Last zu t Talern": a cheaper price for the larger offers }
    Amount := PLongInt(@D.Data[$735 + 4 * K])^;
    Total := LongInt(Int64(LongInt(PLongInt(@D.Data[$731])^ - K)) * Amount);
    IntToPChar(N, Amount);
    StrCopy(S, N);
    StrCat(S, DSText($2288));
    IntToPChar(N, Total);
    StrCat(S, N);
    StrCat(S, DSText($2292));
    C.SetText(201 + K, S);
    if not CanAffordWithCredit(P^, Total) or (FreeSpace < Amount) then
    begin
      C.Enable(101 + K, False);
      C.Enable(201 + K, False);
    end;
  end;
  SetNum(C, 204, FreeSpace);
  SetNum(C, 205, P^.Taler);
  UpdateRadioButtons;
end;

procedure TCaravanDlg.UpdateRadioButtons;
var
  K: Integer;
begin
  for K := 0 to 2 do
    C.SetCheck(101 + K, Ord(K = D.Data[$741]));
end;

function TCaravanDlg.Handle(Id: SmallInt): Boolean;
begin
  if (Id < 101) or (Id > 103) then
    Exit(False);
  D.Data[$741] := Id - 101;
  UpdateRadioButtons;
  Result := True;
end;

function TCaravanDlg.CanClose: Boolean;
var
  K: Byte;
begin
  K := D.Data[$741];
  PLongInt(@D.Data[$735])^ := PLongInt(@D.Data[$735 + 4 * K])^;
  PLongInt(@D.Data[$731])^ := LongInt(PLongInt(@D.Data[$731])^ - K);
  Result := True;
end;

{ -- the hero's level-up ---------------------------------------------------------- }

procedure ShowHeroLevelUp(Parent: Pointer; const Gains: THeroGains);
var
  D: TDialog;
begin
  D := UI.Dialog('HeroLevelUpDlg', $1F34, [APtr(Parent), AStr(DSText($242C))]);
  Move(Gains, D.Data[$2E], $20);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure THeroLevelUpDlg.SetupWindow;
var
  S: array[0..41] of Char;
  N: array[0..41] of Char;
  K: Integer;
begin
  C.SetText(101, PChar(@D.Data[$2E]));
  HeroRankName(D.Data[$47], S);
  StrCat(S, DSText($2440));                         { '!' }
  C.SetText(102, S);
  for K := 0 to 5 do
  begin
    StrCopy(S, DSText($243E));                      { '+' }
    IntToPChar(N, D.Data[$48 + K]);
    StrCat(S, N);
    C.SetText(103 + K, S);
  end;
end;

{ -- the look at a unit ----------------------------------------------------------- }

procedure ShowUnitLookDlg(Parent: Pointer; const P: TPlayer; Army, I: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('UnitLookDlg', $1F9C, [APtr(Parent), AStr(DSText($2418))]);
  if Army = 1 then
    Move(PByte(@P)[$FC + I * $3D], D.Data[$34], $3D)
  else
    Move(PByte(@P)[$321 + I * $3D], D.Data[$34], $3D);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TUnitLookDlg.SetupWindow;
var
  B: PByte;
  S: array[0..25] of Char;
begin
  B := @D.Data[$34];
  { (the help context: the unit type + 200) }
  C.SetText(101, PChar(B));
  UnitRankName(PUnit(B)^, S);
  C.SetText(102, S);
  SetNum(C, 103, B[$1B]);
  SetNum(C, 104, Word(SmallInt(ShortInt(B[$1C]))));     { (IntToStr with a zero high word) }
  SetNum(C, 105, ShortInt(B[$1D]));
  SetNum(C, 106, B[$1F]);
  SetNum(C, 107, Word(SmallInt(ShortInt(B[$20]))));
  SetNum(C, 108, PSmallInt(@B[$2B])^);
  C.SetText(109, DSText($53D8 + B[$2F] * 25));
  SetNum(C, 110, PLongInt(@B[$27])^);
  if ShortInt(B[$22]) = 0 then
    C.SetText(111, DSText($2424))                   { '-' }
  else
    SetNum(C, 111, Word(SmallInt(ShortInt(B[$22]))));
  UI.Call('UnitLookDlg_DrawUnitPicture', [AByte(D.Data[$9F]), APtr(D)]);
end;

procedure TUnitLookDlg.Timer;
begin
  { WMTimer (1040:37d9) }
  if D.Data[$9F] <> 0 then
    D.Data[$9F] := 0
  else if Random(4) = 0 then
    D.Data[$9F] := 1;
  UI.Call('UnitLookDlg_DrawUnitPicture', [AByte(D.Data[$9F]), APtr(D)]);
end;

initialization
  RegisterDialogLogic('BuildingLossDlg', TBuildingLossDlg);
  RegisterDialogLogic('CaravanDlg', TCaravanDlg);
  RegisterDialogLogic('HeroLevelUpDlg', THeroLevelUpDlg);
  RegisterDialogLogic('UnitLookDlg', TUnitLookDlg);
end.
