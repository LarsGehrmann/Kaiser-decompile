{ The main window (segment 1, KaiserWindow, VMT DS:01a4): the original menu
  (MAINMENU from kaiser.exe) and its commands. The game state is the
  savegame record: header (DS.Game) and the player array. }
unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Menus, Dialogs, ExtCtrls, LCLType, LCLIntf,
  NERes, MainPaint, KaiserTypes, KaiserDS, KaiserSave, KaiserUI, Turn, Game, Actions, KaiserLCL, KaiserIni, Annals, Troops, Intel, Census, Reports, Real48, Music, Math, PixelScale,
  MacAppearance, RGraphics, HelpView;

type
  TKaiserForm = class(TForm)
  public
    FSave: TSaveGame;
  private
    FMenu: TMainMenu;
    FSaveFile: string;
    FToolbar: TKaiserToolbar;
    FBuffer: TBitmap;
    FBoss: Boolean;                 { CmBossKey: close without asking (Self+0x4958) }
    { remastered: the picture (logical MainClientWidth x MainClientHeight)
      shown FScale times larger at (FOffX, FOffY) }
    FScale: Double;
    FOffX, FOffY: Integer;
    FToolDown: Boolean;             { a button went down on the toolbar }
    FAccel: TBytes;                 { ACCELERATORS MENUKEYS: flags, key, command (5 bytes) }
    function ToLogical(X, Y: Integer): TPoint;
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure BuildMenu;
    procedure AddGraphicsItems;
    procedure AddItems(Into: TMenuItem; const M: TMenuTemplate);
    procedure MenuClick(Sender: TObject);
    function FindItem(Id: Word): TMenuItem;
    procedure UpdateMenu;
    procedure CheckCommand(Id: Word; On: Boolean);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    function Accelerator(Virt: Boolean; Key: Word; Shift: TShiftState): Boolean;
    procedure CmLoadLastGame;
    procedure CmBossKey;
    procedure FormShow(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure AutoStart(Sender: TObject);
    { tests: KAISER_RESIZE=WxH, the window resized 3 s after the start }
    procedure ResizeTick(Sender: TObject);
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
    commands of KAISER_AUTOMENU (e.g. 201,203; war:A:D, raid:P:M; look:ARMY:SLOT
    for the unit look of the right click), TURNS turns.
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
        else if Copy(Cmds[T], 1, 5) = 'look:' then             { look:ARMY:SLOT }
          ShowUnitLookDlg(Self, FSave.Players[DS.Game.CurrentPlayer],
            StrToIntDef(Copy(Cmds[T], 6, 1), 1), StrToIntDef(Copy(Cmds[T], 8, 2), 1))
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
  { (KAISER_STAY: the window stays open for looking at it) }
  if ((Shots <> '') or (GetEnvironmentVariable('KAISER_AUTOGAME') <> '')) and
     (GetEnvironmentVariable('KAISER_STAY') = '') then
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
  C.FillRect(0, 0, MainClientWidth * RenderScale, MainClientHeight * RenderScale);
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
        if MusicOpen then                         { Paint in a game: MidiClose }
          MusicStop;
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

{ "WxH" of an environment variable }
function SizeFromEnv(const Name: string; out W, H: Integer): Boolean;
var
  S: string;
begin
  S := GetEnvironmentVariable(Name);
  W := StrToIntDef(Copy(S, 1, Pos('x', S) - 1), 0);
  H := StrToIntDef(Copy(S, Pos('x', S) + 1, 9), 0);
  Result := (W > 0) and (H > 0);
end;

procedure TKaiserForm.ResizeTick(Sender: TObject);
var
  W, H: Integer;
begin
  TTimer(Sender).Enabled := False;
  if SizeFromEnv('KAISER_RESIZE', W, H) then
  begin
    ClientWidth := W;
    ClientHeight := H;
  end;
end;

procedure TKaiserForm.ApplyWindowSize;
var
  K, W, H: Integer;
begin
  { SetupWindow / Cm640x480 (1000:0268 / 1ed4): the layout by the
    resolution, the client height ResolutionHeight - 40. Remastered: the
    window the largest whole multiple of it that fits the screen (at
    least 1); the user may resize it freely }
  K := Max(1, Min(Trunc(Screen.WorkAreaWidth * 0.9 / MainClientWidth),
    Trunc(Screen.WorkAreaHeight * 0.9 / MainClientHeight)));
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
    K := 1;                                       { the snapshots at 1x }
  if GetEnvironmentVariable('KAISER_WINDOWSCALE') <> '' then
    K := StrToIntDef(GetEnvironmentVariable('KAISER_WINDOWSCALE'), K);
  { tests: KAISER_WINDOWSIZE=WxH the client size, any scale }
  if SizeFromEnv('KAISER_WINDOWSIZE', W, H) then
  begin
    Constraints.MinWidth := MainClientWidth div 2;
    Constraints.MinHeight := MainClientHeight div 2;
    ClientWidth := W;
    ClientHeight := H;
    DialogScale := Min(W / MainClientWidth, H / MainClientHeight);
    FToolbar.SetBounds(0, 0, FToolbar.BarWidth - 1, MainClientHeight);
    Exit;
  end;
  Constraints.MinWidth := MainClientWidth div 2;
  Constraints.MinHeight := MainClientHeight div 2;
  ClientWidth := MainClientWidth * K;
  ClientHeight := MainClientHeight * K;
  DialogScale := K;
  FToolbar.SetBounds(0, 0, FToolbar.BarWidth - 1, MainClientHeight);
end;

function TKaiserForm.ToLogical(X, Y: Integer): TPoint;
begin
  Result.X := Floor((X - FOffX) / FScale);
  Result.Y := Floor((Y - FOffY) / FScale);
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
var
  P: TPoint;
begin
  P := ToLogical(X, Y);
  { the toolbar's part of the picture }
  if (P.X >= 0) and (P.X < FToolbar.BarWidth - 1) and (P.Y >= 0) and (P.Y < MainClientHeight) then
  begin
    FToolDown := True;
    FToolbar.ToolMouseDown(Button, Shift, P.X, P.Y);
    Exit;
  end;
  { WMLButtonDblClk / WMRButtonDown (1000:039d / 03bb) }
  if (Button = mbLeft) and (ssDouble in Shift) then
    HandleMapClick(True, P.X, P.Y)
  else if Button = mbRight then
    HandleMapClick(False, P.X, P.Y);
end;

procedure TKaiserForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  if FToolDown then
  begin
    P := ToLogical(X, Y);
    FToolbar.ToolMouseMove(Shift, P.X, P.Y);
  end;
end;

procedure TKaiserForm.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  P: TPoint;
begin
  if FToolDown then
  begin
    FToolDown := False;
    P := ToLogical(X, Y);
    FToolbar.ToolMouseUp(Button, Shift, P.X, P.Y);
  end;
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
begin
  { CmHilfe / CmUeberDieHilfe (1000:38ed / 38cf) call WinHelp on
    KAISER.HLP; here the contents of the manual converted by
    tools/help_to_md.py, in the game's help window }
  if not ShowHelpContents then
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
  { remastered: any size and full screen; the picture scales }
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu, biMinimize, biMaximize];
  FScale := 1;
  Position := poScreenCenter;
  Color := clBlack;
  OnPaint := @FormPaint;
  OnClose := @FormClose;
  OnCloseQuery := @FormCloseQuery;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
  OnKeyPress := @FormKeyPress;
  FAccel := Exe.Find(9, 'MENUKEYS');              { RT_ACCELERATOR }
  OnShow := @FormShow;
  OnWindowStateChange := @FormWindowStateChange;
  OnMouseDown := @FormMouseDown;
  OnMouseMove := @FormMouseMove;
  OnMouseUp := @FormMouseUp;
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
  FToolbar.Visible := False;                      { drawn into the picture }
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
  if GetEnvironmentVariable('KAISER_RESIZE') <> '' then
  begin
    Tm := TTimer.Create(Self);
    Tm.Interval := 3000;
    Tm.OnTimer := @ResizeTick;
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
    {$ifdef darwin}
    { the usual macOS shortcuts for the file commands (besides the
      original's keys, FormKeyDown; on Windows those alone: ssMeta would be
      the Windows key) }
    case MI.Tag of
      101: MI.ShortCut := ShortCut(VK_N, [ssMeta]);         { Neues Spiel }
      102: MI.ShortCut := ShortCut(VK_O, [ssMeta]);         { Öffnen }
      103: MI.ShortCut := ShortCut(VK_S, [ssMeta]);         { Speichern }
      401: MI.ShortCut := ShortCut(VK_R, [ssMeta]);         { Runde beenden (Ctrl+R) }
    end;
    {$endif}
    if M.Items[I].Flags and $10 <> 0 then
      AddItems(MI, M.Items[I])
    else
      MI.OnClick := @MenuClick;
    Into.Add(MI);
  end;
end;

{ remastered: "Grafik" after the resolutions (commands 650..652: the
  scaler xBRZ, ScaleNx, big pixels) }
procedure TKaiserForm.AddGraphicsItems;
const
  Names: array[0..2] of string = ('Grafik: weich (xBRZ)', 'Grafik: scharf (ScaleNx)',
    'Grafik: Pixel');
var
  Res, Into, MI: TMenuItem;
  I: Integer;
begin
  Res := FindItem(611);
  if Res = nil then
    Exit;
  Into := Res.Parent;
  MI := TMenuItem.Create(Self);
  MI.Caption := '-';
  Into.Add(MI);
  for I := 0 to 2 do
  begin
    MI := TMenuItem.Create(Self);
    MI.Caption := Names[I];
    MI.Tag := 650 + I;
    MI.RadioItem := True;
    MI.OnClick := @MenuClick;
    Into.Add(MI);
  end;
end;

procedure TKaiserForm.BuildMenu;
begin
  FMenu := TMainMenu.Create(Self);
  AddItems(FMenu.Items, Exe.Menu('MAINMENU'));
  AddGraphicsItems;
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
  for I := 0 to 2 do
    CheckCommand(650 + I, Ord(ScaleMethod) = I);
  CheckCommand(602, DS.OptSound <> 0);
  CheckCommand(603, DS.OptMusic <> 0);
  for I := 0 to 2 do
    CheckCommand(610 + I, DS.OptResolution = I);
  { Menu_UpdateReportChecks (1060:0254) }
  if Running then
    for I := 0 to 7 do
      CheckCommand(701 + I, FSave.Players[DS.Game.CurrentPlayer].ReportFlags and (1 shl I) <> 0);
end;

{ CanClose (1000:0af4): a running game ends only after asking, except by the
  boss key (and under the autopilot) }
procedure TKaiserForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (DS.Game.GameState = 1) and not FBoss and (GetEnvironmentVariable('KAISER_AUTOPILOT') = '') and
     (GetEnvironmentVariable('KAISER_AUTOGAME') = '') and (GetEnvironmentVariable('KAISER_MAINSHOT') = '') then
    CanClose := Application.MessageBox(PChar(Utf8(DSText($0284))), PChar(Utf8(DSText($02BF))),
      MB_YESNO or MB_ICONQUESTION) = IDYES;
end;

{ the original's accelerators (MENUKEYS, TranslateAccelerator): VIRTKEY
  entries by key and SHIFT/CONTROL/ALT, ASCII entries by character (the
  control characters are Ctrl + letter); the first match counts. Commands
  without a handler in the original (212, 313) do nothing }
function TKaiserForm.Accelerator(Virt: Boolean; Key: Word; Shift: TShiftState): Boolean;
var
  P: Integer;
  Flags: Byte;
  K, Cmd: Word;
  Mods: TShiftState;
begin
  Result := False;
  P := 0;
  while P + 5 <= Length(FAccel) do
  begin
    Flags := FAccel[P];
    K := FAccel[P + 1] or (FAccel[P + 2] shl 8);
    Cmd := FAccel[P + 3] or (FAccel[P + 4] shl 8);
    Mods := [];
    if Flags and $04 <> 0 then Include(Mods, ssShift);
    if Flags and $08 <> 0 then Include(Mods, ssCtrl);
    if Flags and $10 <> 0 then Include(Mods, ssAlt);
    if (K <> 0) and ((Flags and 1 <> 0) = Virt) and (K = Key) and
       (not Virt or (Shift * [ssShift, ssCtrl, ssAlt] = Mods)) then
    begin
      if (Cmd <> 212) and (Cmd <> 313) then
        Command(Cmd);
      Exit(True);
    end;
    if Flags and $80 <> 0 then
      Break;
    Inc(P, 5);
  end;
end;

procedure TKaiserForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Accelerator(True, Key, Shift) then
    Key := 0
  else if (Shift * [ssCtrl, ssAlt, ssMeta] = [ssCtrl]) and (Key >= VK_A) and (Key <= VK_Z) and
          Accelerator(False, Key - VK_A + 1, Shift) then                    { Ctrl+A = #1 }
    Key := 0;
end;

procedure TKaiserForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key >= ' ') and Accelerator(False, Ord(Key), []) then
    Key := #0;
end;

{ CmLoadLastGame (1000:1292, Ctrl+L): the game of KAISER.INI's "Letzter Pfad" }
procedure TKaiserForm.CmLoadLastGame;
var
  F: string;
begin
  if (DS.Game.GameState = 1) and
     (Application.MessageBox(PChar(Utf8(DSText($03BA))), PChar(Utf8(DSText($03F0))),
       MB_YESNO or MB_ICONQUESTION) <> IDYES) then
    Exit;
  F := ReadLastGame(SettingsFile);
  if F <> '' then
    LoadGameFile(F);
end;

{ CmBossKey (1000:3944, key b): a running game to boss.ksr (DS:0251), then
  closed without asking }
procedure TKaiserForm.CmBossKey;
begin
  if DS.Game.GameState <> 1 then
    Exit;
  FBoss := True;
  FSave.Header := DS.Game;
  WriteSaveGame(ExtractFilePath(OwnSettingsFile) + 'boss.ksr', FSave);
  Close;
end;

procedure TKaiserForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MusicStop;                                      { Done }
  WriteSettings(OwnSettingsFile);
end;

{ WMSize (1000:08ba): restored (also the first show) on the title screen
  with music on: kaiser.mid; minimised: stopped }
procedure TKaiserForm.FormShow(Sender: TObject);
begin
  if (DS.Game.GameState = 0) and (DS.OptMusic = 1) then
    MusicPlay(MusicFile);
end;

procedure TKaiserForm.FormWindowStateChange(Sender: TObject);
begin
  if DS.Game.GameState <> 0 then
    Exit;
  if WindowState = wsMinimized then
    MusicStop
  else if DS.OptMusic = 1 then
    MusicPlay(MusicFile);
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
    603:                                        { CmSchalmeienklaenge 1000:1e56 }
      begin
        if DS.OptMusic = 0 then
        begin
          if DS.Game.GameState = 0 then
            MusicPlay(MusicFile);
        end
        else
          MusicStop;
        DS.OptMusic := Ord(DS.OptMusic = 0);
      end;
    610..612: SetResolution(Id - 610);              { Cm640x480, Cm800x600, CmResolution1024 }
    650..652:                                   { remastered: the scaler }
      begin
        ScaleMethod := TScaleMethod(Id - 650);
        ClearScaled;
        Invalidate;
      end;
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
    801: CmBossKey;
    803: CmLoadLastGame;
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
     (Application.MessageBox(PChar(Utf8(DSText($0324))), PChar(Utf8(DSText($035A))),
       MB_YESNO or MB_ICONQUESTION) <> IDYES) then
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
  { Ini_WriteLastGame (after CmFileOpen / LoadFromCommandLine); not for
    autosave.ksr and boss.ksr, which are not kept as the game's file }
  if (CompareText(ExtractFileName(FileName), 'autosave.ksr') <> 0) and
     (CompareText(ExtractFileName(FileName), 'boss.ksr') <> 0) then
    WriteLastGame(OwnSettingsFile, ExpandFileName(FileName), ExtractFileName(FileName));
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
var
  LW, LH, RS, DW, DH: Integer;
begin
  { KaiserWindow::Paint (1000:0b5d), drawn off screen. Remastered: the
    picture keeps the original layout of LW x LH; it is drawn RS times
    larger (the pixel scaler's factor for the window's size in device
    pixels) and goes smoothly scaled into the window, the aspect kept }
  UpdateWindowState;
  LW := MainClientWidth;
  LH := MainClientHeight;
  FScale := Min(ClientWidth / LW, ClientHeight / LH);
  if FScale <= 0 then
    FScale := 1;
  DialogScale := FScale;                          { the dialogs opened from now on }
  RS := SupportedFactor(Ceil(FScale * BackingScale - 0.01));
  { (at most ~16 million pixels of picture) }
  while (RS > 1) and (Int64(LW * RS) * (LH * RS) > 16000000) do
    RS := LowerFactor(RS);
  RenderScale := RS;
  try
    FBuffer.SetSize(LW * RS, LH * RS);
    RenderMain(FBuffer.Canvas);
    FToolbar.PaintTo(FBuffer.Canvas, LH);
  finally
    RenderScale := 1;
  end;
  DW := Round(LW * FScale);
  DH := Round(LH * FScale);
  FOffX := (ClientWidth - DW) div 2;
  FOffY := (ClientHeight - DH) div 2;
  Canvas.Brush.Color := $101010;
  if (DW < ClientWidth) or (DH < ClientHeight) then
    Canvas.FillRect(0, 0, ClientWidth, ClientHeight);
  if (DW = LW * RS) and (DH = LH * RS) then
    Canvas.Draw(FOffX, FOffY, FBuffer)
  else
    Canvas.StretchDraw(Rect(FOffX, FOffY, FOffX + DW, FOffY + DH), FBuffer);
end;

end.
