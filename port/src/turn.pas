{ Turn processing: the yearly functions of segment 3 (1010:xxxx), ported in
  the original order of operations. Dialogs and UI functions go through
  KaiserUI exactly where the original opens them; differential tests:
  port/tests/ruletest.pas with the UI calls replayed. }
unit Turn;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI;

procedure RulerFallsIll(Parent: Pointer);                   { 1010:3777 }
procedure WitchChoosesSpell(Parent: Pointer; var P: TPlayer);  { 1010:372a }
procedure GrantFirstHero(Parent: Pointer; var P: TPlayer);  { 1010:2c50 }
procedure HarvestReport(Parent: Pointer; P: TPlayer; Factor: TReal48);  { 1010:288d }
procedure Report_Population(Parent: Pointer; P: TPlayer);  { 1010:27c9 }
procedure Report_Budget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);  { 1010:263f }
procedure LandLossCheck(Parent: Pointer; var P: TPlayer);   { 1010:4891 }
procedure SkipTurnCheck(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);  { 1010:5707 }
procedure RevolutionCheck(Parent: Pointer; var P: TPlayer); { 1010:55bb }
procedure GrainShortageWarning(Parent: Pointer; var P: TPlayer);  { 1010:47b1 }
procedure MarriageDowry(Parent: Pointer; var P: TPlayer);   { 1010:2924 }

implementation

{ the original writes report values into the dialog object before Execute }
procedure PutLong(D: TDialog; Ofs: Integer; V: LongInt);
begin
  Move(V, D.Data[Ofs], 4);
end;

procedure PutReal(D: TDialog; Ofs: Integer; const V: TReal48);
begin
  Move(V, D.Data[Ofs], 6);
end;

{ MAKEINTRESOURCE }
function ResId(Id: Word): PChar; inline;
begin
  Result := PChar(PtrUInt(Id));
end;

procedure RulerFallsIll(Parent: Pointer);
var
  D: TDialog;
begin
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($099E))]);   { KRANKDLG }
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure WitchChoosesSpell(Parent: Pointer; var P: TPlayer);
var
  D: TDialog;
begin
  D := UI.Dialog('HexenDlg', $0598, [APtr(Parent), AStr(DSText($0994))]);    { HEXENDLG }
  UI.Execute(D);
  P.Spell := D.Data[$38];
  UI.Done(D, 1);
end;

procedure GrantFirstHero(Parent: Pointer; var P: TPlayer);
var
  D: TDialog;
begin
  { the first hero of the game; the dialog can also choose the Lindwurm }
  D := UI.Dialog('HeroNameDlg', $351E, [APtr(Parent), AStr(DSText($098C)), AWord(0)]);
  UI.Execute(D);
  if D.Data[$49] = 1 then
    RecruitUnit(P, 1, 12, 0)                   { (the dialog is not freed here) }
  else
  begin
    Inc(P.Army1Count);
    CreateHero(P.Army1[P.Army1Count], UI.GetText(D));
    UI.Done(D, 1);
  end;
  SortArmy(P, 1);
end;

procedure HarvestReport(Parent: Pointer; P: TPlayer; Factor: TReal48);
var
  Buf: array[0..7] of Char;
  D: TDialog;
begin
  { "n %" grain lost; the text resource depends on the harvest quality }
  IntToPChar(Buf, R48Round(R48Mul(Factor, RC($0087, 0, $4800))));
  StrCat(Buf, DSText($098A));
  D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(ResId(P.HarvestQuality + 100)), AStr(Buf)]);
  UI.Execute(D);
  UI.Done(D, 0);
end;

procedure Report_Population(Parent: Pointer; P: TPlayer);
var
  D: TDialog;
begin
  D := UI.Dialog('StartPopDlg', $0536, [APtr(Parent), AStr(DSText($097E))]);
  PutLong(D, $2E, P.Births);
  PutLong(D, $32, P.Deaths);
  PutLong(D, $36, P.Immigrants);
  PutLong(D, $3A, P.Emigrants);
  PutReal(D, $3E, P.Happiness);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure Report_Budget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('StartFinanzDlg', $0916, [APtr(Parent), AStr(DSText($096E))]);
  with Players[Me] do
  begin
    PutLong(D, $34, IncomeBuildings);
    PutLong(D, $38, TaxIncome);
    PutLong(D, $3C, JusticeIncome);
    PutLong(D, $40, ArmyPay);
    PutLong(D, $44, RentAndInterest);
    PutLong(D, $4C, NetIncome);
    PutLong(D, $50, Taler);
    PutLong(D, $48, EventMoney);
    PutLong(D, $54, TradeIncome);
  end;
  PutLong(D, $58, SabotageYearlyCost(Players, Me, NumPlayers));
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure LandLossCheck(Parent: Pointer; var P: TPlayer);
var
  L: TLandLoss;
