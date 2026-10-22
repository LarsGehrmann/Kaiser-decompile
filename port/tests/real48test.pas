{ Differential test: Real48 arithmetic and Random against vectors produced by
  running the original Borland runtime of kaiser.exe in an emulator
  (tools/emu/gen_real48_vectors.py). Usage: real48test real48.vec }
program Real48Test;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, KaiserTypes, Real48;

function HexToR48(const S: string): TReal48;
var
  I: Integer;
begin
  for I := 0 to 5 do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

function R48ToHex(const A: TReal48): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to 5 do
    Result := Result + LowerCase(IntToHex(A[I], 2));
end;

var
  Lines, F: TStringList;
  I, Pass, Fail: Integer;
  Op, Got, Want: string;
  A, B: TReal48;
begin
  Lines := TStringList.Create;
  F := TStringList.Create;
  F.Delimiter := ' ';
  F.StrictDelimiter := True;
  Lines.LoadFromFile(ParamStr(1));
  Pass := 0;
  Fail := 0;
  for I := 0 to Lines.Count - 1 do
  begin
    F.DelimitedText := Lines[I];
    Op := F[0];
    try
      if (Op = 'add') or (Op = 'sub') or (Op = 'mul') or (Op = 'div') or (Op = 'cmp') then
      begin
        A := HexToR48(F[1]);
        B := HexToR48(F[2]);
        Want := F[3];
        try
          if Op = 'add' then Got := R48ToHex(R48Add(A, B))
          else if Op = 'sub' then Got := R48ToHex(R48Sub(A, B))
          else if Op = 'mul' then Got := R48ToHex(R48Mul(A, B))
          else if Op = 'div' then Got := R48ToHex(R48Div(A, B))
          else Got := IntToStr(R48Cmp(A, B));
        except
          on E: ERealError do Got := 'E' + IntToStr(E.Code);
        end;
      end
      else if Op = 'sqrt' then
      begin
        A := HexToR48(F[1]);
        Want := F[2];
        try
          Got := R48ToHex(R48Sqrt(A));
        except
          on E: ERealError do Got := 'E' + IntToStr(E.Code);
        end;
      end
      else if Op = 'fromlong' then
      begin
        Want := F[2];
        Got := R48ToHex(R48FromLong(StrToInt(F[1])));
      end
      else if (Op = 'round') or (Op = 'trunc') then
      begin
        A := HexToR48(F[1]);
        Want := F[2];
        try
          if Op = 'round' then Got := IntToStr(R48Round(A))
          else Got := IntToStr(R48Trunc(A));
        except
          on E: ERealError do Got := 'E' + IntToStr(E.Code);
        end;
      end
      else if Op = 'random' then
      begin
        RandSeed := StrToInt64(F[1]);
        Got := IntToStr(Random(StrToInt(F[2])));
        Got := Got + ' ' + IntToStr(RandSeed);
        Want := F[3] + ' ' + F[4];
      end
      else if Op = 'randreal' then
      begin
        RandSeed := StrToInt64(F[1]);
        Got := R48ToHex(RandomReal) ;
        Got := Got + ' ' + IntToStr(RandSeed);
        Want := F[2] + ' ' + F[3];
      end
      else
        Continue;
    except
      on E: Exception do Got := 'exception ' + E.Message;
    end;
    if Got = Want then
      Inc(Pass)
    else
    begin
      Inc(Fail);
      if Fail <= 15 then
        WriteLn('MISMATCH ', Lines[I], '  got ', Got);
    end;
  end;
  WriteLn(Pass, ' passed, ', Fail, ' failed');
  if Fail > 0 then
    Halt(1);
end.
