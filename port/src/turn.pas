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
procedure Bankruptcy(Parent: Pointer; var P: TPlayer);      { 1010:4f9f }
procedure FormatPlayerTitle(const P: TPlayer; Dest: PChar; WithPrefix, WithEpithet: Byte);  { 1060:03d9 }
procedure PromotionCheck(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);                                              { 1010:48fc }
procedure SabotageEnd(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);  { 1010:192f }
function ShowStartTurnDialog(Parent: Pointer; var P: TPlayer; Me: Byte; Year: Word): Boolean;  { 1010:0002 }
procedure OfferUnitsAtTurnStart(Parent: Pointer; var P: TPlayer);  { 1010:22d4 }
procedure RollYearlyEvent(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);                                              { 1010:2ce5 }
procedure Report_Gossip(Parent: Pointer; var Players: TPlayers; Me: Byte);  { 1010:1bf0 }
procedure DiplomacyTurnStart(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);                                              { 1010:00e5 }
procedure Msg_ReceiveAid(Parent: Pointer; var Players: TPlayers; Me, Sender: Byte;
  Data: LongInt);                                           { 1010:0467 }
procedure Msg_Negotiation(Parent: Pointer; var Players: TPlayers; Me, Sender, NumPlayers,
  Kind: Byte; Year: Word);                                  { 1010:06f6 }
procedure Msg_TributeDemand(Parent: Pointer; var Players: TPlayers; Me, Sender: Byte;
  Data: LongInt);                                           { 1010:0ead }
procedure Msg_TributeAnswer(Parent: Pointer; var Players: TPlayers; Me, Sender, Sub: Byte;
  Data: LongInt; Paid: Byte);                               { 1010:17c6 }

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

procedure Bankruptcy(Parent: Pointer; var P: TPlayer);
var
  Credit, Debt, Orig: LongInt;
  L: TLandLoss;
  D: TDialog;

  { seize buildings of one kind, a fifth of the price each, while debt is left }
  function Seize(Count: LongInt; Price: Byte): LongInt;
  begin
    Result := 1;
    while (Result <= Count) and (Debt > 0) do
    begin
      Inc(Result);
      Debt := Debt - DS.BuildingPrices[Price] div 5;
    end;
    Dec(Result);
  end;

begin
  Credit := CreditLimit(P);
  if P.Taler < 0 then
    LoseFame(P.Fame, 1);
  if LongInt(-Credit) < P.Taler then
    Exit;
  if Random(2) = 0 then
  begin
    { the bank waits another year }
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($0A06))]);
    UI.Execute(D);
    UI.Done(D, 0);
    Exit;
  end;
  FillChar(L, SizeOf(L), 0);
  Debt := LongInt(Abs(P.Taler) - Credit);
  Orig := Debt;
  L.Markets := Seize(P.Markets, 0);
  L.Mills := Seize(P.Mills, 1);
  L.Granaries := Seize(P.Granaries, 4);
  L.Warehouses := Seize(P.Warehouses, 5);
  L.Taverns := Seize(P.Taverns, 7);
  L.Smithies := Seize(P.Smithies, 8);
  L.UniversityParts := Seize(P.UniversityParts, 6);
  L.PalaceParts := Seize(P.PalaceParts, 2);
  L.CathedralParts := Seize(P.CathedralParts, 3);
  if (L.Markets = 0) and (L.Mills = 0) and (L.PalaceParts = 0) and (L.CathedralParts = 0) and
     (L.Granaries = 0) and (L.Warehouses = 0) then
  begin
    { nothing (that counts) to seize }
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($0A06))]);
    UI.Execute(D);
    UI.Done(D, 0);
    Exit;
  end;
  P.Markets := P.Markets - L.Markets;
  P.Mills := P.Mills - L.Mills;
  if L.PalaceParts > 0 then
  begin
    if P.PalaceParts = 12 then
      LoseFame(P.Fame, 10);
    P.PalaceParts := Byte(P.PalaceParts - Byte(L.PalaceParts));
  end;
  if L.CathedralParts > 0 then
  begin
    if P.CathedralParts = 12 then
      LoseFame(P.Fame, 20);
    P.CathedralParts := Byte(P.CathedralParts - Byte(L.CathedralParts));
  end;
  RemoveGranaries(P, L.Granaries);
  RemoveWarehouses(P, L.Warehouses);
  P.UniversityParts := Byte(P.UniversityParts - Byte(L.UniversityParts));
  P.Taverns := P.Taverns - L.Taverns;
  P.Smithies := P.Smithies - L.Smithies;
  P.Taler := LongInt(-Credit) - Debt;
  L.Total := Orig - Debt;
  P.BuildingBalance := P.BuildingBalance + L.Total;
  UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText($0A14)), ARec(@L, SizeOf(L)), AByte(1)]);
  LoseFame(P.Fame, 7);
end;

