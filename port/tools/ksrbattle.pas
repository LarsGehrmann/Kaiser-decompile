{ Headless battle: two players of a savegame fight, the AI plays both sides.

  ksrbattle SAVE ATTACKER DEFENDER CITY SEED [MAXTICKS]

  BattleInit (the attacker's and the defender's Heer as they are in the
  save, CITY 0/1), both sides computer, the state SetupWindow leaves, then
  window timer ticks (WMTimer) until the battle ends. Prints one line:
  end code (10 attacker lost, 11 won, 12 attacker fled, 13 defender fled),
  ticks, units left on both sides, RandSeed and a CRC32 of the battle
  window (offsets 0x2e..0xf9a) - the same line as
  tools/emu/battle_original.py prints for the original. }
program KsrBattle;

{$mode objfpc}{$H+}

uses
  SysUtils, Crc, KaiserTypes, KaiserDS, KaiserSave, Real48, KaiserUI, Battle, War;

var
  Save: TSaveGame;
  A: PBattleArena;
  Att, Def, City: Byte;
  Ticks, MaxTicks: LongInt;
  C: LongWord;
begin
  if ParamCount < 5 then
  begin
    WriteLn('usage: ksrbattle SAVE ATTACKER DEFENDER CITY SEED [MAXTICKS]');
    Halt(2);
  end;
  if LoadSaveGame(ParamStr(1), Save) <> lrOk then
  begin
    WriteLn('cannot load ', ParamStr(1));
    Halt(2);
  end;
  Att := StrToInt(ParamStr(2));
  Def := StrToInt(ParamStr(3));
  City := StrToInt(ParamStr(4));
  RandSeed := StrToInt64(ParamStr(5));
  MaxTicks := 5000;
  if ParamCount >= 6 then
    MaxTicks := StrToInt(ParamStr(6));
  ResetDataSegment;
  DS.Game := Save.Header;
  DS.OptBattleTimer := 400;
  New(A);
  FillChar(A^, SizeOf(A^), 0);
  BattleInit(A^.W, nil, nil, Save.Players[Att], Save.Players[Def], 0, City);
  A^.W.Human[0] := 0;
  A^.W.Human[1] := 0;
  BattleSetupWindow(A^.W);
  BattleEndCode := 0;
  Ticks := 0;
  while (BattleEndCode = 0) and (Ticks < MaxTicks) do
  begin
    WMTimer(A^.W);
    Inc(Ticks);
  end;
  C := crc32(0, nil, 0);
  C := crc32(C, @PByte(@A^.W)[$2E], $F9B - $2E);
  WriteLn(Format('code=%d ticks=%d att=%d def=%d seed=%u crc=%.8x',
    [BattleEndCode, Ticks, A^.W.Side[1].Army1Count, A^.W.Side[0].Army1Count,
     LongWord(RandSeed), C]));
  Dispose(A);
end.
