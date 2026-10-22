{ Game rules of Kaiser: the pure functions of the original rule library
  (segment 14, 1068:xxxx), ported in the original order of operations.

  Every Real48 constant is given exactly as the register words in the original
  code (RC(AX, BX, DX), with the second-operand registers CX, SI, DI written in
  the same order), so results are bit-identical. Each function names the
  original address; differential tests: port/tests/ruletest.pas. }
unit Rules;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  KaiserTypes, KaiserDS, Real48;

type
  PUnit = ^TUnit;
  PPlayer = ^TPlayer;

{ Real48 constant from the three register words of the original code }
function RC(W0, W1, W2: Word): TReal48;

function GrainCapacity(const P: TPlayer): LongInt;          { 1068:0885 }
function SmithyOutput(const P: TPlayer): LongInt;           { 1068:0bd3 }
function WarehouseFreeSpace(const P: TPlayer): LongInt;     { 1068:2ce7 }
function WarehouseRent(const P: TPlayer): LongInt;          { 1068:2da4 }
function FreeBuildingLand(const P: TPlayer): LongInt;       { 1068:2e4c }
function CreditLimit(const P: TPlayer): LongInt;            { 1068:1df2 }
function TaxIncome(const P: TPlayer): LongInt;              { 1068:1cd8 }
function JusticeIncome(const P: TPlayer): LongInt;          { 1068:1d60 }
function Interest(const P: TPlayer): LongInt;               { 1068:290e }
function IncomeFromBuildings(const P: TPlayer): LongInt;    { 1068:19bd }
function ComputeHarvest(const P: TPlayer; Quality: Byte): LongInt;  { 1068:298f }
function ImmigrationRate(const P: TPlayer): TReal48;        { 1068:17f3 }
function EmigrationRate(const P: TPlayer): TReal48;         { 1068:18fa }
function CountUnitsOfType(const P: TPlayer; UnitType: Byte): Byte;  { 1068:643b }
procedure UpdateBirthDeathRates(var P: TPlayer);            { 1068:0ee4 }
function UpdateHappiness(var P: TPlayer): Word;             { 1068:13a8 }
procedure UpdateGrainPrice(var P: TPlayer; Quality: Byte);  { 1068:2a08 }
function UnclaimedLand(const Players: TPlayers; NumPlayers: Byte): LongInt;  { 1068:2f86 }

function WarehouseCapacity(const P: TPlayer): LongInt;      { 1068:08d5 }
function CanAffordWithCredit(const P: TPlayer; Cost: LongInt): Boolean;  { 1068:0ae8 }
procedure GrainNeedMinMax(const P: TPlayer; var Low, Need, High: LongInt);  { 1068:0b2c }
function ComputeScore(const P: TPlayer; Unused1, Unused2: Word): LongInt;  { 1068:12fe }
function TradeAgreementIncome(const Players: TPlayers; Me, NumPlayers: Byte): LongInt;  { 1068:1b26 }
procedure Prokurist(var P: TPlayer);                        { 1068:1bf9 }
function ArmyPay(const P: TPlayer): LongInt;                { 1068:27ac }
function ManoeuvreCost(const P: TPlayer): LongInt;          { 1068:2850 }
procedure AddGoodsCapped(var P: TPlayer; Good: Byte; Amount: LongInt);  { 1068:2d4a }
procedure ReduceByFraction(var V: LongInt; F: TReal48);     { 1068:2dcc }
function FameDiscount(Fame, Cost: LongInt): LongInt;        { 1068:3003 }
procedure GainFame(var Fame: SmallInt; N: SmallInt);        { 1068:3040 }
procedure LoseFame(var Fame: SmallInt; N: SmallInt);        { 1068:305b }
function IsFirstKing(const Players: TPlayers; Me, NumPlayers: Byte): Boolean;  { 1068:31c7 }
procedure UpdateInitiative(var P: TPlayer);                 { 1068:3238 }
function AttackInitiativeCost(Defender, Attacker: Byte): Byte;  { 1068:3282 }
function FiefSize(const P: TPlayer; const U: TUnit): LongInt;  { 1068:4620 }
function HasAnyUnits(const P: TPlayer): Boolean;            { 1068:5c15 }
function ArmyStrength(const P: TPlayer; WithGarde: Byte): LongInt;  { 1068:5c3c }
function HasHero(const P: TPlayer): Boolean;                { 1068:6290 }
function FindHero(var P: TPlayer; var U: PUnit; WithArmy2: Byte): Boolean;  { 1068:6323 }
function Army1HasAbility(const P: TPlayer; Ability: Byte): Boolean;  { 1068:63e4 }
function ArtilleryClass(const P: TPlayer; WithArmy2: Byte): Byte;  { 1068:64d6 }
function HasDesertableUnit(const P: TPlayer; WithArmy2: Byte): Boolean;  { 1068:65c2 }
function MaxLong(A, B: LongInt): LongInt;                   { 1068:69f1 }
function MinLong(A, B: LongInt): LongInt;                   { 1068:6a2b }
function Chance(Percent: LongInt): Boolean;                 { 1068:6a65 }
procedure SetBit(var B: Byte; Bit: Byte);                   { 1068:6eec }
procedure ClearBit(var B: Byte; Bit: Byte);                 { 1068:6f23 }
function TestBit(B: Byte; Bit: Byte): Boolean;              { 1068:6f52 }

