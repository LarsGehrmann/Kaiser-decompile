{ Tests of the remastered game's fixes of the original's bugs (docs/remastered.md):
  each case is one the original gets wrong or crashes on; the differential
  tests (ruletest) keep checking that everything else is unchanged. }
program FixTest;

{$mode objfpc}{$H+}

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, Ai;

var
  Failed: Integer = 0;

procedure Check(Cond: Boolean; const What: string);
begin
  if not Cond then
  begin
    WriteLn('FAILED: ', What);
    Inc(Failed);
  end;
end;

procedure TestFormatThousands;
var
  Buf: array[0..31] of Char;
begin
  FormatThousands(Buf, 123456789);
  Check(StrComp(Buf, '123,456,789') = 0, 'FormatThousands 9 digits: ' + Buf);
  { the original showed 10-digit numbers empty }
  FormatThousands(Buf, 1234567890);
  Check(StrComp(Buf, '1,234,567,890') = 0, 'FormatThousands 10 digits: ' + Buf);
  FormatThousands(Buf, -2147483647);
  Check(StrComp(Buf, '-2,147,483,647') = 0, 'FormatThousands -10 digits: ' + Buf);
  FormatThousands(Buf, Low(LongInt));
  Check(StrComp(Buf, '-2,147,483,648') = 0, 'FormatThousands min: ' + Buf);
end;

procedure TestUnitRankName;
var
  U: TUnit;
  Buf: array[0..63] of Char;
begin
  FillChar(U, SizeOf(U), 0);
  U.UnitType := 1;
  U.Level := 2;
  UnitRankName(U, Buf);
  Check(StrComp(Buf, DS.RankNames[2]) = 0, 'UnitRankName level 2');
  { an empty slot's garbage level: the original read past the names }
  U.Level := 200;
  UnitRankName(U, Buf);
  Check(StrComp(Buf, DS.RankNames[3]) = 0, 'UnitRankName level 200: ' + Buf);
end;

procedure TestArrangeArmies;
var
  P: TPlayer;
  I: Integer;
  Guard: array[0..63] of Byte;      { (lies next to the sort's stack frame) }
begin
  { a full army: 8 + 9 = 17 units; the original's sort had room for 16 }
  FillChar(Guard, SizeOf(Guard), $5A);
  FillChar(P, SizeOf(P), 0);
  P.Army1Count := 8;
  P.Army2Count := 9;
  for I := 1 to 8 do
  begin
    P.Army1[I].UnitType := 1;
    P.Army1[I].Attack := I;
    P.Army1[I].Defence := 1;
    P.Army1[I].MaxHp := 5;
    P.Army1[I].Hp := 5;
  end;
  for I := 1 to 9 do
  begin
    P.Army2[I].UnitType := 1;
    P.Army2[I].Attack := 10 + I;
    P.Army2[I].Defence := 1;
    P.Army2[I].MaxHp := 5;
    P.Army2[I].Hp := 5;
  end;
  Ai_ArrangeArmies(P, 1);
  Check((P.Army1Count = 8) and (P.Army2Count = 9), 'ArrangeArmies 17: counts');
  { the best eight in the Heer: attack 12..19 }
  for I := 1 to 8 do
    Check(P.Army1[I].Attack >= 12, 'ArrangeArmies 17: Heer unit ' + IntToStr(I));
  Check(Guard[0] = $5A, 'ArrangeArmies 17: stack intact');
end;

begin
  ResetDataSegment;
  TestFormatThousands;
  TestUnitRankName;
  TestArrangeArmies;
  if Failed = 0 then
    WriteLn('fixtest: all passed')
  else
  begin
    WriteLn('fixtest: ', Failed, ' failed');
    Halt(1);
  end;
end.
