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
  Strings, KaiserTypes, KaiserDS, KaiserRes, Real48;

type
  PUnit = ^TUnit;
  PPlayer = ^TPlayer;

  { buildings a player loses when the land no longer carries them
    (BuildingsLostForLand), handed over in TransferLand }
  TLandLoss = packed record
    Total: LongInt;   { refund in Taler; TransferLand: number of buildings handed over }
    Unused4: LongInt;
    Markets, Mills, PalaceParts, CathedralParts, Granaries, Warehouses,
    UniversityParts, Taverns, Smithies: LongInt;
  end;

  { what a hero gained at a level-up (UnitGainExperience), for the dialog }
  THeroGains = packed record
    Name: array[0..24] of Char;
    Level, Attack, Defence, MaxHp, Range, Steps, Ammo: Byte;
  end;

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

procedure MaximizeTaxes(var P: TPlayer);                    { 1068:1e29 }
function CanBePromoted(var P: TPlayer): Boolean;            { 1068:3076 }
procedure RemoveGranaries(var P: TPlayer; N: LongInt);      { 1068:0900 }
procedure RemoveWarehouses(var P: TPlayer; N: LongInt);     { 1068:09b4 }
function ProduceGoods(var P: TPlayer): Boolean;             { 1068:0c22 }
function BuildingsLostForLand(var P: TPlayer; var L: TLandLoss): Boolean;  { 1068:22c0 }
procedure UpdateMarketPrices(var Players: TPlayers; Me, NumPlayers: Byte;
  Unused: Word);                                            { 1068:2a77 }
procedure TransferLand(var From, Dest: TPlayer; var L: TLandLoss; Amount: LongInt;
  WithFiefs: Byte);                                         { 1068:41d5 }
procedure SkipTurnLosses(var P: TPlayer; Mode: ShortInt);   { 1068:438c }
function SabotageYearlyCost(const Players: TPlayers; Me, NumPlayers: Byte): LongInt;  { 1068:32b2 }
procedure SabotageFunding(var Players: TPlayers; Me, NumPlayers: Byte);  { 1068:3386 }
function SabotageYearsToNextOp(const Players: TPlayers; var Me, Target: Byte): SmallInt;  { 1068:35c1 }

procedure IntToPChar(Dest: PChar; V: LongInt);              { 1068:6b29 }
function UnitGainExperience(var U: TUnit; var Gains: THeroGains; XP, Spell: Byte): Boolean;  { 1068:4671 }
procedure FillWithMilitia(var P: TPlayer);                  { 1068:4b22 }
procedure GenerateMarauders(var P: TPlayer; Strength: SmallInt);  { 1068:4d7c }
procedure GenerateLindwurm(var P: TPlayer);                 { 1068:506a }
procedure ClearUnit(var U: TUnit);                          { 1068:50c5 }
procedure RemoveArmy1Unit(var P: TPlayer; Index: Byte);     { 1068:50e2 }
procedure RemoveArmy2Unit(var P: TPlayer; Index: Byte);     { 1068:515e }
procedure RemoveMilitia(var P: TPlayer);                    { 1068:51da }
procedure SwapArmies(var P: TPlayer);                       { 1068:5222 }
procedure MakeUnitName(Dest: PChar; UnitType, Number, Country: Byte);  { 1068:53a4 }
procedure RecruitUnit(var P: TPlayer; Army, UnitType, Bonus: Byte);  { 1068:5439 }
procedure InitAvenger(var U: TUnit);                        { 1068:5638 }
function AvengerJoinsWeaker(var A, B: TPlayer; var U: TUnit): Word;  { 1068:56bc }
procedure AvengerLeaves(var A, B: TPlayer; var U: TUnit);   { 1068:5835 }
procedure InitUnit(var P: TPlayer; var U: TUnit; UnitType, Bonus: Byte);  { 1068:598d }
procedure AddUnitToArmy(var P: TPlayer; Army: Byte; var U: TUnit);  { 1068:5b06 }
procedure KnightSquire(var P: TPlayer; var U: TUnit);       { 1068:5b8b }
procedure SortArmy(var P: TPlayer; Army: Byte);             { 1068:5e85 }
procedure CreateHero(var U: TUnit; Name: PChar);            { 1068:5f0c }
procedure HeroRankName(Level: Byte; Dest: PChar);           { 1068:6122 }
function RandomMercenaryType(const P: TPlayer): Byte;       { 1068:6199 }
procedure UnitRankName(const U: TUnit; Dest: PChar);        { 1068:61db }
procedure RaiderVictoryReward(var P: TPlayer; Kind: Byte);  { 1068:66af }
procedure MakeVampire(var Dest: TUnit; const Src: TUnit);   { 1068:674b }

procedure CreateComputerPlayers(var Players: TPlayers; NumHumans, NumCpu,
  Difficulty: Byte);                                        { 1068:0002 }
procedure InitPlayers(var Players: TPlayers; NumPlayers, Difficulty: Byte);  { 1068:01c1 }
procedure InitComputerRuler(var Players: TPlayers; Index: Byte);  { 1068:0788 }
function SabotageAction(var Players: TPlayers; Unused, Me, Target, Kind: Byte;
  var Amount: LongInt; var Caught: Byte): Boolean;          { 1068:36ef }
function Distance(X1, Y1, X2, Y2: SmallInt): Word;          { 1068:666b }
procedure ClearHighScores(var Tables);                      { 1068:67c5 }
procedure SortHighScoreTable(var Table);                    { 1068:67db }
procedure ClearMailboxSlot(var Slot);                       { 1068:68b0 }
procedure AddNews(var Players: TPlayers; NumPlayers, Actor, Target, Kind: Byte);  { 1068:68c5 }
procedure LogSabotageReport(var Players: TPlayers; Unused, Attacker, Target, Kind: Byte;
  Amount: LongInt);                                         { 1068:696f }
procedure FormatPercent(Dest: PChar; Part, Total: LongInt); { 1068:6aa5 }
procedure FormatThousands(Dest: PChar; V: LongInt);         { 1068:6b58 }
procedure BuildingProgressText(Dest: PChar; Parts: Byte);   { 1068:6c36 }
procedure RealmName(Dest: PChar; Land: LongInt);            { 1068:6cb4 }
procedure FameText(Dest: PChar; Fame: Byte);                { 1068:6d8b }
procedure MagnitudeText(Dest: PChar; V: LongInt);           { 1068:6e30 }

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

{ ---- batch 3 ---- }

procedure MaximizeTaxes(var P: TPlayer);
var
  F, Base, T, Total, Best, BestTax, BestJustice: TReal48;
  I, J, TaxLo, TaxHi, JusLo, JusHi: Byte;
  V: SmallInt;

  { try the current tax/justice pair: keep it if happiness stays above
    0.3 and the income is the best so far }
  procedure TryPair;
  begin
    UpdateHappiness(P);
    if R48Cmp(P.Happiness, RC($9A7F, $9999, $1999)) > 0 then      { 0.3 }
    begin
      Total := R48Add(R48Add(R48Mul(Base, P.Happiness), T), FromLong(JusticeIncome(P)));
      if R48Cmp(Total, Best) > 0 then
      begin
        Best := Total;
        BestTax := P.TaxRate;
        BestJustice := P.Justice;
      end;
    end;
  end;

begin
  if P.Spell = 2 then                                  { Bienenfleiss }
    F := RC($0081, $0000, $2000)                       { 1.25 }
  else
    F := RC($0081, $0000, $0000);
  Base := R48Mul(FromLong(P.Mills * 330 + P.Markets * 155), F);
  UpdateBirthDeathRates(P);
  Best := R48Zero;
  BestTax := R48Zero;
  BestJustice := R48Zero;
  { coarse search in steps of 10 % }
  for I := 0 to 5 do
  begin
    P.TaxRate := R48Div(FromLong(I), RC($0084, $0000, $2000));    { / 10 }
    T := FromLong(TaxIncome(P));
    for J := 0 to 5 do
    begin
      P.Justice := R48Div(FromLong(J), RC($0084, $0000, $2000));
      TryPair;
    end;
  end;
  { fine search in steps of 1 % around the best pair }
  V := SmallInt(R48Round(R48Mul(RC($0087, $0000, $4800), BestTax)) - 5);
  if V < 0 then V := 0;
  TaxLo := Byte(V);
  V := SmallInt(R48Round(R48Mul(RC($0087, $0000, $4800), BestTax)) + 5);
  if V > 50 then V := 50;
  TaxHi := Byte(V);
  V := SmallInt(R48Round(R48Mul(RC($0087, $0000, $4800), BestJustice)) - 5);
  if V < 0 then V := 0;
  JusLo := Byte(V);
  V := SmallInt(R48Round(R48Mul(RC($0087, $0000, $4800), BestJustice)) + 5);
  if V > 50 then V := 50;
  JusHi := Byte(V);
  Best := R48Zero;
  for I := TaxLo to TaxHi do
  begin
    P.TaxRate := R48Div(FromLong(I), RC($0087, $0000, $4800));    { / 100 }
    T := FromLong(TaxIncome(P));
    for J := JusLo to JusHi do
    begin
      P.Justice := R48Div(FromLong(J), RC($0087, $0000, $4800));
      TryPair;
    end;
  end;
  P.TaxRate := BestTax;
  P.Justice := BestJustice;
  UpdateHappiness(P);