implementation

{ Integer arithmetic: the original wraps at 32 bits (longint) or 16 bits
  (integer), FPC computes in 64 bits. Results are truncated with LongInt()/
  SmallInt() wherever a division or comparison follows a possible overflow.
  Byte loops "for I := 0 to N - 1" keep the original's byte bound
  (N = 0 -> 256 iterations). }

function RC(W0, W1, W2: Word): TReal48;
begin
  Result[0] := Lo(W0); Result[1] := Hi(W0);
  Result[2] := Lo(W1); Result[3] := Hi(W1);
  Result[4] := Lo(W2); Result[5] := Hi(W2);
end;

function MaxLong(A, B: LongInt): LongInt;
begin
  if A > B then Result := A else Result := B;
end;

function MinLong(A, B: LongInt): LongInt;
begin
  if A < B then Result := A else Result := B;
end;

function FromLong(V: LongInt): TReal48; inline;
begin
  Result := R48FromLong(V);
end;

function GrainCapacity(const P: TPlayer): LongInt;
begin
  Result := P.Granaries * 10000 + 1000 + P.Mills * 500;
end;

function SmithyOutput(const P: TPlayer): LongInt;
begin
  Result := MinLong(P.Population div 2000, P.Land div 20000) + 1;
end;

function WarehouseFreeSpace(const P: TPlayer): LongInt;
begin
  Result := P.Warehouses * 1000 - P.Salt - P.Beer - P.Wine - P.Weapons;
end;

function WarehouseRent(const P: TPlayer): LongInt;
begin
  Result := WarehouseFreeSpace(P) div 10;
end;

function FreeBuildingLand(const P: TPlayer): LongInt;
var
  M: LongInt;
begin
  M := MaxLong(P.Markets, P.Mills);
  M := MaxLong(P.Granaries, M);
  M := MaxLong(P.Warehouses, M);
  M := MaxLong(P.PalaceParts, M);
  M := MaxLong(P.CathedralParts, M);
  M := MaxLong(P.UniversityParts, M);
  M := MaxLong(P.Taverns, M);
  M := MaxLong(P.Smithies, M);
  Result := (P.Land - P.LandUsed) - M * 1000;
end;

function CreditLimit(const P: TPlayer): LongInt;
begin
  Result := (Integer(P.Title) + 7) * 1000;
end;

function TaxIncome(const P: TPlayer): LongInt;
var
  R: TReal48;
begin
  { min(round((tax - 0.09) * pop * 11), pop * 2) }
  R := R48Sub(P.TaxRate, RC($1F7D, $EB85, $3851));
  R := R48Mul(R, FromLong(P.Population));
  R := R48Mul(R, RC($0084, $0000, $3000));
  Result := MinLong(P.Population * 2, R48Round(R));
end;

function JusticeIncome(const P: TPlayer): LongInt;
var
  R: TReal48;
begin
  { min(round((justice - 0.06) * pop * 7), pop * 3 div 2) }
  R := R48Sub(P.Justice, RC($297C, $8F5C, $75C2));
  R := R48Mul(R, FromLong(P.Population));
  R := R48Mul(R, RC($0083, $0000, $6000));
  Result := MinLong(LongInt(P.Population * 3) div 2, R48Round(R));