procedure FormatPlayerTitle(const P: TPlayer; Dest: PChar; WithPrefix, WithEpithet: Byte);
var
  Sp: array[0..1] of Char;
begin
  { "[Kaiser - ]<title> <name>[ genannt "<epithet>"] von <country>" }
  StrCopy(Sp, DSText($4166));                          { ' ' }
  if WithPrefix <> 0 then
    StrCopy(Dest, DSText($4168))                       { 'Kaiser - ' }
  else
    StrCopy(Dest, DSText($4167));                      { '' }
  if P.IsFemale = 0 then
    StrCat(Dest, DS.TitleNames[P.Title])
  else
    StrCat(Dest, DS.FemaleTitleNames[P.Title]);
  StrCat(Dest, Sp);
  StrCat(Dest, P.Name);
  if (WithEpithet <> 0) and (P.Spell <> 0) then
  begin
    StrCat(Dest, DSText($4172));                       { ' genannt "' }
    if P.IsFemale = 0 then
      StrCat(Dest, DSText($3EDA + 25 * P.Spell))
    else
      StrCat(Dest, DSText($4020 + 25 * P.Spell));
    StrCat(Dest, DSText($417B));                       { '"' }
  end;
  StrCat(Dest, DSText($417D));                         { ' von ' }
  StrCat(Dest, DS.CountryNamesRt[P.Country]);
end;

procedure PromotionCheck(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
var
  P: PPlayer;
  T, I, K, R: Byte;
  D: TDialog;
  Buf: array[0..80] of Char;
  NewU: TUnit;
  Gains: THeroGains;
  Hero: PUnit;

  procedure AddToArmy;
  begin
    if (P^.Army1Count < 8) and (P^.ArmyAway = 0) then
      AddUnitToArmy(P^, 1, NewU)
    else
      AddUnitToArmy(P^, 2, NewU);
  end;

begin
  FillChar(NewU, SizeOf(NewU), 0);
  FillChar(Gains, SizeOf(Gains), 0);
  P := @Players[Me];
  T := Byte(P^.Title + 1);
  if not CanBePromoted(P^) then
    Exit;
  Inc(P^.Lifetime);
  if T = 10 then
  begin
    P^.Title := T;                                     { Kaiser: the game is won }
    Exit;
  end;
  UI.Call('PlaySound', [AWord(1), AWord(1)]);
  if P^.IsFemale = 0 then
    D := UI.Dialog('PromotionDlg', $05F0, [APtr(Parent), AStr(DSText($09CE))])     { BEFDLG }
  else
    D := UI.Dialog('PromotionDlg', $05F0, [APtr(Parent), AStr(DSText($09D5))]);    { FEMBEFDLG }
  PWord(@D.Data[$7F])^ := Year;
  D.Data[$81] := P^.Title;
  D.Data[$82] := P^.IsFemale;
  FormatPlayerTitle(P^, Buf, 0, 0);
  StrCopy(PChar(@D.Data[$2E]), Buf);
  UI.ExecDialog(D);
  P^.Title := T;
  GainFame(P^.Fame, 10);
  if (P^.Title <> 9) or (P^.FirstKingBonus <> 0) then
    Exit;
  { Koenig for the first time }
  AddNews(Players, NumPlayers, Me, Me, $0D);
  P^.FirstKingBonus := 1;
  if not IsFirstKing(Players, Me, NumPlayers) then
    Exit;
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($09DF))]);         { FIRSTKINGDLG }
  UI.Execute(D);
  UI.Call('FreeMem', [APtr(D), AWord($2E)]);
  if not HasHero(P^) then
  begin
    { a hero; as in the original the three level-ups go to the last unit of
      the Heer, not to the new hero }
    D := UI.Dialog('HeroNameDlg', $351E, [APtr(Parent), AStr(DSText($09EC)), AWord(0)]);
    UI.Execute(D);
    CreateHero(NewU, UI.GetText(D));
    for I := 0 to 2 do
      UnitGainExperience(P^.Army1[P^.Army1Count], Gains, I * 2 + 10, P^.Spell);
    AddToArmy;
    UI.Done(D, 1);
    UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(P), AByte(0)]);
    Exit;
  end;
  K := Random(3);
  case K of
    0:
      if FindHero(P^, Hero, 1) then
      begin
        Inc(Hero^.Attack);
        Inc(Hero^.MaxHp);
        Inc(Hero^.Defence);
        ShowKaiserDlg(Parent, ResId(K + 600));
      end;
    1:
      begin
        { half pay for everyone }
        for I := 1 to P^.Army1Count do
        begin
          P^.Army1[I].BasePay := P^.Army1[I].BasePay div 2;
          P^.Army1[I].Pay := P^.Army1[I].Pay div 2;
        end;
        for I := 1 to P^.Army2Count do
        begin
          P^.Army2[I].BasePay := P^.Army2[I].BasePay div 2;
          P^.Army2[I].Pay := P^.Army2[I].Pay div 2;
        end;
        ShowKaiserDlg(Parent, ResId(K + 600));
      end;
    2:
      begin
        { a free unit of one of five types }
        R := Random(5);
        InitUnit(P^, NewU, PByte(@DS)[$09C2 + R], PByte(@DS)[$09C8 + R]);
        NewU.Pay := 0;
        D := UI.Dialog('UnitInfoDlg', $35E6, [APtr(Parent), AStr(DSText($09FA)),
          ARec(@NewU, SizeOf(NewU)), AByte($66), AWord(PByte(@DS)[$09C2 + R] + 200)]);
        if UI.Execute(D) = 1 then
        begin
          UI.Done(D, 1);
          AddToArmy;
          UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(P), AByte(0)]);
        end
        else
          UI.Done(D, 1);
      end;
  end;
