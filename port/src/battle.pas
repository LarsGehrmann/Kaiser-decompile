{ The tactical battle (segment 10, BattleWnd 1048:xxxx): the state of the
  battle window (TBattleWnd, laid out like the original object) and its
  logic, ported in the original order of operations. Drawing and the
  message handlers go through KaiserUI. Differential tests:
  port/tests/ruletest.pas (bw= / bwdiff=). }
unit Battle;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  KaiserTypes, KaiserDS, KaiserMaps, Real48, Rules, KaiserUI;

{ unit I (1..8) of side S: side 0 = defender, 1 = attacker }
function BattleUnit(var B: TBattleWnd; S, I: Byte): PUnit; inline;

procedure LoadMapData(var Dest; N: Byte);                   { 1050:1212 }
procedure BattleInit(var B: TBattleWnd; Parent: Pointer; Name: PChar;
  var Attacker, Defender: TPlayer; Mode, City: Byte);       { 1048:0002 }
procedure InitMorale(var B: TBattleWnd);                    { 1048:0966 }
function OtherSide(var B: TBattleWnd): Byte;                { 1048:345c }
function IsInCity(var B: TBattleWnd; const U: TUnit): Boolean;  { 1048:347c }
function IsThreatened(var B: TBattleWnd; S, I: Byte): Boolean;  { 1048:34b7 }
function HeroShouldFlee(var B: TBattleWnd): Boolean;        { 1048:35d8 }
function AnyUnitInMelee(var B: TBattleWnd): Boolean;        { 1048:366e }
function CountAdjacentEnemies(var B: TBattleWnd; S, I: Byte): Byte;  { 1048:36c6 }
function HasAdjacentFriendOfType(var B: TBattleWnd; S, I, UnitType: Byte): Boolean;  { 1048:37c1 }
function InBounds(var B: TBattleWnd; X, Y: SmallInt): Boolean;  { 1048:390b }
function StrengthBalance(var B: TBattleWnd; S: Byte): TReal48;  { 1048:3938 }
{ the drawing of the battle window (UI calls) }
procedure DrawCell(var B: TBattleWnd; X, Y: SmallInt; Code: Byte);   { 1048:2803 }
procedure RedrawUnit(var B: TBattleWnd; S, I: Byte);                { 1048:6192 }
procedure DrawUnitStatus(var B: TBattleWnd; DC: Word; S, I, Panel: Byte);  { 1048:1a60 }
procedure ClearTargetPanel(var B: TBattleWnd);                       { 1048:196c }
procedure EnableButtons(var B: TBattleWnd);                          { 1048:0daa }
procedure DisableButtons(var B: TBattleWnd);                         { 1048:0dde }
procedure PlaySound(N: Word);                                        { 1070:0002 }
{ EndDlg(code): the battle stops after the current message; the last code
  counts (BattleEndCode) }
procedure EndBattle(var B: TBattleWnd; Code: Byte);                  { 1048:8ff5 }

