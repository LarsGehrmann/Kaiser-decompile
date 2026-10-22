{ Differential test of the ported rules against the original machine code.
  Vectors come from tools/emu/gen_rule_vectors.py, which ran the original
  functions of kaiser.exe in an emulator. Usage:
    ruletest SAVEDIR VECTORFILE }
program RuleTest;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, KaiserTypes, KaiserSave, Real48, Rules;

type
  TBytes = array of Byte;

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

var
  Lines, Args: TStringList;
  SaveDir, Func, Got, Want, S, M: string;
  Save: TSaveGame;
  Before, After, V: TBytes;
  I, K, Num, Pass, Fail, PIdx, Arg1, Off: Integer;
begin
  SaveDir := IncludeTrailingPathDelimiter(ParamStr(1));
  Lines := TStringList.Create;
  Lines.LoadFromFile(ParamStr(2));
  Args := TStringList.Create;
  Args.Delimiter := ';';
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
    { apply the mutations to the player array }
    M := Field(S, 'mut');
    if M <> '-' then
    begin
      Args.DelimitedText := M;
      for K := 0 to Args.Count - 1 do
      begin
        Off := StrToInt(Copy(Args[K], 1, Pos(':', Args[K]) - 1));
        V := HexBytes(Copy(Args[K], Pos(':', Args[K]) + 1, MaxInt));
        Move(V[0], PByte(@Save.Players[0])[Off], Length(V));
      end;
    end;
    SetLength(Before, Num * PlayerSize);
    Move(Save.Players[0], Before[0], Length(Before));
    RandSeed := StrToInt64(Field(S, 'seed'));
    Arg1 := 0;
    if Field(S, 'args') <> '-' then
      Arg1 := StrToInt(Copy(Field(S, 'args') + ',', 1, Pos(',', Field(S, 'args') + ',') - 1));
    try
      with Save do
        case Func of
          'GrainCapacity': Got := IntToStr(GrainCapacity(Players[PIdx]));
          'SmithyOutput': Got := IntToStr(SmithyOutput(Players[PIdx]));
          'WarehouseFreeSpace': Got := IntToStr(WarehouseFreeSpace(Players[PIdx]));
          'WarehouseRent': Got := IntToStr(WarehouseRent(Players[PIdx]));
          'FreeBuildingLand': Got := IntToStr(FreeBuildingLand(Players[PIdx]));
          'CreditLimit': Got := IntToStr(CreditLimit(Players[PIdx]));
          'TaxIncome': Got := IntToStr(TaxIncome(Players[PIdx]));
          'JusticeIncome': Got := IntToStr(JusticeIncome(Players[PIdx]));
          'Interest': Got := IntToStr(Interest(Players[PIdx]));
          'IncomeFromBuildings': Got := IntToStr(IncomeFromBuildings(Players[PIdx]));
          'ComputeHarvest': Got := IntToStr(ComputeHarvest(Players[PIdx], Arg1));
          'ImmigrationRate': Got := HexOf(ImmigrationRate(Players[PIdx]));
          'EmigrationRate': Got := HexOf(EmigrationRate(Players[PIdx]));
          'UpdateBirthDeathRates': begin UpdateBirthDeathRates(Players[PIdx]); Got := '-'; end;
          'UpdateHappiness': Got := IntToStr(UpdateHappiness(Players[PIdx]));
          'UpdateGrainPrice': begin UpdateGrainPrice(Players[PIdx], Arg1); Got := '-'; end;
          'UnclaimedLand': Got := IntToStr(UnclaimedLand(Players, Arg1));
        else
          begin
            WriteLn('unknown function ', Func);
            Halt(2);
          end;
        end;
    except
      on E: ERealError do Got := 'E' + IntToStr(E.Code);
    end;
    SetLength(After, Num * PlayerSize);
    Move(Save.Players[0], After[0], Length(After));
    { the rule functions never see the header, so the original must not touch it either }
    Got := 'ret=' + Got + ' seedout=' + IntToStr(RandSeed) + ' diff=' + DiffText(Before, After) +
      ' hdiff=-';
    Want := 'ret=' + Field(S, 'ret') + ' seedout=' + Field(S, 'seedout') + ' diff=' + Field(S, 'diff') +
      ' hdiff=' + Field(S, 'hdiff');
    if Got = Want then
      Inc(Pass)
    else
    begin
      Inc(Fail);
      if Fail <= 10 then
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