end;

procedure SabotageEnd(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  I, Last, Kind, Attacker: Byte;
  Amount: LongInt;
  Text: array[0..127] of Char;
  D: TDialog;
begin
  { the yearly sabotage budget, then the reports of strikes against Me }
  SabotageFunding(Players, Me, NumPlayers);
  P := @Players[Me];
  Last := P^.SabotageLogCount;
  for I := 1 to Last do
  begin
    Attacker := P^.SabotageLog[6 * I - 6];
    Kind := P^.SabotageLog[6 * I - 5];
    Amount := PLongInt(@P^.SabotageLog[6 * I - 4])^;
    if Kind = $0D then
      P^.EventMoney := P^.EventMoney - Amount;
    if Kind = $0E then
      P^.EventMoney := P^.EventMoney - Amount;
    if P^.CpuLevel = 0 then
    begin
      StrCopy(Text, DSText($07B0));                    { '' }
      if Kind > 0 then
        D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(ResId(Kind + 500)), AStr(Text)])
      else if Chance(R48Round(R48Mul(RC($0087, 0, $4800), P^.Justice))) then
      begin
        { the caught agent names his master }
        FormatPlayerTitle(Players[Attacker], Text, 0, 0);
        D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($07B1)), AStr(Text)]);
      end
      else
        D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText($07C2)), AStr(Text)]);
      UI.Execute(D);
      UI.Done(D, 1);
    end
    else if Kind = 0 then
      LoseFame(PSmallInt(@P^.AttitudeQ)[Attacker], 20);   { a computer remembers }
    FillChar(P^.SabotageLog[6 * I - 6], 6, 0);
  end;
  P^.SabotageLogCount := 0;
  if (PLongInt(@P^.Flags5bdQ)^ and $200) <> 0 then
  begin
    Dec(P^.Lifetime);
    P^.SkipTurn := 1;
  end;
end;

function ShowStartTurnDialog(Parent: Pointer; var P: TPlayer; Me: Byte; Year: Word): Boolean;
var
  Title: array[0..57] of Char;
  YearStr: array[0..5] of Char;
  D: TDialog;
begin
  UI.Call('PlaySound', [AWord(9), AWord(1)]);
  FormatPlayerTitle(P, Title, 0, 0);
  IntToPChar(YearStr, Word(Year + 1400));
  if (DS.Game.EmailGameQ <> 0) and (Me <> DS.Game.LastHuman) then
    { e-mail game: the next human enters the password }
    Exit(Byte(UI.Call('Email_AskPassword', [APtr(Parent), APtr(@P), AStr(Title), AStr(YearStr)])) <> 0);
  if P.IsFemale = 0 then
    D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($0644)), AStr(Title), AStr(YearStr)])
  else
    D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($0651)), AStr(Title), AStr(YearStr)]);
  UI.Execute(D);
  UI.Done(D, 1);
  Result := True;
end;