end;

function Interest(const P: TPlayer): LongInt;
begin
  if P.Taler > 0 then
    Result := R48Round(R48Mul(FromLong(P.Taler), RC($CD7B, $CCCC, $4CCC)))  { 0.025 }
  else
    Result := R48Round(R48Mul(FromLong(P.Taler), RC($B47D, $76C8, $1FBE)));  { 0.078 }
end;

function IncomeFromBuildings(const P: TPlayer): LongInt;
var
  Total: LongInt;
  I, N: SmallInt;
  R: TReal48;
begin
  Total := 0;
  N := SmallInt(P.Markets);
  for I := 1 to N do
    Total := Total + Random(155) + 77;
  N := SmallInt(P.Mills);
  for I := 1 to N do
    Total := Total + Random(330) + 165;
  N := SmallInt(P.Taverns);
  for I := 1 to N do
    Total := Total + Random(200) + 100;
  R := R48Mul(FromLong(Total), P.Happiness);
  if P.Spell = 2 then                                 { Bienenfleiss }
    R := R48Mul(R, RC($0081, $0000, $2000));          { 1.25 }
  Result := R48Round(R);
end;

function ComputeHarvest(const P: TPlayer; Quality: Byte): LongInt;
var
  Divisor: TReal48;
begin
  { round((land - land_used) * 5 * quality / (30 + Random(10))) }
  Divisor := FromLong(Random(10) + 30);
  Result := R48Round(R48Div(FromLong((P.Land - P.LandUsed) * 5 * Quality), Divisor));
end;

function ImmigrationRate(const P: TPlayer): TReal48;
var
  T1, R: TReal48;
begin
  T1 := R48Div(R48Div(FromLong(P.Population), RC($0090, $0000, $4350)),  { 50000 }
               RC($0087, $0000, $4800));                                  { 100 }
  R := R48Sub(RC($0081, 0, 0), P.AsylumLaw);
  R := R48Mul(R, P.Happiness);
  R := R48Div(R, RC($0083, $0000, $7000));                                { 7.5 }
  R := R48Sub(R, T1);
  if P.Event = $0B then
    R := R48Add(R, RC($CD7C, $CCCC, $4CCC));                             { 0.05 }
  if R48Cmp(R, R48Zero) < 0 then
    R := R48Zero;
  Result := R;
end;

function EmigrationRate(const P: TPlayer): TReal48;
var
  T1, T2, R: TReal48;
begin
  T1 := R48Div(R48Div(FromLong(P.Population), RC($0090, $0000, $4350)),
               RC($0087, $0000, $4800));
  T2 := R48Add(P.Justice, RC($CD7D, $CCCC, $4CCC));                      { + 0.1 }
  R := R48Sub(RC($0081, 0, 0), P.Happiness);
  R := R48Mul(R, T2);
  R := R48Div(R, RC($0083, $0000, $7000));
  Result := R48Add(R, T1);
end;

function CountUnitsOfType(const P: TPlayer; UnitType: Byte): Byte;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to P.Army1Count do
    if ShortInt(P.Army1[I].UnitType) = UnitType then
      Inc(Result);
  for I := 1 to P.Army2Count do
    if ShortInt(P.Army2[I].UnitType) = UnitType then
      Inc(Result);
end;

procedure UpdateBirthDeathRates(var P: TPlayer);
var
  D: TReal48;