end;

function CanBePromoted(var P: TPlayer): Boolean;
var
  T: Byte;
begin
  if P.MaximizeTaxes <> 0 then
    MaximizeTaxes(P);
  UpdateBirthDeathRates(P);
  UpdateHappiness(P);
  T := Byte(P.Title + 1);
  Result := (DS.PromotionLand[T] <= P.Land) and
    (DS.PromotionTaler[T] <= P.Taler) and
    (DS.PromotionPopulation[T] <= P.Population) and
    (DS.PromotionPalaceParts[T] <= P.PalaceParts) and
    (DS.PromotionCathedralParts[T] <= P.CathedralParts) and
    (DS.PromotionArmyStrength[T] <= ArmyStrength(P, 1)) and
    (R48Cmp(DS.PromotionHappiness[T], P.Happiness) <= 0);
end;

procedure RemoveGranaries(var P: TPlayer; N: LongInt);
var
  Ratio: TReal48;
  OldCap: LongInt;
begin
  { the grain stock keeps its share of the (smaller) capacity }
  OldCap := GrainCapacity(P);
  if P.Granaries < N then
    N := P.Granaries;
  Ratio := R48Div(FromLong(P.Grain), FromLong(OldCap));
  P.Granaries := P.Granaries - N;
  P.Grain := R48Round(R48Mul(FromLong(GrainCapacity(P)), Ratio));
end;

procedure RemoveWarehouses(var P: TPlayer; N: LongInt);
var
  Ratio: array[1..4] of TReal48;
  Cap: LongInt;
  I: Byte;
begin
  Cap := WarehouseCapacity(P);
  if P.Warehouses < N then
    N := P.Warehouses;
  if Cap <= 0 then
    Exit;
  for I := 1 to 4 do
    Ratio[I] := R48Div(FromLong(Stock(P, I)^), FromLong(Cap));
  P.Warehouses := P.Warehouses - N;
  Cap := WarehouseCapacity(P);
  for I := 1 to 4 do
    Stock(P, I)^ := R48Round(R48Mul(FromLong(Cap), Ratio[I]));
end;

function ProduceGoods(var P: TPlayer): Boolean;
var
  F: TReal48;
  Free, V: LongInt;
begin
  { yearly salt or wine, beer and weapons; returns True when the
    warehouses are full }
  F := P.Happiness;
  if P.Spell = 2 then
    F := R48Mul(F, RC($0081, $0000, $2000));
  Free := WarehouseFreeSpace(P);
  if DS.Game.GoodsTradeEnabled <> 0 then
  begin
    if DS.CountryProduct[P.Country] = 1 then
    begin
      V := R48Round(R48Mul(FromLong(P.Population div 25), F));
      if V > Free then V := Free;
      P.Salt := P.Salt + V;
    end
    else
    begin
      V := R48Round(R48Mul(FromLong(P.Population div SmallInt(320 - P.HarvestQuality * 20)), F));
      if V > Free then V := Free;
      P.Wine := P.Wine + V;
    end;
    if P.BrewBeer <> 0 then
    begin
      V := R48Round(R48Mul(FromLong(P.Grain div 100), F));
      if P.Population div 1000 < V then
        V := P.Population div 100;
      Free := WarehouseFreeSpace(P);
      if V > Free then V := Free;
      P.Beer := P.Beer + V;
      P.Grain := P.Grain - V * 100;
    end;
  end;
  V := MinLong(SmithyOutput(P), P.Smithies);
  if DS.Game.GoodsTradeEnabled <> 0 then
  begin
    Free := WarehouseFreeSpace(P);
    if V > Free then V := Free;
  end;
  P.Weapons := P.Weapons + V;
  Result := (P.Warehouses > 0) and (WarehouseFreeSpace(P) = 0);
end;

function BuildingsLostForLand(var P: TPlayer; var L: TLandLoss): Boolean;
var
  K: LongInt;

  { Lost := Count - K; if positive refund a fifth of the price }
  function Lose(Count: LongInt; var Lost: LongInt; Price: Byte): Boolean;
  begin
    Lost := Count - K;
    Result := Lost > 0;
    if Result then
      L.Total := L.Total + LongInt(Lost * DS.BuildingPrices[Price]) div 5
    else
      Lost := 0;
  end;

begin
  { every building needs 1000 of free (non-fief) land }
  K := LongInt(P.Land - P.LandUsed) div 1000;
  L.Total := 0;
  Result := False;
  if Lose(P.Markets, L.Markets, 0) then
  begin
    P.Markets := P.Markets - L.Markets;
    Result := True;
  end;
  if Lose(P.Mills, L.Mills, 1) then
  begin
    P.Mills := P.Mills - L.Mills;
    Result := True;
  end;
  L.PalaceParts := P.PalaceParts - K;
  if L.PalaceParts > 0 then
  begin
    if P.PalaceParts = 12 then
      LoseFame(P.Fame, 10);
    L.Total := L.Total + LongInt(L.PalaceParts * DS.BuildingPrices[2]) div 5;
    P.PalaceParts := Byte(P.PalaceParts - Byte(L.PalaceParts));
    Result := True;
  end
  else
    L.PalaceParts := 0;
  L.CathedralParts := P.CathedralParts - K;
  if L.CathedralParts > 0 then
  begin
    if P.CathedralParts = 12 then
      LoseFame(P.Fame, 20);
    L.Total := L.Total + LongInt(L.CathedralParts * DS.BuildingPrices[3]) div 5;
    P.CathedralParts := Byte(P.CathedralParts - Byte(L.CathedralParts));
    Result := True;
  end
  else
    L.CathedralParts := 0;
  if Lose(P.Granaries, L.Granaries, 4) then
  begin
    RemoveGranaries(P, L.Granaries);
    Result := True;
  end;
  if Lose(P.Warehouses, L.Warehouses, 5) then
  begin
    RemoveWarehouses(P, L.Warehouses);
    Result := True;
  end;
  if Lose(P.UniversityParts, L.UniversityParts, 6) then
  begin
    P.UniversityParts := Byte(P.UniversityParts - Byte(L.UniversityParts));
    Result := True;
  end;
  if Lose(P.Taverns, L.Taverns, 7) then
  begin
    P.Taverns := P.Taverns - L.Taverns;
    Result := True;
  end;
  if Lose(P.Smithies, L.Smithies, 8) then
  begin
    P.Smithies := P.Smithies - L.Smithies;
    Result := True;
  end;
end;

procedure UpdateMarketPrices(var Players: TPlayers; Me, NumPlayers: Byte; Unused: Word);
var
  P: PPlayer;
  U, U4: TReal48;
  R: LongInt;
begin
  P := @Players[Me];
  { land: scarce unclaimed land makes it expensive }
  U := R48Div(R48Div(FromLong(UnclaimedLand(Players, NumPlayers)), FromLong(NumPlayers)),
              RC($0091, $0000, $4350));                                      { / 100000 }
  R := Random(16);
  U4 := R48Mul(R48Mul(R48Mul(U, U), U), U);
  P^.LandPrice := MinLong(60, MaxLong(17,
    LongInt(R48Round(R48Div(RC($0081, 0, 0), R48Add(U4, RC($717A, $0A3D, $23D7)))) + 15 -
      FreeBuildingLand(P^) div 2000))) + R;
  R := Random(6);
  P^.PriceSalt := MaxLong(5, 10 - P^.Salt div 100) + R;
  R := Random(11);
  P^.PriceBeer := MaxLong(25, SmallInt((6 - P^.HarvestQuality) * 7 + 25) - P^.Beer div 50) + R;
  R := Random(11);
  P^.PriceWine := MaxLong(70, SmallInt((6 - P^.HarvestQuality) * 10 + 70) - P^.Wine div 50) + R;
  R := Random(41);
  P^.PriceWeapons := MaxLong(300, LongInt(560 - P^.Weapons * 2)) + R;
