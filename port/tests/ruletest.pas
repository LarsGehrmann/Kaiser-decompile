{ Differential test of the ported rules against the original machine code.
  Vectors come from tools/emu/gen_rule_vectors.py, which ran the original
  functions of kaiser.exe in an emulator. Usage:
    ruletest SAVEDIR VECTORFILE }
program RuleTest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, KaiserTypes, KaiserDS, KaiserSave, Real48, Rules, KaiserUI, Turn, Ai, Game,
  Battle, War, NERes, Actions, Annals, Troops, Intel, Census, Reports, GameDialogs, ReplayUI;

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
  Replay: TReplayUI;
  SaveDir, Func, Got, Want, S, Outs, UIField: string;
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
  BW: TBattleWnd;                  { the battle window of bw= / bwdiff= vectors }
  BWBefore, BWAfter: TBytes;
  HasBW: Boolean;
  BWText: string;
  WInfo: TBattleInfo;
  WRes: TBattleResults;
  Hx: TBytes;

const
  BWLo = $2E;                      { compared part, as BW_CMP in gen_rule_vectors.py }
  BWHi = $F9B;

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

  { the VMT the game constructs a dialog type with (Dlg_ vectors) }
  function DialogVMT(const Name: string): Word;
  begin
    case Name of
      'KaiserDlg': Result := $3364;
      'MessageDlg': Result := $33C6;
      'HelpMessageDlg': Result := $341A;
      'Message2Dlg': Result := $3472;
      'HelpChoice2Dlg': Result := $34C6;
      'HeroNameDlg': Result := $351E;
      'UnitInfoDlg': Result := $35E6;
      'Button2Dlg': Result := $3652;
      'ButtonChoiceDlg': Result := $36EA;
      'PromotionDlg': Result := $05F0;
      'StartFinanzDlg': Result := $0916;
      'StartPopDlg': Result := $0536;
      'HexenDlg': Result := $0598;
      'MassacreDlg': Result := $0CEC;
      'PlunderResultDlg': Result := $0C98;
      'PlunderChoiceDlg': Result := $0D60;
      'HumanCountDlg': Result := $22E4;
      'ComputerCountDlg': Result := $2362;
      'PlayerDataDlg': Result := $195A;
    else
      begin
        WriteLn('unknown dialog type ', Name);
        Halt(2);
      end;
    end;
  end;

  { a Dlg_<type> vector (tools/emu/gen_rule_vectors.py): the type's
    constructor with the arguments of args= (after the parent W: s:<hex>
    string, i:<id> resource id, w: / b: numbers, r:<hex> record, A the
    player array), the fields of fld= into the object, Execute, Done; the
    end code }
  function RunDialogType(const Name, Fld: string): string;
  var
    A: array of TUIArg;
    Strs: array of RawByteString;
    K: Integer;
    It, V: string;
    Hb: TBytes;
    D: TDialog;
    R: SmallInt;
  begin
    A := nil;
    Strs := nil;
    SetLength(A, Args.Count + 1);
    SetLength(Strs, Args.Count);
    A[0] := APtr(Window);
    for K := 0 to Args.Count - 1 do
    begin
      It := Args[K];
      V := Copy(It, 3, MaxInt);
      case It[1] of
        's', 'r':
          begin
            Hb := HexBytes(V);
            SetLength(Strs[K], Length(Hb));
            if Length(Hb) > 0 then
              Move(Hb[0], Strs[K][1], Length(Hb));
            if It[1] = 's' then
              A[K + 1] := AStr(PChar(Strs[K]))
            else
              A[K + 1] := ARec(PChar(Strs[K]), Length(Hb));
          end;
        'i': A[K + 1] := AStr(PChar(PtrUInt(StrToInt(V))));
        'w': A[K + 1] := AWord(StrToInt(V));
        'b': A[K + 1] := AByte(StrToInt(V));
        'A': A[K + 1] := APtr(@Save.Players);
      end;
    end;
    Replay.Unstubbed := Name;
    D := UI.Dialog(Name, DialogVMT(Name), A);
    Patch(PByte(@D.Data[0]), Fld, Parts);
    R := UI.Execute(D);
    { out=: the object's parts the vector reports (offset:hex;...) }
    V := Field(S, 'out');
    if V <> '-' then
    begin
      Parts.DelimitedText := V;
      Outs := '';
      for K := 0 to Parts.Count - 1 do
      begin
        It := Parts[K];
        if K > 0 then
          Outs := Outs + ';';
        Outs := Outs + Copy(It, 1, Pos(':', It)) +
          HexOf(Copy(Snapshot(D.Data[0], Length(D.Data)), StrToInt(Copy(It, 1, Pos(':', It) - 1)),
          (Length(It) - Pos(':', It)) div 2));
      end;
    end;
    UI.Done(D, 1);
    Result := IntToStr(Word(R));
  end;

begin
  { the original's UI calls are replayed; W = this window pointer }
  Replay := TReplayUI.Create;
  UI.Free;
  UI := Replay;
  Window := Pointer(PtrUInt($0EEE1234));
  Replay.Exe := TNEFile.Create(IncludeTrailingPathDelimiter(ParamStr(1)) + 'kaiser.exe');
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
    DS.OptBattleTimer := 400;                     { INI Schlacht-Timer }
    Patch(PByte(@DS.Game), Field(S, 'hmut'), Parts);
    Before := Snapshot(Save.Players[0], Num * PlayerSize);
    HBefore := Snapshot(DS.Game, HeaderSize);
    RandSeed := StrToInt64(Field(S, 'seed'));
    Replay.PlayersBase := PByte(@Save.Players[0]);
    { the battle window: zeroed (BWI) or the original's state after Init (BW) }
    HasBW := Field(S, 'bwdiff') <> '';
    FillChar(BW, SizeOf(BW), 0);
    BWText := Field(S, 'bw');
    if HasBW and (BWText <> '-') then
    begin
      BWBefore := HexBytes(BWText);
      Move(BWBefore[0], PByte(@BW)[BWLo], Length(BWBefore));
    end;
    if HasBW then
    begin
      Replay.BattleBase := PByte(@BW);
      BWBefore := Snapshot(PByte(@BW)[BWLo], BWHi - BWLo);
    end
    else
      Replay.BattleBase := nil;
    UIField := Field(S, 'ui');
    if UIField = '' then
      UIField := '-';
    Replay.Start(UIField);
    Replay.DlgScripts.Clear;
    if (Field(S, 'dlg') <> '') and (Field(S, 'dlg') <> '-') then
      Replay.DlgScripts.DelimitedText := Field(S, 'dlg');
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
      DS.CountryNamesRt[K] := DS.CountryNames[K];
    end;
    Replay.Unstubbed := '';
    try
      if Copy(Func, 1, 4) = 'Dlg_' then
        Got := RunDialogType(Copy(Func, 5, MaxInt), Field(S, 'fld'))
      else
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
          'ClearMailboxSlot': begin ClearMailboxSlot(Pl^.Mailbox); Got := '-'; end;
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
          'RulerFallsIll': begin RulerFallsIll(Window); Got := '-'; end;
          'WitchChoosesSpell': begin WitchChoosesSpell(Window, Pl^); Got := '-'; end;
          'GrantFirstHero': begin GrantFirstHero(Window, Pl^); Got := '-'; end;
          'HarvestReport': begin HarvestReport(Window, Pl^, ArgR(0)); Got := '-'; end;
          'Report_Population': begin Report_Population(Window, Pl^); Got := '-'; end;
          'Report_Budget': begin Report_Budget(Window, Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'LandLossCheck': begin LandLossCheck(Window, Pl^); Got := '-'; end;
          'SkipTurnCheck': begin SkipTurnCheck(Window, Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'RevolutionCheck': begin RevolutionCheck(Window, Pl^); Got := '-'; end;
          'GrainShortageWarning': begin GrainShortageWarning(Window, Pl^); Got := '-'; end;
          'MarriageDowry': begin MarriageDowry(Window, Pl^); Got := '-'; end;
          'Bankruptcy': begin Bankruptcy(Window, Pl^); Got := '-'; end;
          'SabotageEnd': begin SabotageEnd(Window, Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'ShowStartTurnDialog': Got := B2S(ShowStartTurnDialog(Window, Pl^, ArgI(0), ArgI(1)));
          'OfferUnitsAtTurnStart': begin OfferUnitsAtTurnStart(Window, Pl^); Got := '-'; end;
          'Report_Gossip': begin Report_Gossip(Window, Players, ArgI(0)); Got := '-'; end;
          'Ai_FarmlandPerCapita': Got := IntToStr(Ai_FarmlandPerCapita(Pl^));
          'Ai_LandPriceMargin': Got := IntToStr(Ai_LandPriceMargin(Players, ArgI(0), ArgI(1)));
          'Ai_SurplusLand': Got := IntToStr(Ai_SurplusLand(Pl^));
          'Ai_LandToSellForPromotion': Got := IntToStr(Ai_LandToSellForPromotion(Pl^));
          'Ai_IsMuchRicher': Got := B2S(Ai_IsMuchRicher(Pl^, Players[ArgI(0)]));
          'Ai_RevolutionRoll': Got := IntToStr(Ai_RevolutionRoll(Pl^));
          'Ai_SetSabotageBudgets':
            begin
              Ai_SetSabotageBudgets(Players, ArgI(0), ArgI(1));
              Got := '-';
            end;
          'Ai_CanRecruitType': Got := B2S(Ai_CanRecruitType(Pl^, ArgI(0)));
          'Ai_KnightSquires': begin Ai_KnightSquires(Pl^); Got := '-'; end;
          'Ai_DropWeakestHeerUnit': begin Ai_DropWeakestHeerUnit(Pl^); Got := '-'; end;
          'Ai_StrengthRatio': Got := HexOf(Ai_StrengthRatio(Pl^, Players[ArgI(0)]));
          'Ai_AutoBattleRating': Got := IntToStr(Ai_AutoBattleRating(Pl^, ArgI(0)));
          'Ai_AutoBattleLosses': begin Ai_AutoBattleLosses(Pl^, ArgI(0)); Got := '-'; end;
          'Ai_UnitValue': Got := IntToStr(Ai_UnitValue(UnitArg(0)^));
          'Ai_ArrangeArmies': begin Ai_ArrangeArmies(Pl^, ArgI(0)); Got := '-'; end;
          'Ai_BanditBattle': Got := IntToStr(Ai_BanditBattle(Pl^));
          'Ai_AutoBattle': Got := IntToStr(Ai_AutoBattle(Pl^, Players[ArgI(0)]));
          'Battle_OtherSide': Got := IntToStr(OtherSide(BW));
          'Battle_IsInCity': Got := B2S(IsInCity(BW, BattleUnit(BW, ArgI(0), ArgI(1))^));
          'Battle_IsThreatened': Got := B2S(IsThreatened(BW, ArgI(0), ArgI(1)));
          'Battle_HeroShouldFlee': Got := B2S(HeroShouldFlee(BW));
          'Battle_AnyUnitInMelee': Got := B2S(AnyUnitInMelee(BW));
          'Battle_CountAdjacentEnemies': Got := IntToStr(CountAdjacentEnemies(BW, ArgI(0), ArgI(1)));
          'Battle_HasAdjacentFriendOfType':
            Got := B2S(HasAdjacentFriendOfType(BW, ArgI(0), ArgI(1), ArgI(2)));
          'Battle_InBounds': Got := B2S(InBounds(BW, ArgI(0), ArgI(1)));
          'Battle_StrengthBalance': Got := HexOf(StrengthBalance(BW, ArgI(0)));
          'Battle_AiChooseAggressive': Got := B2S(AiChooseAggressive(BW));
          'Battle_AiEnemyOutguns': Got := B2S(AiEnemyOutguns(BW));
          'Battle_StartSideTurn': begin StartSideTurn(BW, ArgI(0)); Got := '-'; end;
          'Battle_ResetSide': begin ResetSide(BW, ArgI(0)); Got := '-'; end;
          'Battle_InitMorale': begin InitMorale(BW); Got := '-'; end;
          'Battle_ComputeMotivation':
            begin
              ComputeMotivation(BW, BattleUnit(BW, ArgI(0), ArgI(1))^, ArgI(2));
              Got := '-';
            end;
          'Battle_RefreshUnitCodes': begin RefreshUnitCodes(BW, ArgI(0)); Got := '-'; end;
          'Battle_CanMoveTo': Got := B2S(CanMoveTo(BW, ArgI(0), ArgI(1)));
          'Battle_CanAttack': Got := B2S(CanAttack(BW, ArgI(0), ArgI(1)));
          'Battle_CanHeal': Got := B2S(CanHeal(BW, ArgI(0), ArgI(1)));
          'Battle_NextUnit': Got := IntToStr(NextUnit(BW));
          'Battle_Duel':
            begin
              Duel(BW, BattleUnit(BW, ArgI(0), ArgI(1))^, BattleUnit(BW, ArgI(2), ArgI(3))^,
                ArgI(4) <> 0, ArgI(5) <> 0, ArgI(6) <> 0);
              Got := '-';
            end;
          'Battle_AttackUnit':
            Got := B2S(AttackUnit(BW, ArgI(0), ArgI(1), ArgI(2), ArgI(3), ArgI(4) <> 0));
          'Battle_AttackObject': Got := B2S(AttackObject(BW, ArgI(0), ArgI(1)));
          'Battle_MoveUnit': begin MoveUnit(BW, ArgI(0), ArgI(1)); Got := '-'; end;
          'Battle_DesertionCheck': begin DesertionCheck(BW); Got := '-'; end;
          'Battle_AiShouldRetreat': Got := B2S(AiShouldRetreat(BW));
          'Battle_AiChooseStance': begin AiChooseStance(BW); Got := '-'; end;
          'Battle_AiFindEnemyHero', 'Battle_AiFirstEnemy', 'Battle_AiLastEnemy',
          'Battle_AiFindHelplessEnemy', 'Battle_AiFindFastEnemy', 'Battle_AiFindWeakestEnemy',
          'Battle_AiFindMostWoundedFriend', 'Battle_AiFindEnemyWithAbility',
          'Battle_AiFindHealingEnemy', 'Battle_AiPickWallTarget', 'Battle_AiPickAdjacentBuilding',
          'Battle_AiChooseTarget':
            begin
              OutCount := 2;
              case Func of
                'Battle_AiFindEnemyHero': B1 := Ord(AiFindEnemyHero(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFirstEnemy': B1 := Ord(AiFirstEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiLastEnemy': B1 := Ord(AiLastEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFindHelplessEnemy':
                  B1 := Ord(AiFindHelplessEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFindFastEnemy': B1 := Ord(AiFindFastEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFindWeakestEnemy':
                  B1 := Ord(AiFindWeakestEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFindMostWoundedFriend':
                  B1 := Ord(AiFindMostWoundedFriend(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiFindEnemyWithAbility':
                  B1 := Ord(AiFindEnemyWithAbility(BW, PSmallInt(@O1)^, PSmallInt(@O2)^, ArgI(0)));
                'Battle_AiFindHealingEnemy':
                  B1 := Ord(AiFindHealingEnemy(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiPickWallTarget': B1 := Ord(AiPickWallTarget(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiPickAdjacentBuilding':
                  B1 := Ord(AiPickAdjacentBuilding(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
                'Battle_AiChooseTarget': B1 := Ord(AiChooseTarget(BW, PSmallInt(@O1)^, PSmallInt(@O2)^));
              end;
              Got := IntToStr(B1);
            end;
          'Battle_AiNearestEnemy':
            begin
              OutCount := 2;
              AiNearestEnemy(BW, ArgI(0), ArgI(1), PSmallInt(@O1)^, PSmallInt(@O2)^);
              Got := '-';
            end;
          'Battle_AiStepToward':
            begin
              OutCount := 2;
              Got := B2S(AiStepToward(BW, ArgI(0), ArgI(1), ArgI(2), ArgI(3),
                PSmallInt(@O1)^, PSmallInt(@O2)^));
            end;
          'Battle_AiTryAttack': Got := B2S(AiTryAttack(BW));
          'Battle_AiMove': begin AiMove(BW); Got := '-'; end;
          'Battle_AiStep': begin AiStep(BW); Got := '-'; end;
          'Battle_WMTimer': begin WMTimer(BW); Got := '-'; end;
          'Battle_Play':
            begin
              { up to N timer ticks, until the battle ends }
              BattleEndCode := 0;
              K := 0;
              while (K < ArgI(0)) and (BattleEndCode = 0) do
              begin
                WMTimer(BW);
                Inc(K);
              end;
              Got := IntToStr(K);
            end;
          'Battle_EndAction': begin EndAction(BW); Got := '-'; end;
          'Battle_CmWarten': begin CmWarten(BW); Got := '-'; end;
          'Battle_CmFertig': begin CmFertig(BW); Got := '-'; end;
          'Battle_CmAufgeben': begin CmAufgeben(BW); Got := '-'; end;
          'Battle_CombatOptionsMenu': begin CombatOptionsMenu(BW, ArgI(0)); Got := '-'; end;
          'Battle_WMLButtonDown': begin WMLButtonDown(BW, ArgI(0), ArgI(1)); Got := '-'; end;
          'War_AskBattlefield':
            Got := B2S(AskBattlefield(Window, Pl^, Save.Players[ArgI(0)], ArgI(1), ArgI(2)));
          'War_RetreatLosses': begin RetreatLosses(Window, Pl^); Got := '-'; end;
          'War_Massacre', 'War_ShowMassacre', 'War_BurnBuildings', 'War_ShowBurnResult',
          'War_PlunderTalerAndLand', 'War_ShowPlunderResult', 'War_Ai_PlunderChoice',
          'War_PlunderDialog':
            begin
              Hx := HexBytes(Args[1]);
              Move(Hx[0], WRes, SizeOf(WRes));
              case Func of
                'War_Massacre': Massacre(Window, Pl^, Save.Players[ArgI(0)], WRes, ArgI(2));
                'War_ShowMassacre': ShowMassacre(Window, Pl^, Save.Players[ArgI(0)], WRes);
                'War_BurnBuildings': BurnBuildings(Window, Pl^, Save.Players[ArgI(0)], WRes, ArgI(2));
                'War_ShowBurnResult': ShowBurnResult(Window, Pl^, Save.Players[ArgI(0)], WRes);
                'War_PlunderTalerAndLand':
                  PlunderTalerAndLand(Window, Pl^, Save.Players[ArgI(0)], WRes, ArgI(2));
                'War_ShowPlunderResult': ShowPlunderResult(Window, Pl^, Save.Players[ArgI(0)], WRes);
                'War_Ai_PlunderChoice': Ai_PlunderChoice(Window, Pl^, Save.Players[ArgI(0)], WRes, ArgI(2));
                'War_PlunderDialog': PlunderDialog(Window, Pl^, Save.Players[ArgI(0)], WRes, ArgI(2));
              end;
              Got := '-';
              Move(WRes, OutBuf, SizeOf(WRes));
              OutSize := SizeOf(WRes);
            end;
          'War_BattleSetup', 'War_BattleFameAndXp':
            begin
              Hx := HexBytes(Args[1]);
              Move(Hx[0], WInfo, SizeOf(WInfo));
              if Func = 'War_BattleSetup' then
                BattleSetup(Window, Pl^, Save.Players[ArgI(0)], WInfo, ArgI(2), ArgI(3), ArgI(4))
              else
                BattleFameAndXp(Window, Pl^, Save.Players[ArgI(0)], WInfo, ArgI(2));
              Got := '-';
              Move(WInfo, OutBuf, SizeOf(WInfo));
              OutSize := SizeOf(WInfo);
            end;
          'War_Battle':
            Got := IntToStr(War.Battle(Window, Pl^, Save.Players[ArgI(0)], ArgI(1), ArgI(2), ArgI(3)));
          'War_FightRaiders':
            Got := IntToStr(FightRaiders(Window, Pl^, ArgI(0), ArgI(1)));
          'War_BattleAftermath':
            begin
              Hx := HexBytes(Args[1]);
              Move(Hx[0], WInfo, SizeOf(WInfo));
              Hx := HexBytes(Args[2]);
              Move(Hx[0], WRes, SizeOf(WRes));
              BattleAftermath(Window, Pl^, Save.Players[ArgI(0)], WInfo, WRes, ArgI(3));
              Got := '-';
              Move(WInfo, OutBuf, SizeOf(WInfo));
              Move(WRes, OutBuf[SizeOf(WInfo)], SizeOf(WRes));
              OutSize := -1;                            { two records }
            end;
          'Do_LandHandeln': begin Do_LandHandeln(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_Gebaeude': begin Do_Gebaeude(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_SteuernFestsetzen': begin Do_SteuernFestsetzen(Window, ArgI(0), Pl^); Got := '-'; end;
          'Do_HandelMitGuetern': begin Do_HandelMitGuetern(Window, Pl^); Got := '-'; end;
          'Do_Hofschmiede': begin Do_Hofschmiede(Window, Pl^); Got := '-'; end;
          'Do_DemographischeDaten': begin Do_DemographischeDaten(Window, ArgI(0), Pl^); Got := '-'; end;
          'Do_Finanzhaushalt': begin Do_Finanzhaushalt(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_InternationalerVergleich': begin Do_InternationalerVergleich(Window, Save.Players, ArgI(0)); Got := '-'; end;
          'Do_Karriereberatung': begin Do_Karriereberatung(Window, Pl^); Got := '-'; end;
          'Do_ManoeverAbhalten': begin Do_ManoeverAbhalten(Window, Pl^, ArgI(0)); Got := '-'; end;
          'CmWirtschaft': begin Do_Wirtschaft(Window, Players[DS.Game.CurrentPlayer]); Got := '-'; end;
          'CmMilitaer': begin Do_Militaer(Window, Players[DS.Game.CurrentPlayer], DS.Game.Year); Got := '-'; end;
          'Do_Laendernamen': begin Do_Laendernamen(Window); Got := '-'; end;
          'CmSpiel': begin Do_Spiel(Window); Got := '-'; end;
          'Do_Abkommen': begin Do_Abkommen(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_TributFordern': begin Do_TributFordern(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_Sabotage': begin Do_Sabotage(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_Entwicklungshilfe': begin Do_Entwicklungshilfe(Window, Save.Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'CensusEditor': begin CensusEditor(Window, Save.Players, ArgI(0)); Got := '-'; end;
          'Do_SzenarioDlg': begin Do_SzenarioDlg(Window); Got := '-'; end;
          'Do_UnitEditDlg': begin Do_UnitEditDlg(Window, Pl^, UnitArg(0)^); Got := '-'; end;
          'TradeCaravan': begin TradeCaravan(Window, Pl^, ArgI(0)); Got := '-'; end;
          'ShowHeroLevelUp':
            begin
              Hx := HexBytes(Args[0]);
              Move(Hx[0], OutBuf, Length(Hx));
              OutSize := Length(Hx);
              ShowHeroLevelUp(Window, THeroGains(Pointer(@OutBuf)^));
              Got := '-';
            end;
          'DeclareWar':
            begin
              OutSize := 1;
              Got := B2S(DeclareWar(Window, Save.Players, ArgI(0), OutBuf[0], ArgI(1), ArgI(2)));
            end;
          'CmDemissionieren': begin Do_Demissionieren(Window, 0, Players); Got := '-'; end;
          'ShowHighScoreDlg', 'ShowRecordsDlg':
            begin
              Hx := HexBytes(Args[0]);
              Move(Hx[0], OutBuf, Length(Hx));
              OutSize := Length(Hx);
              if Func = 'ShowHighScoreDlg' then
                ShowHighScoreDlg(Window, TAnnals(Pointer(@OutBuf)^), ArgI(1))
              else
                ShowRecordsDlg(Window, TRecords(Pointer(@OutBuf)^));
              Got := '-';
            end;
          'ShowCoronation': begin ShowCoronation(Window, Pl^, ArgI(0), ArgI(1)); Got := '-'; end;
          'Do_Geheimdienst': begin Do_Geheimdienst(Window, Save.Players, ArgI(0), ArgI(1), ArgI(2)); Got := '-'; end;
          'Do_KornVerteilen': begin Do_KornVerteilen(Window, Pl^, ArgI(0)); Got := '-'; end;
          'Do_TruppenAufstellen': begin Do_TruppenAufstellen(Window, Pl^, ArgI(0)); Got := '-'; end;
          'ChooseUnitToGive':
            begin
              OutCount := 2;
              B1 := 0;
              B2 := 0;
              Got := B2S(ChooseUnitToGive(Window, Pl^, B1, B2));
              O1 := B1;
              O2 := B2;
            end;
          'BattleInit':
            begin
              BattleInit(BW, Window, nil, Pl^, Save.Players[ArgI(0)], ArgI(1), ArgI(2));
              Got := '-';
            end;
          'CmNeuesSpiel': begin NewGame(Window, 0, Players); Got := '-'; end;
          'CmBeenden': begin EndHumanTurn(Window, 0, Players); Got := '-'; end;
          'NextPlayer': begin NextPlayer(Window, 0, Players); Got := '-'; end;
          'Ai_Turn':
            begin
              Ai_Turn(Window, ArgI(0), Players, ArgI(1), ArgI(2), ArgI(3));
              Got := '-';
            end;
          'Ai_YearlySimulation':
            begin
              Ai_YearlySimulation(Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'Ai_Diplomacy': begin Ai_Diplomacy(Players, ArgI(0), ArgI(1), ArgI(2)); Got := '-'; end;
          'Ai_PopulationModel': begin Ai_PopulationModel(Pl^); Got := '-'; end;
          'Ai_Budget': begin Ai_Budget(Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Ai_GrainPolicy': begin Ai_GrainPolicy(Pl^); Got := '-'; end;
          'Ai_LandPolicy': begin Ai_LandPolicy(Players, ArgI(0), ArgI(1), ArgI(2)); Got := '-'; end;
          'Ai_SellGoods': begin Ai_SellGoods(Pl^, ArgI(0)); Got := '-'; end;
          'Ai_BuildingPolicy': begin Ai_BuildingPolicy(Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Ai_MilitaryPolicy':
            begin
              Ai_MilitaryPolicy(Window, Players, ArgI(0), ArgI(1));
              Got := '-';
            end;
          'Ai_ChooseWarTarget':
            begin
              OutSize := 1;
              Got := B2S(Ai_ChooseWarTarget(Window, Players, ArgI(0), ArgI(1), OutBuf[0]));
            end;
          'Ai_HoldManoeuvre': begin Ai_HoldManoeuvre(Pl^); Got := '-'; end;
          'Ai_EndTurn': begin Ai_EndTurn(Players, ArgI(0), ArgI(1)); Got := '-'; end;
          'Ai_FirstKingReward':
            begin
              Ai_FirstKingReward(Players, ArgI(0), ArgI(1));
              Got := '-';
            end;
          'Ai_FirstYear': begin Ai_FirstYear(Pl^); Got := '-'; end;
          'Ai_ReceiveAid':
            begin
              Ai_ReceiveAid(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3));
              Got := '-';
            end;
          'Ai_AnswerTrade':
            begin
              Ai_AnswerTrade(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3));
              Got := '-';
            end;
          'Ai_AnswerPeace':
            begin
              Ai_AnswerPeace(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3), ArgI(4));
              Got := '-';
            end;
          'Ai_AnswerTribute':
            begin
              Ai_AnswerTribute(Players, ArgI(0), ArgI(1), ArgI(2), ArgI(3), ArgI(4), ArgI(5));
              Got := '-';
            end;
          'PlayerTurnStart':
            Got := B2S(PlayerTurnStart(Window, ArgI(0), Players, ArgI(1), ArgI(2), ArgI(3)));
          'PlayerTurnEnd':
            begin
              PlayerTurnEnd(Window, ArgI(0), Players, ArgI(1), ArgI(2), ArgI(3));
              Got := '-';
            end;
          'DiplomacyTurnStart':
            begin
              DiplomacyTurnStart(Window, Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'RollYearlyEvent':
            begin
              RollYearlyEvent(Window, Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
          'FormatPlayerTitle':
            begin
              OutSize := 120;
              FormatPlayerTitle(Pl^, @OutBuf, ArgI(0), ArgI(1));
              Got := '-';
            end;
          'PromotionCheck':
            begin
              PromotionCheck(Window, Players, ArgI(0), ArgI(1), ArgI(2));
              Got := '-';
            end;
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
      on E: EDivByZero do Got := 'E200';
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
    if OutSize = -1 then                           { BattleAftermath: info, results }
      Outs := HexOf(Snapshot(OutBuf, SizeOf(TBattleInfo))) + ',' +
        HexOf(Snapshot(OutBuf[SizeOf(TBattleInfo)], SizeOf(TBattleResults)));
    After := Snapshot(Save.Players[0], Num * PlayerSize);
    HAfter := Snapshot(DS.Game, HeaderSize);
    Got := 'ret=' + Got + ' out=' + Outs + ' seedout=' + IntToStr(RandSeed) +
      ' diff=' + DiffText(Before, After) + ' hdiff=' + DiffText(HBefore, HAfter) +
      ' ui=' + Replay.LogText;
    Want := 'ret=' + Field(S, 'ret') + ' out=' + Field(S, 'out') +
      ' seedout=' + Field(S, 'seedout') + ' diff=' + Field(S, 'diff') +
      ' hdiff=' + Field(S, 'hdiff') + ' ui=' + UIField;
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