procedure OfferUnitsAtTurnStart(Parent: Pointer; var P: TPlayer);
var
  Offer, Accept: Boolean;
  UnitType, Bonus, L: Byte;
  HelpId: Word;
  Name: array[0..15] of Char;
  NewU: TUnit;
  D: TDialog;

  { a special unit of the player's spell: 1 / (30 - fame div 5) a year }
  procedure SpellUnit(T: Byte; NameOfs, Help: Word);
  begin
    if (Random(Word(30 - P.Fame div 5)) = 0) and (P.Title >= DS.UnitTitleNeeded[T]) then
    begin
      UnitType := T;
      HelpId := Help;
      StrCopy(Name, DSText(NameOfs));
      Offer := True;
    end;
  end;

begin
  FillChar(NewU, SizeOf(NewU), 0);
  FillChar(Name, SizeOf(Name), 0);
  Offer := False;
  UnitType := 0;
  HelpId := 0;
  Bonus := 0;
  case P.Spell of
    3: SpellUnit($22, $08DA, $EA);                     { Chevalerie }
    8: SpellUnit($15, $08E6, $83);                     { Heilende Haende }
    7: SpellUnit($11, $08EE, $82);                     { Gaias Segen }
    $0B:                                               { Pietaet: monks, rarer with more }
      begin
        L := Byte((CountUnitsOfType(P, $0B) + 1) * 15 - P.Fame div 10);
        if (Random(L) = 0) and (P.Title >= DS.UnitTitleNeeded[$0B]) then
        begin
          UnitType := $0B;
          StrCopy(Name, DSText($08F7));
          HelpId := $7F;
          Offer := True;
        end;
      end;
    $0C:                                               { Terror: a vampire, then ... }
      if (P.Title >= DS.UnitTitleNeeded[$0A]) and (CountUnitsOfType(P, $0A) < 1) then
      begin
        UnitType := $0A;
        StrCopy(Name, DSText($0902));
        HelpId := $80;
        Offer := True;
      end
      else
        SpellUnit($12, $090C, $81);
  end;
  if not Offer then
  begin
    { mercenaries }
    if P.Spell = $0A then
      L := 12
    else
      L := 14;
    if Random(Word(L - P.Fame div 10)) = 0 then
    begin
      UnitType := RandomMercenaryType(P);
      HelpId := UnitType + 200;
      StrCopy(Name, DSText($08DA));
      Offer := True;
    end;
  end;
  if not Offer then
    Exit;
  case Random(10) of
    0..6: Bonus := 0;
    7..8: Bonus := 1;
    9: Bonus := 2;
  end;
  Accept := False;
  InitUnit(P, NewU, UnitType, Bonus);
  if P.CpuLevel = 0 then
  begin
    D := UI.Dialog('UnitInfoDlg', $35E6, [APtr(Parent), AStr(Name), ARec(@NewU, SizeOf(NewU)),
      AByte($66), AWord(HelpId)]);
    if UI.Execute(D) = 1 then
      Accept := True;
    UI.Done(D, 1);
  end
  else
    Accept := True;
  if not Accept then
    Exit;
  if P.CpuLevel = 0 then
  begin
    if (P.Army1Count < 8) and (P.ArmyAway = 0) then
      AddUnitToArmy(P, 1, NewU)
    else
      AddUnitToArmy(P, 2, NewU);
    UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(@P), AByte(0)]);
  end
  else
    AddUnitToArmy(P, 1, NewU);                       { (even into a full Heer) }
end;