begin
  { buildings that no longer have land: a fifth of their price back }
  FillChar(L, SizeOf(L), 0);
  if BuildingsLostForLand(P, L) then
  begin
    P.Taler := P.Taler + L.Total;
    P.BuildingBalance := P.BuildingBalance + L.Total;
    UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText($09B8)), ARec(@L, SizeOf(L)), AByte(1)]);
    LoseFame(P.Fame, 2);
  end;
end;

{ a KaiserDlg with only an OK button }
procedure ShowKaiserDlg(Parent: Pointer; Name: PChar);
var
  D: TDialog;
begin
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(Name)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure SkipTurnCheck(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
begin
  { a skipped year (AUSSETZDLG): losses, mild ones if caused by sabotage }
  if Players[Me].SkipTurn = 0 then
    Exit;
  ShowKaiserDlg(Parent, DSText($0A40));
  SkipTurnLosses(Players[Me], Ord((PLongInt(@Players[Me].Flags5bdQ)^ and $200) = 0));
  AddNews(Players, NumPlayers, Me, Me, $0B);
end;

procedure RevolutionCheck(Parent: Pointer; var P: TPlayer);
var
  D: TDialog;
  R: SmallInt;
begin
  { happiness below 0.3: unrest; it fails with chance 1 - 1/(happiness*10) }
  if R48Cmp(P.Happiness, RC($9A7F, $9999, $1999)) >= 0 then
    Exit;
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($0A22))]);
  UI.Call('PlaySound', [AWord($0E), AWord(1)]);
  UI.Execute(D);
  UI.Done(D, 1);
  R := SmallInt(R48Round(R48Mul(P.Happiness, RC($0084, 0, $2000))));
  if Random(Word(R)) <> 0 then
  begin
    ShowKaiserDlg(Parent, DSText($0A2E));
    LoseFame(P.Fame, 10);
    Dec(P.Lifetime);
  end
  else
  begin
    { the revolution succeeds }
    ShowKaiserDlg(Parent, DSText($0A38));
    P.SkipTurn := 1;
    if P.Title > 0 then
      Dec(P.Title);
    LoseFame(P.Fame, 50);
    P.Lifetime := P.Lifetime - 2;
  end;
end;

procedure GrainShortageWarning(Parent: Pointer; var P: TPlayer);
var
  Low, Need, High: LongInt;
  D: TDialog;
begin
  GrainNeedMinMax(P, Low, Need, High);
  Need := Need - Need div 10;
  if P.GrainDistributed > P.Grain then
    P.GrainDistributed := P.Grain;
  if P.GrainDistributed < Need then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($09A8))]);
    if UI.Execute(D) = 2 then                  { "distribute more" }
      UI.Call('Do_KornVerteilen', [APtr(Parent), APtr(@P), AByte(0)]);
    UI.Done(D, 1);
  end;
end;

procedure MarriageDowry(Parent: Pointer; var P: TPlayer);
var
  K, I: Byte;
  D: TDialog;

  { recruit a unit for free (no pay) }
  procedure FreeUnit(UnitType: Byte);
  begin
    RecruitUnit(P, 1, UnitType, 0);
    P.Army1[P.Army1Count].BasePay := 0;
    P.Army1[P.Army1Count].Pay := 0;
  end;

begin
  K := Random(9) + 1;
  if P.IsFemale = 0 then
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(ResId(K + 200))])
  else
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(ResId(K + 250))]);
  UI.Execute(D);
  UI.Done(D, 0);
  case K of
    1:
      begin
        P.Land := P.Land + 1200;
        FreeUnit($21);
      end;
    2:
      begin
        P.Mills := P.Mills + 1;
        P.Grain := P.Grain + 5000;
      end;
    3:
      begin
        P.Markets := P.Markets + 2;
        FreeUnit(2);
      end;
    4:
      begin
        P.Land := P.Land + 1000;
        P.Grain := P.Grain + 3000;
      end;
    5:
      begin
        P.Grain := P.Grain + 1000;
        for I := 1 to 2 do
          FreeUnit(1);
      end;
    6:
      begin
        P.Land := P.Land + 1500;
        P.Taler := P.Taler + 2000;
        P.TotalEventMoney := P.TotalEventMoney + 2000;
      end;
    7:
      begin
        P.Mills := P.Mills + 2;
        P.Taler := P.Taler + 1000;
        P.TotalEventMoney := P.TotalEventMoney + 1000;
      end;
    8:
      begin
        P.Taler := P.Taler + 3000;
        P.TotalEventMoney := P.TotalEventMoney + 3000;
        FreeUnit($21);
      end;
    9:
      begin
        P.Granaries := P.Granaries + 1;
        P.Taler := P.Taler + 500;
      end;
  end;
end;

end.