procedure ComputeMotivation(var B: TBattleWnd; var U: TUnit; S: Byte);  { 1048:3ae4 }
procedure RefreshUnitCodes(var B: TBattleWnd; S: Byte);     { 1048:3cd6 }
function CanMoveTo(var B: TBattleWnd; X, Y: SmallInt): Boolean;  { 1048:3d78 }
function CanAttack(var B: TBattleWnd; X, Y: SmallInt): Boolean;  { 1048:455c }
function CanHeal(var B: TBattleWnd; X, Y: SmallInt): Boolean;    { 1048:5b56 }
procedure HealUnit(var B: TBattleWnd; var Healer, Patient: TUnit);  { 1048:5c60 }
procedure DoHeal(var B: TBattleWnd; HX, HY, TX, TY: SmallInt);   { 1048:5cce }
function MoreThanOneActive(var B: TBattleWnd): Boolean;          { 1048:8c19 }
function NextUnit(var B: TBattleWnd): Byte;                      { 1048:8f08 }
procedure Duel(var B: TBattleWnd; var A, D: TUnit; EnPassant, Surrounded, Knappen: Boolean);  { 1048:4944 }
function AttackUnit(var B: TBattleWnd; S, I: Byte; TX, TY: SmallInt; EnPassant: Boolean): Boolean;  { 1048:5055 }
function AttackObject(var B: TBattleWnd; X, Y: SmallInt): Boolean;  { 1048:54ed }
procedure MoveUnit(var B: TBattleWnd; X, Y: SmallInt);           { 1048:3fc0 }
procedure DesertionCheck(var B: TBattleWnd);                     { 1048:5dc0 }
function AiShouldRetreat(var B: TBattleWnd): Boolean;           { 1048:84ad }
procedure AiChooseStance(var B: TBattleWnd);                     { 1048:808b }
{ AI targets: True and the cell of the target if there is one }
function AiFindEnemyHero(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:6d1d }
function AiFirstEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;     { 1048:6e0b }
function AiLastEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;      { 1048:6e7d }
function AiFindHelplessEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:6f36 }
function AiFindFastEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:704d }
function AiFindWeakestEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:714c }
function AiFindMostWoundedFriend(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:7274 }
function AiFindEnemyWithAbility(var B: TBattleWnd; var X, Y: SmallInt; Ability: Byte): Boolean;  { 1048:73a3 }
function AiFindHealingEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:7493 }
function AiPickWallTarget(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:7581 }
function AiPickAdjacentBuilding(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:760d }
function AiChooseTarget(var B: TBattleWnd; var X, Y: SmallInt): Boolean;  { 1048:7725 }
procedure AiNearestEnemy(var B: TBattleWnd; FX, FY: SmallInt; var X, Y: SmallInt);  { 1048:7a1b }
function AiStepToward(var B: TBattleWnd; FX, FY, TX, TY: SmallInt; var X, Y: SmallInt): Boolean;  { 1048:7b12 }
function AiTryAttack(var B: TBattleWnd): Boolean;               { 1048:7d3d }
procedure AiMove(var B: TBattleWnd);                             { 1048:81a3 }
{ the window timer: start delay, the blinking cursor of a human, the AI }
procedure BattleSetupWindow(var B: TBattleWnd);                  { 1048:0bc3 }
procedure StartTimer(var B: TBattleWnd);                         { 1048:983f }
procedure StopTimer(var B: TBattleWnd);                          { 1048:986a }
procedure WMTimer(var B: TBattleWnd);                            { 1048:96d1 }
procedure AiStep(var B: TBattleWnd);                             { 1048:65a8 }
procedure GetResults(var B: TBattleWnd; var Attacker, Defender: TPlayer; var Results);  { 1048:0e12 }
procedure NextSide(var B: TBattleWnd);   { the other side's turn (AiStep, EndAction) }
{ the human side }
procedure EndAction(var B: TBattleWnd);                          { 1048:631a }
procedure CmWarten(var B: TBattleWnd);                           { 1048:98ab }
procedure CmFertig(var B: TBattleWnd);                           { 1048:9931 }
procedure CmAufgeben(var B: TBattleWnd);                         { 1048:9967 }
procedure CombatOptionsMenu(var B: TBattleWnd; I: Byte);         { 1048:8c92 }
{ a click at pixel (PX, PY) of the window }
procedure WMLButtonDown(var B: TBattleWnd; PX, PY: Word);        { 1048:900d }
{ a right click: the WinHelp topic (0: none) or the combat options of an
  own unit }
function WMRButtonDown(var B: TBattleWnd; PX, PY: Word): LongInt;  { 1048:9525 }
function AiChooseAggressive(var B: TBattleWnd): Boolean;    { 1048:68fe }
function AiEnemyOutguns(var B: TBattleWnd): Boolean;        { 1048:69d4 }
procedure StartSideTurn(var B: TBattleWnd; S: Byte);        { 1048:85e0 }
procedure ResetSide(var B: TBattleWnd; S: Byte);            { 1048:8ac4 }

var
  BattleEndCode: Byte;      { the code of the last EndBattle, 0 while it runs }

implementation

type
  PReal48 = ^TReal48;

function BattleUnit(var B: TBattleWnd; S, I: Byte): PUnit;
begin
  Result := @B.Side[S].Army1[I];
end;

procedure DrawCell(var B: TBattleWnd; X, Y: SmallInt; Code: Byte);
begin
  UI.Call('Battle_DrawCell', [AWord(X), AWord(Y), AByte(Code), APtr(@B)]);
end;

procedure RedrawUnit(var B: TBattleWnd; S, I: Byte);
begin
  UI.Call('Battle_RedrawUnit', [AByte(S), AByte(I), APtr(@B)]);
end;

procedure DrawUnitStatus(var B: TBattleWnd; DC: Word; S, I, Panel: Byte);
begin
  { the panel shows the motivation, so it is recomputed first }
  UI.Call('Battle_DrawUnitStatus', [AWord(DC), AByte(S), AByte(I), AByte(Panel), APtr(@B)]);
  if B.Side[S].Army1Count >= I then
    ComputeMotivation(B, BattleUnit(B, S, I)^, S);
end;

procedure ClearTargetPanel(var B: TBattleWnd);
begin
  UI.Call('Battle_ClearTargetPanel', [APtr(@B)]);
end;

procedure EnableButtons(var B: TBattleWnd);
begin
  UI.Call('Battle_EnableButtons', [APtr(@B)]);
end;

procedure DisableButtons(var B: TBattleWnd);
begin
  UI.Call('Battle_DisableButtons', [APtr(@B)]);
end;

procedure PlaySound(N: Word);
begin
  UI.Call('PlaySound', [AWord(N), AWord(0)]);
end;

procedure EndBattle(var B: TBattleWnd; Code: Byte);
begin
  UI.Call('Battle_End', [AByte(Code), APtr(@B)]);
  BattleEndCode := Code;
end;

function FromLong(V: LongInt): TReal48; inline;
begin
  Result := R48FromLong(V);
end;

{ the grid cell of a position (16-bit offset arithmetic like the original) }
function Cell(X, Y: SmallInt): Word; inline;
begin
  Result := Word(SmallInt(X * 11) + Y);
end;

procedure LoadMapData(var Dest; N: Byte);
begin
  { MAPDATA resource N + 1 (the original stops with an error box when it is
    missing; 1..20 exist) }
  if (N + 1 >= Low(MapData)) and (N + 1 <= High(MapData)) then
    Move(MapData[N + 1], Dest, SizeOf(TBattleMap));
end;

procedure InitMorale(var B: TBattleWnd);
begin
  { side morale = happiness + fame / 300; fear of Terror; Heilende Haende;
    Entertainer. (Called before Init sets the winter and the mode: both are
    still 0 here, so the winter bonus to the fear never applies and the map
    is always the defender's country.) }
  UpdateBirthDeathRates(B.Side[0]);
  UpdateHappiness(B.Side[0]);
  B.SideMorale[0] := R48Add(R48Div(FromLong(B.Side[0].Fame), RC($0089, 0, $1600)),
    B.Side[0].Happiness);
  B.HealingHands[0] := Ord(B.Side[0].Spell = 8);
  B.Entertainer[0] := Ord(Army1HasAbility(B.Side[0], $12));
  if (B.Side[1].Spell = 12) and (B.Side[0].Spell <> 12) then
    B.Fear[0] := RC($CD7E, $CCCC, $4CCC)
  else
    B.Fear[0] := R48Zero;
  B.Human[0] := Ord(B.Side[0].CpuLevel = 0);
  UpdateBirthDeathRates(B.Side[1]);
  UpdateHappiness(B.Side[1]);
  B.SideMorale[1] := R48Add(R48Div(FromLong(B.Side[1].Fame), RC($0089, 0, $1600)),
    B.Side[1].Happiness);
  B.SideMorale[1] := R48Add(R48Div(FromLong(B.Side[1].Fame), RC($0089, 0, $1600)),
    B.Side[1].Happiness);                   { (computed twice) }
  if (B.Side[0].Spell = 12) and (B.Side[1].Spell <> 12) then
    B.Fear[1] := RC($CD7E, $CCCC, $4CCC)
  else
    B.Fear[1] := R48Zero;
  if B.Winter <> 0 then
    B.Fear[1] := R48Add(B.Fear[1], RC($CD7E, $CCCC, $4CCC));
  B.HealingHands[1] := Ord(B.Side[1].Spell = 8);
  B.Entertainer[1] := Ord(Army1HasAbility(B.Side[1], $12));
  B.Human[1] := Ord(B.Side[1].CpuLevel = 0);
  if B.Mode = 0 then
    B.MapCountry := B.Side[0].Country
  else
    B.MapCountry := B.Side[1].Country;
end;

function OtherSide(var B: TBattleWnd): Byte;
begin
  Result := Byte(SmallInt(B.SideToMove + 1) mod 2);
end;

function IsInCity(var B: TBattleWnd; const U: TUnit): Boolean;
begin
  { inside the walls: x 11..13, y 4..6 (the low bytes of the position) }
  Result := (B.City <> 0) and (Byte(U.PosX) >= 11) and (Byte(U.PosX) <= 13) and
    (Byte(U.PosY) >= 4) and (Byte(U.PosY) <= 6);
end;

function IsThreatened(var B: TBattleWnd; S, I: Byte): Boolean;
var
  Enemy, K, D: Byte;
  U, E: PUnit;
begin
  { an enemy next to unit I of side S, or one that can shoot at it (range
    and ammo); the first enemy is looked at even when there is none }
  K := 1;
  Result := False;
  Enemy := Byte(SmallInt(S + 1) mod 2);
  U := BattleUnit(B, S, I);
  repeat
    E := BattleUnit(B, Enemy, K);
    D := Byte(Distance(U^.PosX, U^.PosY, E^.PosX, E^.PosY));
    if (D = 1) or ((E^.Range >= D) and (E^.Ammo > 0)) then
      Result := True;
    Inc(K);
  until Result or (B.Side[Enemy].Army1Count < K);
end;

function HeroShouldFlee(var B: TBattleWnd): Boolean;
var
  U: PUnit;
begin
  { below 20 % of the hit points and threatened }
  Result := False;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if R48Cmp(R48Div(FromLong(ShortInt(U^.Hp)), FromLong(ShortInt(U^.MaxHp))),
     RC($CD7E, $CCCC, $4CCC)) < 0 then
    Result := IsThreatened(B, B.SideToMove, B.UnitToMove);
end;

function AnyUnitInMelee(var B: TBattleWnd): Boolean;
var
  K: Byte;
begin
  { a unit of the side to move has an enemy next to it (the first unit is
    looked at even when there is none) }
  Result := False;
  K := 1;
  repeat
    if CountAdjacentEnemies(B, B.SideToMove, K) > 0 then
      Result := True;
    Inc(K);
  until Result or (B.Side[B.SideToMove].Army1Count < K);
end;

function CountAdjacentEnemies(var B: TBattleWnd; S, I: Byte): Byte;
var
  Enemy, K, Last: Byte;
  U, E: PUnit;
begin
  { melee-capable enemies next to unit I of side S }
  Result := 0;
  if S = 1 then
    Enemy := 0
  else
    Enemy := 1;
  U := BattleUnit(B, S, I);
  Last := B.Side[Enemy].Army1Count;
  for K := 1 to Last do
  begin
    E := BattleUnit(B, Enemy, K);
    if (PByte(@DS.UnitMelee)[ShortInt(E^.UnitType)] <> 0) and
       (Distance(U^.PosX, U^.PosY, E^.PosX, E^.PosY) = 1) then
      Inc(Result);
  end;
end;

function HasAdjacentFriendOfType(var B: TBattleWnd; S, I, UnitType: Byte): Boolean;
var
  K: Byte;
  U, F: PUnit;
begin
  { a conscious, active unit of the type next to unit I of side S }
  Result := False;
  K := 1;
  U := BattleUnit(B, S, I);
  while (B.Side[S].Army1Count >= K) and not Result do
  begin
    F := BattleUnit(B, S, K);
    Result := (SmallInt(ShortInt(F^.UnitType)) = UnitType) and (F^.UnconsciousRounds = 0) and
      (F^.Stance = 0) and (Distance(U^.PosX, U^.PosY, F^.PosX, F^.PosY) = 1);
    Inc(K);
  end;
end;

function InBounds(var B: TBattleWnd; X, Y: SmallInt): Boolean;
begin
  { (column 0 and row 0 count as outside) }
  Result := (X > 0) and (X < 15) and (Y > 0) and (Y < 11);
end;

function StrengthBalance(var B: TBattleWnd; S: Byte): TReal48;
var
  S0, S1: TReal48;
  I, Last: Byte;
  U: PUnit;
begin
  { (own - enemy) / (own + enemy), attack + defence of all units }
  S1 := R48Zero;
  S0 := R48Zero;
  Last := B.Side[1].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 1, I);
    S1 := R48Add(R48Add(FromLong(U^.Attack), S1), FromLong(U^.Defence));
  end;
  Last := B.Side[0].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 0, I);
    S0 := R48Add(R48Add(FromLong(U^.Attack), S0), FromLong(U^.Defence));
  end;
  Result := R48Div(R48Sub(S1, S0), R48Add(S1, S0));
  if (S <> 1) and (Result[0] <> 0) then
    Result[5] := Result[5] xor $80;
end;

procedure ComputeMotivation(var B: TBattleWnd; var U: TUnit; S: Byte);
var
  PayTerm, FearTerm, TypeBonus, LevelTerm, Balance, M: TReal48;
begin
  { side morale + strength balance + level / 10 + type bonus - fear
    + pay / base pay - 1 (+ 0.25 with an Entertainer), clamped to 0.5..1.1 }
  if U.Pay > 0 then
    PayTerm := R48Sub(R48Div(FromLong(U.Pay), FromLong(U.BasePay)), RC($0081, 0, 0))
  else
    PayTerm := R48Zero;
  FearTerm := R48Mul(B.Fear[S], FromLong(PByte(@DS.UnitFearful)[ShortInt(U.UnitType)]));
  TypeBonus := PReal48(@DS.UnitMotivationBonus)[ShortInt(U.UnitType)];
  LevelTerm := R48Div(FromLong(U.Level), RC($0084, 0, $2000));
  Balance := StrengthBalance(B, S);
  M := R48Add(B.SideMorale[S], Balance);
  M := R48Add(M, LevelTerm);
  M := R48Add(M, TypeBonus);
  M := R48Sub(M, FearTerm);
  U.Motivation := R48Add(M, PayTerm);
  if B.Entertainer[S] <> 0 then
    U.Motivation := R48Add(U.Motivation, RC($007F, 0, 0));
  if R48Cmp(U.Motivation, RC($0080, 0, 0)) < 0 then
    U.Motivation := RC($0080, 0, 0);
  if R48Cmp(U.Motivation, RC($CD81, $CCCC, $0CCC)) > 0 then
    U.Motivation := RC($CD81, $CCCC, $0CCC);
end;

procedure RefreshUnitCodes(var B: TBattleWnd; S: Byte);
var
  I, Last: Byte;
  U: PUnit;
begin
  { the units of side S into the occupancy grid }
  if B.Side[S].Army1Count < 1 then
    Exit;
  Last := B.Side[S].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, S, I);
    B.Grid[Cell(U^.PosX, U^.PosY)] := Byte(DS.BattleSideCode[S] + I);
  end;
end;

{ trees, and rivers in winter, for a Schwimmer (23) or a rough-terrain type }
function MoverCrosses(var B: TBattleWnd; Code: Byte): Boolean;
var
  U: PUnit;
begin
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (Code = 8) or (Code = 9) then
    Result := PByte(@DS.UnitRoughTerrain)[ShortInt(U^.UnitType)] <> 0
  else if (Code >= $33) and (Code <= $40) then
    Result := (B.Winter <> 0) or (U^.Ability = $17) or
      (PByte(@DS.UnitRoughTerrain)[ShortInt(U^.UnitType)] <> 0)
  else
    Result := False;
end;

function CanMoveTo(var B: TBattleWnd; X, Y: SmallInt): Boolean;
var
  U: PUnit;
  Code: Byte;
begin
  { a neighbouring cell on the map: free ground, trees and rivers as the
    unit allows, for the defender also its own buildings }
  Result := False;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (Distance(U^.PosX, U^.PosY, X, Y) > 1) or (X < 0) or (X > 14) or (Y < 0) or (Y > 10) then
    Exit;
  Code := B.Grid[Cell(X, Y)];
  if Code = 0 then
    Result := True
  else if (B.SideToMove <> 1) and (((Code >= 2) and (Code <= 7)) or ((Code >= $0B) and (Code <= $0D))) then
    Result := True
  else
    Result := MoverCrosses(B, Code);
end;

function CanAttack(var B: TBattleWnd; X, Y: SmallInt): Boolean;
var
  U: PUnit;
  D: SmallInt;
  Adjacent, Shot: Boolean;
  Code: Byte;
begin
  { an enemy unit (melee next to it, else within range with ammo), a
    building (the attacker only), a wall (Sprengpulver with ammo, or
    Demontage, within range), a tree (Demontage within range) }
  Result := False;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  D := SmallInt(Distance(U^.PosX, U^.PosY, X, Y));
  Adjacent := D = 1;
  Shot := (SmallInt(U^.Range) >= D) and (U^.Ammo > 0);
  Code := B.Grid[Cell(X, Y)];
  if (Code = 8) or (Code = 9) then
    Result := (U^.Ability = $19) and (SmallInt(U^.Range) >= D)
  else if ((Code >= 2) and (Code <= 7)) or ((Code >= $0B) and (Code <= $0D)) then
  begin
    if B.SideToMove = 1 then
      if Adjacent then
        Result := PByte(@DS.UnitMelee)[ShortInt(U^.UnitType)] <> 0
      else
        Result := Shot;
  end
  else if (Code >= $5B) and (Code <= $63) then
  begin
    if SmallInt(U^.Range) >= D then
      if U^.Ability = $0A then
        Result := U^.Ammo > 0
      else if U^.Ability = $19 then
        Result := True;
  end
  else if ((Code >= $6F) and (Code <= $76) and (B.SideToMove = 0)) or
          ((Code >= $79) and (Code <= $80) and (B.SideToMove = 1)) then
  begin
    if Adjacent then
      Result := (PByte(@DS.UnitMelee)[ShortInt(U^.UnitType)] <> 0) or (U^.Ammo > 0)
    else
      Result := Shot;
  end;
