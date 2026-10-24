{ The GUI side of the port (LCL): dialogs built from the original dialog
  templates of kaiser.exe and the TGameUI that runs them.

  A TTemplateForm reproduces a DIALOG template: position and size in dialog
  units (from the template font, like Windows' GetDialogBaseUnits), the
  controls with their ids, captions, styles, SS_ICON statics with the named
  bitmap or icon, the background colour from KAISER.INI. The dialog base
  types of segment 12 (docs/functions/ui-infra.md) put their texts into
  statics 101 / 102 and end with their button id. }
unit KaiserLCL;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, Dialogs, LCLType,
  NERes, KaiserTypes, KaiserDS, KaiserUI, Real48;

type
  { a vertical scroll bar no taller than two arrows (9 x 9 units): Windows
    shows only its arrows, LCL's TScrollBar a knob without them. The
    position works like the scroll bar's: the upper arrow is SB_LINEUP (-1) }
  TSpinBar = class(TUpDown)
  public
    Pos, Lo, Hi: Integer;
    Step: Integer;                  { SetLineStep }
  end;

  TTemplateForm = class(TForm)
  private
    FTemplate: TDlgTemplate;
    FBaseX, FBaseY: Integer;
    FItems: array of TControl;
    FIds: array of SmallInt;
    FAuto: array of Boolean;        { auto check box / radio button style }
    FState: array of Boolean;       { the check state the game set }
    procedure ButtonClick(Sender: TObject);
    procedure ControlClick(Sender: TObject);
    procedure SpinClick(Sender: TObject; Button: TUDBtnType);
    function DU(V: Integer; Horz: Boolean): Integer;
    function IndexOf(C: TControl): Integer;
    procedure ShowStates;
  protected
    { > 0 while the program changes controls (no notifications) }
    FQuiet: Integer;
  public
    { the result of the dialog: the id of the button that ended it }
    EndId: SmallInt;
    constructor CreateFromTemplate(AOwner: TComponent; const T: TDlgTemplate);
    function Item(Id: SmallInt): TControl;
    procedure SetItemText(Id: SmallInt; const Raw: RawByteString);
    procedure EnableItem(Id: SmallInt; On: Boolean);
    { the check state of a check box or radio button (BM_GETCHECK/SETCHECK) }
    function Checked(Id: SmallInt): Boolean;
    procedure SetChecked(Id: SmallInt; On: Boolean);
    { a button without its own handler: ids 1 (OK) and 2 (Cancel) end the
      dialog; others end it too for the choice dialogs }
    procedure Command(Id: SmallInt); virtual;
    { a check box, radio button or scroll bar was used (OWL IdCtlNNN) }
    procedure Notify(Id: SmallInt); virtual;
    { the autopilot moves the mouse to (X, Y) before its snapshot }
    procedure AutoMouse(X, Y: Integer); virtual;
    procedure AutoClicks(const Points: string);
    function Run: SmallInt;
    { EndDlg(code) }
    procedure EndWith(Code: SmallInt);
  private
    FAutoTimer: TTimer;
    procedure AutoTick(Sender: TObject);
  end;

var
  Exe: TNEFile;
  DialogBackground: TColor = $00ACFFFF;   { INI Hintergrund rot/gruen/blau = 255,255,172 }

{ kaiser.exe next to the program, in Kaiser/ or ../Kaiser or given as -exe PATH }
function FindExe: string;
{ the port's KAISER.INI (macOS: Application Support, Windows: %APPDATA%\Kaiser);
  the original's next to
  kaiser.exe is read when the port has none yet }
function SettingsFile: string;
function OwnSettingsFile: string;
{ kaiser.mid next to kaiser.exe }
function MusicFile: string;
function ResBitmap(const Name: RawByteString; Id: Word = 0): TBitmap;
{ a sprite: BITMAP Id with the mask BITMAP Id + 1000 (black = sprite, white =
  transparent; Bmp_DrawMasked 1078:00c4) as a 32-bit bitmap with alpha }
function Sprite(Id: Word): TBitmap;
function Utf8(const Raw: RawByteString): string;

implementation

uses
  Process, IntfGraphics, FPImage, GraphType, Buttons, WinScroll;

function Utf8(const Raw: RawByteString): string;
begin
  Result := CP1252ToUTF8(Raw);
end;

function FindExe: string;
var
  I: Integer;
  Dir: string;
begin
  for I := 1 to ParamCount - 1 do
    if ParamStr(I) = '-exe' then
      Exit(ParamStr(I + 1));
  Dir := ExtractFilePath(ParamStr(0));
  for Result in [Dir + 'kaiser.exe', Dir + 'Kaiser/kaiser.exe', Dir + '../Kaiser/kaiser.exe',
                 Dir + '../../Kaiser/kaiser.exe', Dir + '../../../../Kaiser/kaiser.exe',
                 Dir + '../../../../../Kaiser/kaiser.exe'] do
    { (on Windows the port itself may be called Kaiser.exe) }
    if FileExists(Result) and
       (CompareText(ExpandFileName(Result), ExpandFileName(ParamStr(0))) <> 0) then
      Exit;
  Result := 'kaiser.exe';
end;

function OwnSettingsFile: string;
begin
  {$ifdef windows}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'Kaiser\KAISER.INI';
  {$else}
  {$ifdef darwin}
  Result := GetUserDir + 'Library/Application Support/Kaiser/KAISER.INI';
  {$else}
  Result := GetUserDir + '.config/kaiser/KAISER.INI';
  {$endif}
  {$endif}
end;

function MusicFile: string;
begin
  Result := ExtractFilePath(FindExe) + 'kaiser.mid';
end;

function SettingsFile: string;
begin
  Result := OwnSettingsFile;
  if not FileExists(Result) then
    Result := ExtractFilePath(FindExe) + 'KAISER.INI';
end;

var
  BitmapCache: TStringList;

function ResBitmap(const Name: RawByteString; Id: Word): TBitmap;
var
  Key: string;
  Data: TBytes;
  S: TMemoryStream;
  K: Integer;
begin
  Key := UpperCase(Name) + '#' + IntToStr(Id);
  K := BitmapCache.IndexOf(Key);
  if K >= 0 then
    Exit(TBitmap(BitmapCache.Objects[K]));
  Result := nil;
  Data := Exe.BitmapFile(Name, Id);
  if Data <> nil then
  begin
    S := TMemoryStream.Create;
    try
      S.WriteBuffer(Data[0], Length(Data));
      S.Position := 0;
      Result := TBitmap.Create;
      try
        Result.LoadFromStream(S);
      except
        FreeAndNil(Result);
      end;
    finally
      S.Free;
    end;
  end;
  BitmapCache.AddObject(Key, Result);
end;

var
  SpriteCache: TStringList;
  AutoSeen: TStringList;            { KAISER_AUTOANSWER: how often each dialog came }

function Sprite(Id: Word): TBitmap;
var
  Img, Mask: TBitmap;
  Src, MSrc, Dst: TLazIntfImage;
  X, Y: Integer;
  C: TFPColor;
  K: Integer;
begin
  K := SpriteCache.IndexOf(IntToStr(Id));
  if K >= 0 then
    Exit(TBitmap(SpriteCache.Objects[K]));
  Result := nil;
  Img := ResBitmap('', Id);
  Mask := ResBitmap('', Id + 1000);
  if Img <> nil then
  begin
    Src := Img.CreateIntfImage;
    if Mask <> nil then
      MSrc := Mask.CreateIntfImage
    else
      MSrc := nil;
    Dst := TLazIntfImage.Create(Img.Width, Img.Height, [riqfRGB, riqfAlpha]);
    try
      Dst.CreateData;
      for Y := 0 to Img.Height - 1 do
        for X := 0 to Img.Width - 1 do
        begin
          C := Src.Colors[X, Y];
          C.Alpha := $FFFF;
          if (MSrc <> nil) and (X < MSrc.Width) and (Y < MSrc.Height) and
             (MSrc.Colors[X, Y].Red > $8000) then
            C.Alpha := 0;
          Dst.Colors[X, Y] := C;
        end;
      Result := TBitmap.Create;
      Result.LoadFromIntfImage(Dst);
    finally
      Dst.Free;
      Src.Free;
      MSrc.Free;
    end;
  end;
  SpriteCache.AddObject(IntToStr(Id), Result);
end;

{ an ICON resource into an image (SS_ICON statics) }
procedure LoadIcon(Img: TImage; const Name: RawByteString);
var
  Data: TBytes;
  S: TMemoryStream;
  Ico: TIcon;
begin
  Data := Exe.IconFile(Name);
  if Data = nil then
    Exit;
  S := TMemoryStream.Create;
  Ico := TIcon.Create;
  try
    S.WriteBuffer(Data[0], Length(Data));
    S.Position := 0;
    try
      Ico.LoadFromStream(S);
      Img.Picture.Assign(Ico);
      Img.AutoSize := True;
    except
    end;
  finally
    Ico.Free;
    S.Free;
  end;
end;

{ -- TTemplateForm ---------------------------------------------------------- }

constructor TTemplateForm.CreateFromTemplate(AOwner: TComponent; const T: TDlgTemplate);
const
  Sample = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  I: Integer;
  It: TDlgItem;
  C: TControl;
  Kind: Byte;
  Bmp, Measure: TBitmap;
  Cap: TLabel;
begin
  inherited CreateNew(AOwner);
  FTemplate := T;
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  Color := DialogBackground;
  Caption := Utf8(T.Caption);
  if T.FontFace <> '' then
  begin
    Font.Name := Utf8(T.FontFace);
    { Windows laid the dialogs out at 96 DPI: there LCL converts the points
      itself, on macOS a point is a pixel }
    {$ifdef darwin}
    Font.Size := Round(T.FontSize * 96 / 72);
    {$else}
    Font.Size := T.FontSize;
    {$endif}
  end;
  { the dialog base units of the template font (GetDialogBaseUnits) }
  Measure := TBitmap.Create;
  try
    Measure.SetSize(4, 4);
    Measure.Canvas.Font := Font;
    FBaseX := (Measure.Canvas.TextWidth(Sample) div 26 + 1) div 2;
    FBaseY := Measure.Canvas.TextHeight(Sample);
  finally
    Measure.Free;
  end;
  if FBaseX < 4 then FBaseX := 6;
  if FBaseY < 8 then FBaseY := 13;
  ClientWidth := DU(T.CX, True);
  ClientHeight := DU(T.CY, False);
  SetLength(FItems, Length(T.Items));
  SetLength(FIds, Length(T.Items));
  SetLength(FAuto, Length(T.Items));
  SetLength(FState, Length(T.Items));
  for I := 0 to High(T.Items) do
  begin
    It := T.Items[I];
    C := nil;
    if It.ClassName = 'BUTTON' then
    begin
      Kind := It.Style and $F;
      case Kind of
        2, 3, 5, 6:
          begin
            C := TCheckBox.Create(Self);
            TCheckBox(C).Caption := Utf8(It.Text);
            TCheckBox(C).OnClick := @ControlClick;
          end;
        4, 9:
          begin
            C := TRadioButton.Create(Self);
            TRadioButton(C).Caption := Utf8(It.Text);
            TRadioButton(C).OnClick := @ControlClick;
          end;
        7:
          begin
            { a group box as a frame (a graphic control, so that the labels
              inside stay visible) with its caption }
            C := TBevel.Create(Self);
            TBevel(C).Shape := bsFrame;
            if It.Text <> '' then
            begin
              Cap := TLabel.Create(Self);
              Cap.Parent := Self;
              Cap.Caption := ' ' + Utf8(It.Text) + ' ';
              Cap.Color := DialogBackground;
              Cap.Transparent := False;
              Cap.Left := DU(It.X, True) + 6;
              Cap.Top := DU(It.Y, False) + FBaseY div 2 - Cap.Canvas.TextHeight('X') div 2;
            end;
          end;
      else
        if DU(It.CX, True) < 24 then
        begin
          { a native Cocoa button keeps its padding and squeezes a short
            caption ("?", 9 units wide): one that LCL draws }
          C := TSpeedButton.Create(Self);
          TSpeedButton(C).Caption := Utf8(It.Text);
          TSpeedButton(C).OnClick := @ButtonClick;
          C.Tag := It.Id;
        end
        else
        begin
          C := TButton.Create(Self);
          TButton(C).Caption := Utf8(It.Text);
          TButton(C).Default := Kind = 1;
          TButton(C).OnClick := @ButtonClick;
          TButton(C).Tag := It.Id;
        end;
      end;
    end
    else if It.ClassName = 'EDIT' then
    begin
      C := TEdit.Create(Self);
      TEdit(C).Text := Utf8(It.Text);
    end
    else if It.ClassName = 'LISTBOX' then
    begin
      C := TListBox.Create(Self);
      TListBox(C).OnClick := @ControlClick;            { LBN_SELCHANGE -> IdNNN }
    end
    else if It.ClassName = 'COMBOBOX' then
    begin
      C := TComboBox.Create(Self);
      TComboBox(C).Style := csDropDownList;
      TComboBox(C).OnSelect := @ControlClick;          { CBN_SELCHANGE -> IdNNN }
    end
    else if (It.ClassName = 'SCROLLBAR') and (It.Style and 1 <> 0) and (It.CY <= 2 * It.CX) then
    begin
      C := TSpinBar.Create(Self);
      TSpinBar(C).Orientation := udVertical;
      TSpinBar(C).Step := 1;
      TSpinBar(C).OnClick := @SpinClick;
    end
    else if It.ClassName = 'SCROLLBAR' then
    begin
      {$ifdef darwin}
      { with arrows like Windows' (macOS' own has none) }
      C := TWinScrollBar.Create(Self);
      TWinScrollBar(C).Vertical := It.Style and 1 <> 0;
      TWinScrollBar(C).OnChange := @ControlClick;
      {$else}
      C := TScrollBar.Create(Self);
      if It.Style and 1 <> 0 then
        TScrollBar(C).Kind := sbVertical;
      TScrollBar(C).OnChange := @ControlClick;
      TScrollBar(C).LargeChange := 10;                { OWL's PageMagnitude }
      {$endif}
    end
    else if (It.ClassName = 'STATIC') and (It.Style and $F = 3) then
    begin
      { SS_ICON: the bitmap (or icon) of that name }
      C := TImage.Create(Self);
      Bmp := ResBitmap(It.Text);
      if Bmp <> nil then
      begin
        TImage(C).Picture.Assign(Bmp);
        TImage(C).Transparent := True;
        TImage(C).AutoSize := True;
      end
      else
        LoadIcon(TImage(C), It.Text);
    end
    else
    begin
      C := TLabel.Create(Self);
      TLabel(C).AutoSize := False;
      TLabel(C).WordWrap := True;
      TLabel(C).Caption := Utf8(It.Text);
      case It.Style and $F of
        1: TLabel(C).Alignment := taCenter;
        2: TLabel(C).Alignment := taRightJustify;
      end;
      if It.Style and $F in [4, 5, 6, 7, 8, 9] then        { frames, rectangles }
        TLabel(C).Caption := '';
    end;
    C.Parent := Self;
    C.Left := DU(It.X, True);
    C.Top := DU(It.Y, False);
    C.Font.Color := clBlack;
    if not ((C is TImage) and TImage(C).AutoSize) then
    begin
      C.Width := DU(It.CX, True);
      C.Height := DU(It.CY, False);
    end;
    C.Visible := It.Style and $10000000 <> 0;               { WS_VISIBLE }
    C.Enabled := It.Style and $08000000 = 0;                { WS_DISABLED }
    if C is TBevel then
    begin
      { Windows draws a group box's frame half a text line below its top,
        with or without a caption }
      C.Top := C.Top + FBaseY div 2;
      C.Height := C.Height - FBaseY div 2;
      C.SendToBack;
    end;
    FItems[I] := C;
    FIds[I] := It.Id;
    FAuto[I] := (It.ClassName = 'BUTTON') and (It.Style and $F in [3, 6, 9]);
    FState[I] := False;
  end;
end;

function TTemplateForm.DU(V: Integer; Horz: Boolean): Integer;
begin
  if Horz then
    Result := V * FBaseX div 4
  else
    Result := V * FBaseY div 8;
end;

function TTemplateForm.Item(Id: SmallInt): TControl;
var
  I: Integer;
begin
  for I := 0 to High(FIds) do
    if FIds[I] = Id then
      Exit(FItems[I]);
  Result := nil;
end;

procedure TTemplateForm.SetItemText(Id: SmallInt; const Raw: RawByteString);
var
  C: TControl;
begin
  C := Item(Id);
  if C <> nil then
    C.Caption := Utf8(Raw);
end;

procedure TTemplateForm.EnableItem(Id: SmallInt; On: Boolean);
var
  C: TControl;
begin
  C := Item(Id);
  if C <> nil then
    C.Enabled := On;
end;

function TTemplateForm.IndexOf(C: TControl): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if FItems[I] = C then
      Exit(I);
  Result := -1;
end;

function CheckedOf(C: TControl): Boolean;
begin
  if C is TCheckBox then
    Result := TCheckBox(C).Checked
  else if C is TRadioButton then
    Result := TRadioButton(C).Checked
  else
    Result := False;
end;

procedure TTemplateForm.ControlClick(Sender: TObject);
var
  K: Integer;
  C: TControl;
begin
  K := IndexOf(TControl(Sender));
  if K < 0 then
    Exit;
  C := FItems[K];
  if FQuiet > 0 then
  begin
    if FAuto[K] then
      FState[K] := CheckedOf(C);
    Exit;
  end;
  if FAuto[K] then
    FState[K] := CheckedOf(C);
  { BS_CHECKBOX / BS_RADIOBUTTON: only the program changes the state; LCL has
    also unchecked the other radio buttons of the form }
  ShowStates;
  Notify(FIds[K]);
end;

procedure TTemplateForm.SpinClick(Sender: TObject; Button: TUDBtnType);
var
  B: TSpinBar;
begin
  B := TSpinBar(Sender);
  if Button = btNext then
    Dec(B.Pos, B.Step)
  else
    Inc(B.Pos, B.Step);
  if B.Pos < B.Lo then
    B.Pos := B.Lo;
  if B.Pos > B.Hi then
    B.Pos := B.Hi;
  ControlClick(Sender);
end;

{ the non-auto buttons show the state the game set: LCL unchecks all other
  radio buttons of a parent when one is checked, Windows leaves them alone }
procedure TTemplateForm.ShowStates;
var
  I: Integer;
  Pass: Boolean;
begin
  Inc(FQuiet);
  try
    for Pass in Boolean do              { the unchecked ones first }
      for I := 0 to High(FItems) do
        if not FAuto[I] and (FState[I] = Pass) then
          if FItems[I] is TCheckBox then
            TCheckBox(FItems[I]).Checked := Pass
          else if FItems[I] is TRadioButton then
            TRadioButton(FItems[I]).Checked := Pass;
  finally
    Dec(FQuiet);
  end;
end;

function TTemplateForm.Checked(Id: SmallInt): Boolean;
var
  K: Integer;
begin
  K := IndexOf(Item(Id));
  if K < 0 then
    Exit(False);
  if FAuto[K] then
    FState[K] := CheckedOf(FItems[K]);
  Result := FState[K];
end;

procedure TTemplateForm.SetChecked(Id: SmallInt; On: Boolean);
var
  K, I: Integer;
begin
  K := IndexOf(Item(Id));
  if K < 0 then
    Exit;
  FState[K] := On;
  if FAuto[K] then
  begin
    Inc(FQuiet);
    try
      if FItems[K] is TCheckBox then
        TCheckBox(FItems[K]).Checked := On
      else if FItems[K] is TRadioButton then
        TRadioButton(FItems[K]).Checked := On;
    finally
      Dec(FQuiet);
    end;
    for I := 0 to High(FItems) do
      if FAuto[I] then
        FState[I] := CheckedOf(FItems[I]);
  end;
  ShowStates;
end;

procedure TTemplateForm.Notify(Id: SmallInt);
begin
end;

procedure TTemplateForm.AutoMouse(X, Y: Integer);
begin
end;

type
  TControlAccess = class(TControl);

procedure TTemplateForm.AutoClicks(const Points: string);
var
  L: TStringList;
  I: Integer;
  P: TPoint;
  C: TControl;
begin
  L := TStringList.Create;
  try
    L.Delimiter := ';';
    L.DelimitedText := Points;
    for I := 0 to L.Count - 1 do
    begin
      P.X := StrToIntDef(Copy(L[I], 1, Pos(':', L[I]) - 1), 0);
      P.Y := StrToIntDef(Copy(L[I], Pos(':', L[I]) + 1, 9), 0);
      C := ControlAtPos(P, [capfRecursive, capfAllowWinControls]);
      if C = nil then
        Continue;
      P := C.ScreenToClient(ClientToScreen(P));
      TControlAccess(C).MouseDown(mbLeft, [], P.X, P.Y);
      TControlAccess(C).MouseUp(mbLeft, [], P.X, P.Y);
    end;
  finally
    L.Free;
  end;
end;

procedure TTemplateForm.ButtonClick(Sender: TObject);
begin
  Command(TComponent(Sender).Tag);
end;

procedure TTemplateForm.Command(Id: SmallInt);
begin
  EndId := Id;
  ModalResult := mrOK;
end;

var
  AutoCount: Integer = 0;

procedure TTemplateForm.AutoTick(Sender: TObject);
var
  Answer: string;
  B: TBitmap;
  P: TPortableNetworkGraphic;
  I: Integer;
  Def: SmallInt;
begin
  { KAISER_AUTOPILOT=DIR: save the dialog as DIR/NNN_NAME.png, then press
    its default button (else OK) }
  FAutoTimer.Enabled := False;
  Inc(AutoCount);
  { KAISER_AUTOCLICK=NAME=X:Y;X:Y,...: left clicks on the controls at those
    client points of dialog NAME first (mouse down and up straight to the
    control: synthetic OS clicks do not reach an inactive app) }
  with TStringList.Create do
  try
    CommaText := GetEnvironmentVariable('KAISER_AUTOCLICK');
    if IndexOfName(FTemplate.Name) >= 0 then
      AutoClicks(Values[FTemplate.Name]);
  finally
    Free;
  end;
  { KAISER_AUTOSELECT=NAME=ID:INDEX,...: the user picks entry INDEX of the
    combo box ID first }
  with TStringList.Create do
  try
    CommaText := GetEnvironmentVariable('KAISER_AUTOSELECT');
    if IndexOfName(FTemplate.Name) >= 0 then
    begin
      Answer := Values[FTemplate.Name];
      if Item(StrToIntDef(Copy(Answer, 1, Pos(':', Answer) - 1), 0)) is TComboBox then
        with TComboBox(Item(StrToIntDef(Copy(Answer, 1, Pos(':', Answer) - 1), 0))) do
        begin
          ItemIndex := StrToIntDef(Copy(Answer, Pos(':', Answer) + 1, 9), 0);
          if Assigned(OnSelect) then
            OnSelect(Item(StrToIntDef(Copy(Answer, 1, Pos(':', Answer) - 1), 0)));
        end;
    end;
  finally
    Free;
  end;
  { KAISER_AUTOMOUSE=NAME=X:Y,...: the mouse at (X, Y) of dialog NAME first }
  with TStringList.Create do
  try
    CommaText := GetEnvironmentVariable('KAISER_AUTOMOUSE');
    if IndexOfName(FTemplate.Name) >= 0 then
    begin
      Answer := Values[FTemplate.Name];
      AutoMouse(StrToIntDef(Copy(Answer, 1, Pos(':', Answer) - 1), 0),
        StrToIntDef(Copy(Answer, Pos(':', Answer) + 1, 9), 0));
    end;
  finally
    Free;
  end;
  B := GetFormImage;
  P := TPortableNetworkGraphic.Create;
  try
    P.Assign(B);
    P.SaveToFile(IncludeTrailingPathDelimiter(GetEnvironmentVariable('KAISER_AUTOPILOT')) +
      Format('%.3d_%s.png', [AutoCount, FTemplate.Name]));
  finally
    P.Free;
    B.Free;
  end;
  Def := 1;
  for I := 0 to High(FTemplate.Items) do
    if (FTemplate.Items[I].ClassName = 'BUTTON') and (FTemplate.Items[I].Style and $F = 1) then
      Def := FTemplate.Items[I].Id;
  { KAISER_AUTOANSWER=NAME=ID,...: press button ID in dialog NAME instead;
    NAME=ID/N only the first N times NAME appears }
  AutoSeen.Values[FTemplate.Name] := IntToStr(StrToIntDef(AutoSeen.Values[FTemplate.Name], 0) + 1);
  with TStringList.Create do
  try
    CommaText := GetEnvironmentVariable('KAISER_AUTOANSWER');
    if IndexOfName(FTemplate.Name) >= 0 then
    begin
      Answer := Values[FTemplate.Name];
      if (Pos('/', Answer) = 0) or
         (StrToInt(AutoSeen.Values[FTemplate.Name]) <= StrToIntDef(Copy(Answer, Pos('/', Answer) + 1, 9), 0)) then
        Def := StrToIntDef(Copy(Answer, 1, Pos('/', Answer + '/') - 1), Def);
    end;
  finally
    Free;
  end;
  Command(Def);
  { a button that did not end the dialog (help, recruit): the next round }
  if ModalResult = mrNone then
    FAutoTimer.Enabled := True;
end;

procedure TTemplateForm.EndWith(Code: SmallInt);
begin
  EndId := Code;
  ModalResult := mrOK;
end;

function TTemplateForm.Run: SmallInt;
begin
  EndId := 2;
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
  begin
    FAutoTimer := TTimer.Create(Self);
    { KAISER_AUTODELAY=MS: how long each dialog stays open }
    FAutoTimer.Interval := StrToIntDef(GetEnvironmentVariable('KAISER_AUTODELAY'), 300);
    FAutoTimer.OnTimer := @AutoTick;
  end;
  ShowModal;
  Result := EndId;
end;

initialization
  AutoSeen := TStringList.Create;
  SpriteCache := TStringList.Create;
  BitmapCache := TStringList.Create;
  BitmapCache.CaseSensitive := True;
end.