end;

procedure TransferLand(var From, Dest: TPlayer; var L: TLandLoss; Amount: LongInt;
  WithFiefs: Byte);
var
  Share: TReal48;
begin
  if Amount = 0 then
    Exit;
  Share := R48Div(FromLong(Amount), FromLong(From.Land));
  From.Land := From.Land - Amount;
  Dest.Land := Dest.Land + Amount;
  if WithFiefs <> 0 then
    From.LandUsed := From.LandUsed - R48Round(R48Mul(FromLong(From.LandUsed), Share));
  if BuildingsLostForLand(From, L) then
  begin
    { the receiver gets all but one of each lost market, mill, granary,
      warehouse (at most 30 warehouses) }
    Dest.Markets := Dest.Markets + MaxLong(0, L.Markets - 1);
    Dest.Mills := Dest.Mills + MaxLong(0, L.Mills - 1);
    Dest.Granaries := Dest.Granaries + MaxLong(0, L.Granaries - 1);
    Dest.Warehouses := Dest.Warehouses + MaxLong(0, L.Warehouses - 1);
    if Dest.Warehouses > 30 then
      Dest.Warehouses := 30;
    L.Total := L.Markets + L.Mills + L.Granaries + L.Warehouses;
  end
  else
    L.Total := 0;
end;

procedure SkipTurnLosses(var P: TPlayer; Mode: ShortInt);
var
  D: LongInt;

  { f * (1 + RandomReal): RandomReal is drawn first }
  function Loss: TReal48;
  var
    R: TReal48;
  begin
    R := R48Mul(RandomReal, DS.SkipTurnLoss[Mode]);
    Result := R48Add(DS.SkipTurnLoss[Mode], R);
  end;

begin
  ReduceByFraction(P.Land, Loss);
  if P.Land < 2000 then
    P.Land := 2000;
  D := R48Round(R48Mul(FromLong(P.Taler), Loss));
  P.Taler := P.Taler - D;
  P.TotalEventMoney := P.TotalEventMoney - D;
  ReduceByFraction(P.Population, Loss);
  if P.Population < 50 then
    P.Population := 50;
  if P.Markets > 0 then
    ReduceByFraction(P.Markets, Loss);
  if P.Mills > 0 then
    ReduceByFraction(P.Mills, Loss);
end;

{ Sabotage arrays are indexed by the target's player index; the 9-entry
  arrays overlap the next one for index 9 (never the player himself). }
function Funds(var P: TPlayer; T: Byte): PSmallInt; inline;
begin
  Result := @PSmallInt(@P.SabotageFunds)[T];
end;

function SabotageYearlyCost(const Players: TPlayers; Me, NumPlayers: Byte): LongInt;
var
  Others: array[0..15] of Byte;
  I, K, Last: Byte;
begin
  Result := 0;
  if Players[Me].Taverns <= 0 then
    Exit;
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
    Result := Result + SmallInt(Players[Me].SabotageBudget[Others[I]] * 100);
end;

procedure SabotageFunding(var Players: TPlayers; Me, NumPlayers: Byte);
var
  Others: array[0..15] of Byte;
  I, K, Last, T: Byte;
  Price, MaxBudget, Cost: Word;
  P: PPlayer;
begin
  { agents come back, the yearly budget is paid in, and every
    (target title + 1) * price Taler paid in buys one agent }
  if Players[Me].Spell = 1 then                        { Ambassador }
    Price := 700
  else
    Price := 1000;
  K := 0;
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    if I <> Me then
    begin
      Others[K] := I;
      Inc(K);
    end;
  P := @Players[Me];
  MaxBudget := (P^.Title + 1) * 5;
  Last := Byte(NumPlayers - 2);
  for I := 0 to Last do
  begin
    T := Others[I];
    P^.SabotageAgents[T] := Byte(P^.SabotageAgents[T] + P^.SabotageAgentsReturningQ[T]);
    P^.SabotageAgentsReturningQ[T] := 0;
    if P^.Taverns > 0 then
    begin
      if SmallInt(P^.SabotageBudget[T]) > SmallInt(MaxBudget) then
        P^.SabotageBudget[T] := Byte(MaxBudget);
      Funds(P^, T)^ := SmallInt(Funds(P^, T)^ + P^.SabotageBudget[T] * 100);
      P^.Taler := P^.Taler - SmallInt(P^.SabotageBudget[T] * 100);
      P^.TotalSabotage := P^.TotalSabotage - SmallInt(P^.SabotageBudget[T] * 100);
      Cost := Word((Players[T].Title + 1) * Price);
      if Funds(P^, T)^ >= SmallInt(Cost) then
      begin
        P^.SabotageAgents[T] := Byte(P^.SabotageAgents[T] + 1);
        Funds(P^, T)^ := SmallInt(Funds(P^, T)^ - Cost);
      end;
    end;
  end;
end;

function SabotageYearsToNextOp(const Players: TPlayers; var Me, Target: Byte): SmallInt;
var
  Price, C, B, F: TReal48;
begin
  if Players[Me].SabotageBudget[Target] = 0 then
    Exit(0);
  if Players[Me].Spell = 1 then
    Price := RC($008A, $0000, $2F00)                   { 700 }
  else
    Price := RC($008A, $0000, $7A00);                  { 1000 }
  C := R48Mul(FromLong(Players[Target].Title + 1), Price);
  B := FromLong(SmallInt(Players[Me].SabotageBudget[Target] * 100));
  F := FromLong(PSmallInt(@Players[Me].SabotageFunds)[Target]);
  Result := SmallInt(MaxLong(1, R48Round(R48Div(R48Sub(C, F), B))));
end;

{ ---- batch 4: units and armies ---- }

{ Units of both armies are indexed 1..Count like the original; the slot
  after the 8th (Pad321 / Pad546) is reachable with index 9, as there. }

procedure IntToPChar(Dest: PChar; V: LongInt);
var
  S: ShortString;
begin
  Str(V, S);
  StrPCopy(Dest, S);
end;

function UnitGainExperience(var U: TUnit; var Gains: THeroGains; XP, Spell: Byte): Boolean;
var
  MaxLevel: Byte;