end;

function CanHeal(var B: TBattleWnd; X, Y: SmallInt): Boolean;
var
  U: PUnit;
  Code: Byte;
begin
  { Heilkraefte (17) with ammo, the target an own unit at distance <= 1 }
  Result := False;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (U^.Ability <> $11) or (U^.Ammo = 0) then
    Exit;
  if SmallInt(Distance(U^.PosX, U^.PosY, X, Y)) > 1 then
    Exit;
  Code := B.Grid[Cell(X, Y)];
  if B.SideToMove = 1 then
    Result := (Code >= $6F) and (Code <= $76)
  else if B.SideToMove = 0 then
    Result := (Code >= $79) and (Code <= $80);
end;

procedure HealUnit(var B: TBattleWnd; var Healer, Patient: TUnit);
var
  Amount, Lvl: Byte;
begin
  { 1..level+1 hit points (none for a Vampire), blindness and knock-out
    cured; the healer's turn ends and it uses one charge }
  if Patient.UnitType = $0A then
    Amount := 0
  else
  begin
    Lvl := Healer.Level;
    if Lvl > 3 then
      Lvl := 3;
    Amount := Byte(Random(Lvl + 1) + 1);
  end;
  Patient.Hp := Byte(Patient.Hp + Amount);
  Patient.BlindRounds := 0;
  Patient.UnconsciousRounds := 0;
  if ShortInt(Patient.Hp) > ShortInt(Patient.MaxHp) then
    Patient.Hp := Patient.MaxHp;
  Healer.Steps := 0;
  Dec(Healer.Ammo);
end;

procedure DoHeal(var B: TBattleWnd; HX, HY, TX, TY: SmallInt);
var
  Frame, Base: Word;
begin
  { the healer at (HX, HY) turns to the patient at (TX, TY) }
  if B.SideToMove = 1 then
  begin
    if TX < HX then
      Frame := $AA
    else
      Frame := $82;
    Base := $6E;
  end
  else
  begin
    if TX > HX then
      Frame := $B4
    else
      Frame := $8C;
    Base := $78;
  end;
  DrawCell(B, HX, HY, Byte(B.UnitToMove + Frame));
  PlaySound($19);
  HealUnit(B, BattleUnit(B, B.SideToMove, B.UnitToMove)^,
    BattleUnit(B, B.SideToMove, Byte(B.Grid[Cell(TX, TY)] - Base))^);
  DrawCell(B, HX, HY, B.Grid[Cell(HX, HY)]);
end;

procedure Duel(var B: TBattleWnd; var A, D: TUnit; EnPassant, Surrounded, Knappen: Boolean);
const
  Two: TReal48 = ($82, 0, 0, 0, 0, 0);
var
  Dist: SmallInt;
  AInCity, DInCity: Boolean;
  LvlA, LvlD, RollA, RollD, Damage: Byte;
  Atk, Def, M: TReal48;
begin
  { A strikes D (docs/rules/battle.md 7.2/7.3) }
  Dist := SmallInt(Distance(A.PosX, A.PosY, D.PosX, D.PosY));
  AInCity := IsInCity(B, A);
  DInCity := IsInCity(B, D);
  LvlA := A.Level;
  if LvlA > 3 then
    LvlA := 3;
  LvlD := D.Level;
  if LvlD > 3 then
    LvlD := 3;
  { effective attack and defence }
  Atk := FromLong(A.Attack);
  Def := FromLong(D.Defence);
  Atk := R48Mul(Atk, A.Motivation);
  if A.BlindRounds > 0 then
    Atk := R48Div(Atk, FromLong(A.BlindRounds + 1));
  if D.BlindRounds > 0 then
    Def := R48Div(Def, FromLong(D.BlindRounds + 1));
  if D.UnconsciousRounds > 0 then
    Def := R48Div(Def, Two);
  if (DInCity and not AInCity) or (D.Stance = 1) then
    Def := R48Mul(Def, Two);
  if (Dist > 1) and (D.Ability = 4) then                      { Drachenschild }
    Atk := R48Div(Atk, Two);
  if (A.Ability = $0E) and (ShortInt(A.Hp) < ShortInt(A.MaxHp)) then   { Raserei }
    Atk := R48Mul(Atk, Two);
  if (D.Ability = $10) and (PByte(@DS.UnitCharmable)[ShortInt(A.UnitType)] <> 0) then  { Charme }
    Atk := R48Div(Atk, Two);
  if (A.Ability = $13) and (PByte(@DS.UnitChristian)[ShortInt(D.UnitType)] = 0) then  { Heilige Lanze }
    Atk := R48Mul(Atk, RC($0081, 0, $4000));
  if Surrounded then
    Def := R48Div(Def, Two);
  if D.Stance = 2 then
    Def := R48Div(Def, Two);
  if Knappen then
    Atk := R48Add(Atk, RC($0081, 0, 0));
  if not DInCity and (D.Ability = $1D) and (Dist > 1) then     { Camouflage }
    Def := R48Mul(Def, Two);
  { the hit }
  RollA := Byte(Random(Word(R48Round(R48Add(Atk, RC($0081, 0, 0))))));
  RollD := Byte(Random(Word(R48Round(R48Add(Def, RC($0081, 0, 0))))));
  if (B.Human[0] <> 0) and Chance(50) then
    RollA := Byte(RollA * 2);
  if (A.Ability = 8) and (Dist > 1) then
    PlaySound(6)
  else if (A.Range > 1) and (Dist = 1) and (PByte(@DS.UnitMelee)[ShortInt(A.UnitType)] <> 0) then
    PlaySound($12)
  else
    PlaySound(PByte(@DS.UnitAttackSound)[ShortInt(A.UnitType)]);
  if RollA >= RollD then
  begin
    PlaySound(4);
    M := R48Div(FromLong(A.Attack), RC($0082, 0, $4000));
    if D.UnconsciousRounds > 0 then
      M := R48Mul(M, Two);
    D.UnconsciousRounds := 0;
    D.Stance := 0;
    if A.Ability = 3 then                                      { Vergiftete Klinge }
      if (Random(10 - LvlA) = 0) and (D.Ability <> 9) then
        M := RC($0086, 0, $4800);
    if ((A.Ability = $0A) or (A.Ability = $1A)) and (D.Ability <> 9) then
      if Random(6 - LvlA) = 0 then                             { blinding }
        D.BlindRounds := ShortInt(D.BlindRounds + Byte(LvlA + 3 - LvlD));
    if D.Ability <> 9 then
      if Random(LvlD + 12 - LvlA) = 0 then                     { knock-out }
        D.UnconsciousRounds := ShortInt(Random(6 - LvlD) + 1);
    if (A.Ability = $0F) and (D.Ability <> 9) then             { Morgenstern }
      if Random(6 - LvlA) = 0 then
        D.UnconsciousRounds := ShortInt(D.UnconsciousRounds + Byte(LvlA + 4 - LvlD));
    if (A.Ability = $13) and (D.UnitType = $0A) then
      M := R48Mul(M, Two);
    if A.Ability = $0E then
      if (Random(5 - LvlA) = 0) and (D.Ability <> 9) then
        M := R48Mul(M, Two);
    if (Dist > 1) and (A.Ability = $0C) then                  { Armbrust }
      M := R48Mul(M, Two);
    if (A.Ability = 1) and (D.UnitType = $0C) then             { Drachentoeter }
      M := R48Mul(M, RC($0082, 0, $4000));
    if (D.Ability = 4) and (A.UnitType = $0C) then
      M := R48Div(M, Two);
    Damage := Byte(Random(Word(R48Round(M))) + 1);
    if (B.Human[0] <> 0) and Chance(50) then
      Damage := Byte(R48Round(M));
    D.Hp := Byte(D.Hp - Damage);
  end;
  { the cost }
  if not EnPassant then
  begin
    if (A.Ability = 6) or (A.Ability = $0B) then
      Dec(A.Steps)
    else if A.Ability = $16 then                               { Finesse }
    begin
      if Random(2) = 0 then
        A.Steps := 0
      else if R48Round(Atk) < R48Round(Def) * 4 then
        A.Steps := 0;
    end
    else
      A.Steps := 0;
  end;
  if Dist > 1 then
    Dec(A.Ammo);
end;

function AttackUnit(var B: TBattleWnd; S, I: Byte; TX, TY: SmallInt; EnPassant: Boolean): Boolean;
var
  A, D: PUnit;
  Enemy, EI: Byte;
  Frame, OwnBase, EnemyBase: Word;
  Surrounded, Knappen: Boolean;
begin
  { unit I of side S strikes the enemy at (TX, TY); True if it dies }
  A := BattleUnit(B, S, I);
  Enemy := Byte(SmallInt(S + 1) mod 2);
  if S = 1 then
  begin
    if TX < A^.PosX then
      Frame := $AA
    else
      Frame := $82;
    OwnBase := $6E;
    EnemyBase := $78;
  end
  else
  begin
    if TX > A^.PosX then
      Frame := $B4
    else
      Frame := $8C;
    OwnBase := $78;
    EnemyBase := $6E;
  end;
  EI := Byte(B.Grid[Cell(TX, TY)] - EnemyBase);
  DrawCell(B, A^.PosX, A^.PosY, Byte(I + Frame));
  D := BattleUnit(B, Enemy, EI);
  Surrounded := CountAdjacentEnemies(B, Enemy, EI) > 3;
  Knappen := (PByte(@DS.UnitKnight)[ShortInt(A^.UnitType)] <> 0) and HasAdjacentFriendOfType(B, S, I, $22);
  Duel(B, A^, D^, EnPassant, Surrounded, Knappen);
  RedrawUnit(B, B.SideToMove, B.UnitToMove);
  if ShortInt(D^.Hp) > 0 then
  begin
    RedrawUnit(B, Enemy, EI);
    Exit(False);
  end;
  { killed }
  Inc(A^.Kills);
  Inc(A^.Experience);
  Inc(B.Side[S].EnemyUnitsKilled);
  Inc(B.Side[Enemy].OwnUnitsKilled);
  if Enemy = 1 then
    Inc(B.Results[$36])
  else
    Inc(B.Results[$35]);
  if D^.Ability = $12 then
    B.Entertainer[Enemy] := 0;
  if (A^.UnitType = $0A) and (B.Side[S].Army1Count < 8) and (D^.UnitType <> $0A) and
     (D^.Ability <> 9) then
  begin
    { Infektion: the victim rises as a Vampire of the attacker }
    PlaySound($14);
    Inc(B.Side[S].Army1Count);
    MakeVampire(BattleUnit(B, S, B.Side[S].Army1Count)^, D^);
    B.Grid[Cell(TX, TY)] := Byte(B.Side[S].Army1Count + OwnBase);
    DrawCell(B, TX, TY, B.Grid[Cell(TX, TY)]);
  end
  else
  begin
    DrawCell(B, TX, TY, $0A);
    PlaySound(PByte(@DS.UnitDeathSound)[ShortInt(D^.UnitType)]);
    DrawCell(B, TX, TY, B.Terrain[Cell(TX, TY)]);
    B.Grid[Cell(TX, TY)] := B.Terrain[Cell(TX, TY)];
  end;
  RemoveArmy1Unit(B.Side[Enemy], EI);
  RefreshUnitCodes(B, Enemy);
  Result := True;
end;

{ results counter (longint) at offset Off of the results block }
function ResultCounter(var B: TBattleWnd; Off: Byte): PLongInt; inline;
begin
  Result := PLongInt(@B.Results[Off]);
end;

function AttackObject(var B: TBattleWnd; X, Y: SmallInt): Boolean;
var
  U: PUnit;
  Dist: SmallInt;
  Code, Roll: Byte;
  Gone: Boolean;
begin
  { the current unit attacks a building, wall or tree (battle.md 7.5);
    True if it is destroyed }
  Result := False;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  Dist := SmallInt(Distance(X, Y, U^.PosX, U^.PosY));
  Code := B.Grid[Cell(X, Y)];
  if (Code >= $5B) and (Code <= $63) then
    Code := 1;                                 { a wall }
  if X < U^.PosX then
    DrawCell(B, U^.PosX, U^.PosY, Byte(B.UnitToMove + $AA))
  else
    DrawCell(B, U^.PosX, U^.PosY, Byte(B.UnitToMove + $82));
  if (U^.Ability = 8) and (Dist > 1) then
    PlaySound(6)
  else if (U^.Range > 1) and (Dist = 1) then
    PlaySound($12)
  else
    PlaySound(PByte(@DS.UnitAttackSound)[ShortInt(U^.UnitType)]);
  Roll := Byte(Random(U^.Attack));
  if U^.BlindRounds > 0 then
    Roll := Roll shr 1;
  if (Dist > 1) and (U^.Ability = $14) then                   { Pechpfeile }
    Roll := Byte(Roll * 3);
  if (Roll >= Random(DS.BattleHardness[Code])) or (U^.Ability = $19) or (U^.Ability = $1A) then
  begin
    PlaySound($0B);
    Result := True;
    Gone := True;
    case Code of
      1, 8, 9: ;
      2: Inc(ResultCounter(B, $08)^);
      3: Inc(ResultCounter(B, $0C)^);
      4:
        begin
          Inc(ResultCounter(B, $10)^);
          Gone := LongInt(B.Side[0].PalaceParts) - ResultCounter(B, $10)^ = 0;
        end;
      5:
        begin
          Inc(ResultCounter(B, $14)^);
          Gone := LongInt(B.Side[0].CathedralParts) - ResultCounter(B, $14)^ = 0;
        end;
      6: Inc(ResultCounter(B, $18)^);
      7: Inc(ResultCounter(B, $1C)^);
      $0B: Inc(ResultCounter(B, $20)^);
      $0C: Inc(ResultCounter(B, $24)^);
      $0D: Inc(ResultCounter(B, $28)^);
    else
      Gone := False;
    end;
    if Gone then
    begin
      B.Grid[Cell(X, Y)] := 0;
      B.Terrain[Cell(X, Y)] := 0;
      DrawCell(B, X, Y, 0);
    end;
  end;
  RedrawUnit(B, B.SideToMove, B.UnitToMove);
  if (U^.Ability = 6) or (U^.Ability = $0B) then
    Dec(U^.Steps)
  else
    U^.Steps := 0;
  if Dist > 1 then
    Dec(U^.Ammo);
end;

procedure MoveUnit(var B: TBattleWnd; X, Y: SmallInt);
var
  U, E: PUnit;
  OX, OY, NX, NY: SmallInt;
  K: SmallInt;
  Mirror, Killed, Strike: Boolean;
  FrameBase, OwnBase: Word;
  EnemyBase, Code, EI: Byte;
  EnemyLo, EnemyHi: Byte;
begin
  { one step of the current unit to (X, Y); first every active, conscious,
    melee-capable enemy next to the start cell strikes (en passant) }
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  OX := U^.PosX;
  OY := U^.PosY;
  if B.SideToMove = 1 then
  begin
    Mirror := X < OX;
    FrameBase := $96;
    OwnBase := $6E;
    EnemyBase := $78;
    EnemyLo := $79;
    EnemyHi := $80;
  end
  else
  begin
    FrameBase := $A0;
    Mirror := X > OX;
    OwnBase := $78;
    EnemyBase := $6E;
    EnemyLo := $6F;
    EnemyHi := $76;
  end;
  if B.CursorShown = 0 then
    WMTimer(B);
  K := 1;
  Killed := False;
  repeat
    NX := OX + DS.BattleDx[K];
    NY := OY + DS.BattleDy[K];
    if InBounds(B, NX, NY) then
    begin
      Code := B.Grid[Cell(NX, NY)];
      if (Code >= EnemyLo) and (Code <= EnemyHi) then
      begin
        EI := Byte(Code - EnemyBase);
        E := BattleUnit(B, OtherSide(B), EI);
        Strike := (E^.Stance = 0) and (E^.UnconsciousRounds = 0) and
          (PByte(@DS.UnitMelee)[ShortInt(E^.UnitType)] <> 0);
        if Strike and (U^.Ability = $1B) then                  { Duckmaeuser }
          Strike := Chance(50);
        if Strike then
          Killed := AttackUnit(B, OtherSide(B), EI, OX, OY, True);
      end;
    end;
    Inc(K);
  until (K > 8) or Killed;
  if Killed then
  begin
    if B.Side[1].Army1Count = 0 then
      EndBattle(B, 10);
    if B.Side[0].Army1Count = 0 then
      EndBattle(B, 11);
    B.SideToMove := 1;
    Exit;
  end;
  if U^.UnconsciousRounds > 0 then
  begin
    U^.Steps := 0;
    Exit;
  end;
  DrawCell(B, OX, OY, B.Terrain[Cell(OX, OY)]);
  if Mirror then
  begin
    DrawCell(B, OX, OY, Byte(B.UnitToMove + FrameBase));
    PlaySound(PByte(@DS.UnitMoveSound)[ShortInt(U^.UnitType)]);
    DrawCell(B, OX, OY, B.Terrain[Cell(OX, OY)]);
    DrawCell(B, X, Y, Byte(B.UnitToMove + FrameBase));
    PlaySound(PByte(@DS.UnitMoveSound)[ShortInt(U^.UnitType)]);
    if U^.Ability <> $1D then
      DrawCell(B, X, Y, Byte(B.UnitToMove + OwnBase))
    else
      DrawCell(B, X, Y, B.Terrain[Cell(X, Y)]);       { Camouflage: not drawn }
  end
  else
  begin
    DrawCell(B, OX, OY, B.Terrain[Cell(OX, OY)]);
    if U^.Ability <> $1D then
      DrawCell(B, X, Y, Byte(B.UnitToMove + OwnBase));
    PlaySound(PByte(@DS.UnitMoveSound)[ShortInt(U^.UnitType)]);
  end;
  B.Grid[Cell(X, Y)] := Byte(B.UnitToMove + OwnBase);
  B.Grid[Cell(OX, OY)] := B.Terrain[Cell(OX, OY)];
  U^.PosX := X;
  U^.PosY := Y;
  Dec(U^.Steps);
  if X >= 8 then
    B.CrossedMiddle := 1;
end;

procedure DesertionCheck(var B: TBattleWnd);
var
  U: PUnit;
  OX, OY: SmallInt;
  Other: Byte;
  D: TDialog;
begin
  { at the end of a unit's activation: it deserts if RandomReal * 0.6 >
    motivation; to the enemy if it has room (UEBERLAUFDLG), else it leaves
    (DESERTDLG) }
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if PByte(@DS.UnitCanDesert)[ShortInt(U^.UnitType)] = 0 then
    Exit;
  if R48Cmp(R48Mul(RandomReal, RC($9A80, $9999, $1999)), U^.Motivation) <= 0 then
    Exit;
  OX := U^.PosX;
  OY := U^.PosY;
  StopTimer(B);
  PlaySound($14);
  if B.Side[OtherSide(B)].Army1Count < 8 then
  begin
    Inc(B.Side[OtherSide(B)].Army1Count);
    BattleUnit(B, OtherSide(B), B.Side[OtherSide(B)].Army1Count)^ := U^;
    if OtherSide(B) = 1 then
      B.Grid[Cell(OX, OY)] := Byte(B.Side[1].Army1Count + $6E)
    else
      B.Grid[Cell(OX, OY)] := Byte(B.Side[0].Army1Count + $78);
    DrawCell(B, OX, OY, B.Grid[Cell(OX, OY)]);
    if B.Human[B.SideToMove] <> 0 then
    begin
      D := UI.Dialog('Message2Dlg', $3472, [APtr(@B), AStr(DSText($2EAE)),
        AStr(PChar(@B.Side[B.SideToMove].Name)), AStr(PChar(@U^.Name))]);
      UI.Execute(D);
      UI.Done(D, 1);
    end;
  end
  else
  begin
    B.Grid[Cell(OX, OY)] := B.Terrain[Cell(OX, OY)];
    DrawCell(B, OX, OY, B.Grid[Cell(OX, OY)]);
    if B.Human[B.SideToMove] <> 0 then
    begin
      D := UI.Dialog('Message2Dlg', $3472, [APtr(@B), AStr(DSText($2EBB)),
        AStr(PChar(@B.Side[B.SideToMove].Name)), AStr(PChar(@U^.Name))]);
      UI.Execute(D);
      UI.Done(D, 1);
    end;
  end;
  Inc(B.Side[B.SideToMove].DesertedUnits);
  RemoveArmy1Unit(B.Side[B.SideToMove], B.UnitToMove);
  RefreshUnitCodes(B, B.SideToMove);
  B.UnitToMove := 1;
  if B.Side[1].Army1Count = 0 then
    EndBattle(B, 10);
  if B.Side[0].Army1Count = 0 then
    EndBattle(B, 11);
  StartTimer(B);
end;

function AiShouldRetreat(var B: TBattleWnd): Boolean;
var
  R: TReal48;
  U: PUnit;
begin
  { by the strength balance r of the side to move: a fleeing hero at
    r < -0.2; the attacker (or anyone in a city) at r < -0.33 with 90 %; the
    field defender at r < -0.5 with 40 %; never the Lindwurm }
  R := StrengthBalance(B, B.SideToMove);
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (U^.UnitType = 9) and HeroShouldFlee(B) and (R48Cmp(R, RC($CD7E, $CCCC, $CCCC)) < 0) then
    Exit(True);
  if (U^.UnitType <> $0C) and ((B.SideToMove = 1) or (B.City <> 0)) and
     (R48Cmp(R, RC($5C7F, $C28F, $A8F5)) < 0) and Chance(90) then
    Exit(True);
  Result := (U^.UnitType <> $0C) and (B.SideToMove = 0) and
    (R48Cmp(R, RC($0080, 0, $8000)) < 0) and Chance(40);
end;

procedure AiChooseStance(var B: TBattleWnd);
var
  U: PUnit;
begin
  { the defender: a wounded, unthreatened unit heals; a unit with steps
    left digs in when defensive in the field with no enemy next to it }
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (B.SideToMove = 0) and (ShortInt(U^.Hp) < ShortInt(U^.MaxHp)) and
     not IsThreatened(B, B.SideToMove, B.UnitToMove) then
  begin
    U^.Stance := 2;
    DrawCell(B, U^.PosX, U^.PosY, B.Grid[Cell(U^.PosX, U^.PosY)]);
    U^.Steps := 0;
  end;
  if (B.SideToMove = 0) and (U^.Steps > 0) and (U^.Stance <> 2) and (B.AiAggressive = 0) and
     (B.City = 0) and (CountAdjacentEnemies(B, B.SideToMove, B.UnitToMove) = 0) then
  begin
    U^.Stance := 1;
    DrawCell(B, U^.PosX, U^.PosY, B.Grid[Cell(U^.PosX, U^.PosY)]);
    U^.Steps := 0;
  end;
end;

type
  TUnitTest = function(var U: TUnit; Arg: Byte): Boolean;

{ the first enemy unit that passes Test (units 1.. until found or the last) }
function FirstEnemyWhere(var B: TBattleWnd; var X, Y: SmallInt; Test: TUnitTest;
  Arg: Byte): Boolean;
var
  K: Byte;
  Found: Boolean;
  E: PUnit;
begin
  Result := False;
  if B.Side[OtherSide(B)].Army1Count = 0 then
    Exit;
  Found := False;
  K := 0;
  repeat
    Inc(K);
    if Test(BattleUnit(B, OtherSide(B), K)^, Arg) then
      Found := True;
  until (B.Side[OtherSide(B)].Army1Count = K) or Found;
  if Found then
  begin
    E := BattleUnit(B, OtherSide(B), K);
    X := E^.PosX;
    Y := E^.PosY;
    Result := True;
  end;
end;

function IsHero(var U: TUnit; Arg: Byte): Boolean;
begin
  Result := U.UnitType = 9;
end;

function IsHelpless(var U: TUnit; Arg: Byte): Boolean;
begin
  Result := (U.BlindRounds > 0) or (U.UnconsciousRounds > 0);
end;

function IsFast(var U: TUnit; Arg: Byte): Boolean;
begin
  Result := U.UnitType in [5, $11, $13, $19, $1E];
end;

function HasAbility(var U: TUnit; Arg: Byte): Boolean;
begin
  Result := U.Ability = Arg;
end;

function IsHealing(var U: TUnit; Arg: Byte): Boolean;
begin
  Result := U.Stance = 2;
end;

function AiFindEnemyHero(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
begin
  Result := FirstEnemyWhere(B, X, Y, @IsHero, 0);
end;

function AiFirstEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  E: PUnit;
begin
  Result := B.Side[OtherSide(B)].Army1Count <> 0;
  if Result then
  begin
    E := BattleUnit(B, OtherSide(B), 1);
    X := E^.PosX;
    Y := E^.PosY;
  end;
end;

function AiLastEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  E: PUnit;
begin
  Result := B.Side[OtherSide(B)].Army1Count <> 0;
  if Result then
  begin
    E := BattleUnit(B, OtherSide(B), B.Side[OtherSide(B)].Army1Count);
    X := E^.PosX;
    Y := E^.PosY;
  end;
end;

function AiFindHelplessEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
begin
  Result := FirstEnemyWhere(B, X, Y, @IsHelpless, 0);
end;

function AiFindFastEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
begin
  Result := FirstEnemyWhere(B, X, Y, @IsFast, 0);
end;

function AiFindWeakestEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  K, Best, Last, MinHp: Byte;
  E: PUnit;
begin
  { the enemy with the fewest hit points (the first of equals) }
  Result := False;
  if B.Side[OtherSide(B)].Army1Count = 0 then
    Exit;
  MinHp := $FF;
  Best := 1;
  Last := B.Side[OtherSide(B)].Army1Count;
  for K := 1 to Last do
  begin
    E := BattleUnit(B, OtherSide(B), K);
    if SmallInt(MinHp) > SmallInt(ShortInt(E^.Hp)) then
    begin
      Best := K;
      MinHp := E^.Hp;
    end;
  end;
  E := BattleUnit(B, OtherSide(B), Best);
  X := E^.PosX;
  Y := E^.PosY;
  Result := True;
end;

function AiFindMostWoundedFriend(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  K, Best, Last, MaxLoss: Byte;
  U: PUnit;
  Loss: SmallInt;
begin
  { for a healer (Heilkraefte): the own unit missing the most hit points }
  Result := False;
  if (BattleUnit(B, B.SideToMove, B.UnitToMove)^.Ability <> $11) or
     (B.Side[B.SideToMove].Army1Count = 0) then
    Exit;
  MaxLoss := 0;
  Best := 0;
  Last := B.Side[B.SideToMove].Army1Count;
  for K := 1 to Last do
  begin
    U := BattleUnit(B, B.SideToMove, K);
    Loss := SmallInt(ShortInt(U^.MaxHp)) - ShortInt(U^.Hp);
    if Loss > SmallInt(MaxLoss) then
    begin
      Best := K;
      MaxLoss := Byte(Loss);
    end;
  end;
  if MaxLoss > 0 then
  begin
    U := BattleUnit(B, B.SideToMove, Best);
    X := U^.PosX;
    Y := U^.PosY;
    Result := True;
  end;
end;

function AiFindEnemyWithAbility(var B: TBattleWnd; var X, Y: SmallInt; Ability: Byte): Boolean;
begin
  Result := FirstEnemyWhere(B, X, Y, @HasAbility, Ability);
end;

function AiFindHealingEnemy(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
begin
  Result := FirstEnemyWhere(B, X, Y, @IsHealing, 0);
end;

function AiPickWallTarget(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  R: Byte;
  Code: Byte;
begin
  { the attacker in a city: one of six wall cells around the gate, at
    random, if the wall still stands }
  Result := False;
  if (B.SideToMove = 0) or (B.City = 0) then
    Exit;
  R := Byte(Random(6) + 1);
  Code := B.Grid[Cell(DS.BattleWallX[R], DS.BattleWallY[R])];
  if (Code >= $5B) and (Code <= $63) then
  begin
    X := DS.BattleWallX[R];
    Y := DS.BattleWallY[R];
    Result := True;
  end;
end;

function AiPickAdjacentBuilding(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  U: PUnit;
  OX, OY: SmallInt;
  R, K, Last, Found, Code: Byte;
begin
  { the attacker in a city: a building next to the unit (the last of the 8
    neighbours, counted from a random one) }
  Result := False;
  if (B.SideToMove = 0) or (B.City = 0) then
    Exit;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  OX := U^.PosX;
  OY := U^.PosY;
  R := Byte(Random(8) + 1);
  Found := 0;
  Last := Byte(R + 7);
  for K := R to Last do
  begin
    Code := B.Grid[Cell(OX + DS.BattleDx2[K], OY + DS.BattleDy2[K])];
    if (Code >= 2) and (Code <= 7) then
      Found := K;
  end;
  if Found <> 0 then
  begin
    X := OX + DS.BattleDx2[Found];
    Y := OY + DS.BattleDy2[Found];
    Result := True;
  end;
end;

function AiChooseTarget(var B: TBattleWnd; var X, Y: SmallInt): Boolean;
var
  T: Byte;
begin
  { a target by the type of the current unit, else at random (healing
    enemy, last enemy, wounded friend, helpless enemy) until one is found }
  T := BattleUnit(B, B.SideToMove, B.UnitToMove)^.UnitType;
  case T of
    9, $0D:                                    { Held, Reisiger Raecher }
      case Random(3) of
        0: Result := AiFindEnemyHero(B, X, Y) or AiFindEnemyWithAbility(B, X, Y, $0A);
        1: Result := AiFindMostWoundedFriend(B, X, Y);
        2: Result := AiFindHelplessEnemy(B, X, Y);
      else
        Result := False;
      end;
    6, $16:                                    { Artillerie, Alchimisten }
      Result := (BattleUnit(B, B.SideToMove, B.UnitToMove)^.Ammo > 0) and
        (AiPickWallTarget(B, X, Y) or AiFindHealingEnemy(B, X, Y) or
         AiFindEnemyWithAbility(B, X, Y, $0A) or AiFindHelplessEnemy(B, X, Y) or
         AiFindMostWoundedFriend(B, X, Y) or AiFindEnemyWithAbility(B, X, Y, $0A) or
         AiFindEnemyWithAbility(B, X, Y, $0D));
    5, $13, $19, $1E, $11:
      Result := AiFindFastEnemy(B, X, Y);
    8, $0B:
      Result := AiFindEnemyWithAbility(B, X, Y, $0D) or AiFirstEnemy(B, X, Y);
    $0A, $12, $1C:                             { Vampire, Schwarze Ritter, Berserker }
      Result := AiFindWeakestEnemy(B, X, Y);
    $15:
      Result := AiFindMostWoundedFriend(B, X, Y);
  else
    Result := False;
  end;
  while not Result do
    case Random(4) of
      0: Result := AiFindHealingEnemy(B, X, Y);
      1: Result := AiLastEnemy(B, X, Y);
      2: Result := AiFindMostWoundedFriend(B, X, Y);
      3: Result := AiFindHelplessEnemy(B, X, Y);
    end;
end;

procedure AiNearestEnemy(var B: TBattleWnd; FX, FY: SmallInt; var X, Y: SmallInt);
var
  K, Best, MinD, D: SmallInt;
  E: PUnit;
begin
  { the nearest enemy to (FX, FY), the last of equals counted backwards }
  MinD := 100;
  Best := 0;
  for K := B.Side[OtherSide(B)].Army1Count downto 1 do
  begin
    E := BattleUnit(B, OtherSide(B), K);
    D := SmallInt(Distance(FX, FY, E^.PosX, E^.PosY));
    if D < MinD then
    begin
      Best := K;
      MinD := D;
    end;
  end;
  E := BattleUnit(B, OtherSide(B), Best);
  X := E^.PosX;
  Y := E^.PosY;
end;

function AiStepToward(var B: TBattleWnd; FX, FY, TX, TY: SmallInt; var X, Y: SmallInt): Boolean;
var
  R, K, Last: Byte;
  Best: Word;
  D, ND: SmallInt;
begin
  { the neighbour of (FX, FY) the unit can enter that is nearest to
    (TX, TY), if nearer than (FX, FY); an attacker unit in a city that
    cannot get nearer heads for row 5 (the gate) }
  D := SmallInt(Distance(TX, TY, FX, FY));
  Best := 0;
  R := Byte(Random(8) + 1);
  Last := Byte(R + 7);
  for K := R to Last do
    if CanMoveTo(B, FX + DS.BattleDx3[K], FY + DS.BattleDy3[K]) then
    begin
      ND := SmallInt(Distance(TX, TY, FX + DS.BattleDx3[K], FY + DS.BattleDy3[K]));
      if ND < D then
      begin
        D := ND;
        Best := K;
      end;
    end;
  if Best <> 0 then
  begin
    X := FX + DS.BattleDx3[Best];
    Y := FY + DS.BattleDy3[Best];
    Exit(True);
  end;
  if (B.Grid[Cell(FX, FY)] < $6F) or (B.Grid[Cell(FX, FY)] > $76) or (B.City = 0) then
    Exit(False);
  R := Byte(Random(8) + 1);
  Best := 0;
  D := SmallInt(Distance(FX, FY, FX, 5));
  Last := Byte(R + 7);
  for K := R to Last do
    if CanMoveTo(B, FX + DS.BattleDx3[K], FY + DS.BattleDy3[K]) then
    begin
      ND := SmallInt(Distance(FX, 5, FX + DS.BattleDx3[K], FY + DS.BattleDy3[K]));
      if ND < D then
      begin
        D := ND;
        Best := K;
      end;
    end;
  Result := Best <> 0;
  if Result then
  begin
    X := FX + DS.BattleDx3[Best];
    Y := FY + DS.BattleDy3[Best];
  end;
end;

function AiTryAttack(var B: TBattleWnd): Boolean;
var
  U: PUnit;
  OX, OY, TX, TY: SmallInt;
  Code: Byte;

  procedure StrikeUnit;
  begin
    DrawUnitStatus(B, 0, OtherSide(B),
      Byte(B.Grid[Cell(TX, TY)] - DS.BattleSideCodeB[OtherSide(B)]), 0);
    AttackUnit(B, B.SideToMove, B.UnitToMove, TX, TY, False);
    ClearTargetPanel(B);
  end;

  procedure CheckEnd;
  begin
    if B.Side[1].Army1Count = 0 then
      EndBattle(B, 10);
    if B.Side[0].Army1Count = 0 then
      EndBattle(B, 11);
  end;

begin
  { attack the chosen target; else (15 %) a building next to the unit;
    else the nearest enemy, if in reach }
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  OX := U^.PosX;
  OY := U^.PosY;
  AiChooseTarget(B, TX, TY);
  if (U^.Steps > 0) and CanAttack(B, TX, TY) then
  begin
    Code := B.Grid[Cell(TX, TY)];
    if ((Code >= 2) and (Code <= 7)) or ((Code >= $0B) and (Code <= $0D)) or
       ((Code >= $5B) and (Code <= $63)) then
      AttackObject(B, TX, TY)
    else
      StrikeUnit;
    CheckEnd;
    Exit(True);
  end;
  if (U^.Steps > 0) and Chance(15) and AiPickAdjacentBuilding(B, TX, TY) and
     CanAttack(B, TX, TY) then
  begin
    AttackObject(B, TX, TY);
    Exit(True);
  end;
  AiNearestEnemy(B, OX, OY, TX, TY);
  if (U^.Steps > 0) and CanAttack(B, TX, TY) then
  begin
    StrikeUnit;
    CheckEnd;
    Exit(True);
  end;
  Result := False;
end;

procedure AiMove(var B: TBattleWnd);
var
  U: PUnit;
  OX, OY, TX, TY, NX, NY: SmallInt;

  { attack mode, or a step inside the city walls }
  function MayGo: Boolean;
  begin
    Result := (B.AiAggressive <> 0) or ((B.City <> 0) and (Byte(NX) >= 11) and
      (Byte(NX) <= 13) and (Byte(NY) >= 4) and (Byte(NY) <= 6));
  end;

begin
  { one step toward the target (or the nearest enemy), or heal a friend;
    else a step is spent }
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if (B.AiCautiousHero > 0) and (U^.UnitType = 9) and (U^.Steps < U^.MaxSteps) then
    U^.Steps := 0;
  if U^.Steps < 1 then
    Exit;
  OX := U^.PosX;
  OY := U^.PosY;
  if (PByte(@DS.UnitMelee)[ShortInt(U^.UnitType)] <> 0) or
     ((U^.Ammo > 0) and (CountAdjacentEnemies(B, B.SideToMove, B.UnitToMove) = 0)) then
  begin
    AiChooseTarget(B, TX, TY);
    if AiStepToward(B, OX, OY, TX, TY, NX, NY) and MayGo then
    begin
      MoveUnit(B, NX, NY);
      Exit;
    end;
    if (U^.Ability = $11) and AiFindMostWoundedFriend(B, TX, TY) and CanHeal(B, TX, TY) then
    begin
      DoHeal(B, OX, OY, TX, TY);
      Exit;
    end;
    AiNearestEnemy(B, OX, OY, TX, TY);
    if AiStepToward(B, OX, OY, TX, TY, NX, NY) and MayGo then
    begin
      MoveUnit(B, NX, NY);
      Exit;
    end;
  end;
  Dec(U^.Steps);
end;

procedure AiStep(var B: TBattleWnd);
var
  U: PUnit;
begin
  { one action of the computer's current unit (a timer tick) }
  if B.Human[B.SideToMove] <> 0 then
    Exit;
  if B.Side[1].Army1Count = 0 then
    EndBattle(B, 10);
  if B.Side[0].Army1Count = 0 then
    EndBattle(B, 11);
  DrawUnitStatus(B, 0, B.SideToMove, B.UnitToMove, 1);
  if AiShouldRetreat(B) then
  begin
    StopTimer(B);
    PlaySound($14);
    if B.SideToMove = 0 then
      EndBattle(B, 13)
    else
      EndBattle(B, 12);
    Exit;
  end;
  if not AiTryAttack(B) then
    if (B.AiAggressive <> 0) or (B.City <> 0) then
      AiMove(B)
    else
      AiChooseStance(B);
  if BattleUnit(B, B.SideToMove, B.UnitToMove)^.Steps > 0 then
    AiChooseStance(B);
  if BattleUnit(B, B.SideToMove, B.UnitToMove)^.Steps > 0 then
    Exit;
  DesertionCheck(B);
  if B.Side[1].Army1Count = 0 then
    EndBattle(B, 10);
  if B.Side[0].Army1Count = 0 then
    EndBattle(B, 11);
  if B.CursorShown = 0 then
  begin
    U := BattleUnit(B, B.SideToMove, B.UnitToMove);
    DrawCell(B, U^.PosX, U^.PosY, B.Grid[Cell(U^.PosX, U^.PosY)]);
    B.CursorShown := 1;
  end;
  B.UnitToMove := NextUnit(B);
  if B.UnitToMove = 0 then
    NextSide(B);
  if B.Human[B.SideToMove] <> 0 then
    EnableButtons(B)                         { and the focus to Warten }
  else
    B.AiAggressive := Ord(AiChooseAggressive(B));
  DrawUnitStatus(B, 0, B.SideToMove, B.UnitToMove, 1);
  B.BlinkTicks := 1;
end;

procedure BattleSetupWindow(var B: TBattleWnd);
begin
  { the state SetupWindow leaves (cursors, window position and focus are
    not kept): a computer side to move starts defensive }
  if B.Human[B.SideToMove] = 0 then
  begin
    DisableButtons(B);
    B.AiAggressive := 0;
  end;
  B.SetUp := 1;
  B.CursorShown := 1;
  B.StartTicks := 0;
  B.BlinkTicks := 1;
  B.TimerId := 1;
end;

procedure StartTimer(var B: TBattleWnd);
begin
  B.TimerId := 1;                  { SetTimer }
  B.CursorShown := 0;
end;

var
  StopTimerTick: Boolean = False;

procedure StopTimer(var B: TBattleWnd);
begin
  { KillTimer; a hidden cursor is drawn again by a WM_TIMER sent at once,
    which for a computer side runs a whole AI step. Remastered: not again
    from inside that step: AiStep's retreat calls StopTimer, and for a
    certain retreat (a fleeing hero) the original recursed until the stack
    overflowed (docs/rules/battle.md) }
  if (B.CursorShown = 0) and not StopTimerTick then
  begin
    StopTimerTick := True;
    try
      WMTimer(B);
    finally
      StopTimerTick := False;
    end;
  end;
end;

procedure WMTimer(var B: TBattleWnd);
var
  Blink: Boolean;
  U: PUnit;
begin
  if B.StartTicks < 3 then
    Inc(B.StartTicks)
  else if B.Human[B.SideToMove] <> 0 then
  begin
    { the current unit blinks every 400 ms }
    if DS.OptBattleTimer > 400 then
      Blink := True
    else
      Blink := B.BlinkTicks mod LongInt(400 div DS.OptBattleTimer) = 0;
    if Blink then
    begin
      U := BattleUnit(B, B.SideToMove, B.UnitToMove);
      if B.CursorShown <> 0 then
      begin
        DrawCell(B, U^.PosX, U^.PosY, B.Terrain[Cell(U^.PosX, U^.PosY)]);
        B.CursorShown := 0;
      end
      else
      begin
        DrawCell(B, U^.PosX, U^.PosY, B.Grid[Cell(U^.PosX, U^.PosY)]);
        B.CursorShown := 1;
      end;
      B.BlinkTicks := 1;
    end
    else
      Inc(B.BlinkTicks);
  end
  else
    AiStep(B);
end;

{ the next side whose turn it is (AiStep, EndAction): a side without a
  unit able to act passes }
procedure NextSide(var B: TBattleWnd);
var
  U: PUnit;
  Done: Boolean;
begin
  repeat
    Done := False;
    B.SideToMove := OtherSide(B);
    B.UnitToMove := 1;
    if B.Human[B.SideToMove] = 0 then
      B.AiAggressive := Ord(AiChooseAggressive(B));
    StartSideTurn(B, B.SideToMove);
    repeat
      U := BattleUnit(B, B.SideToMove, B.UnitToMove);
      if (U^.Stance = 0) and (U^.UnconsciousRounds = 0) then
        Done := True
      else
        B.UnitToMove := NextUnit(B);
    until Done or (B.UnitToMove = 0);
  until Done;
end;

procedure GetResults(var B: TBattleWnd; var Attacker, Defender: TPlayer; var Results);
var
  Civilians: PLongInt;
begin
  { after a city battle 2 % of the people die per defender unit lost (at
    most all but 50); the results (0x37 bytes) and both players, healed,
    go back }
  if B.City <> 0 then
  begin
    Civilians := ResultCounter(B, 4);
    Civilians^ := MinLong(B.Side[0].Population - 50,
      LongInt(Int64(B.Results[$35]) * B.Side[0].Population) div 50);
    B.Side[0].Population := B.Side[0].Population - Civilians^;
  end;
  Move(B.Results, Results, SizeOf(B.Results));
  ResetSide(B, 1);
  ResetSide(B, 0);
  Attacker := B.Side[1];
  Defender := B.Side[0];
end;

procedure EndAction(var B: TBattleWnd);
begin
  { after a human action: the end of the battle, of the unit's activation
    (desertion, next unit), of the side's turn }
  DrawUnitStatus(B, 0, B.SideToMove, B.UnitToMove, 1);
  if B.Side[1].Army1Count = 0 then
    EndBattle(B, 10);
  if B.Side[0].Army1Count = 0 then
    EndBattle(B, 11);
  if BattleUnit(B, B.SideToMove, B.UnitToMove)^.Steps > 0 then
    Exit;
  DesertionCheck(B);
  if B.CursorShown = 0 then
    WMTimer(B);
  RedrawUnit(B, B.SideToMove, B.UnitToMove);
  B.UnitToMove := NextUnit(B);
  if B.UnitToMove = 0 then
  begin
    if (DS.Game.EmailGameQ <> 0) and (B.Side[1].CpuLevel = 0) and (B.Side[0].CpuLevel = 0) then
    begin
      { an e-mail game between two humans: hand over }
      B.SideToMove := OtherSide(B);
      StartSideTurn(B, B.SideToMove);
      EndBattle(B, 14);
      Exit;
    end;
    NextSide(B);
  end;
  DrawUnitStatus(B, 0, B.SideToMove, B.UnitToMove, 1);
  ClearTargetPanel(B);
  if B.Human[B.SideToMove] = 0 then
  begin
    DisableButtons(B);
    B.AiAggressive := Ord(AiChooseAggressive(B));
  end;
  B.BlinkTicks := 1;                            { (SetFocus: Warten) }
end;

procedure CmWarten(var B: TBattleWnd);
begin
  { the next ready unit; this one keeps its steps }
  if B.CursorShown = 0 then
    WMTimer(B);
  RedrawUnit(B, B.SideToMove, B.UnitToMove);
  B.UnitToMove := NextUnit(B);
  DrawUnitStatus(B, 0, B.SideToMove, B.UnitToMove, 1);
end;

procedure CmFertig(var B: TBattleWnd);
begin
  BattleUnit(B, B.SideToMove, B.UnitToMove)^.Steps := 0;
  EndAction(B);
end;

procedure CmAufgeben(var B: TBattleWnd);
var
  D: TDialog;
begin
  { retreat (RUECKZUGDLG) or, for the defender of a city, capitulate
    (KAPDLG) }
  if B.SideToMove = 1 then
  begin
    D := UI.Dialog('KaiserDlg', $3364, [APtr(@B), AStr(DSText($2F62))]);
    if UI.Execute(D) = 1 then
      EndBattle(B, 12);                    { (else InvalidateRect: repaint) }
    UI.Done(D, 1);
    Exit;
  end;
  if B.City <> 0 then
    D := UI.Dialog('KaiserDlg', $3364, [APtr(@B), AStr(DSText($2F6E))])
  else
    D := UI.Dialog('KaiserDlg', $3364, [APtr(@B), AStr(DSText($2F62))]);
  if UI.Execute(D) = 1 then
    EndBattle(B, 13);                      { (else InvalidateRect: repaint) }
  UI.Done(D, 1);
end;

procedure CombatOptionsMenu(var B: TBattleWnd; I: Byte);
var
  U: PUnit;
  Enabled: array[0..4] of Byte;
  Stances: Boolean;
  D: TDialog;
  R: SmallInt;
begin
  { KAMPFOPTDLG: Eingraben, Heilen (an active unit with steps, when more
    than one unit of the side is active), Aktivieren, Warten, Fertig (the
    current unit) }
  U := BattleUnit(B, B.SideToMove, I);
  Stances := (U^.Stance = 0) and (U^.Steps > 0) and MoreThanOneActive(B);
  Enabled[0] := Ord(Stances);
  Enabled[1] := Ord(Stances);
  Enabled[2] := Ord(U^.Stance <> 0);
  Enabled[3] := Ord((U^.Stance = 0) and (I = B.UnitToMove));
  Enabled[4] := Enabled[3];
  D := UI.Dialog('ButtonChoiceDlg', $36EA, [APtr(@B), AStr(DSText($2F4A)), AWord(5),
    ARec(@Enabled, SizeOf(Enabled))]);
  R := UI.Execute(D);
  UI.Done(D, 1);
  case R of
    $65, $66:
      begin
        U^.Stance := R - $64;               { 1 Eingraben, 2 Heilen }
        U^.Steps := 0;
        RedrawUnit(B, B.SideToMove, I);
        if I = B.UnitToMove then
          EndAction(B);
      end;
    $67:
      begin
        U^.Stance := 0;
        RedrawUnit(B, B.SideToMove, I);
      end;
    $68: CmWarten(B);
    $69: CmFertig(B);
  end;
end;

procedure WMLButtonDown(var B: TBattleWnd; PX, PY: Word);
var
  X, Y: SmallInt;
  U: PUnit;
  Attack: Boolean;
  Code: Byte;
begin
  { the human's current unit moves, heals or attacks the clicked cell }
  if B.Human[B.SideToMove] = 0 then
    Exit;
  X := PX shr 5;
  Y := PY shr 5;
  if (X > 14) or (Y > 10) then
    Exit;
  U := BattleUnit(B, B.SideToMove, B.UnitToMove);
  if CanMoveTo(B, X, Y) then
  begin
    MoveUnit(B, X, Y);
    EndAction(B);
  end
  else if CanHeal(B, X, Y) then
  begin
    DoHeal(B, U^.PosX, U^.PosY, X, Y);
    EndAction(B);
  end
  else
  begin
    Attack := CanAttack(B, X, Y);
    Code := B.Grid[Cell(X, Y)];
    if Attack and ((((Code >= 2) and (Code <= 7)) or ((Code >= $0B) and (Code <= $0D))) or
       ((Code >= $5B) and (Code <= $63))) then
    begin
      AttackObject(B, X, Y);
      EndAction(B);
    end
    else if Attack then
    begin
      { (a tree that Demontage may attack ends up here: the victim index
        lies far beyond the battle window, see battle.md) }
      AttackUnit(B, B.SideToMove, B.UnitToMove, X, Y, False);
      EndAction(B);
    end;
  end;
end;

function WMRButtonDown(var B: TBattleWnd; PX, PY: Word): LongInt;
var
  X, Y: SmallInt;
  Code: Byte;
begin
  Result := 0;
  if PY > $160 then
  begin
    { below the map: the two status panels }
    if (PX > 0) and (PX < $C8) then
      Result := 10
    else if (PX > $118) and (PX < $1E0) then
      Result := 11;
    Exit;
  end;
  X := PX shr 5;
  Y := PY shr 5;
  Code := B.Grid[Cell(X, Y)];
  if (Code >= 1) and (Code <= 9) then
    Result := $190 + Code
  else if (Code >= $33) and (Code <= $40) then
    Result := $19A
  else if (Code >= $6F) and (Code <= $76) then
  begin
    if (B.SideToMove = 1) and (B.Side[B.SideToMove].CpuLevel = 0) and
       (BattleUnit(B, B.SideToMove, Byte(Code - $6E))^.UnconsciousRounds = 0) then
      CombatOptionsMenu(B, Byte(Code - $6E));
  end
  else if (Code >= $79) and (Code <= $80) then
  begin
    if (B.SideToMove = 0) and (B.Side[B.SideToMove].CpuLevel = 0) and
       (BattleUnit(B, B.SideToMove, Byte(Code - $78))^.UnconsciousRounds = 0) then
      CombatOptionsMenu(B, Byte(Code - $78));
  end;
end;

function MoreThanOneActive(var B: TBattleWnd): Boolean;
var
  I, Last, N: Byte;
begin
  { more than one unit of the side to move without a stance }
  N := 0;
  Last := B.Side[B.SideToMove].Army1Count;
  for I := 1 to Last do
    if BattleUnit(B, B.SideToMove, I)^.Stance = 0 then
      Inc(N);
  Result := N > 1;
end;

function NextUnit(var B: TBattleWnd): Byte;
var
  I, Tries: Byte;
  U: PUnit;
begin
  { the next unit (cyclic) with steps left, no stance, conscious; 0 if none }
  Tries := 0;
  I := B.UnitToMove;
  repeat
    Inc(I);
    if B.Side[B.SideToMove].Army1Count < I then
      I := 1;
    Inc(Tries);
    U := BattleUnit(B, B.SideToMove, I);
    if (U^.Steps > 0) and (U^.Stance = 0) and (U^.UnconsciousRounds = 0) then
      Break;
  until B.Side[B.SideToMove].Army1Count < Tries;
  if B.Side[B.SideToMove].Army1Count < Tries then
    Result := 0
  else
    Result := I;
end;

function AiEnemyOutguns(var B: TBattleWnd): Boolean;
var
  Mine, Theirs: Word;
  I, K, NMe, NThem: SmallInt;
  U, E: PUnit;
begin
  { the attack of all units that reach an enemy (by range), ours against
    theirs }
  Mine := 0;
  Theirs := 0;
  NMe := B.Side[B.SideToMove].Army1Count;
  for I := 1 to NMe do
  begin
    U := BattleUnit(B, B.SideToMove, I);
    if (U^.Ammo > 0) or (PByte(@DS.UnitMelee)[ShortInt(U^.UnitType)] <> 0) then
    begin
      NThem := B.Side[OtherSide(B)].Army1Count;
      for K := 1 to NThem do
      begin
        E := BattleUnit(B, OtherSide(B), K);
        if SmallInt(U^.Range) >= SmallInt(Distance(U^.PosX, U^.PosY, E^.PosX, E^.PosY)) then
          Mine := Word(Mine + U^.Attack);
      end;
    end;
  end;
  NThem := B.Side[OtherSide(B)].Army1Count;
  for I := 1 to NThem do
  begin
    E := BattleUnit(B, OtherSide(B), I);
    if (E^.Ammo > 0) or (PByte(@DS.UnitMelee)[ShortInt(E^.UnitType)] <> 0) then
    begin
      NMe := B.Side[B.SideToMove].Army1Count;
      for K := 1 to NMe do
      begin
        U := BattleUnit(B, B.SideToMove, K);
        if SmallInt(Distance(E^.PosX, E^.PosY, U^.PosX, U^.PosY)) <= SmallInt(E^.Range) then
          Theirs := Word(Theirs + E^.Attack);
      end;
    end;
  end;
  Result := SmallInt(Mine) < SmallInt(Theirs);
end;

function AiChooseAggressive(var B: TBattleWnd): Boolean;
begin
  { the attacker always attacks; in a city the defender waits; in the field
    by its tactic (0: once in melee, 1: when outgunned or in melee,
    2: when the enemy crossed the middle or in melee, 3: always), or when
    clearly stronger }
  Result := False;
  if B.SideToMove = 1 then
    Result := True
  else if B.City = 0 then
  begin
    case B.AiTactic of
      0: Result := AnyUnitInMelee(B);
      1: Result := AiEnemyOutguns(B) or AnyUnitInMelee(B);
      2: Result := (B.CrossedMiddle <> 0) or AnyUnitInMelee(B);
      3: Result := True;
    end;
    if R48Cmp(StrengthBalance(B, B.SideToMove), RC($0080, 0, 0)) > 0 then
      Result := True;
  end;
  if Result then
    B.AiTactic := 2;
end;

procedure StartSideTurn(var B: TBattleWnd; S: Byte);
var
  I, Last, Active: Byte;
  R: Word;
  U: PUnit;
begin
  Active := 0;
  Last := B.Side[S].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, S, I);
    if U^.Stance = 0 then
      Inc(Active)
    else if B.Side[S].CpuLevel <> 0 then
    begin
      { computer units end their stance: healing when healthy or
        threatened, digging in when aggressive or in melee }
      if U^.Stance = 2 then
        if (U^.Hp = U^.MaxHp) or IsThreatened(B, S, I) then
        begin
          U^.Stance := 0;
          Inc(Active);
          UI.Call('Battle_RedrawUnit', [AByte(S), AByte(I), APtr(@B)]);
        end;
      if U^.Stance = 1 then
        if (B.AiAggressive <> 0) or (CountAdjacentEnemies(B, S, I) > 0) then
        begin
          U^.Stance := 0;
          Inc(Active);
          UI.Call('Battle_RedrawUnit', [AByte(S), AByte(I), APtr(@B)]);
        end;
    end;
    { steps: one less in winter (not for rough-terrain types, Samuraischwert,
      Kampfstab) }
    if (B.Winter <> 0) and (PByte(@DS.UnitRoughTerrain)[ShortInt(U^.UnitType)] = 0) and
       (U^.Ability <> 6) and (U^.Ability <> 11) then
      U^.Steps := Byte(MaxLong(1, SmallInt(U^.MaxSteps - 1)))
    else
      U^.Steps := U^.MaxSteps;
    { regeneration: Heilende Haende, ability 7, the stance "Heilen" }
    R := B.HealingHands[S];
    if U^.Ability = 7 then
      Inc(R);
    if U^.Stance = 2 then
      Inc(R);
    if (ShortInt(U^.Hp) < ShortInt(U^.MaxHp)) and Chance(SmallInt(R * 50)) then
      Inc(U^.Hp);
    if U^.BlindRounds > 0 then
      U^.BlindRounds := ShortInt(U^.BlindRounds - Byte(R + 1));
    if U^.BlindRounds < 0 then
      U^.BlindRounds := 0;
    if U^.UnconsciousRounds > 0 then
      U^.UnconsciousRounds := ShortInt(U^.UnconsciousRounds - Byte(R + 1));
    if U^.UnconsciousRounds < 0 then
      U^.UnconsciousRounds := 0;
  end;
  { nobody active: all stances end }
  if Active = 0 then
  begin
    Last := B.Side[S].Army1Count;
    for I := 1 to Last do
      BattleUnit(B, S, I)^.Stance := 0;
  end;
end;

procedure ResetSide(var B: TBattleWnd; S: Byte);
var
  I, Last: Byte;
  U: PUnit;
begin
  { hit points, steps and ammunition to the maximum; not blind, conscious,
    active }
  Last := B.Side[S].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, S, I);
    U^.Hp := U^.MaxHp;
    U^.Steps := U^.MaxSteps;
    U^.Ammo := U^.MaxAmmo;
    U^.UnconsciousRounds := 0;
    U^.BlindRounds := 0;
    U^.Stance := 0;
  end;
end;

procedure BattleInit(var B: TBattleWnd; Parent: Pointer; Name: PChar;
  var Attacker, Defender: TPlayer; Mode, City: Byte);
var
  Markets, Mills, Granaries, Warehouses, Taverns, Smithies: LongInt;
  PalaceParts, CathedralParts, UniversityParts: Byte;
  I, Last: Byte;
  U: PUnit;
begin
  { the battle window: the dialog and its buttons Warten, Fertig, Aufgeben }
  UI.Dialog('KaiserDlg', 0, [APtr(Parent), AStr(Name)]);
  UI.Dialog('TButton', $5C90, [APtr(@B), AWord($65), AStr(DSText($2D98)), AWord($C9),
    AWord($160), AWord($50), AWord($1A), AByte(0)]);
  UI.Dialog('TButton', $5C90, [APtr(@B), AWord($66), AStr(DSText($2DA0)), AWord($C9),
    AWord($17A), AWord($50), AWord($1A), AByte(0)]);
  UI.Dialog('TButton', $5C90, [APtr(@B), AWord($67), AStr(DSText($2DA8)), AWord($C9),
    AWord($194), AWord($50), AWord($1A), AByte(0)]);
  B.Side[1] := Attacker;
  B.Side[0] := Defender;
  { the defender's buildings shown in a city battle }
  Markets := MinLong(4, B.Side[0].Markets);
  Mills := MinLong(8, B.Side[0].Mills);
  PalaceParts := B.Side[0].PalaceParts;
  CathedralParts := B.Side[0].CathedralParts;
  Granaries := MinLong(B.Side[0].Granaries, 1);
  Warehouses := MinLong(B.Side[0].Warehouses, 1);
  UniversityParts := B.Side[0].UniversityParts;
  Taverns := MinLong(B.Side[0].Taverns, 1);
  Smithies := MinLong(B.Side[0].Smithies, 1);
  FillChar(B.Results, SizeOf(B.Results), 0);
  InitMorale(B);
  B.Winter := Ord(Random(6) = 0);
  B.Mode := Mode;
  B.City := City;
  { the attacker lines up }
  ResetSide(B, 1);
  StartSideTurn(B, 1);
  Last := B.Side[1].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 1, I);
    if B.City <> 0 then
    begin
      U^.PosX := DS.BattleAttCityX[I];
      U^.PosY := DS.BattleAttCityY[I];
    end
    else
    begin
      U^.PosX := DS.BattleAttFieldX[I];
      U^.PosY := DS.BattleAttFieldY[I];
    end;
  end;
  { the defender (raiders are placed below) }
  ResetSide(B, 0);
  StartSideTurn(B, 0);
  Last := B.Side[0].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 0, I);
    if B.City <> 0 then
    begin
      U^.PosX := DS.BattleDefCityX[I];
      U^.PosY := DS.BattleDefCityY[I];
    end
    else if B.Mode = 0 then
    begin
      U^.PosX := DS.BattleDefFieldX[I];
      U^.PosY := DS.BattleDefFieldY[I];
    end;
  end;
  { the battlefield: city maps 1..10, field maps 11..20 }
  if B.City <> 0 then
  begin
    LoadMapData(B.Terrain, B.MapCountry);
    B.Terrain[Cell(10, 3)] := $5B;
    B.Terrain[Cell(11, 3)] := $5C;
    B.Terrain[Cell(12, 3)] := $5C;
    B.Terrain[Cell(13, 3)] := $5C;
    B.Terrain[Cell(14, 3)] := $5D;
    B.Terrain[Cell(14, 4)] := $5E;
    B.Terrain[Cell(14, 5)] := $5E;
    B.Terrain[Cell(14, 6)] := $5E;
    B.Terrain[Cell(14, 7)] := $5F;
    B.Terrain[Cell(13, 7)] := $60;
    B.Terrain[Cell(12, 7)] := $60;
    B.Terrain[Cell(11, 7)] := $60;
    B.Terrain[Cell(10, 7)] := $61;
    B.Terrain[Cell(10, 6)] := $62;
    B.Terrain[Cell(10, 4)] := $63;
  end
  else
    LoadMapData(B.Terrain, B.MapCountry + 10);
  if B.City <> 0 then
  begin
    if Markets > 0 then
    begin
      Last := Byte(Markets);
      for I := 1 to Last do
        B.Terrain[Cell(DS.BattleMarketX[I], DS.BattleMarketY[I])] := 2;
    end;
    if Mills > 0 then
    begin
      Last := Byte(Mills);
      for I := 1 to Last do
        B.Terrain[Cell(DS.BattleMillX[I], DS.BattleMillY[I])] := 3;
    end;
    if PalaceParts > 0 then
      B.Terrain[Cell(13, 4)] := 4;
    if CathedralParts > 0 then
      B.Terrain[Cell(13, 6)] := 5;
    if Granaries > 0 then
      B.Terrain[Cell(14, 2)] := 6;
    if Warehouses > 0 then
      B.Terrain[Cell(14, 8)] := 7;
    if UniversityParts > 0 then
      B.Terrain[Cell(13, 5)] := $0B;
    if Taverns > 0 then
      B.Terrain[Cell(12, 4)] := $0C;
    if Smithies > 0 then
      B.Terrain[Cell(12, 6)] := $0D;
  end;
  B.Grid := B.Terrain;
  { raiders: at random on free ground or trees, x 7..11, y 2..8 }
  if B.Mode > 0 then
  begin
    Last := B.Side[0].Army1Count;
    for I := 1 to Last do
    begin
      U := BattleUnit(B, 0, I);
      repeat
        U^.PosX := SmallInt(Random(5) + 7);
        U^.PosY := SmallInt(Random(7) + 2);
      until B.Grid[Cell(U^.PosX, U^.PosY)] in [0, 8, 9];
      B.Grid[Cell(U^.PosX, U^.PosY)] := Byte(I + $14);
      B.Terrain[Cell(U^.PosX, U^.PosY)] := 0;
    end;
  end;
  Last := B.Side[1].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 1, I);
    B.Grid[Cell(U^.PosX, U^.PosY)] := Byte(I + $6E);
  end;
  Last := B.Side[0].Army1Count;
  for I := 1 to Last do
  begin
    U := BattleUnit(B, 0, I);
    B.Grid[Cell(U^.PosX, U^.PosY)] := Byte(I + $78);
  end;
  B.SideToMove := 0;
  B.UnitToMove := 1;
  if B.Winter <> 0 then
    B.AiTactic := 0
  else
    B.AiTactic := Random(4);
  B.AiCautiousHero := Random(2);
  B.CrossedMiddle := 0;
  B.AiAggressive := Ord(AiChooseAggressive(B));
end;

end.