begin
  if P.Population <= 0 then
  begin
    P.DeathRate := R48Zero;
    P.BirthRate := RC($C37D, $28F5, $0F5C);            { 0.07 }
    P.AsylumLaw := RC($0081, 0, 0);                    { 1.0 }
    P.TaxRate := R48Zero;
    P.Justice := R48Zero;
    Exit;
  end;
  { surplus = grain_distributed / 5 - population }
  D := R48Sub(R48Div(FromLong(P.GrainDistributed), RC($0083, $0000, $2000)),
              FromLong(P.Population));
  if R48Cmp(D, R48Zero) >= 0 then
  begin
    P.BirthRate := R48Add(R48Div(D, FromLong(P.Population)), RC($717A, $0A3D, $23D7));
    if R48Cmp(P.BirthRate, RC($C37D, $28F5, $0F5C)) > 0 then
      P.BirthRate := RC($C37D, $28F5, $0F5C);
    P.DeathRate := RC($717A, $0A3D, $23D7);           { 0.01 }
  end
  else
  begin
    P.BirthRate := RC($717A, $0A3D, $23D7);
    D := R48Div(D, FromLong(P.Population));
    D[5] := D[5] and $7F;                              { abs }
    P.DeathRate := R48Add(D, RC($717A, $0A3D, $23D7));
    if R48Cmp(P.DeathRate, RC($6680, $6666, $6666)) > 0 then
      P.DeathRate := RC($6680, $6666, $6666);         { 0.9 }
  end;
  if P.Spell = 8 then                                  { Heilende Haende }
    P.DeathRate := R48Div(P.DeathRate, RC($0082, 0, 0));
  case P.Event of
    9: P.DeathRate := R48Div(P.DeathRate, RC($0083, $0000, $2000));      { / 5 }
    1: P.BirthRate := R48Mul(P.BirthRate, RC($0082, 0, 0));              { * 2 }
    2: P.DeathRate := R48Add(P.DeathRate, RC($9A7E, $9999, $1999));      { 0.15 }
    6: P.DeathRate := R48Add(P.DeathRate, RC($9A7F, $9999, $1999));      { 0.3 }
    $0A: P.DeathRate := R48Add(P.DeathRate, RC($717D, $0A3D, $23D7));    { 0.08 }
    $11: P.DeathRate := R48Add(P.DeathRate, RC($CD7C, $CCCC, $4CCC));    { 0.05 }
    $13: P.DeathRate := R48Add(P.DeathRate, RC($717D, $0A3D, $23D7));    { 0.08 }
  end;
  if (P.Flags5bdQ and $0800) <> 0 then
  begin
    D := R48Div(RandomReal, RC($0086, $0000, $4800));                    { / 50 }
    P.DeathRate := R48Add(R48Add(P.DeathRate, RC($297B, $8F5C, $75C2)), D);  { + 0.03 }
  end;
  if R48Cmp(P.DeathRate, RC($6680, $6666, $6666)) > 0 then
    P.DeathRate := RC($6680, $6666, $6666);
end;

function UpdateHappiness(var P: TPlayer): Word;
var
  T1, T2, T3, T4, T5, T6, T7, H: TReal48;
begin
  T1 := R48Div(R48Div(FromLong(P.Population), RC($0090, $0000, $4350)),  { 50000 }
               RC($0086, $0000, $4800));                                  { 50 }
  T2 := R48Mul(FromLong(P.Taverns), RC($8D75, $6E97, $0312));            { 0.00025 }
  T3 := R48Mul(RC($0081, $0000, $4000), P.DeathRate);                    { 1.5 * death }
  T4 := R48Mul(FromLong(Integer(P.Army1Count) + P.Army2Count),
               RC($7179, $0A3D, $23D7));                                  { 0.005 }
  T5 := R48Mul(FromLong(P.Title), RC($717A, $0A3D, $23D7));              { 0.01 }
  T6 := R48Mul(P.BirthRate, RC($0082, 0, 0));                            { * 2 }
  T7 := R48Div(P.AsylumLaw, RC($0082, $0000, $4000));                    { / 3 }
  H := R48Mul(FromLong(P.Fame), RC($5478, $A5E3, $449B));                { 0.003 }
  H := R48Add(H, RC($007F, 0, 0));                                       { + 0.25 }
  H := R48Add(H, T7);
  H := R48Add(H, T6);
  H := R48Add(H, T5);
  H := R48Add(H, T4);
  H := R48Sub(H, P.TaxRate);
  H := R48Sub(H, P.Justice);
  H := R48Sub(H, T3);
  H := R48Add(H, T2);
  H := R48Sub(H, T1);
  P.Happiness := H;
  if P.CpuLevel <> 0 then
    P.Happiness := R48Add(P.Happiness, RC($9A7E, $9999, $1999));         { 0.15 }
  if P.Spell = 4 then                                                     { Engelszungen }
    P.Happiness := R48Add(P.Happiness, RC($9A7E, $9999, $1999));
  if P.Spell = $0B then                                                   { Pietaet }
    P.Happiness := R48Add(P.Happiness, RC($CD7C, $CCCC, $4CCC));         { 0.05 }
  if P.Spell = $0C then                                                   { Terror }
  begin
    T1 := R48Mul(FromLong(CountUnitsOfType(P, 10)), RC($297A, $8F5C, $75C2));  { 0.015 }
    P.Happiness := R48Sub(R48Sub(P.Happiness, R48Zero), T1);
  end;
  if P.Event = $0B then
    P.Happiness := R48Sub(P.Happiness, RC($CD7D, $CCCC, $4CCC))          { 0.1 }
  else if (P.Event = $11) or (P.Event = $13) then
    P.Happiness := R48Sub(P.Happiness, RC($CD7E, $CCCC, $4CCC));         { 0.2 }
  if (P.Flags5bdQ and $0040) <> 0 then
    P.Happiness := R48Sub(P.Happiness, RC($1F7E, $EB85, $3851));         { 0.18 }
  if (P.Flags5bdQ and $0080) <> 0 then
    P.Happiness := R48Sub(P.Happiness, RC($1F7D, $EB85, $3851));         { 0.09 }
  if (P.Flags5bdQ and $0100) <> 0 then
    P.Happiness := R48Sub(P.Happiness, RC($C37D, $28F5, $0F5C));         { 0.07 }
  if R48Cmp(P.Happiness, RC($0081, 0, 0)) > 0 then
    P.Happiness := RC($0081, 0, 0);
  if R48Cmp(P.Happiness, R48Zero) < 0 then
    P.Happiness := R48Zero;
  Result := Word(R48Round(R48Mul(P.Happiness, RC($0087, $0000, $4800))));  { * 100 }