begin
  { adds XP; at level*2 + 10 experience the unit rises one level and its
    type decides what improves. Heroes fill Gains for the dialog. }
  Result := False;
  if Spell = 9 then                                    { Heldentum }
    MaxLevel := 3
  else
    MaxLevel := 2;
  if (U.UnitType = 9) or (U.UnitType = $0D) then
    MaxLevel := 105;
  U.Experience := SmallInt(U.Experience + XP);
  if U.Level * 2 + 10 > U.Experience then
    Exit;
  if U.Level >= MaxLevel then
    Exit;
  case U.UnitType of
    $21, 1, 3, $23, $0F, 8, $0B, 7, $0C, $12, $14, $18, $1B, $1D, $1F, $22:
      begin
        Inc(U.MaxHp);
        if U.Level mod 2 = 0 then Inc(U.Attack) else Inc(U.Defence);
      end;
    2, 4, $17, $10:
      begin
        if U.Range < 6 then Inc(U.Range);
        if U.Level mod 2 = 0 then Inc(U.MaxHp) else Inc(U.Attack);
        Inc(U.MaxAmmo, 3);
      end;
    5, $19, $1E:
      begin
        Inc(U.MaxHp);
        if U.MaxSteps < 4 then Inc(U.MaxSteps) else Inc(U.Attack);
      end;
    6:
      begin
        if U.Range < 6 then Inc(U.Range) else Inc(U.MaxHp);
        Inc(U.MaxAmmo, 3);
      end;
    $1C:
      begin
        Inc(U.MaxHp);
        Inc(U.Attack);
      end;
    9:
      begin
        Result := True;
        StrCopy(Gains.Name, U.Name);
        Gains.Level := Byte(U.Level + 1);
        case U.Level of
          0..1:
            begin
              Gains.Attack := 1;
              Gains.Defence := 1;
              Gains.MaxHp := Random(2) + 1;
            end;
          2..5:
            begin
              Gains.Attack := 1;
              Gains.Defence := 0;
              Gains.MaxHp := 1;
            end;
          6..250:
            begin
              Gains.Attack := 0;
              Gains.Defence := 0;
              Gains.MaxHp := 1;
            end;
        end;
        Gains.Range := 0;
        Gains.Steps := 0;
        Gains.Ammo := 0;
        Inc(U.Attack, Gains.Attack);
        Inc(U.Defence, Gains.Defence);
        Inc(U.MaxHp, Gains.MaxHp);
        if (U.Level = 2) and (U.Ability <> 6) then
        begin
          Inc(U.MaxSteps);
          Inc(Gains.Steps);
        end;
        if (U.Ability = 5) and (U.Level = 0) then
        begin
          Inc(U.MaxSteps);
          Inc(Gains.Steps);
        end;
        if U.Ability = 8 then
        begin
          if (U.Level = 1) or (U.Level = 3) then
          begin
            Inc(U.Range);
            Inc(Gains.Range);
          end;
          if U.Level < 6 then
          begin
            Inc(U.MaxAmmo);
            Inc(Gains.Ammo);
          end;
        end;
        if (U.Level < 6) and (U.Ability = $11) then
        begin
          Inc(U.MaxAmmo);
          Inc(Gains.Ammo);
        end;
      end;
    $0D:
      begin
        if U.Level < 6 then
          if U.Level mod 2 = 0 then Inc(U.Attack) else Inc(U.Defence);
        Inc(U.MaxHp);
        if U.Range < 6 then Inc(U.Range);
        Inc(U.MaxAmmo);
      end;
    $0A:
      Inc(U.MaxHp);
    $16:
      begin
        Inc(U.Range, Random(3) + 1);
        if U.Range > 6 then U.Range := 6;
        Inc(U.Attack, Random(3) + 1);
        Inc(U.MaxAmmo, Random(3) + 1);
      end;
    $20:
      begin
        Inc(U.MaxHp);
        if U.MaxSteps < 2 then Inc(U.MaxSteps) else Inc(U.Attack);
      end;
    $0E:
      begin
        if U.Level mod 2 = 0 then Inc(U.MaxHp) else Inc(U.Attack);
        if U.MaxSteps < 2 then Inc(U.MaxSteps);
      end;
    $11:
      begin
        Inc(U.MaxHp);
        Inc(U.Range);
        if U.Range > 6 then U.Range := 6;
        if U.MaxSteps < 4 then Inc(U.MaxSteps);
        if U.Level mod 2 = 0 then Inc(U.Attack) else Inc(U.Defence);
        Inc(U.MaxAmmo);
      end;
    $13:
      begin
        if U.Level mod 2 = 0 then Inc(U.Attack) else Inc(U.Defence);
        if U.MaxSteps < 4 then Inc(U.MaxSteps) else Inc(U.Attack);
        Inc(U.MaxHp);
      end;
    $15:
      Inc(U.MaxAmmo, 2);
    $1A:
      begin
        if U.Range < 3 then Inc(U.Range) else Inc(U.Defence);
        Inc(U.MaxHp);
        Inc(U.Attack);
        Inc(U.MaxAmmo);
      end;
  end;
  if U.Range > 6 then
    U.Range := 6;
  U.Experience := SmallInt(U.Experience - (U.Level * 2 + 10));
  Inc(U.Level);
end;

procedure FillWithMilitia(var P: TPlayer);
var
  I: Byte;
begin
  { fill the Heer up to 8 units with militia, stronger with more people }
  for I := Byte(P.Army1Count + 1) to 8 do
    with P.Army1[I] do
    begin
      StrCopy(Name, DS.UnitNames[0]);
      UnitType := 0;
      Attack := Byte(P.Population div 3500 + DS.UnitAttack[0]);
      if Attack > 6 then Attack := 6;
      Defence := Byte(P.Population div 4500 + DS.UnitDefence[0]);
      if Defence > 6 then Defence := 6;
      MaxHp := Byte(P.Population div 3000 + ShortInt(DS.UnitHp[0]));
      if ShortInt(MaxHp) > 6 then MaxHp := 6;
      MaxSteps := DS.UnitSteps[0];
      MaxAmmo := DS.UnitAmmo[0];
      Level := 0;
      Experience := 0;
      Kills := 0;
      Ability := Byte(DS.UnitDefaultAbility[0]);
      Range := DS.UnitRange[0];
      Pay := DS.UnitPay[0];
      BasePay := Pay;
    end;
  P.Army1Count := 8;
end;

procedure GenerateMarauders(var P: TPlayer; Strength: SmallInt);
var
  I, N, Rank, Kind: Byte;
begin
  { a computer "player" with 3..8 raider units, stronger kinds for a
    higher Strength }
  FillChar(P, PlayerSize, 0);
  StrCopy(P.Name, DS.MaraudersName);
  Strength := Strength div 8;
  if Strength > 6 then
    N := 8
  else
    N := Random(Word(Strength)) + 3;
  if N > 8 then
    N := 8;
  P.Army1Count := N;
  P.Happiness := RC($0081, 0, 0);
  P.CpuLevel := 1;
  P.Title := 10;
  P.Population := 0;
  for I := 1 to N do
    with P.Army1[I] do
    begin
      Rank := Random(3) + 1;
      Kind := Random(Word(Strength)) + 1;
      if Kind > 9 then Kind := 9;
      UnitType := DS.RaiderType[Kind];
      Attack := Byte(Random(Rank) + DS.RaiderAttack[Kind]);
      Defence := Byte(Random(Rank) + DS.RaiderDefence[Kind]);
      MaxHp := Byte(Random(Rank) + DS.RaiderHp[Kind]);
      MaxAmmo := 0;
      Range := DS.RaiderRange[Kind];
      Level := Rank - 1;
      MaxSteps := DS.RaiderSteps[Kind];
      Ability := DS.RaiderAbility[Kind];
      StrCopy(Name, DS.AbilityNames[29 + Kind]);         { Diebe .. Raubritter }
      if Kind = 3 then
      begin
        Inc(Range, Rank - 1);
        Inc(MaxAmmo, Rank + 3);
      end;
      if Kind = 8 then
        case Random(5) of
          0: Ability := 9;
          1: Ability := 6;
          2: Ability := 3;
          3: Ability := 4;
          4: Ability := 7;
        end;
    end;
end;

procedure GenerateLindwurm(var P: TPlayer);
begin
  FillChar(P, PlayerSize, 0);
  StrCopy(P.Name, DS.LindwurmName);
  P.Happiness := RC($0081, 0, 0);
  P.CpuLevel := 1;
  P.Title := 10;
  P.Population := 0;
  RecruitUnit(P, 1, 12, 0);
end;

procedure ClearUnit(var U: TUnit);
begin
  FillChar(U, UnitSize, 0);
  U.UnitType := $FF;
end;

procedure RemoveArmy1Unit(var P: TPlayer; Index: Byte);
var
  I, Last: Byte;
begin
  ClearUnit(P.Army1[Index]);
  Last := Byte(P.Army1Count - 1);
  for I := Index to Last do
    Move(P.Army1[I + 1], P.Army1[I], UnitSize);
  Dec(P.Army1Count);
end;

procedure RemoveArmy2Unit(var P: TPlayer; Index: Byte);
var
  I, Last: Byte;
begin
  ClearUnit(P.Army2[Index]);
  Last := Byte(P.Army2Count - 1);
  for I := Index to Last do
    Move(P.Army2[I + 1], P.Army2[I], UnitSize);
  Dec(P.Army2Count);
end;

procedure RemoveMilitia(var P: TPlayer);
var
  I: Byte;
begin
  { militia stand at the end of the Heer: cut it off at the first one }
  I := 1;
  while (I <= P.Army1Count) and (P.Army1[I].UnitType <> 0) do
    Inc(I);
  if I <= P.Army1Count then
    P.Army1Count := I - 1;
end;

procedure SwapArmies(var P: TPlayer);
var
  I, N, C: Byte;
  Tmp: TUnit;
