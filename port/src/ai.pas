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

end.
