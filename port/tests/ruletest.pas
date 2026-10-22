{ Differential test of the ported rules against the original machine code.
  Vectors come from tools/emu/gen_rule_vectors.py, which ran the original
  functions of kaiser.exe in an emulator. Usage:
    ruletest SAVEDIR VECTORFILE }
program RuleTest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, KaiserTypes, KaiserDS, KaiserSave, Real48, Rules;

type
  TBytes = array of Byte;
  PHeroGainsT = ^THeroGains;

function Field(const Line, Key: string): string;
var
  P, E: Integer;
begin
  P := Pos(' ' + Key + '=', ' ' + Line);
  if P = 0 then
    Exit('');
  P := P + Length(Key) + 1;
  E := P;
  while (E <= Length(Line)) and (Line[E] <> ' ') do
    Inc(E);
  Result := Copy(Line, P, E - P);
end;

function HexBytes(const S: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

function HexOf(const A: array of Byte): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do
    Result := Result + LowerCase(IntToHex(A[I], 2));
end;

function DiffText(const A, B: TBytes): string;
var
  I, J: Integer;
begin
  Result := '';
  I := 0;
  while I < Length(A) do
    if A[I] <> B[I] then
    begin
      J := I;
      while (J < Length(A)) and (A[J] <> B[J]) do
        Inc(J);
      if Result <> '' then
        Result := Result + ';';
      Result := Result + IntToStr(I) + ':' + HexOf(Copy(B, I, J - I));
      I := J;
    end
    else
      Inc(I);
  if Result = '' then
    Result := '-';
end;

{ apply "off:hex;off:hex" patches to Base }
procedure Patch(Base: PByte; const M: string; Parts: TStringList);
var
  K, Off: Integer;
  V: TBytes;
begin
  if M = '-' then
    Exit;
  Parts.DelimitedText := M;
  for K := 0 to Parts.Count - 1 do
  begin
    Off := StrToInt(Copy(Parts[K], 1, Pos(':', Parts[K]) - 1));
    V := HexBytes(Copy(Parts[K], Pos(':', Parts[K]) + 1, MaxInt));
    Move(V[0], Base[Off], Length(V));
  end;
end;

function Snapshot(const Buf; Size: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, Size);
  Move(Buf, Result[0], Size);
end;

function B2S(B: Boolean): string;
begin
  Result := IntToStr(Ord(B));
end;

var
  Lines, Parts, Args: TStringList;
  SaveDir, Func, Got, Want, S, Outs: string;
  Save: TSaveGame;
  Before, After, HBefore, HAfter: TBytes;
  I, Num, Pass, Fail, PIdx: Integer;
  O1, O2, O3: LongInt;
  HasLoss: Boolean;
  OutCount: Integer;
  Loss: TLandLoss;
  OutBuf: array[0..4095] of Byte;
  OutSize, K: Integer;
  B1, B2: Byte;
  U: PUnit;

  function ArgI(N: Integer): LongInt;
  begin
    Result := StrToInt(Args[N]);
  end;

  function ArgR(N: Integer): TReal48;
  var
    V: TBytes;
  begin
    V := HexBytes(Args[N]);
    Move(V[0], Result, 6);
  end;

  function Pl: PPlayer;
  begin
    Result := @Save.Players[PIdx];
  end;

  { the unit argument U is army-1 unit number ArgI(N) of the test player }
  function UnitArg(N: Integer): PUnit;
  begin
    Result := @Save.Players[PIdx].Army1[ArgI(N)];
  end;

begin
  SaveDir := IncludeTrailingPathDelimiter(ParamStr(1));
  Lines := TStringList.Create;
  Lines.LoadFromFile(ParamStr(2));
  Parts := TStringList.Create;
  Parts.Delimiter := ';';
  Parts.StrictDelimiter := True;
  Args := TStringList.Create;
  Args.Delimiter := ',';
  Args.StrictDelimiter := True;
  Pass := 0;
  Fail := 0;
  for I := 0 to Lines.Count - 1 do
  begin
    S := Lines[I];
    Func := Field(S, 'func');
    if LoadSaveGame(SaveDir + Field(S, 'save'), Save) <> lrOk then
    begin
      WriteLn('cannot load ', Field(S, 'save'));
      Halt(2);
    end;
    PIdx := StrToInt(Field(S, 'p'));
    Num := Save.Header.NumPlayers;
    Patch(PByte(@Save.Players[0]), Field(S, 'mut'), Parts);
    ResetDataSegment;
    DS.Game := Save.Header;
    Patch(PByte(@DS.Game), Field(S, 'hmut'), Parts);
    Before := Snapshot(Save.Players[0], Num * PlayerSize);
    HBefore := Snapshot(DS.Game, HeaderSize);
    RandSeed := StrToInt64(Field(S, 'seed'));
    if Field(S, 'args') = '-' then
      Args.Clear
    else
      Args.DelimitedText := Field(S, 'args');
    Outs := '-';
    OutCount := 0;
    O1 := 0; O2 := 0; O3 := 0; B1 := 0;
    HasLoss := False;
    FillChar(Loss, SizeOf(Loss), 0);
    OutSize := 0;
    FillChar(OutBuf, SizeOf(OutBuf), 0);
    { runtime country adjectives (DS:6696) as a new game sets them }
    { and computer ruler names (DS:64a2): here the country names }
    for K := 0 to 9 do
    begin
      DS.CountryAdjectives[K] := DS.CountryNames[10 + K];
      DS.CpuRulerNames[K] := DS.CountryNames[K];
    end;
    try
      with Save do
        case Func of
          'GrainCapacity': Got := IntToStr(GrainCapacity(Pl^));
          'SmithyOutput': Got := IntToStr(SmithyOutput(Pl^));
          'WarehouseFreeSpace': Got := IntToStr(WarehouseFreeSpace(Pl^));
          'WarehouseRent': Got := IntToStr(WarehouseRent(Pl^));
          'FreeBuildingLand': Got := IntToStr(FreeBuildingLand(Pl^));
          'CreditLimit': Got := IntToStr(CreditLimit(Pl^));
          'TaxIncome': Got := IntToStr(TaxIncome(Pl^));
          'JusticeIncome': Got := IntToStr(JusticeIncome(Pl^));
          'Interest': Got := IntToStr(Interest(Pl^));
          'IncomeFromBuildings': Got := IntToStr(IncomeFromBuildings(Pl^));
          'ComputeHarvest': Got := IntToStr(ComputeHarvest(Pl^, ArgI(0)));
          'ImmigrationRate': Got := HexOf(ImmigrationRate(Pl^));
          'EmigrationRate': Got := HexOf(EmigrationRate(Pl^));
          'UpdateBirthDeathRates': begin UpdateBirthDeathRates(Pl^); Got := '-'; end;
          'UpdateHappiness': Got := IntToStr(UpdateHappiness(Pl^));
          'UpdateGrainPrice': begin UpdateGrainPrice(Pl^, ArgI(0)); Got := '-'; end;
          'UnclaimedLand': Got := IntToStr(UnclaimedLand(Players, ArgI(0)));
          'WarehouseCapacity': Got := IntToStr(WarehouseCapacity(Pl^));
          'CanAffordWithCredit': Got := B2S(CanAffordWithCredit(Pl^, ArgI(0)));
          'GrainNeedMinMax':
            begin
              OutCount := 3;
              GrainNeedMinMax(Pl^, O1, O2, O3);
              Got := '-';
            end;
          'ComputeScore': Got := IntToStr(ComputeScore(Pl^, ArgI(0), ArgI(1)));
          'TradeAgreementIncome': Got := IntToStr(TradeAgreementIncome(Players, ArgI(0), ArgI(1)));
          'Prokurist': begin Prokurist(Pl^); Got := '-'; end;
          'ArmyPay': Got := IntToStr(ArmyPay(Pl^));
          'ManoeuvreCost': Got := IntToStr(ManoeuvreCost(Pl^));
          'AddGoodsCapped': begin AddGoodsCapped(Pl^, ArgI(0), ArgI(1)); Got := '-'; end;
          'ReduceByFraction': begin ReduceByFraction(Pl^.Grain, ArgR(0)); Got := '-'; end;
          'FameDiscount': Got := IntToStr(FameDiscount(ArgI(0), ArgI(1)));
          'GainFame': begin GainFame(Pl^.Fame, ArgI(0)); Got := '-'; end;
          'LoseFame': begin LoseFame(Pl^.Fame, ArgI(0)); Got := '-'; end;
          'IsFirstKing': Got := B2S(IsFirstKing(Players, ArgI(0), ArgI(1)));
          'UpdateInitiative': begin UpdateInitiative(Pl^); Got := '-'; end;
          'AttackInitiativeCost': Got := IntToStr(AttackInitiativeCost(ArgI(0), ArgI(1)));
          'FiefSize': Got := IntToStr(FiefSize(Pl^, UnitArg(0)^));
          'HasAnyUnits': Got := B2S(HasAnyUnits(Pl^));
          'ArmyStrength': Got := IntToStr(ArmyStrength(Pl^, ArgI(0)));
          'HasHero': Got := B2S(HasHero(Pl^));
          'FindHero':
            begin
              U := nil;
              Got := B2S(FindHero(Pl^, U, ArgI(0)));
              if U = nil then
                Outs := 'nil'
              else
                Outs := IntToStr(PByte(U) - PByte(@Players[0]));
            end;
          'Army1HasAbility': Got := B2S(Army1HasAbility(Pl^, ArgI(0)));
          'CountUnitsOfType': Got := IntToStr(CountUnitsOfType(Pl^, ArgI(0)));
          'ArtilleryClass': Got := IntToStr(ArtilleryClass(Pl^, ArgI(0)));
          'HasDesertableUnit': Got := B2S(HasDesertableUnit(Pl^, ArgI(0)));
          'MaxLong': Got := IntToStr(MaxLong(ArgI(0), ArgI(1)));
          'MinLong': Got := IntToStr(MinLong(ArgI(0), ArgI(1)));
          'Chance': Got := B2S(Chance(ArgI(0)));
          'SetBit': begin SetBit(Pl^.ReportFlags, ArgI(0)); Got := '-'; end;
          'ClearBit': begin ClearBit(Pl^.ReportFlags, ArgI(0)); Got := '-'; end;
          'TestBit': Got := B2S(TestBit(ArgI(0), ArgI(1)));
          'MaximizeTaxes': begin MaximizeTaxes(Pl^); Got := '-'; end;
          'CanBePromoted': Got := B2S(CanBePromoted(Pl^));
          'RemoveGranaries': begin RemoveGranaries(Pl^, ArgI(0)); Got := '-'; end;
          'RemoveWarehouses': begin RemoveWarehouses(Pl^, ArgI(0)); Got := '-'; end;
          'ProduceGoods': Got := B2S(ProduceGoods(Pl^));
          'BuildingsLostForLand':
            begin
              HasLoss := True;
              Got := B2S(BuildingsLostForLand(Pl^, Loss));
            end;
          'UpdateMarketPrices':
            begin
              UpdateMarketPrices(Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'TransferLand':
            begin
              HasLoss := True;
              TransferLand(Pl^, Players[ArgI(0)], Loss, ArgI(1), ArgI(2));
              Got := '-';
            end;
          'SkipTurnLosses': begin SkipTurnLosses(Pl^, ArgI(0)); Got := '-'; end;
          'SabotageYearlyCost': Got := IntToStr(SabotageYearlyCost(Players, ArgI(0), ArgI(1)));
          'SabotageFunding': begin SabotageFunding(Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'UnitGainExperience':
            begin
              OutSize := 32;
              Got := B2S(UnitGainExperience(UnitArg(0)^, PHeroGainsT(@OutBuf)^, ArgI(1), ArgI(2)));
            end;
          'FillWithMilitia': begin FillWithMilitia(Pl^); Got := '-'; end;
          'GenerateMarauders': begin GenerateMarauders(Pl^, ArgI(0)); Got := '-'; end;
          'GenerateLindwurm': begin GenerateLindwurm(Pl^); Got := '-'; end;
          'ClearUnit': begin ClearUnit(UnitArg(0)^); Got := '-'; end;
          'RemoveArmy1Unit': begin RemoveArmy1Unit(Pl^, ArgI(0)); Got := '-'; end;
          'RemoveArmy2Unit': begin RemoveArmy2Unit(Pl^, ArgI(0)); Got := '-'; end;
          'RemoveMilitia': begin RemoveMilitia(Pl^); Got := '-'; end;
          'SwapArmies': begin SwapArmies(Pl^); Got := '-'; end;
          'MakeUnitName':
            begin
              OutSize := 40;
              MakeUnitName(@OutBuf, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'RecruitUnit': begin RecruitUnit(Pl^, ArgI(0), ArgI(1), ArgI(2)); Got := '-'; end;
          'InitAvenger': begin InitAvenger(UnitArg(0)^); Got := '-'; end;
          'AvengerJoinsWeaker':
            Got := IntToStr(AvengerJoinsWeaker(Pl^, Players[ArgI(0)],
              Players[ArgI(1)].Army1[ArgI(2)]));
          'AvengerLeaves':
            begin
              OutSize := 61;
              AvengerLeaves(Pl^, Players[ArgI(0)], PUnit(@OutBuf)^);
              Got := '-';
            end;
          'InitUnit': begin InitUnit(Pl^, UnitArg(0)^, ArgI(1), ArgI(2)); Got := '-'; end;
          'AddUnitToArmy':
            begin
              AddUnitToArmy(Pl^, ArgI(0), Players[ArgI(1)].Army1[ArgI(2)]);
              Got := '-';
            end;
          'KnightSquire': begin KnightSquire(Pl^, UnitArg(0)^); Got := '-'; end;
          'SortArmy': begin SortArmy(Pl^, ArgI(0)); Got := '-'; end;
          'CreateHero': begin CreateHero(UnitArg(0)^, nil); Got := '-'; end;
          'HeroRankName':
            begin
              OutSize := 40;
              HeroRankName(ArgI(0), @OutBuf);
              Got := '-';
            end;
          'RandomMercenaryType': Got := IntToStr(RandomMercenaryType(Pl^));
          'UnitRankName':
            begin
              OutSize := 40;
              UnitRankName(UnitArg(0)^, @OutBuf);
              Got := '-';
            end;
          'RaiderVictoryReward': begin RaiderVictoryReward(Pl^, ArgI(0)); Got := '-'; end;
          'MakeVampire':
            begin
              OutSize := 61;
              MakeVampire(PUnit(@OutBuf)^, UnitArg(0)^);
              Got := '-';
            end;
          'CreateComputerPlayers':
            begin
              CreateComputerPlayers(Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'InitPlayers': begin InitPlayers(Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'InitComputerRuler': begin InitComputerRuler(Players, ArgI(0)); Got := '-'; end;
          'SabotageAction':
            begin
              OutCount := 2;
              Got := B2S(SabotageAction(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3), O1, B1));
              O2 := B1;
            end;
          'Distance': Got := IntToStr(Distance(ArgI(0), ArgI(1), ArgI(2), ArgI(3)));
          'ClearHighScores':
            begin
              OutSize := 2750;
              ClearHighScores(OutBuf);
              Got := '-';
            end;
          'SortHighScoreTable': begin SortHighScoreTable(Pl^); Got := '-'; end;
          'ClearMailboxSlot': begin ClearMailboxSlot(Pl^.Diplomacy671Q); Got := '-'; end;
          'AddNews': begin AddNews(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3)); Got := '-'; end;
          'LogSabotageReport':
            begin
              LogSabotageReport(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3), ArgI(4));
              Got := '-';
            end;
          'FormatPercent': begin OutSize := 40; FormatPercent(@OutBuf, ArgI(0), ArgI(1)); Got := '-'; end;
          'FormatThousands': begin OutSize := 40; FormatThousands(@OutBuf, ArgI(0)); Got := '-'; end;
          'BuildingProgressText': begin OutSize := 40; BuildingProgressText(@OutBuf, ArgI(0)); Got := '-'; end;
          'RealmName': begin OutSize := 40; RealmName(@OutBuf, ArgI(0)); Got := '-'; end;
          'FameText': begin OutSize := 40; FameText(@OutBuf, ArgI(0)); Got := '-'; end;
          'MagnitudeText': begin OutSize := 40; MagnitudeText(@OutBuf, ArgI(0)); Got := '-'; end;
          'SabotageYearsToNextOp':
            begin
              B1 := PIdx;
              B2 := ArgI(0);
              Got := IntToStr(SabotageYearsToNextOp(Players, B1, B2));
            end;
        else
          begin
            WriteLn('unknown function ', Func);
            Halt(2);
          end;
        end;
    except
      on E: ERealError do Got := 'E' + IntToStr(E.Code);
    end;
    { out parameters written before a runtime error count too }
    if OutCount = 2 then
      Outs := IntToStr(O1) + ',' + IntToStr(O2)
    else if OutCount = 3 then
      Outs := IntToStr(O1) + ',' + IntToStr(O2) + ',' + IntToStr(O3);
    if HasLoss then
      Outs := HexOf(Snapshot(Loss, SizeOf(Loss)));
    if OutSize > 0 then
      Outs := HexOf(Snapshot(OutBuf, OutSize));
    After := Snapshot(Save.Players[0], Num * PlayerSize);
    HAfter := Snapshot(DS.Game, HeaderSize);
    Got := 'ret=' + Got + ' out=' + Outs + ' seedout=' + IntToStr(RandSeed) +
      ' diff=' + DiffText(Before, After) + ' hdiff=' + DiffText(HBefore, HAfter);
    Want := 'ret=' + Field(S, 'ret') + ' out=' + Field(S, 'out') +
      ' seedout=' + Field(S, 'seedout') + ' diff=' + Field(S, 'diff') +
      ' hdiff=' + Field(S, 'hdiff');
    if Got = Want then
      Inc(Pass)
    else
    begin
      Inc(Fail);
      if Fail <= 12 then
      begin
        WriteLn('MISMATCH ', Copy(S, 1, Pos(' ->', S)));
        WriteLn('   want ', Want);
        WriteLn('   got  ', Got);
      end;
    end;
  end;
  WriteLn(Pass, ' passed, ', Fail, ' failed');
  if Fail > 0 then
    Halt(1);
end.