begin
  N := Byte(MinLong(P.Army1Count, P.Army2Count));
  for I := 1 to N do
  begin
    Tmp := P.Army1[I];
    P.Army1[I] := P.Army2[I];
    P.Army2[I] := Tmp;
  end;
  if P.Army1Count > P.Army2Count then
  begin
    for I := Byte(N + 1) to P.Army1Count do
      P.Army2[I] := P.Army1[I];
  end
  else
    for I := Byte(N + 1) to P.Army2Count do
      P.Army1[I] := P.Army2[I];
  C := P.Army1Count;
  P.Army1Count := P.Army2Count;
  P.Army2Count := C;
end;

procedure MakeUnitName(Dest: PChar; UnitType, Number, Country: Byte);
var
  Tmp: array[0..25] of Char;
begin
  { "<type>" or "<country adjective> Ritter", then "+<number>" }
  if UnitType = 7 then
  begin
    StrCopy(Dest, DS.CountryAdjectives[Country]);
    StrCat(Dest, DS.StrSpace);
    StrCat(Dest, DS.UnitNames[7]);
  end
  else
    StrCopy(Dest, DS.UnitNames[UnitType]);
  if Number > 0 then
  begin
    IntToPChar(Tmp, Number);
    StrCat(Dest, DS.StrPlusName);
    StrCat(Dest, Tmp);
  end;
end;

procedure RecruitUnit(var P: TPlayer; Army, UnitType, Bonus: Byte);
var
  NewU: TUnit;
  Gains: THeroGains;
  I: Byte;
begin
  { fields the original leaves uninitialised (hp, steps, ammo, motivation,
    position, ...) are 0 here }
  FillChar(NewU, SizeOf(NewU), 0);
  FillChar(Gains, SizeOf(Gains), 0);
  MakeUnitName(NewU.Name, UnitType, Bonus, P.Country);
  NewU.UnitType := UnitType;
  NewU.HeroPortrait := Bonus;
  NewU.Attack := DS.UnitAttack[UnitType];
  NewU.Defence := DS.UnitDefence[UnitType];
  NewU.MaxHp := DS.UnitHp[UnitType];
  NewU.MaxSteps := DS.UnitSteps[UnitType];
  NewU.MaxAmmo := DS.UnitAmmo[UnitType];
  NewU.Range := DS.UnitRange[UnitType];
  NewU.Pay := SmallInt(FameDiscount(P.Fame, DS.UnitPay[UnitType]) * (Bonus + 1));
  NewU.BasePay := NewU.Pay;
  if (P.Spell = $0C) and (UnitType = $12) then         { Terror }
    NewU.Pay := NewU.Pay div 3;
  NewU.Experience := 0;
  if UnitType = $0C then                               { Lindwurm }
    NewU.Level := 6
  else
    NewU.Level := 0;
  NewU.Kills := 0;
  NewU.UnconsciousRounds := 1;
  NewU.Ability := Byte(DS.UnitDefaultAbility[UnitType]);
  if UnitType = 8 then                                 { Kreuzritter }
    case Random(3) of
      0: NewU.Ability := 7;
      1: NewU.Ability := 4;
      2: NewU.Ability := 9;
    end;
  { as in the original, the bonus ranks go to the last unit of the Heer
    (every caller passes 0) }
  for I := 1 to Bonus do
  begin
    UnitGainExperience(P.Army1[P.Army1Count], Gains, 10, 0);
    NewU.Level := 0;
    NewU.Experience := 0;
  end;
  if P.Spell = 9 then                                  { Heldentum }
    UnitGainExperience(NewU, Gains, 10, P.Spell);
  if Army = 1 then
  begin
    Inc(P.Army1Count);
    P.Army1[P.Army1Count] := NewU;
  end
  else
  begin
    Inc(P.Army2Count);
    P.Army2[P.Army2Count] := NewU;
  end;
end;

procedure InitAvenger(var U: TUnit);
begin
  { the Reisiger Raecher (type 13) }
  MakeUnitName(U.Name, $0D, 0, 0);
  U.UnitType := $0D;
  U.HeroPortrait := 0;
  U.Attack := DS.UnitAttack[$0D];
  U.Defence := DS.UnitDefence[$0D];
  U.MaxHp := DS.UnitHp[$0D];
  U.MaxSteps := DS.UnitSteps[$0D];
  U.MaxAmmo := DS.UnitAmmo[$0D];
  U.Range := DS.UnitRange[$0D];
  U.Pay := 0;
  U.BasePay := U.Pay;
  U.Experience := 0;
  U.Level := 0;
  U.Kills := 0;
  U.UnconsciousRounds := 1;
  U.Ability := Byte(DS.UnitDefaultAbility[$0D]);
end;

function AvengerJoinsWeaker(var A, B: TPlayer; var U: TUnit): Word;
var
  ScoreA, ScoreB, StrA, StrB: LongInt;
  Side: SmallInt;
begin
  { the avenger joins a player who has less than 2/3 of the other's score
    and army strength. The original never sets its result (0 here). }
  Result := 0;
  Side := -1;
  ScoreA := ComputeScore(A, 0, 0);
  ScoreB := ComputeScore(B, 0, 0);
  StrA := ArmyStrength(A, 1);
  StrB := ArmyStrength(B, 1);
  if (LongInt(ScoreB - ScoreB div 3) > ScoreA) and (LongInt(StrB - StrB div 3) > StrA) then
    Side := 1
  else if (LongInt(ScoreA - ScoreA div 3) > ScoreB) and (LongInt(StrA - StrA div 3) > StrB) then
    Side := 0;
  if Side > -1 then
    if Side = 0 then
    begin
      if B.Army1Count < 8 then
        AddUnitToArmy(B, 1, U)
      else if B.Army2Count < 8 then
        AddUnitToArmy(B, 2, U);
    end
    else if A.Army1Count < 8 then
      AddUnitToArmy(A, 1, U);
end;

procedure AvengerLeaves(var A, B: TPlayer; var U: TUnit);
var
  I: Byte;
  Found: Boolean;
begin
  { take the avenger out of B's Heer or Garde or A's Heer into U, or make
    a new one }
  Found := False;
  I := 0;
  while (I < B.Army1Count) and not Found do
  begin
    Inc(I);
    Found := B.Army1[I].UnitType = $0D;
  end;
  if Found then
  begin
    U := B.Army1[I];
    RemoveArmy1Unit(B, I);
    Exit;
  end;
  I := 0;
  while (I < B.Army2Count) and not Found do
  begin
    Inc(I);
    Found := B.Army2[I].UnitType = $0D;
  end;
  if Found then
  begin
    U := B.Army2[I];
    RemoveArmy2Unit(B, I);
    Exit;
  end;
  I := 0;
  while (I < A.Army1Count) and not Found do
  begin
    Inc(I);
    Found := A.Army1[I].UnitType = $0D;
  end;
  if Found then
  begin
    U := A.Army1[I];
    RemoveArmy1Unit(A, I);
  end
  else
    InitAvenger(U);
end;

procedure InitUnit(var P: TPlayer; var U: TUnit; UnitType, Bonus: Byte);
var
  Gains: THeroGains;
  I: Byte;
begin
  FillChar(Gains, SizeOf(Gains), 0);
  MakeUnitName(U.Name, UnitType, Bonus, P.Country);
  U.UnitType := UnitType;
  U.HeroPortrait := Bonus;
  U.Attack := DS.UnitAttack[UnitType];
  U.Defence := DS.UnitDefence[UnitType];
  U.MaxHp := DS.UnitHp[UnitType];
  U.MaxSteps := DS.UnitSteps[UnitType];
  U.MaxAmmo := DS.UnitAmmo[UnitType];
  U.Range := DS.UnitRange[UnitType];
  U.Pay := SmallInt(FameDiscount(P.Fame, DS.UnitPay[UnitType]) * (Bonus + 1));
  if (P.Spell = $0C) and (UnitType = $12) then
    U.Pay := U.Pay div 3;
  U.BasePay := U.Pay;
  U.Experience := 0;
  U.Level := 0;
  U.Kills := 0;
  U.UnconsciousRounds := 1;
  U.Ability := Byte(DS.UnitDefaultAbility[UnitType]);
  { bonus ranks raise the values but the level stays 0 }
  for I := 1 to Bonus do
  begin
    UnitGainExperience(U, Gains, 10, 0);
    U.Level := 0;
    U.Experience := 0;
  end;