procedure RollYearlyEvent(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
var
  P: PPlayer;
  E, F, G, I: Byte;
  A, U, K: LongInt;
  R: LongInt;
  Hero: PUnit;
  D: TDialog;
begin
  { this year's event (docs/rules/events.md); bad events are rarer with
    Karma (F = 2, G = 1) }
  P := @Players[Me];
  P^.Event := 0;
  if P^.Spell = $0A then
  begin
    F := 2;
    G := 1;
  end
  else
  begin
    F := 1;
    G := 0;
  end;
  if (P^.Population > 100000) and (Random(4) = 0) then
    E := 6                                             { plague in big countries }
  else
    E := Random(23) + 1;
  case E of
    2:
      if P^.Population < 50000 then
        if Random(F * 3) <> 0 then
          E := 0;
    3:
      if Random(3 - G) = 0 then
      begin
        { land gained }
        A := Random(Word((P^.Title + 1) * 1000)) + 500;
        U := UnclaimedLand(Players, NumPlayers);
        if A > U then
          A := U;
        if A = 0 then
          E := 0
        else
          P^.Land := P^.Land + A;
      end
      else
        E := 0;
    4:
      if (Random(F * 2) = 0) and (P^.Mills > 0) then
        P^.Mills := P^.Mills - 1
      else
        E := 0;
    5:
      if Random(3 - G) <> 0 then
        E := 0;
    6:
      if (P^.Population < 50000) and (Random(F * 10) <> 0) then
        E := 0
      else
      begin
        P^.Lifetime := P^.Lifetime - Random(2);
        AddNews(Players, NumPlayers, Me, Me, 4);
      end;
    7:
      begin
        { new markets on free land }
        K := LongInt(P^.Land - P^.LandUsed) div 1000 - P^.Markets;
        if (K > 0) and (Random(4 - G) = 0) then
          P^.Markets := P^.Markets + MinLong(K, Random(Word(P^.Fame div 10)) + 2)
        else
          E := 0;
      end;
    8:
      begin
        { a unit deserts }
        I := Random(P^.Army1Count) + 1;
        if (Random(F * 2) = 0) and (P^.Army1Count > 2) and (P^.Spell <> 9) and
           (DS.UnitCanDesert[ShortInt(P^.Army1[I].UnitType)] <> 0) then
        begin
          RemoveArmy1Unit(P^, I);
          Inc(P^.DesertedUnits);
        end
        else
          E := 0;
      end;
    9:
      if Random(2 - G) = 0 then
        E := 0
      else
        Inc(P^.Lifetime);
    $0A:
      if Random(F * 8) = 0 then
      begin
        { fire }
        AddNews(Players, NumPlayers, Me, Me, 3);
        P^.Markets := P^.Markets - Random(Word(P^.Markets div 2));
        P^.Mills := P^.Mills - Random(Word(P^.Mills div 2));
        R := Random(P^.PalaceParts shr 1);
        if (R > 0) and (P^.PalaceParts = 12) then
          LoseFame(P^.Fame, 10);
        P^.PalaceParts := Byte(P^.PalaceParts - Byte(R));
        R := Random(P^.CathedralParts shr 1);
        if (R > 0) and (P^.CathedralParts = 12) then
          LoseFame(P^.Fame, 20);
        P^.CathedralParts := Byte(P^.CathedralParts - Byte(R));
        R := Random(Word(P^.Granaries div 2));
        RemoveGranaries(P^, R);
        R := Random(Word(P^.Warehouses div 2));
        RemoveWarehouses(P^, R);
        P^.Lifetime := P^.Lifetime - Random(2);
      end
      else
        E := 0;
    $0B:
      if Random(4) <> 0 then
        E := 0;
    $0C:
      if Random(F * 6) <> 0 then
        E := 0;
    $0D:
      if (Random(F * 5) <> 0) or (P^.Spell = $0B) then
        E := 0;
    $0E:
      begin
        { new mills on free land }
        K := LongInt(P^.Land - P^.LandUsed) div 1000 - P^.Mills;
        if (K > 0) and (Random(4 - G) = 0) then
          P^.Mills := P^.Mills + MinLong(K, Random(Word(P^.Fame div 10)) + 2)
        else
          E := 0;
      end;
    $0F:
      if Random(4 - G) <> 0 then
        E := 0;
    $10:
      if Random(F * 2) <> 0 then
        E := 0;
    $11:
      if Random(2) = 0 then
        E := 0;
    $12:
      if (Random(F * 2) = 0) and (P^.Granaries > 1) then
        RemoveGranaries(P^, 1)
      else
        E := 0;
    $13:
      if Random(100) > 0 then
        E := 0;
    $14:
      if (P^.Warehouses > 0) and (Random(F * 3) = 0) and (P^.Warehouses > 0) then
        RemoveWarehouses(P^, 1)
      else
        E := 0;
    $15, $16:
      { the fortune teller: only after year 39 and without immortality }
      if (DS.Game.Immortality = 0) and (Year > $27) then
      begin
        if P^.Lifetime >= 5 then
          E := $15
        else
          E := $16;
      end
      else
        E := 0;
    $17:
      if (P^.ArmyAway <> 0) and FindHero(P^, Hero, 0) then
      begin
        Hero^.Experience := SmallInt(Hero^.Experience + Hero^.Level * 2 + 10);
        GainFame(P^.Fame, 8);
      end
      else
        E := 0;
  end;
  if (P^.CpuLevel = 0) and (E <> 0) then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(ResId(E + 300))]);
    UI.Execute(D);
    UI.Done(D, 1);
  end;
  P^.Event := E;
end;

procedure Report_Gossip(Parent: Pointer; var Players: TPlayers; Me: Byte);
var
  P: PPlayer;
  I, Last, Actor, Target, Kind: Byte;
  Country: array[0..79] of Char;
  Title: array[0..79] of Char;
  D: TDialog;

  procedure Msg(NameOfs: Word);
  begin
    D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText(NameOfs)), AStr(Country)]);
  end;

  procedure Msg2(NameOfs: Word);
  begin
    D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText(NameOfs)), AStr(Country),
      AStr(Title)]);
  end;

begin
  { "Klatsch und Tratsch": the news of the year }
  P := @Players[Me];
  if P^.NewsCount = 0 then
    Exit;
  Last := P^.NewsCount;
  for I := 1 to Last do
  begin
    Actor := P^.News[3 * I - 3];
    Target := P^.News[3 * I - 2];
    Kind := P^.News[3 * I - 1];
    StrCopy(Country, DS.CountryNamesRt[Players[Actor].Country]);
    FormatPlayerTitle(Players[Actor], Title, 0, 0);
    D := nil;
    case Kind of
      1: Msg($07D2);                                   { KLATSCHSABODLG }
      2: Msg($07E1);                                   { KLATSCHPALBRANDDLG }
      3: Msg($07F4);                                   { KLATSCHVULKANDLG }
      4: Msg($0805);                                   { KLATSCHPESTDLG }
      5, 6:
        begin
          StrCat(Country, DSText($0814));              { ' und ' }
          StrCat(Country, DS.CountryNamesRt[Players[Target].Country]);
          if Kind = 5 then
            Msg($081A)                                 { KLATSCHPEACEDLG }
          else
            Msg($082A);                                { KLATSCHTRADEDLG }
        end;
      7: Msg($083A);                                   { KLATSCHMARODLG }
      8, 9:
        begin
          FormatPlayerTitle(Players[Target], Title, 0, 0);
          if Kind = 8 then
            Msg2($0849)                                { KLATSCHWARWONDLG }
          else
            Msg2($085A);                               { KLATSCHWARLOSTDLG }
        end;
      $0B: Msg($086C);                                 { KLATSCHANADLG }
      $0C: Msg($087A);                                 { KLATSCHUNRUHEDLG }
      $0D:
        if Players[Actor].IsFemale = 0 then
          Msg2($088B)                                  { KLATSCHKINGDLG }
        else
          Msg2($089A);                                 { KLATSCHQUEENDLG }
      $0E: Msg($08AA);                                 { KLATSCHPALDLG }
      $0F: Msg($08B8);                                 { KLATSCHKATDLG }
      $10: Msg2($08C6);                                { KLATSCHDEMISSIONDLG }
    end;
    if D <> nil then
    begin
      UI.Execute(D);
      UI.Done(D, 1);
    end;
  end;
  P^.NewsCount := 0;