end;

procedure UpdateGrainPrice(var P: TPlayer; Quality: Byte);
var
  F, R: TReal48;
begin
  { round((RandomReal * 20 + 20) * (6 - quality) / 3 + 30) }
  F := FromLong(6 - Integer(Quality));
  R := R48Add(R48Mul(RandomReal, RC($0085, $0000, $2000)), RC($0085, $0000, $2000));
  R := R48Mul(R, F);
  R := R48Div(R, RC($0082, $0000, $4000));
  R := R48Add(R, RC($0085, $0000, $7000));
  P.GrainPrice := R48Round(R);
end;

function UnclaimedLand(const Players: TPlayers; NumPlayers: Byte): LongInt;
var
  I, Last: Byte;
  Sum: LongInt;
begin
  Sum := 0;
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    Sum := Sum + Players[I].Land;
  Result := MaxLong(LongInt(NumPlayers * LongInt(100000) - Sum), 0);
end;

{ ---- batch 2 ---- }

{ Goods 1..4 (salt, beer, wine, weapons) are consecutive longints / words
  / bytes in the player record; the original indexes them like arrays. }
function Stock(var P: TPlayer; Good: Byte): PLongInt; inline;
begin
  Result := @PLongInt(@P.Salt)[Good - 1];
end;

function WarehouseCapacity(const P: TPlayer): LongInt;
begin
  Result := P.Warehouses * 1000;
end;

function CanAffordWithCredit(const P: TPlayer; Cost: LongInt): Boolean;
begin
  Result := LongInt(P.Taler - Cost) >= LongInt(-CreditLimit(P));
end;

procedure GrainNeedMinMax(const P: TPlayer; var Low, Need, High: LongInt);
var
  N: LongInt;
begin
  N := P.Population * 5;
  Low := R48Round(R48Mul(FromLong(N), RC($7B7D, $AE14, $6147)));    { 0.11 }
  Need := N;
  High := R48Round(R48Mul(FromLong(N), RC($E181, $147A, $07AE)));   { 1.06 }
end;

function ComputeScore(const P: TPlayer; Unused1, Unused2: Word): LongInt;
begin
  Result := ArmyStrength(P, 1) div 50 + P.Taler div 100000 + P.Land div 20000 +
    P.Population div 2000 + P.Title + P.Fame div 20;
end;

function TradeAgreementIncome(const Players: TPlayers; Me, NumPlayers: Byte): LongInt;
var
  I, Last: Byte;
  Sum: LongInt;
begin
  Sum := 0;
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    if (I <> Me) and (Players[Me].TradeAgreement[I] <> 0) then
      Sum := Sum + Players[I].Mills * 330 + Players[I].Markets * 155;
  Result := Sum div (NumPlayers + 6);