end;

procedure AddUnitToArmy(var P: TPlayer; Army: Byte; var U: TUnit);
var
  Gains: THeroGains;
begin
  FillChar(Gains, SizeOf(Gains), 0);
  if P.Spell = 9 then
    UnitGainExperience(U, Gains, 10, P.Spell);
  if Army = 1 then
  begin
    Inc(P.Army1Count);
    P.Army1[P.Army1Count] := U;
  end
  else
  begin
    Inc(P.Army2Count);
    P.Army2[P.Army2Count] := U;
  end;
end;

procedure KnightSquire(var P: TPlayer; var U: TUnit);
var
  Gains: THeroGains;
  Pay: LongInt;
begin
  { a Knappe becomes a Ritter for 5000 Taler and keeps double his pay }
  FillChar(Gains, SizeOf(Gains), 0);
  Pay := SmallInt(U.Pay shl 1);
  InitUnit(P, U, 7, U.HeroPortrait);
  U.Pay := SmallInt(Pay);
  U.BasePay := SmallInt(Pay);
  P.Taler := P.Taler - 5000;
  P.TotalRecruiting := P.TotalRecruiting - 5000;
  GainFame(P.Fame, 1);
  if P.Spell = 9 then
    UnitGainExperience(U, Gains, 10, P.Spell);
end;

{ SortUnits/UnitLess are local routines of the original (near calls) }
function UnitLess(const A, B: TUnit; Mode: Byte): Boolean;  { 1068:5d18 }
begin
  Result := False;
  case Mode of
    1: Result := A.Attack + A.Defence < B.Attack + B.Defence;
    3: Result := ShortInt(A.MaxHp) < ShortInt(B.MaxHp);
    2: Result := A.Level < B.Level;
    4: Result := A.Kills < B.Kills;
  end;
end;

procedure SortUnits(Units: PUnit; Count, Mode: Byte);       { 1068:5db8 }
var
  I, J: Byte;
  Tmp: TUnit;
begin
  { insertion sort, strongest first; Units points to unit 1 }
  for I := 2 to Count do
  begin
    J := I;
    Tmp := Units[I - 1];
    while (J > 1) and UnitLess(Units[J - 2], Tmp, Mode) do
    begin
      Units[J - 1] := Units[J - 2];
      Dec(J);
    end;
    Units[J - 1] := Tmp;
  end;
end;

procedure SortArmy(var P: TPlayer; Army: Byte);
begin
  { sorts only when both armies have units, as the original }
  if (P.Army1Count < 1) or (P.Army2Count < 1) then
    Exit;
  if Army = 1 then
  begin
    SortUnits(@P.Army1[1], P.Army1Count, 3);
    SortUnits(@P.Army1[1], P.Army1Count, 1);
  end
  else
  begin
    SortUnits(@P.Army2[1], P.Army2Count, 3);
    SortUnits(@P.Army2[1], P.Army2Count, 1);
  end;
end;

procedure CreateHero(var U: TUnit; Name: PChar);
var
  K: Byte;
  Buf: array[0..25] of Char;
begin
  { a random hero kind 1..18 decides the ability and stat changes; without
    a name a random one from string resources 101..320 }
  FillChar(Buf, SizeOf(Buf), 0);
  U.UnitType := 9;
  K := Random(18) + 1;
  U.HeroPortrait := K;
  if Name = nil then
  begin
    LoadString(Random(220) + 101, Buf, 16);
    StrCopy(U.Name, Buf);
  end
  else
    StrCopy(U.Name, Name);
  U.Attack := DS.UnitAttack[9];
  U.Defence := DS.UnitDefence[9];
  U.MaxHp := DS.UnitHp[9];
  U.MaxSteps := DS.UnitSteps[9];
  U.Range := DS.UnitRange[9];
  U.MaxAmmo := DS.UnitAmmo[9];
  U.Level := 0;
  U.Experience := 0;
  U.Kills := 0;
  U.Pay := 0;
  U.BasePay := 0;
  case K of
    1: U.Ability := $15;
    2: begin U.Ability := 1; Inc(U.Attack, 2); end;
    3: begin U.Ability := 3; Dec(U.Attack, 2); end;
    4: begin U.Ability := 5; Inc(U.Defence); end;
    5: U.Ability := $12;
    6: begin U.Ability := 2; Inc(U.Defence, 2); end;
    7: begin U.Ability := 6; Dec(U.Attack, 2); end;
    8: begin U.Ability := 7; Dec(U.Defence); Dec(U.MaxHp, 2); end;
    9: begin U.Ability := $10; Inc(U.MaxHp); end;
    10: U.Ability := 9;
    11: begin U.Ability := 4; Inc(U.Defence); end;
    12: begin U.Ability := 8; Inc(U.Range); Dec(U.Attack); Inc(U.MaxAmmo); end;
    13: begin U.Ability := $0F; Dec(U.Defence); end;
    14: begin U.Ability := $11; Dec(U.Defence); Dec(U.Attack); Dec(U.MaxHp, 2); Inc(U.MaxAmmo, 2); end;
    15: begin U.Ability := $13; Dec(U.Defence); end;
    16: begin U.Ability := $16; Dec(U.Attack); end;
    17: U.Ability := $18;
    18: U.Ability := $1B;
  end;
end;

procedure HeroRankName(Level: Byte; Dest: PChar);
var
  Tmp: array[0..11] of Char;
begin
  if Level <= 6 then
    StrCopy(Dest, DS.RankNames[4 + Level])
  else
  begin
    Level := Byte(Level - 6);
    StrCopy(Dest, DS.RankNames[10]);                   { Halbgott }
    StrCat(Dest, DS.StrPlusHero);
    IntToPChar(Tmp, Level);
    StrCat(Dest, Tmp);
  end;
end;

