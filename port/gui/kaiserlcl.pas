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
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Dialogs, LCLType,
  NERes, KaiserTypes, KaiserDS, KaiserUI, Real48;

type
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
    function DU(V: Integer; Horz: Boolean): Integer;
    function IndexOf(C: TControl): Integer;
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
    { a button without its own handler: ids 1 (OK) and 2 (Cancel) end the
      dialog; others end it too for the choice dialogs }
    procedure Command(Id: SmallInt); virtual;
    { a check box, radio button or scroll bar was used (OWL IdCtlNNN) }
    procedure Notify(Id: SmallInt); virtual;
    function Run: SmallInt;
  private
    FAutoTimer: TTimer;
    procedure AutoTick(Sender: TObject);
  end;

var
  Exe: TNEFile;
  DialogBackground: TColor = $00ACFFFF;   { INI Hintergrund rot/gruen/blau = 255,255,172 }

{ kaiser.exe next to the program, in ../Kaiser or given as -exe PATH }
function FindExe: string;
{ the port's KAISER.INI (Application Support); the original's next to
  kaiser.exe is read when the port has none yet }
function SettingsFile: string;
function OwnSettingsFile: string;
function ResBitmap(const Name: RawByteString; Id: Word = 0): TBitmap;
{ a sprite: BITMAP Id with the mask BITMAP Id + 1000 (black = sprite, white =
  transparent; Bmp_DrawMasked 1078:00c4) as a 32-bit bitmap with alpha }
function Sprite(Id: Word): TBitmap;
function Utf8(const Raw: RawByteString): string;

implementation

uses
  Process, IntfGraphics, FPImage, GraphType;

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
  for Result in [Dir + 'kaiser.exe', Dir + '../Kaiser/kaiser.exe', Dir + '../../Kaiser/kaiser.exe',
                 Dir + '../../../../Kaiser/kaiser.exe', Dir + '../../../../../Kaiser/kaiser.exe'] do
    if FileExists(Result) then
      Exit;
  Result := 'kaiser.exe';
end;

function OwnSettingsFile: string;
begin
  Result := GetUserDir + 'Library/Application Support/Kaiser/KAISER.INI';
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
    Font.Size := Round(T.FontSize * 96 / 72);   { Windows laid the dialogs out at 96 DPI }
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
              Cap.Top := DU(It.Y, False) - Cap.Canvas.TextHeight('X') div 2;
            end;
          end;
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
      C := TListBox.Create(Self)
    else if It.ClassName = 'COMBOBOX' then
    begin
      C := TComboBox.Create(Self);
      TComboBox(C).Style := csDropDownList;
    end
    else if It.ClassName = 'SCROLLBAR' then
    begin
      C := TScrollBar.Create(Self);
      if It.Style and 1 <> 0 then
        TScrollBar(C).Kind := sbVertical;
      TScrollBar(C).OnChange := @ControlClick;
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
      C.SendToBack;
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
    FState[K] := CheckedOf(C);
    Exit;
  end;
  if ((C is TCheckBox) or (C is TRadioButton)) and not FAuto[K] then
  begin
    { BS_CHECKBOX / BS_RADIOBUTTON: only the program changes the state }
    Inc(FQuiet);
    try
      if C is TCheckBox then
        TCheckBox(C).Checked := FState[K]
      else
        TRadioButton(C).Checked := FState[K];
    finally
      Dec(FQuiet);
    end;
  end
  else
    FState[K] := CheckedOf(C);
  Notify(FIds[K]);
end;

procedure TTemplateForm.Notify(Id: SmallInt);
begin
end;

procedure TTemplateForm.ButtonClick(Sender: TObject);
begin
  Command(TButton(Sender).Tag);
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
  B: TBitmap;
  P: TPortableNetworkGraphic;
  I: Integer;
  Def: SmallInt;
begin
  { KAISER_AUTOPILOT=DIR: save the dialog as DIR/NNN_NAME.png, then press
    its default button (else OK) }
  FAutoTimer.Enabled := False;
  Inc(AutoCount);
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
  Command(Def);
end;

function TTemplateForm.Run: SmallInt;
begin
  EndId := 2;
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
  begin
    FAutoTimer := TTimer.Create(Self);
    FAutoTimer.Interval := 300;
    FAutoTimer.OnTimer := @AutoTick;
  end;
  ShowModal;
  Result := EndId;
end;

initialization
  SpriteCache := TStringList.Create;
  BitmapCache := TStringList.Create;
  BitmapCache.CaseSensitive := True;
end.