end;

procedure Prokurist(var P: TPlayer);
var
  I: Byte;
  V: LongInt;
begin
  { sell the whole stock of every good whose price reached the minimum }
  for I := 1 to 4 do
    if (PByte(@P.ProkuristSalt)[I - 1] <> 0) and
       (PLongInt(@P.PriceSalt)[I - 1] >= PSmallInt(@P.ProkuristMinSalt)[I - 1]) then
    begin
      V := Stock(P, I)^ * PLongInt(@P.PriceSalt)[I - 1];
      P.Taler := P.Taler + V;
      P.TotalGoodsSales := P.TotalGoodsSales + V;
      Stock(P, I)^ := 0;
    end;
end;

function ArmyPay(const P: TPlayer): LongInt;
var
  I: Byte;
begin
  Result := 0;
  for I := 1 to P.Army1Count do
    Result := Result + P.Army1[I].Pay;
  for I := 1 to P.Army2Count do
    Result := Result + P.Army2[I].Pay;
end;

function ManoeuvreCost(const P: TPlayer): LongInt;
var
  I, MaxLevel: Byte;
  Cost: LongInt;
begin
  { heroes 2000 each, other units (level + 1) * 500 if they can still rise }
  Cost := 0;
  if P.Spell = 9 then                                  { Heldentum }
    MaxLevel := 3
  else
    MaxLevel := 2;
  for I := 1 to P.Army1Count do
    if P.Army1[I].UnitType = 9 then
      Cost := Cost + 2000
    else if P.Army1[I].Level < MaxLevel then
      Cost := Cost + SmallInt((P.Army1[I].Level + 1) * 500);
  Result := FameDiscount(P.Fame, Cost);
end;

procedure AddGoodsCapped(var P: TPlayer; Good: Byte; Amount: LongInt);
var
  Free: LongInt;
begin
  if DS.Game.GoodsTradeEnabled = 0 then
    Exit;
  Free := WarehouseFreeSpace(P);
  if Free > Amount then
    Free := Amount;
  Stock(P, Good)^ := Stock(P, Good)^ + Free;
end;

procedure ReduceByFraction(var V: LongInt; F: TReal48);
var
  NewV: LongInt;
begin
  { V := V - round(V * F), but at least 1 less }
  NewV := V - R48Round(R48Mul(FromLong(V), F));
  if NewV = V then
    V := V - 1
  else
    V := NewV;
end;

function FameDiscount(Fame, Cost: LongInt): LongInt;
begin
  Result := Cost - LongInt(Cost * Fame) div 200;
end;

procedure GainFame(var Fame: SmallInt; N: SmallInt);
begin
  Fame := SmallInt(Fame + N);
  if Fame > 100 then
    Fame := 100;
end;

procedure LoseFame(var Fame: SmallInt; N: SmallInt);
begin
  Fame := SmallInt(Fame - N);
  if Fame < 0 then
    Fame := 0;
end;

function IsFirstKing(const Players: TPlayers; Me, NumPlayers: Byte): Boolean;
var
  I, Last: Byte;
  Found: Boolean;
begin
  { nobody else is Koenig (title 9) or has been first Koenig }
  Found := False;
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    if (I <> Me) and ((Players[I].Title = 9) or (Players[I].FirstKingBonus <> 0)) then
      Found := True;
  Result := not Found;
end;

procedure UpdateInitiative(var P: TPlayer);
begin
  if DS.Game.InitiativeEnabled <> 0 then
  begin
    if P.Initiative > 0 then
      P.Initiative := 0;
    P.Initiative := ShortInt(Byte(P.Initiative) + Byte(P.Fame div 50 + 2));
    if P.Spell = 5 then                                { Feldmarschall }
      P.Initiative := ShortInt(Byte(P.Initiative) + 1);
  end
  else
    P.Initiative := 0;
end;

function AttackInitiativeCost(Defender, Attacker: Byte): Byte;
begin
  if DS.Game.InitiativeEnabled <> 0 then
    Result := DS.AttackInitiativeCost[Defender, Attacker]
  else
    Result := 0;
end;

function FiefSize(const P: TPlayer; const U: TUnit): LongInt;
begin
  Result := SmallInt(U.BasePay div 100 * 100);
  if P.Spell = 3 then                                  { Chevalerie }
    Result := Result div 2;
