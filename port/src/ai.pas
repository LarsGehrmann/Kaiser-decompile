{ Computer players: the AI year (segment 2, 1008:xxxx) and its helpers
  (segment 7, 1030:xxxx), ported in the original order of operations.
  Differential tests: port/tests/ruletest.pas. }
unit Ai;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI, Turn;

{ segment 7 }
function Ai_FarmlandPerCapita(P: TPlayer): Byte;            { 1030:0002 }
function Ai_LandPriceMargin(const Players: TPlayers; Me, NumPlayers: Byte): Byte;  { 1030:00c7 }
function Ai_SurplusLand(const P: TPlayer): LongInt;         { 1030:01de }
function Ai_LandToSellForPromotion(const P: TPlayer): LongInt;  { 1030:0301 }
function Ai_IsMuchRicher(const A, B: TPlayer): Boolean;     { 1030:04ab }
function Ai_RevolutionRoll(const P: TPlayer): Byte;         { 1030:059b }
procedure Ai_SetSabotageBudgets(var Players: TPlayers; Me, NumPlayers: Byte);  { 1030:060f }
function Ai_CanRecruitType(const P: TPlayer; UnitType: Byte): Boolean;  { 1030:06d9 }
procedure Ai_KnightSquires(var P: TPlayer);                 { 1030:075a }
procedure Ai_DropWeakestHeerUnit(var P: TPlayer);           { 1030:0844 }
function Ai_StrengthRatio(const A, B: TPlayer): TReal48;    { 1030:08ba }
function Ai_AutoBattleRating(const P: TPlayer; Defender: Byte): LongInt;  { 1030:09f2 }
procedure Ai_AutoBattleLosses(var P: TPlayer; Bonus: Byte); { 1030:0bda }
function Ai_UnitValue(const U: TUnit): SmallInt;            { 1030:0cc0 }
procedure Ai_ArrangeArmies(var P: TPlayer; Mode: Byte);     { 1030:0d02 }
function Ai_BanditBattle(var P: TPlayer): Byte;             { 1030:0fe9 }
function Ai_AutoBattle(var A, B: TPlayer): Byte;            { 1030:1062 }

{ segment 2: the computer player's year }
procedure Ai_Turn(Parent: Pointer; HWnd: Word; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);                                              { 1008:0002 }
procedure Ai_YearlySimulation(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);  { 1008:01fd }
procedure Ai_Diplomacy(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);  { 1008:0843 }
procedure Ai_PopulationModel(var P: TPlayer);               { 1008:0ff7 }
procedure Ai_Budget(var Players: TPlayers; Me, NumPlayers: Byte);  { 1008:1131 }
procedure Ai_GrainPolicy(var P: TPlayer);                   { 1008:13b9 }
procedure Ai_LandPolicy(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);  { 1008:1594 }
procedure Ai_SellGoods(var P: TPlayer; Year: Word);         { 1008:17a5 }
procedure Ai_BuildingPolicy(var Players: TPlayers; Me, NumPlayers: Byte);  { 1008:18ca }
procedure Ai_MilitaryPolicy(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);  { 1008:2006 }
function Ai_ChooseWarTarget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  var Target: Byte): Boolean;                               { 1008:24eb }
procedure Ai_HoldManoeuvre(var P: TPlayer);                 { 1008:296c }
procedure Ai_EndTurn(var Players: TPlayers; Me, NumPlayers: Byte);  { 1008:29ea }
procedure Ai_FirstKingReward(var Players: TPlayers; Me, NumPlayers: Byte);  { 1008:2e1a }
procedure Ai_FirstYear(var P: TPlayer);                     { 1008:3088 }
procedure Ai_ReceiveAid(var Players: TPlayers; Me, Sender, Sub: Byte; Data: LongInt);  { 1008:33ad }
procedure Ai_AnswerTrade(var Players: TPlayers; Me, Sender, NumPlayers, Kind: Byte);  { 1008:34f4 }
procedure Ai_AnswerPeace(var Players: TPlayers; Me, Sender, NumPlayers, Kind: Byte;
  Data: LongInt);                                           { 1008:37a5 }
procedure Ai_AnswerTribute(var Players: TPlayers; Me, Sender, NumPlayers, Kind, Sub: Byte;
  Data: LongInt);                                           { 1008:3abb }

implementation

function FromLong(V: LongInt): TReal48; inline;
begin
  Result := R48FromLong(V);
end;

{ ---- segment 7 ------------------------------------------------------------- }

function Ai_FarmlandPerCapita(P: TPlayer): Byte;
var
  R: TReal48;
begin
  { (land - land_used) / population, clamped to 0..100 }
  R := R48Div(FromLong(LongInt(P.Land - P.LandUsed)), FromLong(P.Population));
  if R48Cmp(R, RC($0087, 0, $4800)) > 0 then
    R := RC($0087, 0, $4800);
  if R48Cmp(R, R48Zero) < 0 then
    R := R48Zero;
  Result := Byte(R48Round(R));
end;

function Ai_LandPriceMargin(const Players: TPlayers; Me, NumPlayers: Byte): Byte;
var
  U, R: TReal48;
  V: LongInt;
begin
  { how far below its own valuation the land price is: the valuation is
    high when little unclaimed land is left (u = unclaimed per player /
    100000, 1 / (u^4 + 0.01)) and when the AI has no free building land }
  U := R48Div(R48Div(FromLong(UnclaimedLand(Players, NumPlayers)), FromLong(NumPlayers)),
    RC($0091, 0, $4350));
  V := FreeBuildingLand(Players[Me]) div 2000;
  R := R48Mul(R48Mul(R48Mul(U, U), U), U);
  R := R48Div(RC($0081, 0, 0), R48Add(R, RC($717A, $0A3D, $23D7)));
  V := MinLong(60, MaxLong(17, LongInt(R48Round(R) + 15 - V)));
  Result := Byte(V + 15 - Players[Me].LandPrice);
end;

function Ai_SurplusLand(const P: TPlayer): LongInt;
var
  M: LongInt;
begin
  { free land beyond 1000 per market, mill or palace/cathedral part (of
    the largest of these counts, at least 2) }
  M := 2;
  if P.Markets > M then
    M := P.Markets;
  if P.Mills > M then
    M := P.Mills;
  if P.PalaceParts > M then
    M := P.PalaceParts;
  if P.CathedralParts > M then
    M := P.CathedralParts;
  Result := LongInt(P.Land - LongInt(M * 1000) - P.LandUsed);
  if Result <= 0 then
    Result := 0;
end;

function Ai_LandToSellForPromotion(const P: TPlayer): LongInt;
var
  T: Byte;
  Need: LongInt;
begin
  { everything for the next title but the Taler: the land to sell (at
    land_price per 10) to raise them, if the land requirement still holds }
  Result := 0;
  T := Byte(P.Title + 1);
  if DS.PromotionLand[T] > P.Land then
    Exit;
  if DS.PromotionPopulation[T] > P.Population then
    Exit;
  if DS.PromotionPalaceParts[T] > P.PalaceParts then
    Exit;
  if DS.PromotionCathedralParts[T] > P.CathedralParts then
    Exit;
  if DS.PromotionArmyStrength[T] > ArmyStrength(P, 1) then
    Exit;
  if R48Cmp(DS.PromotionHappiness[T], P.Happiness) > 0 then
    Exit;
  Need := LongInt(DS.PromotionTaler[T] - P.Taler + 1000) div (P.LandPrice div 10);
  if LongInt(P.Land - P.LandUsed - Need) >= DS.PromotionLand[T] then
    Result := Need;
end;

function Ai_IsMuchRicher(const A, B: TPlayer): Boolean;
var
  WA, WB: LongInt;
begin
  { wealth = Taler + 5 per Hufe beyond the Kaiser's land requirement;
    True when B has more than 1.5 times the wealth of A }
  if B.Land > DS.PromotionLand[10] then
    WB := LongInt((B.Land - DS.PromotionLand[10]) * 5)
  else
    WB := 0;
  WB := LongInt(WB + B.Taler);
  if A.Land > DS.PromotionLand[10] then
    WA := LongInt((A.Land - DS.PromotionLand[10]) * 5)
  else
    WA := 0;
  WA := LongInt(WA + A.Taler);
  Result := LongInt(WA * 3) div 2 < WB;
