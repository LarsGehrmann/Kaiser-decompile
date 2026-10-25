{ The game's dialogs on template forms. The dialog types themselves (the
  original SetupWindow, control handlers, CanClose, timers) are
  KaiserUI.TDialogLogic classes in port/src (actions.pas, troops.pas,
  intel.pas, annals.pas, gamedialogs.pas), registered by the constructor
  name; TLogicDialog binds one to its form (TFormControls) and does the
  painting the logic leaves to the UI (the troop grids, the unit
  portrait). A dialog of a type without logic is a plain TKaiserDialog. }
unit KaiserDlgs;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Controls, StdCtrls, ExtCtrls, Forms, Graphics, Strings, NERes,
  KaiserTypes, KaiserDS, KaiserUI, KaiserLCL, Troops;

type
  TKaiserDialog = class(TTemplateForm)
  protected
    FSetUp: Boolean;
    { OWL-like access to the controls by id }
    function GetCheck(Id: SmallInt): Boolean;
    procedure SetCheck(Id: SmallInt; On: Boolean);
    function GetPosition(Id: SmallInt): Integer;
    procedure SetRange(Id: SmallInt; Lo, Hi: Integer);
    procedure SetPosition(Id: SmallInt; V: Integer);
    procedure SetText(Id: SmallInt; const Raw: RawByteString);
    function GetText(Id: SmallInt): RawByteString;
    procedure AddString(Id: SmallInt; const Raw: RawByteString);
    function GetSelIndex(Id: SmallInt): Integer;
    procedure SetSelIndex(Id: SmallInt; I: Integer);
    procedure DoShow; override;
  public
    D: TDialog;
    Args: array of TUIArg;
    { the original methods }
    procedure SetupWindow; virtual;
    function CanClose: Boolean; virtual;
    procedure Handle(Id: SmallInt); virtual;
    procedure Command(Id: SmallInt); override;
    procedure Notify(Id: SmallInt); override;
  end;
  TKaiserDialogClass = class of TKaiserDialog;

  { the controls of a template form for a ported dialog type }
  TFormControls = class(TDlgControls)
  public
    F: TKaiserDialog;
    procedure SetText(Id: SmallInt; S: PChar); override;
    function GetText(Id: SmallInt; Buf: PChar; MaxChars: Integer): Integer; override;
    procedure Enable(Id: SmallInt; On: Boolean); override;
    procedure Show(Id: SmallInt; Cmd: SmallInt); override;
    procedure SetCaption(S: PChar); override;
    procedure SetItemCaption(Id: SmallInt; S: PChar); override;
    procedure SetCheck(Id: SmallInt; V: Word); override;
    function GetCheck(Id: SmallInt): Word; override;
    procedure SetRange(Id: SmallInt; Lo, Hi: SmallInt); override;
    procedure SetPosition(Id: SmallInt; V: SmallInt); override;
    function GetPosition(Id: SmallInt): SmallInt; override;
    procedure SetLineStep(Id: SmallInt; N: SmallInt); override;
    function AddString(Id: SmallInt; S: PChar): SmallInt; override;
    function GetSelIndex(Id: SmallInt): SmallInt; override;
    function SetSelIndex(Id: SmallInt; I: SmallInt): SmallInt; override;
    procedure ComboSetText(Id: SmallInt; S: PChar); override;
    procedure EndDlg(Code: SmallInt); override;
  end;

  { a dialog whose type is ported (KaiserUI.TDialogLogic, port/src) }
  TLogicDialog = class(TKaiserDialog)
  private
    FControls: TFormControls;
    FHeer, FGarde: TImage;          { ANORDNENDLG: the painted grids }
    FTimer: TTimer;                 { the type's WMTimer (TDialogLogic.TimerInterval) }
    FPortrait: TImage;              { UnitInfoDlg's portrait }
    FMap: TImage;                   { GEGNERDLG: the map of the countries }
    FPicture: TImage;               { UnitLookDlg / RecruitDlg: the unit; the crown }
    FInfo: TImage;                  { ANORDNENDLG: the card of the unit under the mouse }
    { remastered: the dialog's scale and the scaler's factor (DialogScale,
      DialogFactor when it was made) }
    FS: Double;
    FF: Integer;
    function Buffer(LW, LH: Integer; Back: TColor): TBitmap;
    procedure Show(var Img: TImage; X, Y, LW, LH: Integer; B: TBitmap; Mouse: Boolean);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TimerTick(Sender: TObject);
  public
    { TroopDlg_DrawHeer / DrawGarde (1038:84a1 / 8699): the grids of the
      Heer (64 x 160) and the Garde (112 x 112, in walls) on the dialog's
      background with the unit icons (sprites 1100+type / 1200+type, a hero
      1150+picture), the selected cells red }
    procedure DrawTroops;
    { UnitInfoDlg.DrawPortrait (1058:0af8): the sprite 1100 + type (Blink:
      1300 + type) on the dialog's background, 32 x 32 at (12, 64) of a
      237 x 254 window, scaled to the window size }
    procedure DrawPortrait(Blink: Byte);
    { GegnerDlg.DrawMap (1038:462f): the 10 countries as boxes with their
      names on black, 240 x 200 at (340, 14) of a 626 x 335 window, scaled
      to the window size; grey: no player, yellow: one's own (every country
      with initiative on), green: affordable, red: the attack costs more
      initiative than one has }
    procedure DrawTargetMap;
    { UnitLookDlg.DrawUnitPicture (1040:367b): 64 x 64 at (8, 8), the LAND
      pattern in a black frame, the sprite 1100 + type (1300 + type
      blinking; a hero 1150 / 1350 + picture) at (16, 16) }
    procedure DrawUnitLook(Blink: Byte);
    { RecruitDlg.DrawUnitPicture (1040:55b5): the sprite 1100 + type (1300 +
      type blinking) on the dialog's background at (12, 8) of a 237 x 254
      window, both scaled with the width (the original's y uses it too) }
    procedure DrawRecruitPicture(Blink: Byte);
    { UnitEditDlg.DrawPortrait (1038:56b9): the same for the edited unit
      (+0x703): 1100 + type, a hero 1150 + picture }
    procedure DrawUnitEditPortrait;
    procedure DrawSmallSprite(Id: Integer);
    { CoronationDlg.WMPaint (1040:4d8c): KLEINEKRONE, 120 x 115 of it at
      (88, 118) of a 296 x 354 window, scaled }
    procedure DrawCrown;
    { TroopDlg.DrawUnitInfo (1038:8921): the card of the unit under the
      mouse at (+0x718, +0x71a), 355 x 64 scaled with +0x71d: the name; the
      rank stars (12 x 12, 6030 + kind) and the ability right-aligned; the
      attribute icons 6000.. with attack, defence, hits, range, steps (and
      salvos), the ranged kind 6010..; victories and pay (6020, 6021). A
      Garde unit's card starts at 178 (ranged: 140) }
    procedure DrawUnitInfo;
    procedure AutoMouse(X, Y: Integer); override;
    destructor Destroy; override;
    function Logic: TDialogLogic;
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
    procedure Command(Id: SmallInt); override;
    procedure Notify(Id: SmallInt); override;
  end;

function DialogClassOf(const Name: string): TKaiserDialogClass;

implementation

uses
  Math, Rules, Real48, Turn, KaiserRes, HelpView, WinScroll, RGraphics, PixelScale;

{ -- TKaiserDialog ----------------------------------------------------------- }

function TKaiserDialog.GetCheck(Id: SmallInt): Boolean;
begin
  Result := Checked(Id);
end;

procedure TKaiserDialog.SetCheck(Id: SmallInt; On: Boolean);
begin
  SetChecked(Id, On);
end;

function TKaiserDialog.GetPosition(Id: SmallInt): Integer;
var
  C: TControl;
begin
  C := Item(Id);
  if C is TScrollBar then
    Result := TScrollBar(C).Position
  else if C is TWinScrollBar then
    Result := TWinScrollBar(C).Position
  else if C is TSpinBar then
    Result := TSpinBar(C).Pos
  else
    Result := 0;
end;

procedure TKaiserDialog.SetRange(Id: SmallInt; Lo, Hi: Integer);
var
  C: TControl;
begin
  C := Item(Id);
  Inc(FQuiet);
  try
    if C is TScrollBar then
    begin
      { in one step (Min first raised for Lo > the old Max); Hi < Lo is an
        empty range, which LCL refuses }
      TScrollBar(C).SetParams(TScrollBar(C).Position, Lo, Max(Lo, Hi), 0);
    end
    else if C is TWinScrollBar then
      TWinScrollBar(C).SetParams(TWinScrollBar(C).Position, Lo, Hi)
    else if C is TSpinBar then
    begin
      TSpinBar(C).Lo := Lo;
      TSpinBar(C).Hi := Hi;
    end;
  finally
    Dec(FQuiet);
  end;
end;

procedure TKaiserDialog.SetPosition(Id: SmallInt; V: Integer);
var
  C: TControl;
begin
  C := Item(Id);
  Inc(FQuiet);
  try
    if C is TScrollBar then
      TScrollBar(C).Position := V
    else if C is TWinScrollBar then
      TWinScrollBar(C).Position := V
    else if C is TSpinBar then
      TSpinBar(C).Pos := V;
  finally
    Dec(FQuiet);
  end;
end;

procedure TKaiserDialog.SetText(Id: SmallInt; const Raw: RawByteString);
begin
  SetItemText(Id, Raw);
end;

function TKaiserDialog.GetText(Id: SmallInt): RawByteString;
var
  C: TControl;
begin
  C := Item(Id);
  if C = nil then
    Exit('');
  if C is TEdit then
    Result := UTF8ToCP1252(TEdit(C).Text)
  else
    Result := UTF8ToCP1252(C.Caption);
end;

procedure TKaiserDialog.AddString(Id: SmallInt; const Raw: RawByteString);
var
  C: TControl;
begin
  C := Item(Id);
  if C is TComboBox then
    TComboBox(C).Items.Add(Utf8(Raw))
  else if C is TListBox then
    TListBox(C).Items.Add(Utf8(Raw));
end;

function TKaiserDialog.GetSelIndex(Id: SmallInt): Integer;
var
  C: TControl;
begin
  C := Item(Id);
  if C is TComboBox then
    Result := TComboBox(C).ItemIndex
  else if C is TListBox then
    Result := TListBox(C).ItemIndex
  else
    Result := -1;
end;

procedure TKaiserDialog.SetSelIndex(Id: SmallInt; I: Integer);
var
  C: TControl;
begin
  C := Item(Id);
  if C is TComboBox then
    TComboBox(C).ItemIndex := I
  else if C is TListBox then
    TListBox(C).ItemIndex := I;
end;

procedure TKaiserDialog.DoShow;
begin
  inherited DoShow;
  if not FSetUp then
  begin
    FSetUp := True;
    Inc(FQuiet);
    try
      SetupWindow;
    finally
      Dec(FQuiet);
    end;
  end;
end;

procedure TKaiserDialog.SetupWindow;
begin
end;

function TKaiserDialog.CanClose: Boolean;
begin
  Result := True;
end;

procedure TKaiserDialog.Handle(Id: SmallInt);
begin
end;

procedure TKaiserDialog.Command(Id: SmallInt);
begin
  { OWL: IDOK asks CanClose, IDCANCEL ends; other buttons go to their
    handler (a button without one does nothing) }
  case Id of
    1:
      if CanClose then
        inherited Command(1);
    2: inherited Command(2);
  else
    Handle(Id);
  end;
end;

procedure TKaiserDialog.Notify(Id: SmallInt);
begin
  Handle(Id);
end;

{ -- ported dialog types ------------------------------------------------------ }

procedure TFormControls.SetText(Id: SmallInt; S: PChar);
begin
  F.SetText(Id, S);
end;

function TFormControls.GetText(Id: SmallInt; Buf: PChar; MaxChars: Integer): Integer;
var
  T: RawByteString;
begin
  T := Copy(F.GetText(Id), 1, MaxChars - 1);
  StrPCopy(Buf, T);
  Result := Length(T);
end;

procedure TFormControls.Enable(Id: SmallInt; On: Boolean);
begin
  F.EnableItem(Id, On);
end;

procedure TFormControls.Show(Id: SmallInt; Cmd: SmallInt);
var
  Ctl: TControl;
begin
  Ctl := F.Item(Id);
  if Ctl <> nil then
    Ctl.Visible := Cmd <> 0;                 { SW_HIDE = 0 }
end;

procedure TFormControls.SetCaption(S: PChar);
begin
  F.Caption := Utf8(S);
end;

procedure TFormControls.SetItemCaption(Id: SmallInt; S: PChar);
begin
  F.SetText(Id, S);
end;

procedure TFormControls.SetCheck(Id: SmallInt; V: Word);
begin
  F.SetCheck(Id, V <> 0);
end;

function TFormControls.GetCheck(Id: SmallInt): Word;
begin
  Result := Ord(F.GetCheck(Id));
end;

procedure TFormControls.SetRange(Id: SmallInt; Lo, Hi: SmallInt);
begin
  F.SetRange(Id, Lo, Hi);
end;

procedure TFormControls.SetPosition(Id: SmallInt; V: SmallInt);
begin
  F.SetPosition(Id, V);
end;

function TFormControls.GetPosition(Id: SmallInt): SmallInt;
begin
  Result := F.GetPosition(Id);
end;

procedure TFormControls.SetLineStep(Id: SmallInt; N: SmallInt);
var
  Ctl: TControl;
begin
  Ctl := F.Item(Id);
  if Ctl is TScrollBar then
    TScrollBar(Ctl).SmallChange := N
  else if Ctl is TWinScrollBar then
    TWinScrollBar(Ctl).SmallChange := N
  else if Ctl is TSpinBar then
    TSpinBar(Ctl).Step := N;
end;

function TFormControls.AddString(Id: SmallInt; S: PChar): SmallInt;
var
  Ctl: TControl;
begin
  F.AddString(Id, S);
  Ctl := F.Item(Id);
  if Ctl is TComboBox then
    Result := TComboBox(Ctl).Items.Count - 1
  else if Ctl is TListBox then
    Result := TListBox(Ctl).Items.Count - 1
  else
    Result := -1;
end;

function TFormControls.GetSelIndex(Id: SmallInt): SmallInt;
begin
  Result := F.GetSelIndex(Id);
end;

function TFormControls.SetSelIndex(Id: SmallInt; I: SmallInt): SmallInt;
begin
  F.SetSelIndex(Id, I);
  Result := I;
end;

procedure TFormControls.ComboSetText(Id: SmallInt; S: PChar);
var
  Ctl: TControl;
begin
  Ctl := F.Item(Id);
  if Ctl is TComboBox then
    TComboBox(Ctl).Text := Utf8(S);
end;

procedure TFormControls.EndDlg(Code: SmallInt);
begin
  F.EndWith(Code);
end;

destructor TLogicDialog.Destroy;
begin
  if Logic <> nil then
    Logic.C := nil;
  FControls.Free;
  inherited Destroy;
end;

function TLogicDialog.Logic: TDialogLogic;
begin
  Result := TDialogLogic(D.Logic);
end;

procedure TLogicDialog.SetupWindow;
begin
  FS := DialogScale;
  FF := DialogFactor;
  FControls := TFormControls.Create;
  FControls.F := Self;
  Logic.C := FControls;
  { the window size, as KaiserDlg.SetupWindow leaves it at +0x2a / +0x2c
    (dialogs with painted areas scale their positions with it) }
  PSmallInt(@D.Data[$2A])^ := Width;
  PSmallInt(@D.Data[$2C])^ := Height;
  OnMouseDown := @FormMouseDown;
  OnMouseMove := @FormMouseMove;
  Logic.SetupWindow;
  if D.Name = 'TroopDlg' then
    DrawTroops;
  if D.Name = 'GegnerDlg' then
    DrawTargetMap;
  if D.Name = 'CoronationDlg' then
    DrawCrown;
  if D.Name = 'UnitEditDlg' then
    DrawUnitEditPortrait;
  if Logic.TimerInterval > 0 then
  begin
    FTimer := TTimer.Create(Self);
    FTimer.Interval := Logic.TimerInterval;
    FTimer.OnTimer := @TimerTick;
  end;
end;

procedure TLogicDialog.TimerTick(Sender: TObject);
begin
  if Logic.TimerInterval > 0 then
    Logic.Timer;
end;

{ -- the painted parts (remastered: each drawn FF times larger into a
  buffer of its logical size, shown FS times larger; positions that the
  logic derives from the window size stay window coordinates, the fixed
  pixel sizes and offsets of the original are logical units) -------------- }

function TLogicDialog.Buffer(LW, LH: Integer; Back: TColor): TBitmap;
begin
  Result := TBitmap.Create;
  { no alpha channel: on Windows what GDI draws into a 32-bit bitmap keeps
    alpha 0 and read back (ToPix) came out as transparent black }
  Result.PixelFormat := pf24bit;
  Result.SetSize(Max(1, LW * FF), Max(1, LH * FF));
  Result.Canvas.Brush.Color := Back;
  Result.Canvas.FillRect(0, 0, Result.Width, Result.Height);
end;

procedure TLogicDialog.Show(var Img: TImage; X, Y, LW, LH: Integer; B: TBitmap;
  Mouse: Boolean);
var
  P: TPixImage;
  Key: LongWord;
  I: Integer;
  T: TBitmap;
begin
  { the dialog colour made transparent: macOS converts a stretched bitmap's
    colours differently from the window's own background (a lighter box
    around the troop grids). Not on Windows: there the colours match, and a
    picture transparent all over (the empty unit card) showed black }
  P := ToPix(B);
  {$ifdef darwin}
  Key := $FF000000 or (LongWord(Red(DialogBackground)) shl 16) or
    (LongWord(Green(DialogBackground)) shl 8) or LongWord(Blue(DialogBackground));
  for I := 0 to High(P.Px) do
    if P.Px[I] = Key then
      P.Px[I] := 0;
  {$endif}
  T := FromPix(P);
  if Img = nil then
  begin
    Img := TImage.Create(Self);
    Img.Parent := Self;
    if Mouse then
    begin
      Img.OnMouseDown := @GridMouseDown;
      Img.OnMouseMove := @GridMouseMove;
    end;
  end;
  Img.SetBounds(X, Y, Max(1, Round(LW * FS)), Max(1, Round(LH * FS)));
  Img.Stretch := True;
  Img.AntialiasingMode := amOn;
  try
    Img.Picture.Assign(T);
  finally
    T.Free;
  end;
end;

{ a font of the original's LOGFONT -12 bold Comic Sans, FF times larger }
procedure SetPaintFont(Cv: TCanvas; F: Integer);
begin
  Cv.Font.Name := 'Comic Sans MS';
  Cv.Font.Height := -12 * F;
  Cv.Font.Style := [fsBold];
  Cv.Font.Color := clBlack;
  if F > 1 then
    Cv.Font.Quality := fqAntialiased;
end;

procedure TLogicDialog.DrawPortrait(Blink: Byte);
var
  B: TBitmap;
  Base: Word;
begin
  if Blink <> 0 then
    Base := 1300
  else
    Base := 1100;
  B := Buffer(32, 32, DialogBackground);
  try
    if ScaledSprite(Base + ShortInt(D.Data[$4E]), FF) <> nil then
      B.Canvas.Draw(0, 0, ScaledSprite(Base + ShortInt(D.Data[$4E]), FF));
    Show(FPortrait, Round(12 * Width / 237), Round(64 * Height / 254), 32, 32, B, False);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Button = mbLeft then
    Logic.Mouse(X, Y);
end;

procedure TLogicDialog.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  Logic.MouseMove(X, Y);
end;

{ in a painted part: its window position plus the logical offset }
procedure TLogicDialog.GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Button = mbLeft then
    Logic.Mouse(TControl(Sender).Left + Trunc(X / FS), TControl(Sender).Top + Trunc(Y / FS));
end;

procedure TLogicDialog.GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  Logic.MouseMove(TControl(Sender).Left + Trunc(X / FS), TControl(Sender).Top + Trunc(Y / FS));
end;

procedure TLogicDialog.DrawTroops;
var
  P: PPlayer;
  B: TBitmap;
  Cv: TCanvas;
  I: Integer;
  Wall: TBitmap;

  procedure Icon(const U: TUnit; Base, X, Y: Integer; Selected: Boolean);
  var
    S: TBitmap;
    N: Integer;
  begin
    if Selected then
    begin
      Cv.Brush.Color := clRed;
      Cv.FillRect(X * FF, Y * FF, (X + 31) * FF, (Y + 31) * FF);   { NULL_PEN: one pixel smaller }
    end;
    if U.UnitType = 9 then
      N := Base + 50 + PByte(@U)[$1A]                 { a hero: his picture }
    else
      N := Base + U.UnitType;
    S := ScaledSprite(N, FF);
    if S <> nil then
      Cv.Draw(X * FF, Y * FF, S);
  end;

  procedure Fill(X1, Y1, X2, Y2: Integer);
  begin
    Cv.FillRect(X1 * FF, Y1 * FF, X2 * FF, Y2 * FF);
  end;

begin
  { the dialog brush (DS:63a6) and NULL_PEN: no frame }
  P := PPlayer(@D.Data[$34]);
  B := Buffer(64, 160, DialogBackground);
  try
    Cv := B.Canvas;
    for I := 1 to P^.Army1Count do
      if I <= 8 then
        Icon(P^.Army1[I], 1100, DS.TroopHeerX[I] * 32, DS.TroopHeerY[I] * 32,
          (D.Data[$70A] = I) or (D.Data[$70B] = I));
    Show(FHeer, PSmallInt(@D.Data[$710])^, PSmallInt(@D.Data[$712])^, 64, 160, B, True);
  finally
    B.Free;
  end;
  B := Buffer(112, 112, DialogBackground);
  try
    Cv := B.Canvas;
    Wall := ScaledPattern('MAUER', FF);
    if Wall <> nil then
    begin
      Cv.Brush.Bitmap := Wall;
      { the walls, the gate on the left (Rectangle with NULL_PEN) }
      Fill(0, 0, 111, 7);
      Fill(105, 8, 111, 104);
      Fill(0, 104, 111, 111);
      Fill(0, 8, 7, 39);
      Fill(0, 72, 7, 104);
      Cv.Brush.Bitmap := nil;
    end;
    for I := 1 to P^.Army2Count do
      if I <= 9 then
        Icon(P^.Army2[I], 1200, DS.TroopGardeX[I] * 32 + 8, DS.TroopGardeY[I] * 32 + 8,
          (D.Data[$70C] = I) or (D.Data[$70D] = I));
    Show(FGarde, PSmallInt(@D.Data[$714])^, PSmallInt(@D.Data[$716])^, 112, 112, B, True);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.DrawTargetMap;
var
  SX, SY: Double;
  B: TBitmap;
  Cv: TCanvas;
  C, Me, Cost: Byte;
  P: PPlayer;

  { the original's scaled coordinates: window (WX, WY) and in the buffer
    (logical times FF) }
  function WX(V: Integer): Integer;
  begin
    Result := Trunc(V * SX + 0.5);
  end;

  function WY(V: Integer): Integer;
  begin
    Result := Trunc(V * SY + 0.5);
  end;

  function X(V: Integer): Integer;
  begin
    Result := Trunc(V * SX / FS * FF + 0.5);
  end;

  function Y(V: Integer): Integer;
  begin
    Result := Trunc(V * SY / FS * FF + 0.5);
  end;

begin
  SX := 1;
  SY := 1;
  if PSmallInt(@D.Data[$2A])^ > 0 then
    SX := PSmallInt(@D.Data[$2A])^ / 626;
  if PSmallInt(@D.Data[$2C])^ > 0 then
    SY := PSmallInt(@D.Data[$2C])^ / 335;
  Me := D.Data[$3C];
  P := PPlayer(@D.Data[$48 + Me * SizeOf(TPlayer)]);
  B := TBitmap.Create;
  try
    B.SetSize(X(240) - FF, Y(200) - FF);
    Cv := B.Canvas;
    Cv.Brush.Color := clBlack;
    Cv.FillRect(0, 0, B.Width, B.Height);
    { LOGFONT DS:606c (Seg10_InitBattleFont): Comic Sans MS, -12, bold }
    SetPaintFont(Cv, FF);
    Cv.Pen.Color := clBlack;
    Cv.Pen.Width := FF;
    for C := 0 to 9 do
    begin
      if ShortInt(D.Data[$449A + C]) < 0 then
        Cv.Brush.Color := clSilver                      { LTGRAY_BRUSH }
      else
      begin
        Cost := AttackInitiativeCost(C, P^.Country);
        if Cost = 0 then
        begin
          if (DS.Game.InitiativeEnabled <> 0) or (P^.Country = C) then
            Cv.Brush.Color := clYellow
          else
            Cv.Brush.Color := clLime;
        end
        else if Cost in [2..5] then
        begin
          if P^.Initiative >= Cost then
            Cv.Brush.Color := clLime
          else
            Cv.Brush.Color := clRed;
        end;
        { other costs keep the brush of the country before }
      end;
      Cv.Rectangle(X(DS.TargetMapX[C] * 20), Y(DS.TargetMapY[C] * 20),
        X((DS.TargetMapX[C] + 4) * 20), Y((DS.TargetMapY[C] + 2) * 20));
      Cv.Brush.Style := bsClear;                         { TRANSPARENT }
      { TA_CENTER or TA_BASELINE at the middle of the box }
      Cv.TextOut(X((DS.TargetMapX[C] + 2) * 20) - Cv.TextWidth(Utf8(DS.CountryNamesRt[C])) div 2,
        Y((DS.TargetMapY[C] + 1) * 20) - Cv.TextHeight('X') * 3 div 4,
        Utf8(DS.CountryNamesRt[C]));
      Cv.Brush.Style := bsSolid;
    end;
    if FMap = nil then
    begin
      FMap := TImage.Create(Self);
      FMap.Parent := Self;
    end;
    FMap.SetBounds(WX(340), WY(14), WX(240) - 1, WY(200) - 1);
    FMap.Stretch := True;
    FMap.AntialiasingMode := amOn;
    FMap.Picture.Assign(B);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.DrawUnitLook(Blink: Byte);
var
  B, S, Land: TBitmap;
  N: Integer;
begin
  B := Buffer(64, 64, clGreen);
  try
    Land := ScaledPattern('LAND', FF);
    if Land <> nil then
      B.Canvas.Brush.Bitmap := Land;
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := FF;
    B.Canvas.Rectangle(FF div 2, FF div 2, 64 * FF - FF div 2, 64 * FF - FF div 2);
    B.Canvas.Brush.Bitmap := nil;
    if Blink <> 0 then
      N := 1300
    else
      N := 1100;
    if D.Data[$4D] = 9 then
      Inc(N, 50 + D.Data[$4E])
    else
      Inc(N, ShortInt(D.Data[$4D]));
    S := ScaledSprite(N, FF);
    if S <> nil then
      B.Canvas.Draw(16 * FF, 16 * FF, S);
    Show(FPicture, Round(8 * FS), Round(8 * FS), 64, 64, B, False);
  finally
    B.Free;
  end;
end;

{ a 32 x 32 sprite on the dialog's background at (12, 8) of a 237 x 254
  window, both scaled with the width (RecruitDlg, UnitEditDlg) }
procedure TLogicDialog.DrawSmallSprite(Id: Integer);
var
  B, S: TBitmap;
  SX: Double;
begin
  SX := 1;
  if PSmallInt(@D.Data[$2A])^ > 0 then
    SX := PSmallInt(@D.Data[$2A])^ / 237;
  B := Buffer(32, 32, DialogBackground);
  try
    S := ScaledSprite(Id, FF);
    if S <> nil then
      B.Canvas.Draw(0, 0, S);
    Show(FPicture, Trunc(12 * SX + 0.5), Trunc(8 * SX + 0.5), 32, 32, B, False);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.DrawRecruitPicture(Blink: Byte);
begin
  if Blink <> 0 then
    DrawSmallSprite(1300 + D.Data[$70E])
  else
    DrawSmallSprite(1100 + D.Data[$70E]);
end;

procedure TLogicDialog.DrawUnitEditPortrait;
begin
  if D.Data[$71C] = 9 then
    DrawSmallSprite(1100 + 50 + D.Data[$71D])         { a hero: his picture }
  else
    DrawSmallSprite(1100 + ShortInt(D.Data[$71C]));
end;

procedure TLogicDialog.DrawCrown;
var
  B, Crown: TBitmap;
  SX, SY: Double;
  W, H: Integer;
begin
  SX := 1;
  SY := 1;
  if PSmallInt(@D.Data[$2A])^ > 0 then
    SX := PSmallInt(@D.Data[$2A])^ / 296;
  if PSmallInt(@D.Data[$2C])^ > 0 then
    SY := PSmallInt(@D.Data[$2C])^ / 354;
  Crown := ResBitmap('KLEINEKRONE');
  if Crown = nil then
    Exit;
  { Bmp_Draw: a BitBlt of 120 x 115 scaled, not stretched; the bitmap is
    120 x 115 and the original's window 296 wide (scale 1): no more of it }
  W := Min(Trunc(120 * SX / FS + 0.5), Crown.Width);
  H := Min(Trunc(115 * SY / FS + 0.5), Crown.Height);
  B := Buffer(W, H, clBlack);
  try
    B.Canvas.Draw(0, 0, ScaledBitmap('KLEINEKRONE', 0, FF));
    Show(FPicture, Trunc(88 * SX + 0.5), Trunc(118 * SY + 0.5), W, H, B, False);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.DrawUnitInfo;
var
  B: TBitmap;
  Cv: TCanvas;
  U: TUnit;
  W, X0, I, Kind, Count: Integer;
  Ranged: Boolean;
  Scale: TReal48;
  LS: Double;

  procedure Icon(Id, X, Y: Integer);
  var
    S: TBitmap;
  begin
    S := ScaledSprite(Id, FF);
    if S <> nil then
      Cv.Draw(X * FF, Y * FF, S);
  end;

  procedure Text(X, Y: Integer; const T: RawByteString);
  begin
    Cv.TextOut(X * FF, Y * FF, Utf8(T));
  end;

  { the original's Round(V * scale) with the scale taken back to logical
    units (the window is FS times larger) }
  function Scaled(V: LongInt): Integer;
  begin
    if FS = 1 then
      Result := R48Round(R48Mul(R48FromLong(V), Scale))
    else
      Result := Round(V * LS);
  end;

begin
  Move(D.Data[$71D], Scale, SizeOf(Scale));
  LS := R48ToDouble(Scale) / FS;
  W := Scaled(355);
  B := Buffer(W - 1, 64, DialogBackground);
  try
    Cv := B.Canvas;
    { LOGFONT DS:606c: Comic Sans MS, -12, bold; black, transparent }
    SetPaintFont(Cv, FF);
    Cv.Brush.Style := bsClear;
    if D.Data[$70F] <> 0 then
    begin
      if D.Data[$70E] = 1 then
        Move(D.Data[$130 + D.Data[$70F] * $3D], U, SizeOf(U))
      else
        Move(D.Data[$355 + D.Data[$70F] * $3D], U, SizeOf(U));
      Ranged := (U.Range >= 2) or (U.Ability = $11);
      if D.Data[$70E] = 1 then
        X0 := 0
      else if Ranged then
        X0 := Scaled(140)
      else
        X0 := Scaled(178);
      Text(X0, 0, PChar(@U.Name));
      { the rank: 1-3 stars of three kinds, from level 6 on one and +n }
      Count := 0;
      Kind := 0;
      if U.Level < 3 then
        Count := U.Level
      else if U.Level <= 5 then
      begin
        Count := U.Level - 3;
        Kind := 1;
      end
      else
        Kind := 2;
      for I := 0 to Count do
        Icon(6030 + Kind, X0 + I * 12, 16);
      if U.Level > 6 then
        Text(X0 + Count * 12 + 16, 16, '+' + IntToStr(U.Level - 6));
      for I := 0 to 4 do
        Icon(6000 + I, X0 + I * 36, 32);
      if Ranged then
      begin
        case U.UnitType of
          26: Kind := 0;
          9: Kind := Ord(U.Ability = $11);
          4, 6: Kind := 2;
          22: Kind := 3;
          21: Kind := 1;
        else
          Kind := 4;
        end;
        Icon(6010 + Kind, X0 + 180, 32);
      end;
      Icon(6020, X0, 48);
      Icon(6021, X0 + 36, 48);
      Text(X0 + 14, 32, IntToStr(U.Attack));
      Text(X0 + 50, 32, IntToStr(U.Defence));
      Text(X0 + 86, 32, IntToStr(ShortInt(U.MaxHp)));
      Text(X0 + 122, 32, IntToStr(U.Range));
      Text(X0 + 158, 32, IntToStr(U.MaxSteps));
      if Ranged then
        Text(X0 + 194, 32, IntToStr(U.MaxAmmo));
      Text(X0 + 14, 48, IntToStr(U.Kills));
      Text(X0 + 50, 48, IntToStr(U.Pay));
      { SETTEXTALIGN TA_RIGHT: the ability ends at 200 (ranged) / 166 }
      if U.Ability <> 0 then
      begin
        if Ranged then
          I := X0 + 200
        else
          I := X0 + 166;
        Cv.TextOut(I * FF - Cv.TextWidth(Utf8(DSText($53D8 + U.Ability * 25))), 16 * FF,
          Utf8(DSText($53D8 + U.Ability * 25)));
      end;
    end;
    if FInfo = nil then
    begin
      FInfo := TImage.Create(Self);
      FInfo.Parent := Self;
      FInfo.OnMouseMove := @GridMouseMove;
    end;
    Show(FInfo, PSmallInt(@D.Data[$718])^, PSmallInt(@D.Data[$71A])^, W - 1, 64, B, False);
  finally
    B.Free;
  end;
end;

procedure TLogicDialog.AutoMouse(X, Y: Integer);
begin
  Logic.MouseMove(X, Y);
end;

function TLogicDialog.CanClose: Boolean;
begin
  Result := Logic.CanClose;
end;

{ the help context of the types whose port does not keep it (the constant
  the original's Init passes to HelpDlg.Init 1058:01bb, +0x2e); IdHelp
  (1058:0221) calls WinHelp with it }
function HelpContextOf(const Name: string; const D: TDialog): Word;
const
  Names: array[0..15] of string = ('GrainDlg', 'LandDlg', 'InvestDlg', 'TaxDlg',
    'GoodsDlg', 'ProkuristDlg', 'DemographyDlg', 'BudgetDlg', 'CareerDlg', 'AbkommenDlg',
    'SpendenDlg', 'TributDlg', 'SabotageWahlDlg', 'SabotageBudgetDlg', 'TroopDlg', 'GeheimDlg');
  Contexts: array[0..15] of Word = ($65, $66, $67, $68, $6F, $8C, $71, $72, $73, $6A,
    $69, $6B, $8D, $6C, $6D, $74);
var
  I: Integer;
begin
  if Name = 'UnitLookDlg' then
    Exit(D.Data[$4D] + 200);                        { the unit type + 200 }
  if Name = 'RecruitDlg' then
    Exit(PWord(@D.Data[$2E])^);                     { kept by the logic: the type + 200 }
  for I := 0 to High(Names) do
    if Names[I] = Name then
      Exit(Contexts[I]);
  Result := 0;
end;

procedure TLogicDialog.Command(Id: SmallInt);
var
  Ctx: Word;
begin
  { the type's own handler first; OK and Cancel else as TDialog }
  if Logic.Handle(Id) then
    Exit;
  if Id = 999 then
  begin
    Ctx := HelpContextOf(D.Name, D);
    if Ctx <> 0 then
      ShowHelpTopic(Ctx);
    Exit;
  end;
  inherited Command(Id);
end;

procedure TLogicDialog.Notify(Id: SmallInt);
begin
  Logic.Handle(Id);
end;

function DialogClassOf(const Name: string): TKaiserDialogClass;
begin
  if DialogLogicOf(Name) <> nil then
    Result := TLogicDialog
  else
    Result := TKaiserDialog;
end;

end.
