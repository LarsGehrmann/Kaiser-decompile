{ The GUI's TGameUI: the logic's dialogs become the dialog types of
  KaiserDlgs on their original templates; the whole UI functions (sounds,
  message boxes ...) are done here or, not yet ported, reported. }
unit LclUI;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, LCLType, NERes, KaiserTypes, KaiserDS, KaiserUI, Real48,
  KaiserLCL, KaiserDlgs, Rules, Actions, Annals, Troops, Intel, GameDialogs;

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
  Id: Word;
begin
  Result := inherited Dialog(Name, VMT, Args);
  if (Length(Args) < 2) or (Name = 'TButton') or (Args[1].Kind <> uaStr) then
    Exit;
  { the template: a name or MAKEINTRESOURCE(id) (the reports of the turn) }
  Id := 0;
  TplName := ArgText(Args[1]);
  if TplName = '' then
    Id := Word(PtrUInt(Args[1].P));
  if ((TplName = '') and (Id = 0)) or (Exe.Find(RT_DIALOG, TplName, Id) = nil) then
    Exit;
  F := DialogClassOf(Name).CreateFromTemplate(MainForm, Exe.DialogRes(PChar(Args[1].P)));
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
  Data: TBytes;
  FN: string;
  S: TFileStream;
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
  else if Name = 'UnitInfoDlg_DrawPortrait' then
  begin
    F := FormOf(FindDialog(Args[1].P));
    if F is TLogicDialog then
      TLogicDialog(F).DrawPortrait(Byte(Args[0].V));
  end
  else if Name = 'DisableButton2' then
  begin
    if FindDialog(Args[0].P) <> nil then
      GameDialogs.DisableButton2(FindDialog(Args[0].P));
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
  begin
    { WAVEDATA resource n, played by afplay (sndPlaySound, asynchronous),
      when "Krach & Geschrei" is on }
    if DS.OptSound = 0 then
      Exit;
    Data := Exe.FindNamedType('WAVEDATA', '', Word(Args[0].V));
    if Data = nil then
      Exit;
    FN := GetTempDir + 'kaiser_sound_' + IntToStr(Args[0].V) + '.wav';
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
      Options := [];
      Execute;
    finally
      Free;
    end;
  end
  else if Name = 'MessageBox' then
    Result := Application.MessageBox(PChar(Utf8(ArgText(Args[1]))), 'Kaiser', MB_OK)
  else if Name = 'Randomize' then
    Real48.RandSeed := LongInt(GetTickCount64);      { the clock, like Borland's Randomize }
end;

end.