end;

function Ai_RevolutionRoll(const P: TPlayer): Byte;
begin
  { below 25 % happiness: 1 = unrest, 2 (chance 1 / round(10 * happiness))
    = revolution; 0 = calm }
  if R48Cmp(P.Happiness, RC($007F, 0, 0)) < 0 then
  begin
    if Random(Word(R48Round(R48Mul(P.Happiness, RC($0084, 0, $2000))))) <> 0 then
      Result := 1
    else
      Result := 2;
  end
  else
    Result := 0;
end;

procedure Ai_SetSabotageBudgets(var Players: TPlayers; Me, NumPlayers: Byte);
var
  Others: array[0..11] of Byte;
  I, K, Last: Byte;
  Budget: Word;
begin
  { (6 - aggression) * (title + 1) / 2 for every disliked player (attitude < 50) }
  FillChar(Others, SizeOf(Others), 0);
  K := 0;
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    if I <> Me then
    begin
      Others[K] := I;
      Inc(K);
    end;
  with Players[Me] do
  begin
    Budget := Word(Word(6 - AiAggressionQ) * Word(Title + 1)) shr 1;
    Last := Byte(NumPlayers - 2);
    for I := 0 to Last do
      if PSmallInt(@AttitudeQ[2 * Others[I]])^ < 50 then
        SabotageBudget[Others[I]] := Byte(Budget);
  end;
end;

function Ai_CanRecruitType(const P: TPlayer; UnitType: Byte): Boolean;
begin
  { from Fuerst on, until there are two units of type 6 only types whose
    default ability is 10; at most DS.AiMaxUnits[type] of a type, and the
    weapons in stock }
  Result := False;
  if (P.Title > 5) and (CountUnitsOfType(P, 6) < 2) and
     (DS.UnitDefaultAbility[UnitType] <> 10) then
    Exit;
  if DS.AiMaxUnits[UnitType] <= CountUnitsOfType(P, UnitType) then
    Exit;
  if DS.UnitWeapons[UnitType] > P.Weapons then
    Exit;
  Result := True;
end;

procedure Ai_KnightSquires(var P: TPlayer);
var
  Percent: SmallInt;
  I, Last: Byte;
begin
  { every knight (type $22) may get a squire: 5 %, with spell 3 50 % }
  if P.Spell = 3 then
    Percent := 50
  else
    Percent := 5;
  Last := P.Army1Count;
  for I := 1 to Last do
    if (P.Army1[I].UnitType = $22) and Chance(Percent) then
      KnightSquire(P, P.Army1[I]);
  Last := P.Army2Count;
  for I := 1 to Last do
    if (P.Army2[I].UnitType = $22) and Chance(Percent) then
      KnightSquire(P, P.Army2[I]);
end;

procedure Ai_DropWeakestHeerUnit(var P: TPlayer);
var
  N: Byte;
begin
  { the last unit of the sorted Heer moves to the Garde, if there is room }
  N := P.Army1Count;
  SortArmy(P, 1);
  if P.Army2Count < 8 then
  begin
    Inc(P.Army2Count);
    Move(P.Army1[N], P.Army2[P.Army2Count], SizeOf(TUnit));
    RemoveArmy1Unit(P, N);
  end
  else
    RemoveArmy1Unit(P, N);
end;

function Ai_StrengthRatio(const A, B: TPlayer): TReal48;
var
  StrengthA, Sum: LongInt;
  I, Last: Byte;
begin
  { ArmyStrength(A) / attack+defence of B's armies (the Heer only when at
    home); 10 when B has nothing }
  StrengthA := ArmyStrength(A, 1);
  Sum := 0;
  if B.ArmyAway = 0 then
  begin
    Last := B.Army1Count;
    for I := 1 to Last do
      Sum := LongInt(Sum + SmallInt(B.Army1[I].Defence + B.Army1[I].Attack));
  end;
  Last := B.Army2Count;
  for I := 1 to Last do
    Sum := LongInt(Sum + SmallInt(B.Army2[I].Defence + B.Army2[I].Attack));
  if Sum > 0 then
    Result := R48Div(FromLong(StrengthA), FromLong(Sum))
  else
    Result := RC($0084, 0, $2000);
end;

function Ai_AutoBattleRating(const P: TPlayer; Defender: Byte): LongInt;
var
  Fight, Levels, Home: Word;
  I, Last: Byte;
  F1, F2, F3, F4: TReal48;
begin
  { attack + defence + 2 * level of the Heer, the defender adds militia
    from the population; artillery, type 10 and type $15 multiply }
  Fight := 0;
  Levels := 0;
  Last := P.Army1Count;
  for I := 1 to Last do
  begin
    Fight := Word(Fight + P.Army1[I].Attack);
    Fight := Word(Fight + P.Army1[I].Defence);
    Levels := Word(Levels + P.Army1[I].Level * 2);
  end;
  F1 := R48Zero;           { (left uninitialised for other classes) }
  case ArtilleryClass(P, 0) of
    0: F1 := RC($0081, 0, 0);                      { 1 }
    1: F1 := RC($6681, $6666, $0666);              { 1.05 }
    2: F1 := RC($3381, $3333, $1333);              { 1.15 }
  end;
  if Defender <> 0 then
  begin
    Home := Word(LongInt(P.Population div 4000 + 1) * SmallInt((8 - P.Army1Count) * 2));
    F2 := RC($0081, 0, $2000);                     { 1.25 }
  end
  else
  begin
    Home := 0;
    F2 := RC($0081, 0, 0);
  end;
  if CountUnitsOfType(P, 10) > 0 then
    F3 := RC($9A81, $9999, $1999)                  { 1.2 }
  else
    F3 := RC($0081, 0, 0);
  if CountUnitsOfType(P, $15) > 0 then
    F4 := RC($3381, $3333, $1333)                  { 1.15 }
  else
    F4 := RC($0081, 0, 0);
  Result := R48Round(R48Mul(R48Mul(R48Mul(R48Mul(
    FromLong(SmallInt(Word(Fight + Home + Levels))), F1), F2), F3), F4));
end;

procedure Ai_AutoBattleLosses(var P: TPlayer; Bonus: Byte);
var
  I, Last, Lost, D: Byte;
begin
  { each Heer unit dies with chance 1 / (bonus + (attack+defence)/10 + level)
    (heroes count 10); the dead are cleared and sorted to the end }
  Lost := 0;
  Last := P.Army1Count;
  for I := 1 to Last do
  begin
    if P.Army1[I].UnitType = 9 then
      D := 10
    else
      D := Byte(SmallInt(P.Army1[I].Defence + P.Army1[I].Attack) div 10);
    if Random(Word(Bonus + D + P.Army1[I].Level)) = 0 then
    begin
      Inc(Lost);
      ClearUnit(P.Army1[I]);
    end;
  end;
  SortArmy(P, 1);
  P.Army1Count := Byte(P.Army1Count - Lost);
end;

function Ai_UnitValue(const U: TUnit): SmallInt;
begin
  Result := 0;
  if U.Ability = 10 then
    Result := Result + 10;
  Result := SmallInt(Result + U.Attack);
  Result := SmallInt(Result + U.Defence);
  Result := SmallInt(Result + U.Range);
end;

procedure Ai_ArrangeArmies(var P: TPlayer; Mode: Byte);
var
  T: array[0..16] of TUnit;
  Tmp: TUnit;
  I, J, Last, Total, N1: Byte;
