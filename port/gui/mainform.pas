{ The main window (segment 1, KaiserWindow, VMT DS:01a4): the original menu
  (MAINMENU from kaiser.exe) and its commands. The game state is the
  savegame record: header (DS.Game) and the player array. }
unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Menus, Dialogs, ExtCtrls, LCLType,
  NERes, KaiserTypes, KaiserDS, KaiserSave, KaiserUI, Turn, Game, KaiserLCL;

type
  TKaiserForm = class(TForm)
  private
    FMenu: TMainMenu;
    FSave: TSaveGame;
    FSaveFile: string;
    procedure BuildMenu;
    procedure AddItems(Into: TMenuItem; const M: TMenuTemplate);
    procedure MenuClick(Sender: TObject);
    function FindItem(Id: Word): TMenuItem;
    procedure UpdateMenu;
    procedure FormPaint(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Command(Id: Word);
    procedure EnableCommand(Id: Word; On: Boolean);
    procedure CmNeuesSpiel;
    procedure CmFileOpen;
    procedure CmSpeichern(AskName: Boolean);
    procedure CmBeenden;
  end;

var
  KaiserForm: TKaiserForm;

implementation

const
  { the commands of the "Aktionen", "Informationen" and "Berichte" menus are
    the Do_* functions of segments 8 and 9 (milestone 7b) }
  CmdNew = 101; CmdOpen = 102; CmdSave = 103; CmdSaveAs = 104; CmdExit = 24340;
  CmdEndTurn = 401; CmdInfo = 502;

constructor TKaiserForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Kaiser';
  Width := 800;
  Height := 600;
  Position := poScreenCenter;
  Color := DialogBackground;
  OnPaint := @FormPaint;
  FillChar(FSave, SizeOf(FSave), 0);
  BuildMenu;
  UpdateMenu;
end;

procedure TKaiserForm.AddItems(Into: TMenuItem; const M: TMenuTemplate);
var
  I: Integer;
  MI: TMenuItem;
begin
  for I := 0 to High(M.Items) do
  begin
    MI := TMenuItem.Create(Self);
    if (M.Items[I].Flags and $10 = 0) and (M.Items[I].Text = '') and (M.Items[I].Id = 0) then
      MI.Caption := '-'
    else
      MI.Caption := Utf8(M.Items[I].Text);
    MI.Tag := M.Items[I].Id;
    MI.Checked := M.Items[I].Flags and $8 <> 0;           { MF_CHECKED }
    if M.Items[I].Flags and $10 <> 0 then
      AddItems(MI, M.Items[I])
    else
      MI.OnClick := @MenuClick;
    Into.Add(MI);
  end;
end;

procedure TKaiserForm.BuildMenu;
begin
  FMenu := TMainMenu.Create(Self);
  AddItems(FMenu.Items, Exe.Menu('MAINMENU'));
  Menu := FMenu;
end;

function TKaiserForm.FindItem(Id: Word): TMenuItem;

  function Search(M: TMenuItem): TMenuItem;
  var
    I: Integer;
  begin
    for I := 0 to M.Count - 1 do
    begin
      if (M.Items[I].Tag = Id) and (M.Items[I].Count = 0) then
        Exit(M.Items[I]);
      Result := Search(M.Items[I]);
      if Result <> nil then
        Exit;
    end;
    Result := nil;
  end;

begin
  Result := Search(FMenu.Items);
end;

procedure TKaiserForm.EnableCommand(Id: Word; On: Boolean);
var
  MI: TMenuItem;
begin
  MI := FindItem(Id);
  if MI <> nil then
    MI.Enabled := On;
end;

procedure TKaiserForm.UpdateMenu;
var
  Running: Boolean;
begin
  Running := DS.Game.GameState = 1;
  EnableCommand(CmdSave, Running);
  EnableCommand(CmdSaveAs, Running);
  EnableCommand(CmdEndTurn, Running);
end;

procedure TKaiserForm.MenuClick(Sender: TObject);
begin
  Command(TMenuItem(Sender).Tag);
end;

procedure TKaiserForm.Command(Id: Word);
var
  D: TDialog;
begin
  case Id of
    CmdNew: CmNeuesSpiel;
    CmdOpen: CmFileOpen;
    CmdSave: CmSpeichern(FSaveFile = '');
    CmdSaveAs: CmSpeichern(True);
    CmdEndTurn: CmBeenden;
    CmdExit: Close;
    CmdInfo:
      begin
        D := UI.Dialog('KaiserDlg', $3364, [APtr(Self), AStr('INFO')]);
        UI.Execute(D);
        UI.Done(D, 1);
      end;
  else
    Application.MessageBox(PChar('Dieser Befehl ist noch nicht portiert (Befehl ' +
      IntToStr(Id) + ').'), 'Kaiser', MB_OK);
  end;
  UpdateMenu;
  Invalidate;
end;

procedure TKaiserForm.CmNeuesSpiel;
begin
  NewGame(Self, 0, FSave.Players);
  FSaveFile := '';
end;

procedure TKaiserForm.CmFileOpen;
var
  OD: TOpenDialog;
  S: TSaveGame;
begin
  { 1000:0e3c: a running game is given up only after asking }
  if (DS.Game.GameState = 1) and
     (Application.MessageBox('Das laufende Spiel abbrechen?', 'Kaiser', MB_YESNO) <> IDYES) then
    Exit;
  DS.Game.GameState := 0;
  OD := TOpenDialog.Create(Self);
  try
    OD.Filter := 'Kaiser-Spielstand (*.ksr)|*.ksr;*.KSR';
    if not OD.Execute then
      Exit;
    if LoadSaveGame(OD.FileName, S) <> lrOk then
    begin
      Application.MessageBox(PChar('Kann Datei ' + OD.FileName + ' nicht laden.'), 'Kaiser', MB_OK);
      Exit;
    end;
    FSave := S;
    FSaveFile := OD.FileName;
    DS.Game := FSave.Header;
    if DS.Game.EmailGameQ = 0 then
    begin
      DS.Game.GameState := 6;
      Invalidate;
      ShowStartTurnDialog(Self, FSave.Players[DS.Game.CurrentPlayer], DS.Game.CurrentPlayer,
        DS.Game.Year);
      DS.Game.GameState := 1;
    end;
  finally
    OD.Free;
  end;
end;

procedure TKaiserForm.CmSpeichern(AskName: Boolean);
var
  SD: TSaveDialog;
begin
  if AskName then
  begin
    SD := TSaveDialog.Create(Self);
    try
      SD.Filter := 'Kaiser-Spielstand (*.ksr)|*.ksr';
      SD.DefaultExt := 'ksr';
      if not SD.Execute then
        Exit;
      FSaveFile := SD.FileName;
    finally
      SD.Free;
    end;
  end;
  FSave.Header := DS.Game;
  WriteSaveGame(FSaveFile, FSave);
end;

procedure TKaiserForm.CmBeenden;
begin
  if DS.Game.GameState <> 1 then
    Exit;
  EndHumanTurn(Self, 0, FSave.Players);
end;

procedure TKaiserForm.FormPaint(Sender: TObject);
var
  Logo: TBitmap;
  P: ^TPlayer;
  Y: Integer;

  procedure Line(const S: string);
  begin
    Canvas.TextOut(20, Y, S);
    Inc(Y, Canvas.TextHeight(S) + 4);
  end;

begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  if DS.Game.GameState <> 1 then
  begin
    Logo := ResBitmap('BIGLOGO');
    if Logo <> nil then
      Canvas.Draw((ClientWidth - Logo.Width) div 2, (ClientHeight - Logo.Height) div 2, Logo);
    Exit;
  end;
  { (the original status display is milestone 7d) }
  P := @FSave.Players[DS.Game.CurrentPlayer];
  Canvas.Font.Size := 12;
  Y := 20;
  Line(Utf8(PChar(@P^.Name)) + ' - Jahr ' + IntToStr(DS.Game.Year));
  Line('Taler: ' + IntToStr(P^.Taler));
  Line('Land: ' + IntToStr(P^.Land) + ' Hufen');
  Line('Bevoelkerung: ' + IntToStr(P^.Population));
  Line('Ruhm: ' + IntToStr(P^.Fame));
end;

end.