end;

{ ---- diplomatic messages ---------------------------------------------------

  Players[X].Mailbox holds one message from every other player Y (6 bytes at
  6*Y): Kind, Sub, Data. The sender writes it during its turn, the receiver
  handles it in DiplomacyTurnStart and answers into the sender's mailbox. }

type
  PMailSlot = ^TMailSlot;
  TMailSlot = packed record
    Kind, Sub: Byte;
    Data: LongInt;
  end;

{ the message player From left for player Owner }
function Mail(var Players: TPlayers; Owner, From: Byte): PMailSlot;
begin
  Result := PMailSlot(@Players[Owner].Mailbox[6 * From]);
end;

procedure SetMail(S: PMailSlot; Kind, Sub: Byte; Data: LongInt);
begin
  S^.Kind := Kind;
  S^.Sub := Sub;
  S^.Data := Data;
end;

function MsgDlg(Parent: Pointer; NameOfs: Word; Text: PChar): TDialog;
begin
  Result := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText(NameOfs)), AStr(Text)]);
end;

function Msg2Dlg(Parent: Pointer; NameOfs: Word; Text1, Text2: PChar): TDialog;
begin
  Result := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText(NameOfs)), AStr(Text1),
    AStr(Text2)]);
end;

procedure Msg_ReceiveAid(Parent: Pointer; var Players: TPlayers; Me, Sender: Byte;
  Data: LongInt);
var
  Title, Buf: array[0..81] of Char;
  D: TDialog;
begin
  { a gift: the sender already gave it away, only settlers arrive here }
  FormatPlayerTitle(Players[Sender], Title, 0, 0);
  case Mail(Players, Me, Sender)^.Sub of
    0:
      begin
        IntToPChar(Buf, Data);
        StrCat(Buf, DSText($066E));                    { ' Taler' }
      end;
    1:
      begin
        IntToPChar(Buf, Data);
        StrCat(Buf, DSText($0683));                    { ' Hufe fruchtbarsten Bodens' }
      end;
    2:
      begin
        StrCopy(Buf, DSText($069E));                   { 'eine Einheit ' }
        StrCat(Buf, DS.UnitNames[SmallInt(Data)]);
      end;
    3:
      begin
        Players[Me].Immigrants := Players[Me].Immigrants + Data;
        IntToPChar(Buf, Data);
        StrCat(Buf, DSText($06AC));                    { ' "Siedler"' }
      end;
  else
    Exit;
  end;
  D := Msg2Dlg(Parent, $0675, Title, Buf);             { MSGSPENDENDLG }
  UI.Execute(D);
  UI.Done(D, 1);
  ClearMailboxSlot(Mail(Players, Me, Sender)^);
end;

procedure Msg_Negotiation(Parent: Pointer; var Players: TPlayers; Me, Sender, NumPlayers,
  Kind: Byte; Year: Word);
var
  Title, Buf: array[0..81] of Char;
  Inbox, Reply: PMailSlot;
  D: TDialog;