begin
  { all units sorted by value: the best eight form the Heer, the rest the
    Garde; mode 2 swaps the two afterwards (the Garde is the best) }
  if ((P.Army1Count = 0) or (P.ArmyAway <> 0)) and (Mode = 2) then
    Exit;
  if (P.Army2Count = 0) and (Mode = 1) then
    Exit;
  if (P.Army1Count = 0) and (P.Army2Count = 0) then
    Exit;
  FillChar(T, SizeOf(T), 0);
  FillChar(Tmp, SizeOf(Tmp), 0);
  Total := Byte(P.Army1Count + P.Army2Count);
  Last := P.Army1Count;
  for I := 1 to Last do
    T[I] := P.Army1[I];
  Last := P.Army2Count;
  for I := 1 to Last do
    T[P.Army1Count + I] := P.Army2[I];
  for I := 2 to Total do
  begin
    J := I;
    Tmp := T[I];
    while (J > 1) and (Ai_UnitValue(T[J - 1]) < Ai_UnitValue(Tmp)) do
    begin
      T[J] := T[J - 1];
      Dec(J);
    end;
    T[J] := Tmp;
  end;
  N1 := Total;
  if N1 > 8 then
    N1 := 8;
  for I := 1 to N1 do
    P.Army1[I] := T[I];
  Last := Byte(Total - N1);
  for I := 1 to Last do
    P.Army2[I] := T[N1 + I];
  P.Army1Count := N1;
  P.Army2Count := Byte(Total - N1);
  SortArmy(P, 1);
  if Mode = 2 then
    SwapArmies(P);
end;

function Ai_BanditBattle(var P: TPlayer): Byte;
var
  Rating, Strength: LongInt;
  R: Word;
  Bonus: Byte;
begin
  { a computer player against the raiders of event 17: 1 = won }
  Ai_ArrangeArmies(P, 1);
  Rating := Ai_AutoBattleRating(P, 0);
  Strength := ArmyStrength(P, 1);
  R := Random(Word(Strength));
  if Random(Word(Rating)) > R then
  begin
    Result := 1;
    Bonus := 3;
  end
  else
  begin
    Result := 0;
    Bonus := 2;
  end;
  Ai_AutoBattleLosses(P, Bonus);
  Dec(P.Initiative);
end;

function Ai_AutoBattle(var A, B: TPlayer): Byte;
var
  RatingA, RatingB: LongInt;
  Gains: THeroGains;
begin
  { attacker A against defender B without the battle screen: the higher
    rating wins (1 = A won); the Avenger gains experience }
  Ai_ArrangeArmies(A, 1);
  Ai_ArrangeArmies(B, 1);
  RatingA := Ai_AutoBattleRating(A, 0);
  RatingB := Ai_AutoBattleRating(B, 1);
  if RatingA > RatingB then
  begin
    Result := 1;
    Ai_AutoBattleLosses(A, 3);
    Ai_AutoBattleLosses(B, 2);
  end
  else
  begin
    Result := 0;
    Ai_AutoBattleLosses(A, 2);
    Ai_AutoBattleLosses(B, 3);
  end;
  FillChar(Gains, SizeOf(Gains), 0);
  UnitGainExperience(DS.Game.Avenger, Gains, Random(3) + 2, 0);
end;

{ ---- segment 2 ------------------------------------------------------------- }

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

