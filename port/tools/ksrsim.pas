{ Headless simulator: play a savegame on, every human just ends the turn.

  ksrsim SAVE TURNS SEED [OUT.KSR]

  Runs EndHumanTurn (the original "Runde beenden") TURNS times with the
  default UI answers (dialogs OK, UI functions 0). After each turn one line:
  turn, current player, year, RandSeed and a CRC32 of the player array and
  the game record - the same lines as tools/emu/sim_original.py prints for
  the original. OUT.KSR receives the final state. }
program KsrSim;

{$mode objfpc}{$H+}

uses
  SysUtils, Crc, KaiserTypes, KaiserDS, KaiserSave, Real48, KaiserUI, Game;

var
  Save: TSaveGame;
  Turns, Turn, Num, K: Integer;
  C: Cardinal;
  Human, Crowned: Boolean;

begin
  if ParamCount < 3 then
  begin
    WriteLn('usage: ksrsim SAVE TURNS SEED [OUT.KSR]');
    Halt(2);
  end;
  if LoadSaveGame(ParamStr(1), Save) <> lrOk then
  begin
    WriteLn('cannot load ', ParamStr(1));
    Halt(2);
  end;
  Turns := StrToInt(ParamStr(2));
  ResetDataSegment;
  DS.Game := Save.Header;
  DS.Game.GameState := 1;
  DS.Game.EmailGameQ := 0;
  for K := 0 to 9 do
  begin
    { the runtime name tables as the differential tests set them }
    DS.CountryAdjectives[K] := DS.CountryNames[10 + K];
    DS.CpuRulerNames[K] := DS.CountryNames[K];
    DS.CountryNamesRt[K] := DS.CountryNames[K];
  end;
  RandSeed := StrToInt64(ParamStr(3));
  Num := DS.Game.NumPlayers;
  for Turn := 1 to Turns do
  begin
    UI.Reset;
    EndHumanTurn(nil, 0, Save.Players);
    C := crc32(0, nil, 0);
    C := crc32(C, PByte(@Save.Players[0]), Num * PlayerSize);
    C := crc32(C, PByte(@DS.Game), HeaderSize);
    WriteLn(Turn, ' cur=', DS.Game.CurrentPlayer, ' year=', DS.Game.Year, ' seed=', RandSeed,
      ' crc=', LowerCase(IntToHex(C, 8)), ' state=', DS.Game.GameState);
    Human := False;
    Crowned := False;
    for K := 0 to Num - 1 do
    begin
      Human := Human or (Save.Players[K].CpuLevel = 0);
      Crowned := Crowned or (Save.Players[K].Title >= 10);
    end;
    if (DS.Game.GameState <> 1) or Crowned or not Human then
      Break;
  end;
  if ParamCount >= 4 then
  begin
    Save.Header := DS.Game;
    WriteSaveGame(ParamStr(4), Save);
  end;
end.