begin
  { trade agreements (5..8) and peace treaties (9..11) }
  FormatPlayerTitle(Players[Sender], Title, 0, 0);
  Inbox := Mail(Players, Me, Sender);
  Reply := Mail(Players, Sender, Me);
  case Kind of
    6:                                                 { trade agreement cancelled }
      begin
        D := MsgDlg(Parent, $06B8, Title);             { MSGTRADEENDDLG }
        UI.Execute(D);
        ClearMailboxSlot(Inbox^);
        Players[Me].TradeAgreement[Sender] := 0;
        UI.Done(D, 1);
      end;
    5:                                                 { trade agreement offered }
      begin
        D := MsgDlg(Parent, $06C7, Title);             { MSGTRADEDLG }
        if UI.Execute(D) = 1 then
          SetMail(Reply, 7, 0, 0)
        else
          SetMail(Reply, 8, 0, 0);
        UI.Done(D, 1);
        ClearMailboxSlot(Inbox^);
        ShowKaiserDlg(Parent, DSText($06D3));          { KURIERDLG }
      end;
    7:                                                 { offer accepted }
      begin
        D := MsgDlg(Parent, $06DD, Title);             { MSGTRADEOKDLG }
        UI.Execute(D);
        ClearMailboxSlot(Inbox^);
        Players[Me].TradeAgreement[Sender] := 1;
        Players[Sender].TradeAgreement[Me] := 1;
        GainFame(Players[Me].Fame, 2);
        AddNews(Players, NumPlayers, Me, Sender, 6);
        UI.Done(D, 1);
      end;
    8:                                                 { offer declined }
      begin
        D := MsgDlg(Parent, $06EB, Title);             { MSGTRADENODLG }
        UI.Execute(D);
        ClearMailboxSlot(Inbox^);
        Players[Me].TradeAgreement[Sender] := 0;
        Players[Sender].TradeAgreement[Me] := 0;
        UI.Done(D, 1);
      end;
    9:                                                 { peace for Data years offered }
      begin
        IntToPChar(Buf, Inbox^.Data);
        D := Msg2Dlg(Parent, $06F9, Title, Buf);       { MSGPEACEDLG }
        if UI.Execute(D) = 1 then
        begin
          Reply^.Kind := $0A;
          Reply^.Sub := 0;
          Reply^.Data := Inbox^.Data;
          GainFame(Players[Me].Fame, SmallInt(Reply^.Data div 5 + 1));
          Players[Me].Lifetime := SmallInt(Players[Me].Lifetime + Random(2));
          { one year more when Me moves after the sender }
          if Me < Sender then
            Players[Me].PeaceYears[Sender] := Byte(Reply^.Data)
          else
            Players[Me].PeaceYears[Sender] := Byte(Reply^.Data + 1);
        end
        else
          SetMail(Reply, $0B, 0, 0);
        UI.Done(D, 1);
        ClearMailboxSlot(Inbox^);
        ShowKaiserDlg(Parent, DSText($06D3));          { KURIERDLG }
      end;
    $0A:                                               { peace accepted: until year ... }
      begin
        IntToPChar(Buf, LongInt(Inbox^.Data + Year + 1400 - 1));
        D := Msg2Dlg(Parent, $0705, Title, Buf);       { MSGPEACEOKDLG }
        UI.Execute(D);
        Players[Me].PeaceYears[Sender] := Byte(Inbox^.Data);
        UI.Done(D, 1);
        AddNews(Players, NumPlayers, Me, Sender, 5);
        GainFame(Players[Me].Fame, SmallInt(Inbox^.Data div 5));
        Players[Me].Lifetime := SmallInt(Players[Me].Lifetime + Random(2));
        ClearMailboxSlot(Inbox^);
      end;
    $0B:                                               { peace declined }
      begin
        D := MsgDlg(Parent, $0713, Title);             { MSGPEACENODLG }
        UI.Execute(D);
        ClearMailboxSlot(Inbox^);
        UI.Done(D, 1);
      end;
  end;
end;

procedure Msg_TributeDemand(Parent: Pointer; var Players: TPlayers; Me, Sender: Byte;
  Data: LongInt);
var
  P: PPlayer;
  Title, Buf: array[0..81] of Char;
  Reply: PMailSlot;
  L: TLandLoss;
  D: TDialog;