end;

function HasAnyUnits(const P: TPlayer): Boolean;
begin
  Result := (P.Army1Count > 0) or (P.Army2Count > 0);
end;

function ArmyStrength(const P: TPlayer; WithGarde: Byte): LongInt;
var
  I: Byte;
begin
  Result := 0;
  for I := 1 to P.Army1Count do
    Result := Result + P.Army1[I].Attack + P.Army1[I].Defence;
  if WithGarde <> 0 then
    for I := 1 to P.Army2Count do
      Result := Result + P.Army2[I].Attack + P.Army2[I].Defence;
end;

function HasHero(const P: TPlayer): Boolean;
var
  I, N: Byte;
begin
  N := 0;
  for I := 1 to P.Army1Count do
    if P.Army1[I].UnitType = 9 then
      Inc(N);
  for I := 1 to P.Army2Count do
    if P.Army2[I].UnitType = 9 then
      Inc(N);
  Result := N > 0;
end;

function FindHero(var P: TPlayer; var U: PUnit; WithArmy2: Byte): Boolean;
var
  I: Byte;
begin
  { U is only set when a hero is found }
  Result := False;
  I := 1;
  while (I <= P.Army1Count) and not Result do
  begin
    if P.Army1[I].UnitType = 9 then
    begin
      U := @P.Army1[I];
      Result := True;
    end;
    Inc(I);
  end;
  if not Result and (WithArmy2 <> 0) then
  begin
    I := 1;
    while (I <= P.Army2Count) and not Result do
    begin
      if P.Army2[I].UnitType = 9 then
      begin
        U := @P.Army2[I];
        Result := True;
      end;
      Inc(I);
    end;
  end;
end;

function Army1HasAbility(const P: TPlayer; Ability: Byte): Boolean;
var
  I: Byte;
begin
  Result := False;
  if P.Army1Count = 0 then
    Exit;
  I := 1;
  while (I <= P.Army1Count) and (P.Army1[I].Ability <> Ability) do
    Inc(I);
  Result := I <= P.Army1Count;
end;

function ArtilleryClass(const P: TPlayer; WithArmy2: Byte): Byte;
var
  I: Byte;
  Ranged, Blasting: Boolean;
begin
  { 0 = no ranged unit, 1 = ranged units, 2 = Sprengpulver (ability 10) }
  Ranged := False;
  Blasting := False;
  for I := 1 to P.Army1Count do
  begin
    if P.Army1[I].Range > 1 then
      Ranged := True;
    if P.Army1[I].Ability = 10 then
      Blasting := True;
  end;
  if WithArmy2 <> 0 then
    for I := 1 to P.Army2Count do
    begin
      if P.Army2[I].Range > 1 then
        Ranged := True;
      if P.Army2[I].Ability = 10 then
        Blasting := True;
    end;
  if not Blasting and not Ranged then
    Result := 0
  else if not Blasting then
    Result := 1
  else
    Result := 2;
end;

function HasDesertableUnit(const P: TPlayer; WithArmy2: Byte): Boolean;
var
  I, N: Byte;
begin
  N := 0;
  for I := 1 to P.Army1Count do
    if DS.UnitCanDesert[ShortInt(P.Army1[I].UnitType)] <> 0 then
      Inc(N);
  if WithArmy2 <> 0 then
    for I := 1 to P.Army2Count do
      if DS.UnitCanDesert[ShortInt(P.Army2[I].UnitType)] <> 0 then
        Inc(N);
  Result := N > 0;
end;

function Chance(Percent: LongInt): Boolean;
begin
  if Percent < 0 then
    Percent := 0;
  Result := LongInt(Random(100)) < Percent;
end;

procedure SetBit(var B: Byte; Bit: Byte);
var
  Mask: Byte;
begin
  Mask := Byte(1 shl Bit);
  if (B and Mask) = 0 then
    B := Byte(B + Mask);
end;

procedure ClearBit(var B: Byte; Bit: Byte);
begin
  if TestBit(B, Bit) then
    B := Byte(B - Byte(1 shl Bit));
end;

function TestBit(B: Byte; Bit: Byte): Boolean;
begin
  Result := (B and Byte(1 shl Bit)) <> 0;
end;

end.
