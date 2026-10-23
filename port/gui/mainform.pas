{ The main window (segment 1, KaiserWindow, VMT DS:01a4): the original menu
  (MAINMENU from kaiser.exe) and its commands. The game state is the
  savegame record: header (DS.Game) and the player array. }
unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Menus, Dialogs, ExtCtrls, LCLType, LCLIntf,
  NERes, MainPaint, KaiserTypes, KaiserDS, KaiserSave, KaiserUI, Turn, Game, Actions, KaiserLCL, KaiserIni, Annals, Troops, Intel, Census, Reports, Real48;

type
  TKaiserForm = class(TForm)
  public
    FSave: TSaveGame;
  private
    FMenu: TMainMenu;
    FSaveFile: string;
    FToolbar: TKaiserToolbar;
    FBuffer: TBitmap;
    procedure BuildMenu;
    procedure AddItems(Into: TMenuItem; const M: TMenuTemplate);
    procedure MenuClick(Sender: TObject);
    function FindItem(Id: Word): TMenuItem;
    procedure UpdateMenu;
    procedure CheckCommand(Id: Word; On: Boolean);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormPaint(Sender: TObject);
    procedure AutoStart(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure ApplyWindowSize;
    procedure SetResolution(R: Byte);
    procedure UpdateWindowState;
    procedure HandleMapClick(Dbl: Boolean; X, Y: Integer);
    procedure CmHilfe;
    procedure MainShots(const Dir, Prefix: string);
    procedure AutoWar(const Cmd: string);
  public
    { KaiserWindow::Paint (1000:0b5d) without its menu/caption side effects:
      the client area (without the toolbar) as the original paints it }
    procedure RenderMain(C: TCanvas);
    { the whole client area with the toolbar, for snapshots }
    procedure RenderWindow(B: TBitmap);
    function LoadGameFile(const FileName: string): Boolean;
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

procedure TKaiserForm.AutoStart(Sender: TObject);
var
  T: Integer;
  Cmds: TStringList;
  Shots, LoadFile: string;
begin
  { KAISER_AUTOPILOT with KAISER_AUTOGAME=TURNS: a new game, the menu
    commands of KAISER_AUTOMENU (e.g. 201,203), TURNS turns.
    KAISER_LOAD=FILE (or a savegame as the first argument, like the
    original's LoadFromCommandLine 1000:1136) loads it instead.
    KAISER_MAINSHOT=DIR saves the main window as DIR/title_WxH.png before
    and DIR/game_WxH.png after, for each resolution, then closes }
  TTimer(Sender).Enabled := False;
  Shots := GetEnvironmentVariable('KAISER_MAINSHOT');
  if Shots <> '' then
    MainShots(Shots, 'title');
  LoadFile := GetEnvironmentVariable('KAISER_LOAD');
  if LoadFile = '' then
    LoadFile := GetEnvironmentVariable('KAISER_AUTOLOAD');
  if (LoadFile = '') and (ParamCount > 0) and (Copy(ParamStr(1), 1, 1) <> '-') and
     FileExists(ParamStr(1)) then
    LoadFile := ParamStr(1);
  if LoadFile <> '' then
  begin
    { autosave.ksr and boss.ksr are not kept as the file to save to }
    if LoadGameFile(LoadFile) and
       ((CompareText(ExtractFileName(LoadFile), 'autosave.ksr') = 0) or
        (CompareText(ExtractFileName(LoadFile), 'boss.ksr') = 0)) then
      FSaveFile := '';
  end
  else if GetEnvironmentVariable('KAISER_AUTOGAME') <> '' then
    CmNeuesSpiel;
  if GetEnvironmentVariable('KAISER_AUTOGAME') <> '' then
  begin
    Invalidate;
    Cmds := TStringList.Create;
    try
      Cmds.CommaText := GetEnvironmentVariable('KAISER_AUTOMENU');
      for T := 0 to Cmds.Count - 1 do
        if (Copy(Cmds[T], 1, 4) = 'war:') or (Copy(Cmds[T], 1, 5) = 'raid:') then
          AutoWar(Cmds[T])
        else
          Command(StrToIntDef(Cmds[T], 0));
    finally
      Cmds.Free;
    end;
    for T := 1 to StrToIntDef(GetEnvironmentVariable('KAISER_AUTOGAME'), 0) do
      if DS.Game.GameState = 1 then
        CmBeenden;
  end;
  if Shots <> '' then
    MainShots(Shots, 'game');
  if (Shots <> '') or (GetEnvironmentVariable('KAISER_AUTOGAME') <> '') then
    Close;
end;

procedure TKaiserForm.MainShots(const Dir, Prefix: string);
var
  R, Orig: Byte;
  B: TBitmap;
  P: TPortableNetworkGraphic;
begin
  Orig := DS.OptResolution;
  ForceDirectories(Dir);
  for R := 0 to 2 do
  begin
    Command(610 + R);
    Application.ProcessMessages;
    B := TBitmap.Create;
    P := TPortableNetworkGraphic.Create;
    try
      RenderWindow(B);
      P.Assign(B);
      P.SaveToFile(IncludeTrailingPathDelimiter(Dir) + Format('%s_%dx%d.png',
        [Prefix, ResolutionWidth, ResolutionHeight]));
    finally
      P.Free;
      B.Free;
    end;
    { the form as LCL paints it (FormPaint and the toolbar control) }
    B := GetFormImage;
    P := TPortableNetworkGraphic.Create;
    try
      P.Assign(B);
      P.SaveToFile(IncludeTrailingPathDelimiter(Dir) + Format('%s_live_%dx%d.png',
        [Prefix, ResolutionWidth, ResolutionHeight]));
    finally
      P.Free;
      B.Free;
    end;
  end;
  Command(610 + Orig);
end;

procedure TKaiserForm.RenderWindow(B: TBitmap);
begin
  B.SetSize(MainClientWidth, MainClientHeight);
  UpdateWindowState;
  RenderMain(B.Canvas);
  FToolbar.PaintTo(B.Canvas, MainClientHeight);
end;

procedure TKaiserForm.RenderMain(C: TCanvas);
begin
  { the class background: BLACK_BRUSH (KaiserWindow::GetWindowClass) }
  C.Brush.Style := bsSolid;
  C.Brush.Color := clBlack;
  C.FillRect(0, 0, MainClientWidth, MainClientHeight);
  case DS.Game.GameState of
    0: PaintTitleScreen(C);
    1: DrawPlayerBuildings(C, FSave.Players[DS.Game.CurrentPlayer], DS.Game.Year);
    2, 6, 7: PaintPatternBackground(C);
  end;
end;

procedure TKaiserForm.UpdateWindowState;
var
  Buf: array[0..127] of Char;
  S: string;
begin
  { the menu/toolbar and caption part of KaiserWindow::Paint }
  case DS.Game.GameState of
    0, 2, 6, 7:
      begin
        FToolbar.EnableTools(LastGameTool(FToolbar), False);
        S := Utf8(DSText($02CE));                  { 'Kaiser' }
      end;
    1:
      begin
        FToolbar.EnableTools(LastGameTool(FToolbar), True);
        FormatPlayerTitle(FSave.Players[DS.Game.CurrentPlayer], Buf, 1, 1);
        S := Utf8(Buf);
      end;
  else
    S := Caption;
  end;
  if Caption <> S then
    Caption := S;
end;

procedure TKaiserForm.ApplyWindowSize;
begin
  { SetupWindow / Cm640x480 (1000:0268 / 1ed4): the window by the
    resolution, the client height ResolutionHeight - 40 }
  ClientWidth := MainClientWidth;
  ClientHeight := MainClientHeight;
  FToolbar.SetBounds(0, 0, FToolbar.BarWidth - 1, ClientHeight);
end;

procedure TKaiserForm.SetResolution(R: Byte);
begin
  { Cm640x480 / Cm800x600 load the matching tool set; the hidden 1024x768
    (CmResolution1024 1000:1fc8) keeps the current one }
  if DS.OptResolution = R then
    Exit;
  DS.OptResolution := R;
  case R of
    0: FToolbar.SetResource(DSText($0224));       { KAISERTOOLS_640 }
    1: FToolbar.SetResource(DSText($0234));       { KAISERTOOLS_800 }
  end;
  ApplyWindowSize;
  Invalidate;
end;

procedure TKaiserForm.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  { WMLButtonDblClk / WMRButtonDown (1000:039d / 03bb) }
  if (Button = mbLeft) and (ssDouble in Shift) then
    HandleMapClick(True, X, Y)
  else if Button = mbRight then
    HandleMapClick(False, X, Y);
end;

procedure TKaiserForm.HandleMapClick(Dbl: Boolean; X, Y: Integer);
var
  P: ^TPlayer;
  OX, OY, I: Integer;
begin
  { 1000:03d9, in client coordinates (the picture starts at x = 32); a
    right click on a unit shows it (ShowUnitLookDlg 1040:330f). Unlike the
    original nothing reacts without a running game }
  if DS.Game.GameState <> 1 then
    Exit;
  P := @FSave.Players[DS.Game.CurrentPlayer];
  OX := PSmallInt(@PByte(@DS)[$0270 + 2 * DS.OptResolution])^;
  OY := PSmallInt(@PByte(@DS)[$0276 + 2 * DS.OptResolution])^;
  if (P^.ArmyAway = 0) and (Y >= ResolutionHeight - $4C) and (Y <= ResolutionHeight - $28) then
  begin
    I := (ResolutionWidth - $90 - X) div 32;
    if (I >= 0) and (I < P^.Army1Count) then
      if Dbl then
        Command(211)                                { Truppen aufstellen }
      else
        ShowUnitLookDlg(Self, P^, 1, P^.Army1Count - I);
    Exit;
  end;
  if not Dbl and (X >= (OX + 7) * 32) and (X < (OX + 10) * 32) and
     (Y >= (OY + 5) * 32) and (Y < (OY + 8) * 32) then
  begin
    { the Garde in the town: the 3 x 3 cells DS:0266 }
    I := PByte(@DS)[$0266 + ((X - (OX + 7) * 32) div 32) * 3 + (Y - (OY + 5) * 32) div 32];
    if I <= P^.Army2Count then
      ShowUnitLookDlg(Self, P^, 2, I);
    Exit;
  end;
  if not Dbl then
    Exit;
  if (P^.Granaries > 0) and (X >= (OX + 9) * 32) and (X < (OX + 10) * 32) and
     (Y >= (OY + 4) * 32 - 16) and (Y < (OY + 5) * 32 - 16) then
    Command(201);                                   { Korn verteilen }
  if (DS.Game.GoodsTradeEnabled <> 0) and (P^.Warehouses > 0) and (X >= (OX + 7) * 32) and
     (X < (OX + 8) * 32) and (Y >= (OY + 8) * 32 + 16) and (Y < (OY + 9) * 32 + 16) then
    Command(205);                                   { Handel mit Guetern }
  if (P^.Smithies > 0) and (X >= (OX + 8) * 32) and (X < (OX + 9) * 32) and
     (Y >= (OY + 7) * 32) and (Y < (OY + 8) * 32) then
    Command(306);                                   { Hofschmiede }
  if (P^.Taverns > 0) and (X >= (OX + 8) * 32) and (X < (OX + 9) * 32) and
     (Y >= (OY + 5) * 32) and (Y < (OY + 6) * 32) then
    Command(224);                                   { Sabotage }
end;

procedure TKaiserForm.CmHilfe;
var
  Dir, F: string;
  I: Integer;
begin
  { CmHilfe / CmUeberDieHilfe (1000:38ed / 38cf) call WinHelp on
    KAISER.HLP; here the manual converted by tools/help_to_md.py }
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
    Exit;
  Dir := ExtractFilePath(ParamStr(0));
  F := '';
  for I := 0 to 6 do
  begin
    if FileExists(Dir + 'docs/manual.md') then
    begin
      F := ExpandFileName(Dir + 'docs/manual.md');
      Break;
    end;
    Dir := Dir + '../';
  end;
  if F <> '' then
    OpenDocument(F)
  else
    Application.MessageBox('Die Hilfe (KAISER.HLP) ist in dieser Fassung nicht enthalten; ' +
      'docs/manual.md wurde nicht gefunden.', 'Kaiser', MB_OK);
end;

{ KAISER_AUTOMENU item war:A:D: player A (a computer) attacks D as in
  NextPlayer (ResolveWar: the UI call 'Battle'); raid:P:M: the marauders
  (M = 1) or the Lindwurm (2) attack P (the UI call 'FightRaiders' of the
  turn start) }
procedure TKaiserForm.AutoWar(const Cmd: string);
var
  Parts: TStringList;
  Cur: Byte;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ':';
    Parts.DelimitedText := Cmd;
    if Parts.Count < 3 then
      Exit;
    if Parts[0] = 'raid' then
    begin
      UI.Call('FightRaiders', [APtr(Self), APtr(@FSave.Players[StrToInt(Parts[1])]),
        AByte(StrToInt(Parts[1])), AByte(StrToInt(Parts[2]))]);
      Exit;
    end;
    Cur := DS.Game.CurrentPlayer;
    DS.Game.CurrentPlayer := StrToInt(Parts[1]);
    ResolveWar(Self, FSave.Players, StrToInt(Parts[2]));
    DS.Game.CurrentPlayer := Cur;
  finally
    Parts.Free;
  end;
end;

constructor TKaiserForm.Create(AOwner: TComponent);
var
  Tm: TTimer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Kaiser';
  BorderStyle := bsSingle;                        { no thick frame, no maximize box }
  BorderIcons := [biSystemMenu, biMinimize];
  Position := poScreenCenter;
  Color := clBlack;
  OnPaint := @FormPaint;
  OnClose := @FormClose;
  OnMouseDown := @FormMouseDown;
  FillChar(FSave, SizeOf(FSave), 0);
  FBuffer := TBitmap.Create;
  { the toolbar KAISERTOOLS_640 / _800, docked on the left (1000:0045) }
  FToolbar := TKaiserToolbar.Create(Self);
  FToolbar.Parent := Self;
  if DS.OptResolution = 0 then
    FToolbar.SetResource(DSText($0224))
  else
    FToolbar.SetResource(DSText($0234));
  FToolbar.OnCommand := @Command;
  FToolbar.EnableTools(LastGameTool(FToolbar), False);    { SetupWindow }
  ApplyWindowSize;
  BuildMenu;
  UpdateMenu;
  if (GetEnvironmentVariable('KAISER_AUTOGAME') <> '') or
     (GetEnvironmentVariable('KAISER_MAINSHOT') <> '') or
     (GetEnvironmentVariable('KAISER_LOAD') <> '') or
     ((ParamCount > 0) and (Copy(ParamStr(1), 1, 1) <> '-')) then
  begin
    Tm := TTimer.Create(Self);
    Tm.Interval := 200;
    Tm.OnTimer := @AutoStart;
  end;
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
    { the usual macOS shortcuts for the file commands }
    case MI.Tag of
      101: MI.ShortCut := ShortCut(VK_N, [ssMeta]);         { Neues Spiel }
      102: MI.ShortCut := ShortCut(VK_O, [ssMeta]);         { Öffnen }
      103: MI.ShortCut := ShortCut(VK_S, [ssMeta]);         { Speichern }
      401: MI.ShortCut := ShortCut(VK_E, [ssMeta]);         { Runde beenden }
    end;
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

procedure TKaiserForm.CheckCommand(Id: Word; On: Boolean);
var
  MI: TMenuItem;
begin
  MI := FindItem(Id);
  if MI <> nil then
    MI.Checked := On;
end;

procedure TKaiserForm.UpdateMenu;
var
  Running: Boolean;
  I: Integer;
begin
  { Menu_EnableGameCommands / Menu_DisableGameCommands (1060:006c / 0104):
    the 31 game commands of DS:3e4c }
  Running := DS.Game.GameState = 1;
  for I := 0 to 30 do
    EnableCommand(PWord(@PByte(@DS)[$3E4C + 2 * I])^, Running);
  EnableCommand(CmdSave, Running);
  EnableCommand(CmdSaveAs, Running);
  EnableCommand(CmdEndTurn, Running);
  { UpdateSettingsMenu (1060:019c) }
  CheckCommand(601, DS.OptAutosave <> 0);
  CheckCommand(602, DS.OptSound <> 0);
  CheckCommand(603, DS.OptMusic <> 0);
  for I := 0 to 2 do
    CheckCommand(610 + I, DS.OptResolution = I);
  { Menu_UpdateReportChecks (1060:0254) }
  if Running then
    for I := 0 to 7 do
      CheckCommand(701 + I, FSave.Players[DS.Game.CurrentPlayer].ReportFlags and (1 shl I) <> 0);
end;

procedure TKaiserForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  WriteSettings(OwnSettingsFile);
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
    201:                                        { CmKornVerteilen 1000:1598 }
      if DS.Game.GameState = 1 then
      begin
        Do_KornVerteilen(Self, FSave.Players[DS.Game.CurrentPlayer], 0);
        Invalidate;
      end;
    202:                                        { CmLandHandeln 1000:15d7 }
      if DS.Game.GameState = 1 then
      begin
        Do_LandHandeln(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    204:                                        { CmSteuernFestsetzen 1000:164b }
      if DS.Game.GameState = 1 then
      begin
        Do_SteuernFestsetzen(Self, 0, FSave.Players[DS.Game.CurrentPlayer]);
        Invalidate;
      end;
    205:                                        { CmHandelMitGuetern 1000:168c }
      if (DS.Game.GameState = 1) and (DS.Game.GoodsTradeEnabled <> 0) then
      begin
        Do_HandelMitGuetern(Self, FSave.Players[DS.Game.CurrentPlayer]);
        Invalidate;
      end;
    213:                                        { CmManoeverAbhalten 1000:18fe }
      if DS.Game.GameState = 1 then
      begin
        Do_ManoeverAbhalten(Self, FSave.Players[DS.Game.CurrentPlayer], DS.Game.CurrentPlayer);
        Invalidate;
      end;
    301:                                        { CmDemographischeDaten 1000:1b70 }
      if DS.Game.GameState = 1 then
        Do_DemographischeDaten(Self, 0, FSave.Players[DS.Game.CurrentPlayer]);
    302:                                        { CmFinanzhaushalt 1000:1b9f }
      if DS.Game.GameState = 1 then
      begin
        Do_Finanzhaushalt(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    303:                                        { CmKarriereberatung 1000:1bd9 }
      if DS.Game.GameState = 1 then
        Do_Karriereberatung(Self, FSave.Players[DS.Game.CurrentPlayer]);
    304:                                        { CmInternationalerVergleich 1000:1c42 }
      if DS.Game.GameState = 1 then
        Do_InternationalerVergleich(Self, FSave.Players, DS.Game.NumPlayers);
    311:                                        { CmWirtschaft 1000:1cf0 }
      if DS.Game.GameState = 1 then
        Do_Wirtschaft(Self, FSave.Players[DS.Game.CurrentPlayer]);
    312:                                        { CmMilitaer 1000:1c91 }
      if DS.Game.GameState = 1 then
        Do_Militaer(Self, FSave.Players[DS.Game.CurrentPlayer], DS.Game.Year);
    320:                                        { CmSpiel 1000:1d4b }
      if DS.Game.GameState = 1 then
        Do_Spiel(Self);
    604: Do_Laendernamen(Self);                  { CmLaendernamen 1000:1ec3 }
    106: Do_Annalen(Self);                       { CmAnnalen 1000:1541 }
    107: Do_Rekorde(Self);                       { CmRekorde 1000:1575 }
    222:                                        { CmAbkommen 1000:17fc }
      if DS.Game.GameState = 1 then
      begin
        Do_Abkommen(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    223:                                        { CmTributFordern 1000:183d }
      if DS.Game.GameState = 1 then
      begin
        Do_TributFordern(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    224:                                        { CmSabotage 1000:187e }
      if DS.Game.GameState = 1 then
      begin
        Do_Sabotage(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    214:                                        { CmKriegFuehren 1000:193f }
      if DS.Game.GameState = 1 then
      begin
        Do_KriegFuehren(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers,
          DS.Game.Year);
        Invalidate;
      end;
    209:                                        { CmDemissionieren 1000:16d0 }
      if DS.Game.GameState = 1 then
      begin
        Do_Demissionieren(Self, 0, FSave.Players);
        Invalidate;
      end;
    601: DS.OptAutosave := Ord(DS.OptAutosave = 0);        { Geschichtsschreibung }
    602: DS.OptSound := Ord(DS.OptSound = 0);              { Krach und Geschrei }
    603: DS.OptMusic := Ord(DS.OptMusic = 0);              { Schalmeienklaenge (MIDI not played) }
    610..612: SetResolution(Id - 610);              { Cm640x480, Cm800x600, CmResolution1024 }
    501, 503: CmHilfe;                              { Hilfe, Ueber die Hilfe }
    701..708:                                   { Berichte: the reports at turn start }
      if DS.Game.GameState = 1 then
        with FSave.Players[DS.Game.CurrentPlayer] do
          ReportFlags := ReportFlags xor (1 shl (Id - 701));
    211:                                        { CmTruppenAufstellen 1000:18bf }
      if DS.Game.GameState = 1 then
      begin
        Troops.Do_TruppenAufstellen(Self, FSave.Players[DS.Game.CurrentPlayer], 0);
        Invalidate;
      end;
    221:                                        { CmEntwicklungshilfe 1000:17bb }
      if DS.Game.GameState = 1 then
      begin
        Do_Entwicklungshilfe(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    305:                                        { CmGeheimdienst 1000:1c04 }
      if DS.Game.GameState = 1 then
      begin
        Intel.Do_Geheimdienst(Self, FSave.Players, DS.Game.NumPlayers, DS.Game.CurrentPlayer,
          DS.Game.Year);
        Invalidate;
      end;
    802:                                        { Ctrl+P: CensusEditor 1038:4d68 }
      if DS.Game.GameState = 1 then
      begin
        CensusEditor(Self, FSave.Players, DS.Game.NumPlayers);
        Invalidate;
      end;
    306:                                        { CmHofschmiede 1000:1c66 }
      if DS.Game.GameState = 1 then
        Do_Hofschmiede(Self, FSave.Players[DS.Game.CurrentPlayer]);
    203:                                        { CmGebaeude 1000:1611 }
      if DS.Game.GameState = 1 then
      begin
        Do_Gebaeude(Self, FSave.Players, DS.Game.CurrentPlayer, DS.Game.NumPlayers);
        Invalidate;
      end;
    CmdExit: Close;
    CmdInfo:                                    { CmInfo 1000:390b: KaiserDlg ABOUTBOX }
      begin
        D := UI.Dialog('KaiserDlg', $3364, [APtr(Self), AStr(DSText($04F2))]);
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
    LoadGameFile(OD.FileName);
  finally
    OD.Free;
  end;
end;

function TKaiserForm.LoadGameFile(const FileName: string): Boolean;
var
  S: TSaveGame;
begin
  Result := LoadSaveGame(FileName, S) = lrOk;
  if not Result then
  begin
    Application.MessageBox(PChar('Kann Datei ' + FileName + ' nicht laden.'), 'Kaiser', MB_OK);
    Exit;
  end;
  FSave := S;
  FSaveFile := FileName;
  DS.Game := FSave.Header;
  { LoadGame (1050:07ed): Randomize, an e-mail game its stored RandSeed }
  if DS.Game.EmailGameQ = 0 then
    UI.Call('Randomize', [])
  else
    Real48.RandSeed := DS.Game.RandSeed;
  if DS.Game.EmailGameQ = 0 then
  begin
    DS.Game.GameState := 6;
    Invalidate;
    ShowStartTurnDialog(Self, FSave.Players[DS.Game.CurrentPlayer], DS.Game.CurrentPlayer,
      DS.Game.Year);
    DS.Game.GameState := 1;
  end;
  UpdateMenu;
  Invalidate;
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
begin
  { KaiserWindow::Paint (1000:0b5d), drawn off screen and blitted }
  UpdateWindowState;
  FBuffer.SetSize(MainClientWidth, MainClientHeight);
  RenderMain(FBuffer.Canvas);
  Canvas.Draw(0, 0, FBuffer);
end;

end.