begin
  { pay the demanded tribute (answer 4) or refuse it (answer 3) }
  FormatPlayerTitle(Players[Sender], Title, 0, 0);
  IntToPChar(Buf, Data);
  P := @Players[Me];
  Reply := Mail(Players, Sender, Me);
  FillChar(L, SizeOf(L), 0);
  case Mail(Players, Me, Sender)^.Sub of
    0:                                                 { Taler }
      begin
        StrCat(Buf, DSText($0722));                    { ' Taler' }
        D := Msg2Dlg(Parent, $0729, Title, Buf);       { MSGTRIBUTDLG }
        if UI.Execute(D) = 1 then
        begin
          SetMail(Reply, 4, 0, Data);
          P^.Taler := P^.Taler - Data;
          P^.TotalTribute := P^.TotalTribute - Data;
          Players[Sender].Taler := Players[Sender].Taler + Data;
          Players[Sender].TotalTribute := Players[Sender].TotalTribute + Data;
          LoseFame(P^.Fame, 5);
        end
        else
          SetMail(Reply, 3, 0, Data);
      end;
    1:                                                 { land, at least 2000 free land is kept }
      begin
        if LongInt(P^.Land - P^.LandUsed - Data) < 2000 then
          Data := LongInt(P^.Land - P^.LandUsed - 2000);
        IntToPChar(Buf, Data);
        StrCat(Buf, DSText($0736));                    { ' Hufe Eures Bodens' }
        D := Msg2Dlg(Parent, $0729, Title, Buf);       { MSGTRIBUTDLG }
        if UI.Execute(D) = 1 then
        begin
          SetMail(Reply, 4, 1, Data);
          { (with Data = 0 the original shows its stale stack record) }
          TransferLand(P^, Players[Sender], L, Data, 0);
          if L.Total > 0 then
            UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText($0749)),   { VERLUSTDLG }
              ARec(@L, SizeOf(L)), AByte(0)]);
          LoseFame(P^.Fame, 5);
        end
        else
          SetMail(Reply, 3, 1, Data);
      end;
    3:                                                 { workers, at least 50 people are kept }
      begin
        if LongInt(P^.Population - Data) < 50 then
          Data := LongInt(P^.Population - 50);
        IntToPChar(Buf, Data);
        StrCat(Buf, DSText($0754));                    { ' "Arbeitskräfte"' }
        D := Msg2Dlg(Parent, $0729, Title, Buf);       { MSGTRIBUTDLG }
        if UI.Execute(D) = 1 then
        begin
          SetMail(Reply, 4, 3, Data);
          P^.Emigrants := P^.Emigrants + Data;
          LoseFame(P^.Fame, 5);
        end
        else
          SetMail(Reply, 3, 3, Data);
      end;
    5:                                                 { a trade agreement }
      begin
        StrCopy(Buf, DSText($0765));                   { 'ein Handelsabkommen' }
        D := Msg2Dlg(Parent, $0729, Title, Buf);       { MSGTRIBUTDLG }
        if UI.Execute(D) = 1 then
          SetMail(Reply, 4, 5, 0)
        else
          SetMail(Reply, 3, 5, 0);
      end;
    4:                                                 { Data years of peace }
      begin
        StrCat(Buf, DSText($0779));                    { ' Jahre Frieden' }
        D := Msg2Dlg(Parent, $0729, Title, Buf);       { MSGTRIBUTDLG }
        if UI.Execute(D) = 1 then
        begin
          SetMail(Reply, 4, 4, Data);
          if Me < Sender then
            P^.PeaceYears[Sender] := Byte(Data)
          else
            P^.PeaceYears[Sender] := Byte(Data + 1);
        end
        else
          SetMail(Reply, 3, 4, Data);
      end;
  else
    Exit;      { (the original frees an uninitialised dialog pointer here) }
  end;
  UI.Done(D, 1);
  ClearMailboxSlot(Mail(Players, Me, Sender)^);
  ShowKaiserDlg(Parent, DSText($0788));                { KURIERDLG }
end;

procedure Msg_TributeAnswer(Parent: Pointer; var Players: TPlayers; Me, Sender, Sub: Byte;
  Data: LongInt; Paid: Byte);
var
  Title: array[0..81] of Char;
  D: TDialog;
begin
  { the answer to our demand; Taler and land were already handed over by
    the payer, workers arrive as immigrants }
  FormatPlayerTitle(Players[Sender], Title, 0, 0);
  if Paid <> 0 then
  begin
    D := MsgDlg(Parent, $0792, Title);                 { MSGTRIBUTOKDLG }
    UI.Execute(D);
    case Sub of
      3: Players[Me].Immigrants := Players[Me].Immigrants + Data;
      5:
        begin
          Players[Sender].TradeAgreement[Me] := 1;
          Players[Me].TradeAgreement[Sender] := 1;
        end;
      4: Players[Me].PeaceYears[Sender] := Byte(Data);
    end;
    UI.Done(D, 1);
  end
  else
  begin
    D := MsgDlg(Parent, $07A1, Title);                 { MSGTRIBUTNODLG }
    UI.Execute(D);
    UI.Done(D, 1);
  end;
  ClearMailboxSlot(Mail(Players, Me, Sender)^);
end;

procedure DiplomacyTurnStart(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
var
  I, Last: Byte;
  Title: array[0..81] of Char;
  S: PMailSlot;
  D: TDialog;
begin
  { peace treaties run out }
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    if ShortInt(Players[Me].PeaceYears[I]) > 0 then
    begin
      if Players[Me].PeaceYears[I] = 1 then
      begin
        FormatPlayerTitle(Players[I], Title, 0, 0);
        D := MsgDlg(Parent, $0662, Title);             { PEACEENDDLG }
        UI.Execute(D);
        UI.Done(D, 1);
      end;
      Dec(Players[Me].PeaceYears[I]);
    end;
  { the messages of the other players }
  for I := 0 to Last do
  begin
    S := Mail(Players, Me, I);
    case S^.Kind of
      1: Msg_ReceiveAid(Parent, Players, Me, I, S^.Data);
      2: Msg_TributeDemand(Parent, Players, Me, I, S^.Data);
      3: Msg_TributeAnswer(Parent, Players, Me, I, S^.Sub, S^.Data, 0);
      4: Msg_TributeAnswer(Parent, Players, Me, I, S^.Sub, S^.Data, 1);
      5..$0B: Msg_Negotiation(Parent, Players, Me, I, NumPlayers, S^.Kind, Year);
    end;
  end;
end;

end.
