{ Headless simulator: play a savegame on, every human just ends the turn.

  ksrsim SAVE TURNS SEED [OUT.KSR]
  ksrsim new:HUMANS:COMPUTERS:LEVEL TURNS SEED [OUT.KSR]

  The second form starts a new game first (NewGame): human i is
  "Spieler<i+1>", male, country i; computer level 1..4; immortality off,
  goods trade and initiative on.

  Runs EndHumanTurn (the original "Runde beenden") TURNS times with the
  default UI answers (dialogs OK, UI functions 0). After each turn one line:
  turn, current player, year, RandSeed and a CRC32 of the player array and
  the game record - the same lines as tools/emu/sim_original.py prints for
  the original. OUT.KSR receives the final state. }
program KsrSim;

{$mode objfpc}{$H+}

uses
  SysUtils, Strings, Crc, KaiserTypes, KaiserDS, KaiserSave, Real48, KaiserUI, Game;

type
  { the answers of the new-game dialogs }
  TSimUI = class(TGameUI)
    Humans, Cpus, Level, NextHuman: Byte;
    function Execute(D: TDialog): SmallInt; override;
  end;

function TSimUI.Execute(D: TDialog): SmallInt;
var
  Name: string;
begin
  Result := 1;
  if D.Name = 'HumanCountDlg' then
    D.Data[$34] := Humans
  else if D.Name = 'ComputerCountDlg' then
  begin
    D.Data[$34] := Cpus;
    if Level > 0 then
      D.Data[$3B] := Level - 1;
  end
  else if D.Name = 'PlayerDataDlg' then
  begin
    { the humans are asked in order }
    Name := 'Spieler' + IntToStr(NextHuman + 1);
    StrPCopy(PChar(@D.Data[$2E]), Name);
    D.Data[$4C] := 0;
    D.Data[$4D] := NextHuman;
    Inc(NextHuman);
  end;
end;

var
  Sim: TSimUI;
  Spec: TStringArray;
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
  Sim := TSimUI.Create;
  UI.Free;
  UI := Sim;
  ResetDataSegment;
  FillChar(Save, SizeOf(Save), 0);
  if Copy(ParamStr(1), 1, 4) = 'new:' then
  begin
    Spec := ParamStr(1).Split(':');
    Sim.Humans := StrToInt(Spec[1]);
    Sim.Cpus := StrToInt(Spec[2]);
    Sim.Level := StrToInt(Spec[3]);
    DS.Game.GoodsTradeEnabled := 1;
    DS.Game.InitiativeEnabled := 1;
  end
  else
  begin
    if LoadSaveGame(ParamStr(1), Save) <> lrOk then
    begin
      WriteLn('cannot load ', ParamStr(1));
      Halt(2);
    end;
    DS.Game := Save.Header;
    DS.Game.GameState := 1;
  end;
  DS.Game.EmailGameQ := 0;
  Turns := StrToInt(ParamStr(2));
  for K := 0 to 9 do
  begin
    { the runtime name tables as the differential tests set them }
    DS.CountryAdjectives[K] := DS.CountryNames[10 + K];
    DS.CpuRulerNames[K] := DS.CountryNames[K];
    DS.CountryNamesRt[K] := DS.CountryNames[K];
  end;
  RandSeed := StrToInt64(ParamStr(3));
  if Sim.Humans > 0 then
  begin
    UI.Reset;
    NewGame(nil, 0, Save.Players);
  end;
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
