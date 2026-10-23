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
  Rules, Real48, Turn, KaiserRes;

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
      TScrollBar(C).Min := Lo;
      TScrollBar(C).Max := Hi;
      TScrollBar(C).PageSize := 0;
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
      TScrollBar(C).Position := V;
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
    TScrollBar(Ctl).SmallChange := N;
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

procedure TLogicDialog.DrawPortrait(Blink: Byte);
var
  B: TBitmap;
  Base: Word;
begin
  if FPortrait = nil then
  begin
    FPortrait := TImage.Create(Self);
    FPortrait.Parent := Self;
    FPortrait.Transparent := True;
  end;
  FPortrait.SetBounds(Round(12 * Width / 237), Round(64 * Height / 254), 32, 32);
  if Blink <> 0 then
    Base := 1300
  else
    Base := 1100;
  B := Sprite(Base + ShortInt(D.Data[$4E]));
  if B <> nil then
    FPortrait.Picture.Assign(B);
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

procedure TLogicDialog.GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Button = mbLeft then
    Logic.Mouse(TControl(Sender).Left + X, TControl(Sender).Top + Y);
end;

procedure TLogicDialog.GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  Logic.MouseMove(TControl(Sender).Left + X, TControl(Sender).Top + Y);
end;

procedure TLogicDialog.DrawTroops;
var
  P: PPlayer;
  Buf: TBitmap;

  { the grid is drawn off screen and then shown (drawing on the TImage's own
    bitmap left the Cocoa window showing only the first frame) }
  function Grid(var Img: TImage; X, Y, W, H: Integer): TCanvas;
  begin
    if Img = nil then
    begin
      Img := TImage.Create(Self);
      Img.Parent := Self;
      Img.OnMouseDown := @GridMouseDown;
      Img.OnMouseMove := @GridMouseMove;
    end;
    Img.SetBounds(X, Y, W, H);
    Buf.SetSize(W, H);
    Result := Buf.Canvas;
    { the dialog brush (DS:63a6) and NULL_PEN: no frame }
    Result.Brush.Color := DialogBackground;
    Result.FillRect(0, 0, W, H);
  end;

  procedure Icon(Cv: TCanvas; const U: TUnit; Base, X, Y: Integer; Selected: Boolean);
  var
    B: TBitmap;
    N: Integer;
  begin
    if Selected then
    begin
      Cv.Brush.Color := clRed;
      Cv.FillRect(X, Y, X + 31, Y + 31);           { NULL_PEN: one pixel smaller }
    end;
    if U.UnitType = 9 then
      N := Base + 50 + PByte(@U)[$1A]                 { a hero: his picture }
    else
      N := Base + U.UnitType;
    B := Sprite(N);
    if B <> nil then
      Cv.Draw(X, Y, B);
  end;

var
  Cv: TCanvas;
  I: Integer;
  Wall: TBitmap;
begin
  P := PPlayer(@D.Data[$34]);
  Buf := TBitmap.Create;
  try
    Cv := Grid(FHeer, PSmallInt(@D.Data[$710])^, PSmallInt(@D.Data[$712])^, 64, 160);
    for I := 1 to P^.Army1Count do
      if I <= 8 then
        Icon(Cv, P^.Army1[I], 1100, DS.TroopHeerX[I] * 32, DS.TroopHeerY[I] * 32,
          (D.Data[$70A] = I) or (D.Data[$70B] = I));
    FHeer.Picture.Assign(Buf);
    Cv := Grid(FGarde, PSmallInt(@D.Data[$714])^, PSmallInt(@D.Data[$716])^, 112, 112);
    Wall := ResBitmap('MAUER');
    if Wall <> nil then
    begin
      Cv.Brush.Bitmap := Wall;
      { the walls, the gate on the left (Rectangle with NULL_PEN) }
      Cv.FillRect(0, 0, 111, 7);
      Cv.FillRect(105, 8, 111, 104);
      Cv.FillRect(0, 104, 111, 111);
      Cv.FillRect(0, 8, 7, 39);
      Cv.FillRect(0, 72, 7, 104);
      Cv.Brush.Bitmap := nil;
    end;
    for I := 1 to P^.Army2Count do
      if I <= 9 then
        Icon(Cv, P^.Army2[I], 1200, DS.TroopGardeX[I] * 32 + 8, DS.TroopGardeY[I] * 32 + 8,
          (D.Data[$70C] = I) or (D.Data[$70D] = I));
    FGarde.Picture.Assign(Buf);
  finally
    Buf.Free;
  end;
end;

function TLogicDialog.CanClose: Boolean;
begin
  Result := Logic.CanClose;
end;

procedure TLogicDialog.Command(Id: SmallInt);
begin
  { the type's own handler first; OK and Cancel else as TDialog }
  if Logic.Handle(Id) then
    Exit;
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