function RandomMercenaryType(const P: TPlayer): Byte;
begin
  { a random mercenary type 14..35 the player's title allows }
  repeat
    Result := Random(22) + 14;
  until DS.UnitTitleNeeded[Result] <= P.Title;
end;

procedure UnitRankName(const U: TUnit; Dest: PChar);
var
  Tmp: array[0..11] of Char;
begin
  if (U.UnitType = 9) or ((U.UnitType >= $0C) and (U.UnitType <= $0D)) then
  begin
    if U.Level <= 6 then
      StrCopy(Dest, DS.RankNames[4 + U.Level])
    else
    begin
      StrCopy(Dest, DS.RankNames[10]);
      StrCat(Dest, DS.StrPlusRank);
      IntToPChar(Tmp, Byte(U.Level - 6));
      StrCat(Dest, Tmp);
    end;
  end
  else
    StrCopy(Dest, DS.RankNames[U.Level]);
end;

procedure RaiderVictoryReward(var P: TPlayer; Kind: Byte);
var
  Reward: LongInt;
  I: Byte;
begin
  { 1: bandits, (1000 + Random(1500)) * title Taler; 2: the Lindwurm,
    100000 Taler, 20 fame and +3 defence for the Heer }
  Reward := 0;                     { other kinds: uninitialised in the original }
  if Kind = 1 then
    Reward := Word(P.Title * (Random(1500) + 1000))
  else if Kind = 2 then
  begin
    Reward := 100000;
    GainFame(P.Fame, 20);
    for I := 1 to P.Army1Count do
      Inc(P.Army1[I].Defence, 3);
  end;
  P.EventMoney := P.EventMoney + Reward;
  P.Event := 0;
end;

procedure MakeVampire(var Dest: TUnit; const Src: TUnit);
begin
  Dest := Src;
  StrCopy(Dest.Name, DS.UnitNames[10]);                { Vampire }
  Dest.UnitType := $0A;
  Dest.Level := 0;
  Dest.Experience := 0;
  Dest.Hp := Dest.MaxHp;
  Dest.Range := 1;
  Dest.Steps := 0;
  Dest.Ammo := 0;
  Dest.MaxAmmo := 0;
  Dest.Pay := 0;
  Dest.BasePay := 0;
  Dest.BlindRounds := 0;
  Dest.UnconsciousRounds := 0;
  Dest.Ability := Byte(DS.UnitDefaultAbility[10]);
end;

{ ---- batch 5: game setup, sabotage, texts ---- }

procedure CreateComputerPlayers(var Players: TPlayers; NumHumans, NumCpu,
  Difficulty: Byte);
var
  Free: array[0..15] of Byte;
  K, C, I, R, T, Last: Byte;
  Used: Boolean;
begin
  { computer players get the countries no human took, in random order }
  FillChar(Free, SizeOf(Free), 0);
  K := 0;
  for C := 0 to 9 do
  begin
    Used := False;
    Last := Byte(NumHumans - 1);
    for I := 0 to Last do
      if Players[I].Country = C then
        Used := True;
    if not Used then
    begin
      Free[K] := C;
      Inc(K);
    end;
  end;
  Last := Byte(K - 1);
  for I := 0 to Last do
  begin
    R := Random(K);
    T := Free[I];
    Free[I] := Free[R];
    Free[R] := T;
  end;
  Last := Byte(NumHumans + NumCpu - 1);
  for I := NumHumans to Last do
  begin
    FillChar(Players[I], PlayerSize, 0);
    case Difficulty of
      1: Players[I].CpuLevel := Random(2) + 5;         { Dorftrottel }
      2: Players[I].CpuLevel := Random(2) + 3;
      3: Players[I].CpuLevel := Random(2) + 1;
      4: Players[I].CpuLevel := 1;                     { Absolutist }
    end;
    Players[I].Country := Free[I - NumHumans];
  end;
end;

procedure InitPlayers(var Players: TPlayers; NumPlayers, Difficulty: Byte);
var
  I, J, R, Last, N: Byte;
  Tmp: TPlayer;
begin
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    with Players[I] do
    begin
      if CpuLevel = 0 then
      begin
        { humans; with the census editor on, the names "Alchimisten" and
          "Berserker" start as Koenig with 999000 Taler }
        if (DS.Game.CensusEditorEnabled <> 0) and
           ((StrIComp(Name, DS.UnitNames[22]) = 0) or (StrIComp(Name, DS.UnitNames[28]) = 0)) then
        begin
          Title := 9;
          Taler := 999000;
        end
        else
        begin
          Title := 0;
          Taler := 1000;
        end;
        Land := 10000;
        Population := 1000;
        ReportFlags := $27;
      end
      else
      begin
        StrCopy(Name, DS.CpuRulerNames[Country]);
        Spell := Random(12) + 1;
        IsFemale := 0;
        SkipTurn := 0;
        BrewBeer := DS.Game.GoodsTradeEnabled;
        if Difficulty = 4 then                         { Absolutist: strong start }
        begin
          Title := 7;
          Markets := 25;
          Mills := 25;
          Taler := 10000;
          Land := 30000;
          Population := 3000;
          Fame := 70;
        end
        else
        begin
          Title := 0;
          Taler := 1000;
          Land := 10000;
          Population := 1000;
          Fame := 0;
        end;
      end;
      AiAggressionQ := Random(6) + 1;
      TotalEventMoney := 1000;
      BirthRate := RC($717A, $0A3D, $23D7);            { 0.01 }
      DeathRate := RC($717A, $0A3D, $23D7);
      Happiness := RC($0081, 0, 0);
      TaxRate := RC($CD7D, $CCCC, $4CCC);              { 0.1 }
      Justice := RC($717D, $0A3D, $23D7);              { 0.08 }
      AsylumLaw := RC($1480, $47AE, $7AE1);            { 0.98 }
      Grain := 5000;
      LandPrice := Random(15) + 17;
      GrainPrice := Random(100) + 20;
      Granaries := 1;
      if DS.Game.GoodsTradeEnabled <> 0 then
        Warehouses := 1;
      Weapons := 2;
      SkipTurn := 0;
      for J := 0 to Last do
        PSmallInt(@AttitudeQ)[J] := 100;
      Lifetime := Random(20) + 60;
    end;
  { shuffle the order of the first human_players entries }
  N := DS.Game.HumanPlayers;
  Last := Byte(N - 1);
  for I := 0 to Last do
  begin
    R := Random(N);
    if R <> I then
    begin
      Tmp := Players[I];
      Players[I] := Players[R];
      Players[R] := Tmp;
    end;
  end;
end;

procedure InitComputerRuler(var Players: TPlayers; Index: Byte);
begin
  { a new computer ruler after the old one died }
  with Players[Index] do
  begin
    StrCopy(Name, DS.CpuRulerNames[Country]);
    AiAggressionQ := Random(6) + 1;
    Spell := Random(12) + 1;
    BrewBeer := DS.Game.GoodsTradeEnabled;
    Title := 0;
    CpuLevel := Random(6) + 1;
    IsFemale := 0;
    Fame := 0;
    Lifetime := Random(30) + 50;
  end;
end;

function SabotageAction(var Players: TPlayers; Unused, Me, Target, Kind: Byte;
  var Amount: LongInt; var Caught: Byte): Boolean;
var
  T: PPlayer;
  Hero: PUnit;
  Flags: PLongInt;
  Pct: SmallInt;
  I: Byte;
begin
  { one sabotage strike of Me against Target (kinds: docs/rules/diplomacy.md).
    Flags at +0x5bd are handled as a longint, as in the original. }
  Result := False;
  Caught := 0;
  Amount := 0;
  T := @Players[Target];
  Flags := PLongInt(@T^.Flags5bdQ);
  Hero := nil;
  case Kind of
    1: Result := T^.Mills > 10;
    2: Result := T^.PalaceParts > 1;
    3: Result := T^.Warehouses > 0;
    4: Result := True;
    7: if (Flags^ and $40) = 0 then Result := True;
    8: if (Flags^ and $80) = 0 then Result := True;
    9: if (T^.Title > 0) and ((Flags^ and $100) = 0) then Result := True;
    5, 6:
      begin
        if (T^.Army1Count > 0) and (T^.ArmyAway = 0) and HasDesertableUnit(T^, 0) then
          Result := True;
        if Players[Me].Army2Count > 8 then
          Kind := 5;                         { no room in the own Garde }
      end;
    $0A: if (Flags^ and $200) = 0 then Result := True;
    $0B:
      if FindHero(T^, Hero, 1) and ((Flags^ and $400) = 0) and (ShortInt(Hero^.MaxHp) > 5) then
        Result := True;
    $0C: if (Flags^ and $800) = 0 then Result := True;
    $0D: if (Flags^ and $1000) = 0 then Result := T^.Taler > 5000;
    $0E: if (Flags^ and $2000) = 0 then Result := T^.Taler > 1000;
  end;
  Pct := SmallInt(DS.SabotageChance[Kind] - R48Round(R48Mul(T^.Justice, RC($0087, 0, $4800))));
  if Pct < 1 then
    Pct := 1;
  Result := Result and Chance(Pct);
  Caught := Ord(Chance(Pct));
  if Result then
  begin
    case Kind of
      1:
        begin
          Amount := T^.Mills div 10;
          if T^.Spell = $0A then
            Amount := LongInt(Random(2) + 1) * Amount
          else
            Amount := LongInt(Random(3) + 1) * Amount;
          T^.Mills := T^.Mills - Amount;
        end;
      2:
        begin
          if T^.Spell = $0A then
            Amount := MinLong(T^.PalaceParts, Random(3) + 1)
          else
            Amount := MinLong(T^.PalaceParts, Random(5) + 1);
          T^.PalaceParts := Byte(T^.PalaceParts - Byte(Amount));
        end;
      3:
        begin
          Amount := 1;
          RemoveWarehouses(T^, Amount);
        end;
      4:
        begin
          { experience lost, except for ability 9 }
          for I := 1 to T^.Army1Count do
            if T^.Army1[I].Ability <> 9 then
              T^.Army1[I].Experience := 0;
          for I := 1 to T^.Army2Count do
            if T^.Army2[I].Ability <> 9 then
              T^.Army2[I].Experience := 0;
        end;
      7: Flags^ := Flags^ + $40;
      8: Flags^ := Flags^ + $80;
      9:
        begin
          Flags^ := Flags^ + $100;
          LoseFame(T^.Fame, Random(5) + 3);
        end;
      5, 6:
        begin
          { a random unit deserts (6: to the attacker's Garde) }
          repeat
            I := Random(T^.Army1Count) + 1;
          until DS.UnitCanDesert[ShortInt(T^.Army1[I].UnitType)] <> 0;
          Amount := ShortInt(T^.Army1[I].UnitType);
          if Kind = 6 then
          begin
            Inc(Players[Me].Army2Count);
            Players[Me].Army2[Players[Me].Army2Count] := T^.Army1[I];
          end;
          RemoveArmy1Unit(T^, I);
          Inc(T^.DesertedUnits);
        end;
      $0A: Flags^ := Flags^ + $200;
      $0B:
        begin
          case Random(4) of
            0:
              begin
                if Hero^.Attack > 7 then Dec(Hero^.Attack);
                Dec(Hero^.MaxHp);
              end;
            1:
              begin
                if Hero^.Defence > 7 then Dec(Hero^.Defence);
                Dec(Hero^.MaxHp);
              end;
            2:
              begin
                if Hero^.MaxSteps > 2 then Dec(Hero^.MaxSteps);
                Hero^.Steps := Hero^.MaxSteps;
                Dec(Hero^.MaxHp);
              end;
            3: Dec(Hero^.MaxHp, 2);
          end;
          Hero^.Hp := Hero^.MaxHp;
        end;
      $0C: Flags^ := Flags^ + $800;
      $0D:
        begin
          Flags^ := Flags^ + $1000;
          Amount := T^.Taler div (Random(6) + 5);
        end;
      $0E:
        begin
          Flags^ := Flags^ + $2000;
          Amount := T^.Taler div (Random(16) + 15);
          Players[Me].Taler := Players[Me].Taler + Amount;
          Players[Me].TotalSabotage := Players[Me].TotalSabotage + Amount;
        end;
    end;
    LogSabotageReport(Players, Unused, Me, Target, Kind, Amount);
  end;
  if Caught <> 0 then
  begin
    LogSabotageReport(Players, Unused, Me, Target, 0, 0);
    Inc(Players[Me].SabotageAgentsReturningQ[Target]);
  end;
  Dec(Players[Me].SabotageAgents[Target]);
end;

function Distance(X1, Y1, X2, Y2: SmallInt): Word;
begin
  { 16-bit squares as the original; a negative wrapped sum fails in Sqrt }
  Result := Word(R48Round(R48Sqrt(FromLong(SmallInt((Y1 - Y2) * (Y1 - Y2) + (X1 - X2) * (X1 - X2))))));
end;

procedure ClearHighScores(var Tables);
begin
  FillChar(Tables, $ABE, 0);       { 5 tables x 11 entries x 50 bytes }
end;

procedure SortHighScoreTable(var Table);
type
  TEntry = array[0..49] of Byte;   { score: longint at +0x2a }
  TTable = array[0..10] of TEntry;
var
  T: TTable absolute Table;
  Tmp: TEntry;
  I, J, Best: Byte;
begin
  for I := 0 to 9 do
  begin
    Tmp := T[I];
    Best := I;
    for J := I + 1 to 10 do
      if PLongInt(@T[J][$2A])^ > PLongInt(@Tmp[$2A])^ then
      begin
        Tmp := T[J];
        Best := J;
      end;
    T[Best] := T[I];
    T[I] := Tmp;
  end;
end;

procedure ClearMailboxSlot(var Slot);
begin
  FillChar(Slot, 6, 0);
end;

procedure AddNews(var Players: TPlayers; NumPlayers, Actor, Target, Kind: Byte);
var
  I, Last, N: Byte;
begin
  { tell everyone except actor and target (gossip report) }
  Last := Byte(NumPlayers - 1);
  for I := 0 to Last do
    with Players[I] do
      if (I <> Actor) and (I <> Target) and (NewsCount < 10) then
      begin
        Inc(NewsCount);
        N := NewsCount;
        PByte(@News)[3 * N - 3] := Actor;
        PByte(@News)[3 * N - 2] := Target;
        PByte(@News)[3 * N - 1] := Kind;
      end;
end;

procedure LogSabotageReport(var Players: TPlayers; Unused, Attacker, Target, Kind: Byte;
  Amount: LongInt);
var
  N: Byte;
begin
  with Players[Target] do
    if SabotageLogCount < 15 then
    begin
      Inc(SabotageLogCount);
      N := SabotageLogCount;
      SabotageLog[6 * N - 6] := Attacker;
      SabotageLog[6 * N - 5] := Kind;
      PLongInt(@SabotageLog[6 * N - 4])^ := Amount;
    end;
end;

procedure FormatPercent(Dest: PChar; Part, Total: LongInt);
begin
  if Total = 0 then
    StrCopy(Dest, DSText($42EE))                       { '0%' }
  else
  begin
    IntToPChar(Dest, R48Round(R48Mul(R48Div(FromLong(Part), FromLong(Total)),
      RC($0087, 0, $4800))));
    StrCat(Dest, DSText($42EF));                       { '%' }
  end;
end;

procedure FormatThousands(Dest: PChar; V: LongInt);
var
  Digits: array[0..13] of Char;
  Grouped: array[0..13] of Char;
  Len, OutLen, Count, I, K: SmallInt;
begin
  { digits in groups of three separated by ',' and a leading '-' }
  if V < 0 then
    IntToPChar(Digits, LongInt(-V))
  else
    IntToPChar(Digits, V);
  StrCopy(Grouped, DSText($4304));                     { '' }
  StrCopy(Dest, DSText($4304));
  Len := StrLen(Digits);
  if Len = 0 then
    Exit;
  OutLen := PSmallInt(@PByte(@DS)[$42F0 + 2 * Len])^;  { length with separators }
  Count := 0;
  I := Len - 1;
  K := OutLen - 1;
  repeat
    Inc(Count);
    if Count > 3 then
    begin
      Grouped[K] := ',';
      Dec(K);
      Count := 1;
    end;
    Grouped[K] := Digits[I];
    Dec(K);
    Dec(I);
  until I = -1;
  Grouped[OutLen] := #0;
  if V < 0 then
    StrCat(Dest, DSText($4305));                       { '-' }
  StrCat(Dest, Grouped);
end;

procedure BuildingProgressText(Dest: PChar; Parts: Byte);
begin
  case Parts of
    1..3: StrCopy(Dest, DSText($4308));                { Grundstein }
    4..8: StrCopy(Dest, DSText($4313));                { in Bau }
    9..11: StrCopy(Dest, DSText($431A));               { bald fertig }
    12: StrCopy(Dest, DSText($4326));                  { vollendet }
  else
    StrCopy(Dest, DSText($4330));                      { - }
  end;
end;

procedure RealmName(Dest: PChar; Land: LongInt);
begin
  { by the land needed for the titles 10, 9, 7, 5, 2 }
  if Land >= DS.PromotionLand[10] then
    StrCopy(Dest, DSText($4332))                       { Kaiserreich }
  else if Land >= DS.PromotionLand[9] then
    StrCopy(Dest, DSText($433E))                       { Koenigreich }
  else if Land >= DS.PromotionLand[7] then
    StrCopy(Dest, DSText($4349))                       { Fuerstentum }
  else if Land >= DS.PromotionLand[5] then
    StrCopy(Dest, DSText($4354))                       { Herzogtum }
  else if Land >= DS.PromotionLand[2] then
    StrCopy(Dest, DSText($435E))                       { Grafschaft }
  else
    StrCopy(Dest, DSText($4369));                      { Landstrich }
end;

procedure FameText(Dest: PChar; Fame: Byte);
begin
  case Fame of
    0..19: StrCopy(Dest, DSText($4374));               { inexistent }
    20..39: StrCopy(Dest, DSText($437F));              { windig }
    40..59: StrCopy(Dest, DSText($4386));              { bekannt }
    60..79: StrCopy(Dest, DSText($438E));              { angesehen }
    80..94: StrCopy(Dest, DSText($4398));              { ehrwuerdig }
    95..100: StrCopy(Dest, DSText($43A2));             { legendaer }
  end;
end;

procedure MagnitudeText(Dest: PChar; V: LongInt);
begin
  if V >= 1000000 then
    StrCopy(Dest, DSText($43AC))                       { Millionen }
  else if V >= 100000 then
    StrCopy(Dest, DSText($43B6))                       { Hunderttausende }
  else if V >= 10000 then
    StrCopy(Dest, DSText($43C6))                       { Zehntausende }
  else if V >= 1000 then
    StrCopy(Dest, DSText($43D3))                       { Tausende }
  else if V >= 100 then
    StrCopy(Dest, DSText($43DC))                       { Hunderte }
  else
    StrCopy(Dest, DSText($43E5));                      { - }
end;

end.
