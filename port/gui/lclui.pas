{ The GUI's TGameUI: the logic's dialogs become the dialog types of
  KaiserDlgs on their original templates; the whole UI functions (sounds,
  message boxes ...) are done here or, not yet ported, reported. }
unit LclUI;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, LCLType, NERes, KaiserTypes, KaiserDS, KaiserUI, Real48,
  KaiserLCL, KaiserDlgs, Rules, Actions, Annals, Troops, Intel, Battle, War, BattleForm;

type
  TLclUI = class(TGameUI)
  private
    FForms: array of TKaiserDialog;
    function FormOf(D: TDialog): TKaiserDialog;
  public
    MainForm: TForm;
    Players: PPlayers;            { the game's players (Victory) }
    function Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog; override;
    function Execute(D: TDialog): SmallInt; override;
    procedure Done(D: TDialog; Flag: Word); override;
    function ExecDialog(D: TDialog): SmallInt; override;
    function Call(const Name: string; const Args: array of TUIArg): SmallInt; override;
  end;

implementation

uses
  Process;

{ the port writes its annals and records next to its KAISER.INI; it reads
  the original's next to kaiser.exe until it has its own }
function OwnDataFile(const Name: string): string;
begin
  Result := ExtractFilePath(OwnSettingsFile) + Name;
end;

function DataFile(const Name: string): string;
begin
  Result := OwnDataFile(Name);
  if not FileExists(Result) then
    Result := ExtractFilePath(FindExe) + Name;
end;

function ArgText(const A: TUIArg): RawByteString;
begin
  if (A.Kind = uaStr) and (PtrUInt(A.P) >= $10000) then
    Result := PChar(A.P)
  else
    Result := '';
end;

{ PlaySound (1070:0002): WAVEDATA resource N with afplay when "Krach &
  Geschrei" is on; Async = 0 (the battle) waits for its end (sndPlaySound
  SND_SYNC): the battle's animations show their frames meanwhile. Without
  sound the original counts 500,000 loops instead. (Silent under the
  autopilot.) }
procedure PlayWave(N: Word; Async: Boolean);
var
  Data: TBytes;
  FN: string;
  S: TFileStream;
begin
  if not Async and (ActiveBattle <> nil) then
    ActiveBattle.Flush;
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
    Exit;
  if (DS.OptSound = 0) or (N = 0) then
  begin
    if not Async then
      Sleep(100);
    Exit;
  end;
  Data := Exe.FindNamedType('WAVEDATA', '', N);
  if Data = nil then
    Exit;
  FN := GetTempDir + 'kaiser_sound_' + IntToStr(N) + '.wav';
  if not FileExists(FN) then
  begin
    S := TFileStream.Create(FN, fmCreate);
    try
      S.WriteBuffer(Data[0], Length(Data));
    finally
      S.Free;
    end;
  end;
  with TProcess.Create(nil) do
  try
    Executable := '/usr/bin/afplay';
    Parameters.Add(FN);
    if Async then
      Options := []
    else
      Options := [poWaitOnExit];
    Execute;
  finally
    Free;
  end;
end;

function TLclUI.FormOf(D: TDialog): TKaiserDialog;
var
  I: Integer;
begin
  for I := 0 to High(FForms) do
    if (FForms[I] <> nil) and (FForms[I].D = D) then
      Exit(FForms[I]);
  Result := nil;
end;

function TLclUI.Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog;
var
  I: Integer;
  TplName: RawByteString;
  F: TKaiserDialog;
begin
  Result := inherited Dialog(Name, VMT, Args);
  if (Length(Args) < 2) or (Name = 'TButton') then
    Exit;
  if (Name = 'KaiserDlg') and (VMT = 0) then
    Exit;                        { BattleInit: the battle window (Battle_Execute) }
  TplName := ArgText(Args[1]);
  if (TplName = '') or (Exe.Find(RT_DIALOG, TplName) = nil) then
    Exit;
  F := DialogClassOf(Name).CreateFromTemplate(MainForm, Exe.Dialog(TplName));
  F.D := Result;
  SetLength(F.Args, Length(Args));
  for I := 0 to High(Args) do
    F.Args[I] := Args[I];
  SetLength(FForms, Length(FForms) + 1);
  FForms[High(FForms)] := F;
end;

function TLclUI.Execute(D: TDialog): SmallInt;
var
  F: TKaiserDialog;
begin
  F := FormOf(D);
  if F = nil then
    Exit(inherited Execute(D));
  Result := F.Run;
  if ActiveBattle <> nil then
    ActiveBattle.NeedPaint := True;          { the battle window gets a WM_PAINT }
end;

procedure TLclUI.Done(D: TDialog; Flag: Word);
var
  I: Integer;
begin
  for I := 0 to High(FForms) do
    if (FForms[I] <> nil) and (FForms[I].D = D) then
      FreeAndNil(FForms[I]);
end;

function TLclUI.ExecDialog(D: TDialog): SmallInt;
begin
  Result := Execute(D);
end;

function TLclUI.Call(const Name: string; const Args: array of TUIArg): SmallInt;
var
  F: TKaiserDialog;
begin
  Result := 0;
  { the ported menu actions the turn calls }
  if Name = 'Do_KornVerteilen' then
    Do_KornVerteilen(Args[0].P, PPlayer(Args[1].P)^, Byte(Args[2].V))
  else if Name = 'Do_LandHandeln' then
    Do_LandHandeln(Args[0].P, PPlayers(Args[1].P)^, Byte(Args[2].V), Byte(Args[3].V))
  else if Name = 'Do_Gebaeude' then
    Do_Gebaeude(Args[0].P, PPlayers(Args[1].P)^, Byte(Args[2].V), Byte(Args[3].V))
  else if Name = 'Do_HandelMitGuetern' then
    Do_HandelMitGuetern(Args[0].P, PPlayer(Args[1].P)^)
  else if Name = 'Do_TruppenAufstellen' then
    Troops.Do_TruppenAufstellen(Args[0].P, PPlayer(Args[1].P)^, Byte(Args[2].V))
  else if Name = 'Do_Geheimdienst' then
    Intel.Do_Geheimdienst(Args[0].P, PPlayers(Args[1].P)^, Byte(Args[2].V), Byte(Args[3].V),
      Word(Args[4].V))
  else if (Name = 'TroopDlg_DrawHeer') or (Name = 'TroopDlg_DrawGarde') then
  begin
    F := FormOf(FindDialog(Args[1].P));
    if F is TLogicDialog then
      TLogicDialog(F).DrawTroops;
  end
  else if Name = 'Victory' then
    Annals.Victory(Args[0].P, Players^)
  else if Name = 'Annals_Load' then
    Result := Ord(AnnalsLoad(DataFile('KAISER.SCO'), TAnnals(Args[0].P^)))
  else if Name = 'Annals_Save' then
    AnnalsSave(OwnDataFile('KAISER.SCO'), TAnnals(Args[0].P^))
  else if Name = 'Records_Load' then
    RecordsLoad(DataFile('KAISER.REC'), TRecords(Args[0].P^))
  else if Name = 'Records_Save' then
    RecordsSave(OwnDataFile('KAISER.REC'), TRecords(Args[0].P^))
  else if Name = 'PlaySound' then
    PlayWave(Word(Args[0].V), Args[1].V <> 0)
  { the battle window (BattleForm) }
  else if Name = 'Battle_Execute' then
    Result := RunBattle(Args[0].P)
  else if Copy(Name, 1, 7) = 'Battle_' then
  begin
    if (ActiveBattle = nil) or (Length(Args) = 0) or (ActiveBattle.B <> Args[High(Args)].P) then
      Exit;
    if Name = 'Battle_DrawCell' then
      ActiveBattle.DrawCell(SmallInt(Word(Args[0].V)), SmallInt(Word(Args[1].V)), Byte(Args[2].V))
    else if Name = 'Battle_RedrawUnit' then
      ActiveBattle.RedrawUnit(Byte(Args[0].V), Byte(Args[1].V))
    else if Name = 'Battle_DrawUnitStatus' then
      ActiveBattle.DrawUnitStatus(Byte(Args[1].V), Byte(Args[2].V), Byte(Args[3].V))
    else if Name = 'Battle_ClearTargetPanel' then
      ActiveBattle.ClearTargetPanel
    else if Name = 'Battle_EnableButtons' then
      ActiveBattle.EnableButtons(True)
    else if Name = 'Battle_DisableButtons' then
      ActiveBattle.EnableButtons(False);
    { Battle_End: BattleEndCode, the window closes after the message }
  end
  { a computer attacks a human (ResolveWar), the marauders / the Lindwurm }
  else if Name = 'Battle' then
    Result := War.Battle(Args[0].P, PPlayer(Args[1].P)^, PPlayer(Args[2].P)^, Byte(Args[3].V),
      Byte(Args[4].V), Byte(Args[5].V))
  else if Name = 'FightRaiders' then
    Result := War.FightRaiders(Args[0].P, PPlayer(Args[1].P)^, Byte(Args[2].V), Byte(Args[3].V))
  else if Name = 'MessageBox' then
    Result := Application.MessageBox(PChar(Utf8(ArgText(Args[1]))), 'Kaiser', MB_OK)
  else if Name = 'Randomize' then
    Real48.RandSeed := LongInt(GetTickCount64);      { the clock, like Borland's Randomize }
end;

end.