{ the computer player's attitude towards player I (100 at the start) }
function Attitude(var P: TPlayer; I: Byte): PSmallInt; inline;
begin
  Result := PSmallInt(@P.AttitudeQ[2 * I]);
end;

{ the money side of this year's event, as for humans (PlayerTurnStart) }
procedure EventMoney(var P: TPlayer);
var
  R: TReal48;
  W: LongInt;
begin
  case P.Event of
    5: P.EventMoney := LongInt(P.EventMoney + (Random(5000) + 1000));
    $0C: P.EventMoney := LongInt(P.EventMoney - P.Population * 3);
    $0F:
      begin
        R := R48Add(RandomReal, RC($0080, 0, 0));
        P.EventMoney := LongInt(P.EventMoney + R48Round(R48Mul(R48Mul(
          R48Add(P.Justice, RC($717A, $0A3D, $23D7)), R), RC($0090, 0, $4350))));
      end;
    $0D: P.EventMoney := LongInt(P.EventMoney - SmallInt(P.Title * 1000));
    $11:
      begin
        W := Random(1000) + 500;
        P.EventMoney := LongInt(P.EventMoney - Word(P.Title * W));
      end;
  end;
end;

procedure Ai_PopulationModel(var P: TPlayer);
begin
  UpdateBirthDeathRates(P);
  UpdateHappiness(P);
  P.Births := R48Round(R48Mul(FromLong(P.Population), P.BirthRate));
  P.Deaths := R48Round(R48Mul(FromLong(P.Population), P.DeathRate));
  P.Immigrants := LongInt(P.Immigrants + R48Round(R48Mul(ImmigrationRate(P), FromLong(P.Population))));
  P.Emigrants := LongInt(P.Emigrants + R48Round(R48Mul(EmigrationRate(P), FromLong(P.Population))));
  P.Population := LongInt(P.Population + P.Births - P.Deaths + P.Immigrants - P.Emigrants);
  if P.Population < 50 then
    P.Population := 50;
end;

procedure Ai_Budget(var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  Gain: LongInt;
begin
  { like the human budget, but no army pay and no warehouse rent; a
    positive net income is scaled by the computer level, a negative one is
    ignored; no running totals }
  P := @Players[Me];
  P^.IncomeBuildings := IncomeFromBuildings(Players[Me]);
  P^.TradeIncome := TradeAgreementIncome(Players, Me, NumPlayers);
  P^.TaxIncome := Rules.TaxIncome(Players[Me]);
  P^.JusticeIncome := Rules.JusticeIncome(Players[Me]);
  P^.ArmyPay := Rules.ArmyPay(Players[Me]);
  P^.RentAndInterest := Interest(Players[Me]);
  EventMoney(P^);
  P^.NetIncome := LongInt(P^.IncomeBuildings + P^.TradeIncome + P^.TaxIncome + P^.JusticeIncome
    + P^.RentAndInterest + P^.EventMoney);
  if P^.NetIncome > 0 then
    Gain := R48Round(R48Mul(FromLong(P^.NetIncome), DS.AiIncomeFactor[P^.CpuLevel]))
  else
    Gain := 0;
  P^.Taler := LongInt(P^.Taler + Gain);
end;

procedure Ai_GrainPolicy(var P: TPlayer);
var
  Low, Need, High, Dist, D: LongInt;
  R: Byte;
begin
  { distribute grain by the farmland per head; buy what is missing, sell
    half of the surplus now and then }
  Low := 0;
  Need := 0;
  High := 0;
  Dist := 0;
  GrainNeedMinMax(P, Low, Need, High);
  R := Ai_FarmlandPerCapita(P);
  case R of
    0..5: Dist := LongInt(Random(Word(Need - Low))) + Low;
    6..10: Dist := LongInt(Random(Word(High - Need))) + Need;
    11..255: Dist := High;
  end;
  if LongInt(P.CpuLevel * 500 + 10000) < P.Population then
    Dist := Need;
  D := LongInt(Dist - P.Grain);
  P.GrainDistributed := Dist;
  if D > 0 then
  begin
    P.Taler := LongInt(P.Taler - LongInt(D * P.GrainPrice) div 144);
    P.Grain := Dist;
  end;
  if (P.Grain > Dist) and (Random(P.CpuLevel + 1) = 0) then
  begin
    D := LongInt(P.Grain - Dist) div 2;
    P.Taler := LongInt(P.Taler + LongInt(D * P.GrainPrice) div 144);
    P.Grain := LongInt(P.Grain - D);
  end;
end;

procedure Ai_LandPolicy(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);
var
  P: PPlayer;
  Farmland, Margin: Byte;
  Afford, Delta, X: LongInt;
begin
  { sell land down to 12..17 Hufen per head while the price is high,
    buy (unclaimed) land when it is cheap }
  P := @Players[Me];
  Farmland := Ai_FarmlandPerCapita(P^);
  Margin := Ai_LandPriceMargin(Players, Me, NumPlayers);
  if P^.Taler > 0 then
  begin
    X := P^.Taler div (P^.LandPrice div 10);
    Afford := MinLong(X, UnclaimedLand(Players, NumPlayers));
  end
  else
    Afford := 0;
  Delta := 0;
  case Margin of
    0..5:
      begin
        X := LongInt(P^.Land - LongInt(Random(6) + 12) * P^.Population);
        if X < 0 then
          X := 0;
        Delta := LongInt(-MinLong(X, Ai_SurplusLand(P^)));
      end;
    6..9:
      if (Afford > 0) and (Random(Word(SmallInt(Farmland) div 3)) = 0) then
        Delta := Afford div (Random(4) + 1);
    10..15:
      if Afford > 0 then
        Delta := Afford div P^.CpuLevel;
  end;
  P^.Land := LongInt(P^.Land + Delta);
  P^.Taler := LongInt(P^.Taler - LongInt((P^.LandPrice div 10) * Delta));
end;

procedure Ai_SellGoods(var P: TPlayer; Year: Word);
begin
  { all salt, beer and wine are sold once the price is good enough }
  if (P.Salt > 0) and (P.PriceSalt >= 10) then
  begin
    P.Taler := LongInt(P.Taler + LongInt(P.Salt * P.PriceSalt));
    P.Salt := 0;
  end;
  if (P.Beer > 0) and (P.PriceBeer >= 45) then
  begin
    P.Taler := LongInt(P.Taler + LongInt(P.Beer * P.PriceBeer));
    P.Beer := 0;
  end;
  if (P.Wine > 0) and (P.PriceWine >= 100) then
  begin
    P.Taler := LongInt(P.Taler + LongInt(P.Wine * P.PriceWine));
    P.Wine := 0;
  end;
end;

procedure Ai_BuildingPolicy(var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  PMarket, PMill, PPalace, PCathedral, PGranary, PWarehouse, PTavern, PSmithy: LongInt;
  Pair, D, N, K: LongInt;
begin
  P := @Players[Me];
  if P^.Taler <= 0 then
    Exit;
  if P^.Spell = 6 then                       { Ferengicharme: 3/4 of the prices }
  begin
    PMarket := LongInt(DS.BuildingPrices[0] * 3) div 4;
    PMill := LongInt(DS.BuildingPrices[1] * 3) div 4;
    PPalace := LongInt(DS.BuildingPrices[2] * 3) div 4;
    PCathedral := LongInt(DS.BuildingPrices[3] * 3) div 4;
    PGranary := LongInt(DS.BuildingPrices[4] * 3) div 4;
    PWarehouse := LongInt(DS.BuildingPrices[5] * 3) div 4;
    PTavern := LongInt(DS.BuildingPrices[7] * 3) div 4;
    PSmithy := LongInt(DS.BuildingPrices[8] * 3) div 4;
  end
  else
  begin
    PMarket := DS.BuildingPrices[0];
    PMill := DS.BuildingPrices[1];
    PPalace := DS.BuildingPrices[2];
    PCathedral := DS.BuildingPrices[3];
    PGranary := DS.BuildingPrices[4];
    PWarehouse := DS.BuildingPrices[5];
    PTavern := DS.BuildingPrices[7];
    PSmithy := DS.BuildingPrices[8];
  end;
  Pair := LongInt(PMarket + PMill);
  { a palace part from Fuerst (7) on, a cathedral part as Koenig: one per turn }
  if (P^.Title >= 7) and (P^.PalaceBuiltThisTurn = 0) and (P^.PalaceParts < 12) and
     (P^.Taler >= PPalace) then
  begin
    Inc(P^.PalaceParts);
    P^.Taler := LongInt(P^.Taler - PPalace);
    P^.PalaceBuiltThisTurn := 1;
    if P^.PalaceParts = 12 then
      AddNews(Players, NumPlayers, Me, Me, $0E);
  end;
  if (P^.Title = 9) and (P^.CathedralBuiltThisTurn = 0) and (P^.CathedralParts < 12) and
     (P^.Taler >= PCathedral) then
  begin
    Inc(P^.CathedralParts);
    P^.Taler := LongInt(P^.Taler - PCathedral);
    P^.CathedralBuiltThisTurn := 1;
    if P^.CathedralParts = 12 then
      AddNews(Players, NumPlayers, Me, Me, $0F);
  end;
  { a granary while the storage is below 6 per head }
  if (GrainCapacity(P^) < LongInt(P^.Population * 6)) and (P^.Taler > LongInt(PGranary * 3)) then
  begin
    P^.Granaries := LongInt(P^.Granaries + 1);
    P^.Taler := LongInt(P^.Taler - PGranary);
  end;
  { a warehouse per 3000 people (the check uses the full price) }
  if (DS.Game.GoodsTradeEnabled <> 0) and (P^.Warehouses < P^.Population div 3000) and
     (P^.Taler > LongInt(DS.BuildingPrices[5] * 2)) then
  begin
    P^.Warehouses := LongInt(P^.Warehouses + 1);
    P^.Taler := LongInt(P^.Taler - PWarehouse);
  end;
  { the first tavern is free from Ritter on; then one per 1000 Hufen }
  if P^.Taverns = 0 then
  begin
    if P^.Title >= 2 then
      P^.Taverns := 1;
  end
  else if (LongInt(PTavern * 2) < P^.Taler) and
          (LongInt((P^.Land - P^.LandUsed) div 1000 + 1) > P^.Taverns) then
  begin
    P^.Taverns := LongInt(P^.Taverns + 1);
    P^.Taler := LongInt(P^.Taler - PTavern);
  end;
  { a smithy while the weapons output needs more (half price) }
  if (SmithyOutput(P^) > P^.Smithies) and (P^.Taler > PSmithy) then
  begin
    P^.Smithies := LongInt(P^.Smithies + 1);
    P^.Taler := LongInt(P^.Taler - PSmithy div 2);
  end;
  if P^.Taler < 0 then
    Exit;
  { as many markets as mills: build the missing kind }
  D := LongInt(P^.Markets - P^.Mills);
  if D > 0 then
  begin
    N := MinLong(P^.Taler div PMill, D);
    P^.Mills := LongInt(P^.Mills + N);
    P^.Taler := LongInt(P^.Taler - LongInt(N * PMill));
  end
  else
  begin
    if D < 0 then
      D := LongInt(-D);
    N := MinLong(P^.Taler div PMarket, D);
    P^.Markets := LongInt(P^.Markets + N);
    P^.Taler := LongInt(P^.Taler - LongInt(N * PMarket));
  end;
  if (P^.Taler < 0) or (P^.Markets > 100) or (P^.Mills > 100) then
    Exit;
  { then pairs of market and mill on the surplus land }
  N := MinLong(P^.Taler div Pair, Ai_SurplusLand(P^) div 1000);
  if N <= 0 then
    Exit;
  K := N div 2;
  K := LongInt(K + LongInt(Random(Word(N div 2))) + 1);
  P^.Markets := LongInt(P^.Markets + K);
  P^.Mills := LongInt(P^.Mills + K);
  P^.Taler := LongInt(P^.Taler - LongInt(Pair * K));
end;

procedure Ai_MilitaryPolicy(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  T, I, K, Last: Byte;
  Gains: THeroGains;
  Others: array[0..11] of Byte;
  Amount: LongInt;
  Caught: Byte;
begin
  FillChar(Gains, SizeOf(Gains), 0);
  FillChar(Others, SizeOf(Others), 0);
  Amount := 0;
  Caught := 0;
  P := @Players[Me];
  OfferUnitsAtTurnStart(Parent, P^);
  if P^.Army1Count > 8 then
    Ai_DropWeakestHeerUnit(P^);
  Ai_KnightSquires(P^);
  Ai_ArrangeArmies(P^, 2);
  { recruit while the army is weaker than the next title needs (plus a
    margin for the peaceful) }
  if ArmyStrength(P^, 1) < LongInt(DS.PromotionArmyStrength[P^.Title + 1] +
     DS.PromotionArmyStrength[P^.Title + 1] div SmallInt(P^.AiAggressionQ * 2)) then
  begin
    repeat
      T := P^.Title;
      while T > 0 do
      begin
        if Ai_CanRecruitType(P^, T) and
           (FameDiscount(P^.Fame, DS.UnitCost[T]) <= P^.Taler) then
          Break;
        Dec(T);
      end;
      if (T > 0) and (P^.Army1Count <= 8) then
      begin
        if T = 9 then
        begin
          Inc(P^.Army1Count);
          CreateHero(P^.Army1[P^.Army1Count], nil);
          if P^.Spell = 9 then
            UnitGainExperience(P^.Army1[P^.Army1Count], Gains, 10, P^.Spell);
          SortArmy(P^, 1);
        end
        else
          RecruitUnit(P^, 1, T, 0);
      end;
      if (T = 0) or (P^.Army1Count = 9) then
        Break;
    until not (DS.PromotionArmyStrength[P^.Title + 1] > ArmyStrength(P^, 1));
    if P^.Army1Count > 8 then
      Ai_DropWeakestHeerUnit(P^);
  end;
  { Haudegen knights of the Garde get a fief of 3000 Hufen }
  if P^.Spell <> 9 then
  begin
    Last := P^.Army2Count;
    for I := 1 to Last do
      if Chance(50) and (DS.UnitKnight[ShortInt(P^.Army2[I].UnitType)] <> 0) and
         (ShortInt(P^.Army2[I].UnitType) >= 8) and (P^.Army2[I].Level = 2) and
         (P^.Army2[I].Pay > 0) and (Ai_SurplusLand(P^) > 3000) and
         (LongInt(P^.LandUsed + 3000) < P^.Land div 20) then
      begin
        P^.LandUsed := LongInt(P^.LandUsed + 3000);
        P^.Army2[I].Pay := 0;
        UnitGainExperience(P^.Army2[I], Gains, $18, 9);
      end;
  end;
  { sabotage against much richer players (needs a tavern) }
  if P^.Taverns > 0 then
  begin
    K := 0;
    Last := Byte(NumPlayers - 1);
    for I := 0 to Last do
      if I <> Me then
      begin
        Others[K] := I;
        Inc(K);
      end;
    Last := Byte(NumPlayers - 2);
    for I := 0 to Last do
      if Chance(SmallInt(20 div (P^.AiAggressionQ + 1))) and
         (P^.SabotageAgents[Others[I]] > 0) and
         Ai_IsMuchRicher(P^, Players[Others[I]]) then
        SabotageAction(Players, NumPlayers, Me, Others[I], Random(14) + 1, Amount, Caught);
  end;
end;

function Ai_ChooseWarTarget(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte;
  var Target: Byte): Boolean;
var
  P: PPlayer;
  Unclaimed: LongInt;
  B, I, Last, UnitLast, Weight, Found: Byte;
  Ratio: TReal48;
  Attack: Boolean;
  Gains: THeroGains;
begin
  { computer opponents are fought at once (auto battle); the first human
    opponent found is returned for a real battle }
  FillChar(Gains, SizeOf(Gains), 0);
  P := @Players[Me];
  Unclaimed := UnclaimedLand(Players, NumPlayers);
  Found := 0;
  Last := Byte(NumPlayers - 1);
  for B := 0 to Last do
  begin
    if P^.Initiative <= 0 then
      Continue;
    if B = Me then
      Continue;
    if (P^.Army1Count = 0) and (P^.Army2Count = 0) then
      Continue;
    if P^.Title <= 1 then
      Continue;
    if P^.PeaceYears[B] <> 0 then
      Continue;
    Ratio := Ai_StrengthRatio(P^, Players[B]);
    if Players[B].CpuLevel = 0 then
      Weight := 100
    else
      Weight := Byte((7 - P^.AiAggressionQ) * 5);
    Attack := False;
    { a human about to become Kaiser who is much richer }
    if (Players[B].Title >= 9) and (R48Cmp(Ratio, RC($0080, 0, $4000)) > 0) and
       (Players[B].CpuLevel = 0) and Ai_IsMuchRicher(P^, Players[B]) and
       Chance(SmallInt((7 - P^.AiAggressionQ) * 3)) then
      Attack := True;
    { a hated, much weaker player }
    if not Attack and (Attitude(P^, B)^ < 10) and (R48Cmp(Ratio, RC($0082, 0, 0)) > 0) and
       Chance(SmallInt((7 - P^.AiAggressionQ) * 3)) then
      Attack := True;
    { a Koenig without land left to buy who still lacks land for Kaiser }
    if not Attack then
    begin
      if Unclaimed <> 0 then
        Continue;
      if P^.Land >= DS.PromotionLand[10] then
        Continue;
      if P^.Title <> 9 then
        Continue;
      if P^.Population < DS.PromotionPopulation[10] then
        Continue;
      if DS.PromotionTaler[10] div 2 > P^.Taler then
        Continue;
      if R48Cmp(Ratio, RC($9A80, $9999, $5999)) <= 0 then
        Continue;
    end;
    if not Chance(Weight) then
      Continue;
    if not Chance(50) and (P^.TradeAgreement[B] <> 0) then
      Continue;
    if Players[B].CpuLevel = 0 then
    begin
      if Found = 0 then
      begin
        Found := 1;
        Target := B;
      end;
      Continue;
    end;
    if Ai_AutoBattle(P^, Players[B]) <> 0 then
    begin
      UnitLast := P^.Army1Count;
      for I := 1 to UnitLast do
        UnitGainExperience(P^.Army1[I], Gains, 8, P^.Spell);
      AddNews(Players, NumPlayers, B, Me, 8);
    end
    else
    begin
      UnitLast := Players[B].Army1Count;
      for I := 1 to UnitLast do
        UnitGainExperience(Players[B].Army1[I], Gains, 8, Players[B].Spell);
      AddNews(Players, NumPlayers, B, Me, 9);
    end;
    P^.Initiative := ShortInt(P^.Initiative - AttackInitiativeCost(P^.Country, Players[B].Country));
    if P^.Initiative < 0 then
      P^.ArmyAway := 1;
  end;
  Result := (P^.Initiative > 0) and (ArmyStrength(P^, 1) > 0) and (Found <> 0);
end;

procedure Ai_HoldManoeuvre(var P: TPlayer);
var
  I, Last: Byte;
  Gains: THeroGains;
begin
  { a manoeuvre for experience, from title >= aggression on }
  FillChar(Gains, SizeOf(Gains), 0);
  if (P.Title < P.AiAggressionQ) or (P.ArmyAway <> 0) then
    Exit;
  Ai_ArrangeArmies(P, 1);
  Last := P.Army1Count;
  for I := 1 to Last do
    UnitGainExperience(P.Army1[I], Gains, Random(5) + 1, P.Spell);
  Dec(P.Initiative);
end;

procedure Ai_EndTurn(var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  L: TLandLoss;
  Sell: LongInt;
begin
  FillChar(L, SizeOf(L), 0);
  P := @Players[Me];
  Ai_HoldManoeuvre(P^);
  UpdateBirthDeathRates(P^);
  UpdateHappiness(P^);
  if CanBePromoted(P^) then
  begin
    Inc(P^.Title);
    GainFame(P^.Fame, 10);
    Inc(P^.Lifetime);
    if (P^.Title = 9) and (P^.FirstKingBonus = 0) then
    begin
      AddNews(Players, NumPlayers, Me, Me, $0D);
      P^.FirstKingBonus := 1;
      if IsFirstKing(Players, Me, NumPlayers) then
        Ai_FirstKingReward(Players, Me, NumPlayers);
    end;
  end
  else
  begin
    { from Herzog on: lower taxes and justice until happy enough }
    while (P^.Title >= 8) and (R48Cmp(P^.TaxRate, R48Zero) > 0) and
          (R48Cmp(P^.Justice, R48Zero) > 0) and
          (R48Cmp(DS.PromotionHappiness[P^.Title + 1], P^.Happiness) > 0) do
    begin
      P^.TaxRate := R48Sub(P^.TaxRate, RC($717A, $0A3D, $23D7));
      P^.Justice := R48Sub(P^.Justice, RC($717A, $0A3D, $23D7));
      UpdateHappiness(P^);
    end;
    if P^.Title = 9 then
    begin
      Sell := Ai_LandToSellForPromotion(P^);
      P^.Land := LongInt(P^.Land - Sell);
      P^.Taler := LongInt(P^.Taler + LongInt((P^.LandPrice div 10) * Sell));
    end;
    if CanBePromoted(P^) then
    begin
      Inc(P^.Title);
      GainFame(P^.Fame, 10);
      if P^.Title = 9 then
      begin
        AddNews(Players, NumPlayers, Me, Me, $0D);
        if IsFirstKing(Players, Me, NumPlayers) then
          Ai_FirstKingReward(Players, Me, NumPlayers);
      end;
    end;
  end;
  if BuildingsLostForLand(P^, L) then
  begin
    P^.Taler := LongInt(P^.Taler + L.Total);
    LoseFame(P^.Fame, 2);
  end;
  if P^.Taler < 0 then
  begin
    LoseFame(P^.Fame, 1);
    P^.Taler := 0;
  end;
  if R48Cmp(P^.Happiness, RC($0080, 0, 0)) < 0 then
    LoseFame(P^.Fame, 1);
  case Ai_RevolutionRoll(P^) of
    1:                                       { unrest }
      begin
        LoseFame(P^.Fame, 10);
        Dec(P^.Lifetime);
        AddNews(Players, NumPlayers, Me, Me, $0C);
      end;
    2:                                       { revolution: a title less, a year out }
      begin
        if P^.Title > 0 then
          Dec(P^.Title);
        LoseFame(P^.Fame, 50);
        Dec(P^.Lifetime);
        P^.SkipTurn := 1;
      end;
  end;
  if P^.Flags5bdQ and $80 <> 0 then
    P^.SkipTurn := 1;
  if P^.SkipTurn <> 0 then
  begin
    if P^.Flags5bdQ and $80 <> 0 then
      SkipTurnLosses(P^, 0)
    else
      SkipTurnLosses(P^, 1);
    AddNews(Players, NumPlayers, Me, Me, $0B);
  end;
end;

procedure Ai_FirstKingReward(var Players: TPlayers; Me, NumPlayers: Byte);
var
  P: PPlayer;
  K: Byte;
  Hero: PUnit;
  U: TUnit;
  Gains: THeroGains;
  I, Last: Byte;
begin
  { the first Koenig: a hero, else a stronger hero, half pay, or a unit }
  FillChar(Gains, SizeOf(Gains), 0);
  FillChar(U, SizeOf(U), 0);
  Hero := nil;
  P := @Players[Me];
  if not HasHero(P^) then
  begin
    Inc(P^.Army1Count);
    CreateHero(P^.Army1[P^.Army1Count], nil);
    K := 0;
    repeat
      UnitGainExperience(P^.Army1[P^.Army1Count], Gains, K * 2 + 10, P^.Spell);
      if K = 2 then
        Break;
      Inc(K);
    until False;
    SortArmy(P^, 1);
    if P^.Army1Count > 8 then
      Ai_DropWeakestHeerUnit(P^);
  end
  else
    case Random(3) of
      0:
        if FindHero(P^, Hero, 1) then
        begin
          Inc(Hero^.Attack);
          Inc(Hero^.MaxHp);
          Inc(Hero^.Defence);
        end;
      1:
        begin
          Last := P^.Army1Count;
          for I := 1 to Last do
            P^.Army1[I].Pay := P^.Army1[I].Pay div 2;
        end;
      2:
        begin
          K := Random(5);
          InitUnit(P^, U, DS.AiKingRewardType[K], DS.AiKingRewardBonus[K]);
          U.Pay := 0;
          AddUnitToArmy(P^, 1, U);
          if P^.Army1Count > 8 then
            Ai_DropWeakestHeerUnit(P^);
        end;
    end;
end;

procedure Ai_FirstYear(var P: TPlayer);
var
  I, Last: Byte;
  Gains: THeroGains;
begin
  { the first year of a computer player: a spell, a hero, from Fuerst on a
    starting army, and a dowry like MarriageDowry's }
  FillChar(Gains, SizeOf(Gains), 0);
  P.Spell := Random(12) + 1;
  Inc(P.Army1Count);
  CreateHero(P.Army1[P.Army1Count], nil);
  if P.Title >= 7 then
  begin
    UnitGainExperience(P.Army1[P.Army1Count], Gains, Random(20) + $21, 0);
    RecruitUnit(P, 1, 6, 0);
    RecruitUnit(P, 1, 6, 0);
    RecruitUnit(P, 1, Random(3) + 2, 0);
    RecruitUnit(P, 1, 5, 0);
    RecruitUnit(P, 1, 3, 0);
    RecruitUnit(P, 1, 4, 0);
    Last := P.Army1Count;
    for I := 1 to Last do
      UnitGainExperience(P.Army1[I], Gains, $16, P.Spell);
  end;
  if P.Spell = 9 then
  begin
    Last := P.Army1Count;
    for I := 1 to Last do
      UnitGainExperience(P.Army1[I], Gains, 10, 9);
  end;
  case Random(8) + 1 of
    1:
      begin
        P.Land := LongInt(P.Land + 1200);
        RecruitUnit(P, 1, 1, 0);
      end;
    2:
      begin
        P.Mills := LongInt(P.Mills + 1);
        P.Grain := LongInt(P.Grain + 5000);
      end;
    3:
      begin
        P.Markets := LongInt(P.Markets + 2);
        RecruitUnit(P, 1, 3, 0);
      end;
    4:
      begin
        P.Land := LongInt(P.Land + 1000);
        P.Grain := LongInt(P.Grain + 3000);
      end;
    5:
      begin
        P.Grain := LongInt(P.Grain + 1000);
        RecruitUnit(P, 1, 2, 0);
        RecruitUnit(P, 1, 2, 0);
      end;
    6:
      begin
        P.Land := LongInt(P.Land + 1500);
        P.Taler := LongInt(P.Taler + 2000);
      end;
    7:
      begin
        P.Mills := LongInt(P.Mills + 2);
        P.Taler := LongInt(P.Taler + 1000);
      end;
    8:
      begin
        P.Taler := LongInt(P.Taler + 3000);
        RecruitUnit(P, 1, 1, 0);
      end;
  end;
end;

procedure Ai_ReceiveAid(var Players: TPlayers; Me, Sender, Sub: Byte; Data: LongInt);
var
  P: PPlayer;
begin
  { a gift improves the attitude towards the sender }
  P := @Players[Me];
  case Sub of
    0: GainFame(Attitude(P^, Sender)^, SmallInt(Data div 1000));      { Taler }
    1: GainFame(Attitude(P^, Sender)^, SmallInt(Data div 500));       { land }
    2: GainFame(Attitude(P^, Sender)^, 5);                            { a unit }
    3:                                                                { settlers }
      begin
        P^.Immigrants := LongInt(P^.Immigrants + Data);
        GainFame(Attitude(P^, Sender)^, SmallInt(Data div 100));
      end;
  else
    Exit;
  end;
  ClearMailboxSlot(Mail(Players, Me, Sender)^);
end;

procedure Ai_AnswerTrade(var Players: TPlayers; Me, Sender, NumPlayers, Kind: Byte);
var
  P: PPlayer;
  Accept: Boolean;
begin
  P := @Players[Me];
  case Mail(Players, Me, Sender)^.Kind of
    5:                                       { offered: friends or richer partners }
      begin
        Accept := (Attitude(P^, Sender)^ >= 30) and Chance(SmallInt(Attitude(P^, Sender)^ - 20));
        if not Accept then
          Accept := (Players[Sender].IncomeBuildings > P^.IncomeBuildings) and Chance(50);
        if Accept then
          SetMail(Mail(Players, Sender, Me), 7, 0, 0)
        else
          SetMail(Mail(Players, Sender, Me), 8, 0, 0);
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
      end;
    7:                                       { our offer accepted }
      begin
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        P^.TradeAgreement[Sender] := 1;
        Players[Sender].TradeAgreement[Me] := 1;
        GainFame(Attitude(P^, Sender)^, 10);
        GainFame(P^.Fame, 1);
        if Players[Sender].CpuLevel = 0 then
          AddNews(Players, NumPlayers, Me, Sender, 6);
      end;
    6:                                       { cancelled by the other side }
      begin
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        P^.TradeAgreement[Sender] := 0;
        LoseFame(Attitude(P^, Sender)^, 20);
      end;
    8:                                       { our offer declined }
      begin
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        P^.TradeAgreement[Sender] := 0;
        Players[Sender].TradeAgreement[Me] := 0;
        LoseFame(Attitude(P^, Sender)^, 10);
      end;
  end;
end;

procedure Ai_AnswerPeace(var Players: TPlayers; Me, Sender, NumPlayers, Kind: Byte;
  Data: LongInt);
var
  P: PPlayer;
  Weak, Friend: Boolean;
  R: PMailSlot;
begin
  P := @Players[Me];
  case Mail(Players, Me, Sender)^.Kind of
    9:                                       { peace for Data years offered }
      begin
        Weak := (R48Cmp(Ai_StrengthRatio(P^, Players[Sender]), RC($0080, 0, $4000)) < 0) and
          Chance(LongInt(80 - Data));
        Friend := (Attitude(P^, Sender)^ > 50) and Chance(LongInt(Attitude(P^, Sender)^ - Data));
        if (Players[Sender].Title < 9) and (Weak or Friend) then
        begin
          R := Mail(Players, Sender, Me);
          R^.Kind := $0A;
          R^.Sub := 0;
          R^.Data := Mail(Players, Me, Sender)^.Data;
          GainFame(P^.Fame, 1);
          if Me < Sender then
            P^.PeaceYears[Sender] := Byte(Data)
          else
            P^.PeaceYears[Sender] := Byte(Data + 1);
          Inc(P^.Lifetime);
        end
        else
          SetMail(Mail(Players, Sender, Me), $0B, 0, 0);
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
      end;
    $0A:                                     { our offer accepted }
      begin
        P^.PeaceYears[Sender] := Byte(Data);
        if Players[Sender].CpuLevel = 0 then
          AddNews(Players, NumPlayers, Me, Sender, 5);
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        GainFame(Attitude(P^, Sender)^, 30);
        GainFame(P^.Fame, SmallInt(Data div 5));
        P^.Lifetime := SmallInt(P^.Lifetime + Random(2));
      end;
    $0B:                                     { declined }
      begin
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        LoseFame(Attitude(P^, Sender)^, 20);
      end;
  end;
end;

procedure Ai_AnswerTribute(var Players: TPlayers; Me, Sender, NumPlayers, Kind, Sub: Byte;
  Data: LongInt);
var
  P: PPlayer;
  Paid: Boolean;
  L: TLandLoss;

  { 100 * (1 - Data / Total) % }
  function Willing(Total: LongInt): Boolean;
  begin
    Result := Chance(R48Round(R48Mul(R48Sub(RC($0081, 0, 0),
      R48Div(FromLong(Data), FromLong(Total))), RC($0087, 0, $4800))));
  end;

begin
  FillChar(L, SizeOf(L), 0);
  P := @Players[Me];
  case Mail(Players, Me, Sender)^.Kind of
    2:                                       { a tribute is demanded }
      begin
        LoseFame(Attitude(P^, Sender)^, 20);
        Paid := False;
        { only a much weaker player considers paying }
        if (R48Cmp(Ai_StrengthRatio(P^, Players[Sender]), RC($3380, $3333, $3333)) < 0) and
           Chance(50) then
          case Sub of
            0:                               { Taler, from the event money }
              begin
                if P^.Taler > 0 then
                  Paid := Willing(P^.Taler);
                if Paid then
                begin
                  P^.EventMoney := LongInt(P^.EventMoney - Data);
                  Players[Sender].Taler := LongInt(Players[Sender].Taler + Data);
                  Players[Sender].TotalTribute := LongInt(Players[Sender].TotalTribute + Data);
                  SetMail(Mail(Players, Sender, Me), 4, 0, Data);
                  LoseFame(P^.Fame, 5);
                end;
              end;
            1:                               { land, 12000 free land are kept }
              begin
                if LongInt(P^.Land - P^.LandUsed - Data) < 12000 then
                  Data := LongInt(P^.Land - P^.LandUsed - 12000);
                Paid := Willing(P^.Land);
                if Paid then
                begin
                  TransferLand(P^, Players[Sender], L, Data, 0);
                  SetMail(Mail(Players, Sender, Me), 4, 1, Data);
                  LoseFame(P^.Fame, 5);
                end;
              end;
            3:                               { workers, 50 people are kept }
              begin
                if LongInt(P^.Population - Data) < 50 then
                  Data := LongInt(P^.Population - 50);
                Paid := Willing(P^.Population);
                if Paid then
                begin
                  P^.Emigrants := LongInt(P^.Emigrants + Data);
                  SetMail(Mail(Players, Sender, Me), 4, 3, Data);
                  LoseFame(P^.Fame, 5);
                end;
              end;
            5:                               { a trade agreement }
              begin
                if Players[Sender].Spell = 1 then
                  Paid := Chance(30)
                else
                  Paid := Chance(70);
                if Paid then
                  SetMail(Mail(Players, Sender, Me), 4, 5, 0);
              end;
            4:                               { Data years of peace }
              begin
                Paid := Chance(LongInt(60 - Data));
                if Paid then
                begin
                  SetMail(Mail(Players, Sender, Me), 4, 4, Data);
                  if Me < Sender then
                    P^.PeaceYears[Sender] := Byte(Data)
                  else
                    P^.PeaceYears[Sender] := Byte(Data + 1);
                end;
              end;
          end;
        if not Paid then
          SetMail(Mail(Players, Sender, Me), 3, Sub, Data);
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
      end;
    4:                                       { our demand was paid }
      begin
        case Sub of
          3: P^.Immigrants := LongInt(P^.Immigrants + Data);
          5:
            begin
              Players[Sender].TradeAgreement[Me] := 1;
              P^.TradeAgreement[Sender] := 1;
              AddNews(Players, NumPlayers, Me, Sender, 6);
            end;
          4:
            begin
              P^.PeaceYears[Sender] := Byte(Data);
              AddNews(Players, NumPlayers, Me, Sender, 5);
            end;
        end;
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
        GainFame(Attitude(P^, Sender)^, 20);
      end;
    3:                                       { our demand was refused }
      begin
        LoseFame(Attitude(P^, Sender)^, 40);
        ClearMailboxSlot(Mail(Players, Me, Sender)^);
      end;
  end;
end;

procedure Ai_Diplomacy(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);
var
  P: PPlayer;
  I, Last: Byte;
  S, R: PMailSlot;
begin
  P := @Players[Me];
  { answer the messages }
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
  begin
    S := Mail(Players, Me, I);
    case S^.Kind of
      1: Ai_ReceiveAid(Players, Me, I, S^.Sub, S^.Data);
      2..4: Ai_AnswerTribute(Players, Me, I, NumPlayers, S^.Kind, S^.Sub, S^.Data);
      5..8: Ai_AnswerTrade(Players, Me, I, NumPlayers, S^.Kind);
      9..$0B: Ai_AnswerPeace(Players, Me, I, NumPlayers, S^.Kind, S^.Data);
    end;
  end;
  { new proposals, at most one per player and year }
  for I := 0 to Last do
  begin
    if I = Me then
      Continue;
    R := Mail(Players, I, Me);
    { offer trade to friends that are not too mighty and earn more (or
      always with spell 1) }
    if (P^.TradeAgreement[I] = 0) and (R^.Kind = 0) and (Attitude(P^, I)^ > 30) and
       Chance(SmallInt(Attitude(P^, I)^ - 30)) and (Players[I].Title < 6) and
       ((P^.Spell = 1) or (Players[I].IncomeBuildings > P^.IncomeBuildings)) then
      SetMail(R, 5, 0, 0);
    { cancel trade with mighty partners that earn less or are disliked }
    if (P^.TradeAgreement[I] <> 0) and (R^.Kind = 0) and (Players[I].Title > 6) and
       (((Players[I].IncomeBuildings < P^.IncomeBuildings) and Chance(10)) or
        ((Attitude(P^, I)^ < 30) and Chance(SmallInt(50 - Attitude(P^, I)^)))) then
    begin
      R^.Kind := 6;
      R^.Sub := 0;
      R^.Data := (Random(5) + 1) * 5;
      P^.TradeAgreement[I] := 0;
    end;
    { offer peace to richer players when weak or friendly }
    if (P^.PeaceYears[I] = 0) and (R^.Kind = 0) and (Players[I].Title < 9) and
       (Players[I].IncomeBuildings < P^.IncomeBuildings) and
       Chance(SmallInt(P^.AiAggressionQ * 5)) and
       ((R48Cmp(Ai_StrengthRatio(P^, Players[I]), RC($CD80, $CCCC, $4CCC)) < 0) or
        (Attitude(P^, I)^ > 80)) then
    begin
      R^.Kind := 9;
      R^.Sub := 0;
      R^.Data := (Random(5) + 1) * 5;
    end;
    { demand tribute from much weaker players }
    if (P^.PeaceYears[I] = 0) and (R^.Kind = 0) and
       Chance(SmallInt((7 - P^.AiAggressionQ) * 5)) and
       (R48Cmp(Ai_StrengthRatio(P^, Players[I]), RC($0082, 0, 0)) > 0) then
    begin
      R^.Kind := 2;
      case Random(3) of
        0:                                   { land, if the way is short }
          begin
            R^.Sub := 1;
            R^.Data := MinLong(LongInt(Players[I].Land - Players[I].LandUsed - 12000), 30000);
            if (AttackInitiativeCost(P^.Country, Players[I].Country) <= 2) and (R^.Data > 100) then
              R^.Data := LongInt(Random(Word(R^.Data - 100))) + 100
            else
              R^.Kind := 0;
          end;
        1:                                   { workers }
          begin
            R^.Sub := 3;
            R^.Data := MinLong(LongInt(Players[I].Population - 50), 1000);
            if R^.Data > 0 then
              R^.Data := LongInt(Random(Word(R^.Data))) + 1
            else
              R^.Kind := 0;
          end;
        2:                                   { Taler }
          begin
            R^.Sub := 0;
            if Players[I].Taler < 0 then
              R^.Data := Random(10000)
            else
              R^.Data := Players[I].Taler div (Random(5) + 2);
          end;
      end;
      if P^.Spell <> 1 then
        LoseFame(P^.Fame, 1);
    end;
  end;
end;

procedure Ai_YearlySimulation(var Players: TPlayers; Me, NumPlayers: Byte; Year: Word);
var
  P: PPlayer;
  I, Last, Actor, Target, Kind: Byte;
  Cap: LongInt;
  Gains: THeroGains;
begin
  FillChar(Gains, SizeOf(Gains), 0);
  P := @Players[Me];
  UpdateInitiative(P^);
  P^.EventMoney := 0;
  P^.Immigrants := 0;
  P^.Emigrants := 0;
  P^.PalaceBuiltThisTurn := 0;
  P^.CathedralBuiltThisTurn := 0;
  P^.TaxRate := RC($CD7D, $CCCC, $4CCC);     { 0.1 }
  P^.Justice := RC($717D, $0A3D, $23D7);     { 0.08 }
  if P^.Spell = 7 then
    P^.HarvestQuality := Random(3) + 3
  else
    P^.HarvestQuality := Random(5) + 1;
  P^.Harvest := ComputeHarvest(P^, P^.HarvestQuality);
  UpdateGrainPrice(P^, P^.HarvestQuality);
  P^.Grain := MaxLong(0, LongInt(P^.Grain - P^.GrainDistributed));
  if DS.Game.GoodsTradeEnabled <> 0 then
    ProduceGoods(P^);
  { grain / (10 + 90 * random) rots }
  P^.Grain := LongInt(P^.Grain - R48Round(R48Div(FromLong(P^.Grain),
    R48Add(R48Mul(RandomReal, RC($0087, 0, $3400)), RC($0084, 0, $2000)))));
  if P^.Flags5bdQ and $1000 <> 0 then
    P^.Grain := P^.Grain div 2;
  Cap := GrainCapacity(P^);
  if P^.Grain > Cap then
    P^.Grain := Cap;
  if P^.Event = $10 then
    P^.Grain := P^.Harvest
  else
    P^.Grain := LongInt(P^.Grain + P^.Harvest);
  UpdateMarketPrices(Players, Me, NumPlayers, Year);
  if DS.Game.GoodsTradeEnabled <> 0 then
    Ai_SellGoods(P^, Year);
  if P^.Initiative >= 0 then
    P^.ArmyAway := 0;
  Last := P^.Army1Count;
  for I := 1 to Last do
    UnitGainExperience(P^.Army1[I], Gains, 1, P^.Spell);
  Last := P^.Army2Count;
  for I := 1 to Last do
    UnitGainExperience(P^.Army2[I], Gains, 1, P^.Spell);
  if Chance(30) and Army1HasAbility(P^, $15) then
    GainFame(P^.Fame, 1);
  { a war against a treaty partner: the attacker is hated }
  Last := P^.NewsCount;
  for I := 1 to Last do
  begin
    Actor := P^.News[3 * I - 3];
    Target := P^.News[3 * I - 2];
    Kind := P^.News[3 * I - 1];
    if ((Kind = 8) or (Kind = 9)) and (ShortInt(P^.PeaceYears[Actor]) > 0) then
      Attitude(P^, Target)^ := 0;
  end;
  { treaties run out; peace and trade improve the attitude, time worsens it }
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
  begin
    if ShortInt(P^.PeaceYears[I]) > 0 then
    begin
      Dec(P^.PeaceYears[I]);
      GainFame(Attitude(P^, I)^, 3);
    end;
    if P^.TradeAgreement[I] <> 0 then
      GainFame(Attitude(P^, I)^, 2);
    LoseFame(Attitude(P^, I)^, Random(Word(10 - P^.AiAggressionQ)));
  end;
end;

procedure Ai_Turn(Parent: Pointer; HWnd: Word; var Players: TPlayers; Me, NumPlayers: Byte;
  Year: Word);
var
  P: PPlayer;
begin
  { the year of a computer player (CpuTurn); HWnd is unused }
  P := @Players[Me];
  Dec(P^.Lifetime);
  if P^.SkipTurn <> 0 then
    Exit;
  if Year = 0 then
  begin
    Ai_FirstYear(P^);
    Ai_Diplomacy(Players, Me, NumPlayers, Year);
  end
  else
  begin
    RollYearlyEvent(Parent, Players, Me, NumPlayers, Year);
    Ai_YearlySimulation(Players, Me, NumPlayers, Year);
    SabotageEnd(Parent, Players, Me, NumPlayers);
    Ai_SetSabotageBudgets(Players, Me, NumPlayers);
    Ai_Diplomacy(Players, Me, NumPlayers, Year);
    if P^.Event = $11 then
    begin
      if Ai_BanditBattle(P^) <> 0 then
        RaiderVictoryReward(P^, 1)
      else
        AddNews(Players, NumPlayers, Me, Me, 7);
    end;
    Ai_PopulationModel(P^);
    Ai_Budget(Players, Me, NumPlayers);
  end;
  Ai_GrainPolicy(P^);
  Ai_LandPolicy(Players, Me, NumPlayers, Year);
  Ai_BuildingPolicy(Players, Me, NumPlayers);
  if Year > 0 then
    Ai_MilitaryPolicy(Parent, Players, Me, NumPlayers);
  if (DS.Game.Immortality = 0) and (P^.Lifetime <= 0) then
  begin
    AddNews(Players, NumPlayers, Me, Me, $10);
    InitComputerRuler(Players, Me);
  end;
  FillChar(P^.Flags5bdQ, 4, 0);
end;

end.
