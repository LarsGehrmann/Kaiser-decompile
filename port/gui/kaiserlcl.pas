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
    procedure ButtonClick(Sender: TObject);
    function DU(V: Integer; Horz: Boolean): Integer;
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
    function Run: SmallInt;
  end;

  TLclUI = class(TGameUI)
  private
    FForms: array of record
      D: TDialog;
      F: TTemplateForm;
      Args: array of TUIArg;
    end;
    function FormOf(D: TDialog): TTemplateForm;
  public
    MainForm: TForm;
    function Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog; override;
    function Execute(D: TDialog): SmallInt; override;
    procedure Done(D: TDialog; Flag: Word); override;
    function ExecDialog(D: TDialog): SmallInt; override;
    function GetText(D: TDialog): PChar; override;
    function Call(const Name: string; const Args: array of TUIArg): SmallInt; override;
  end;

var
  Exe: TNEFile;
  DialogBackground: TColor = $00ACFFFF;   { INI Hintergrund rot/gruen/blau = 255,255,172 }

{ kaiser.exe next to the program, in ../Kaiser or given as -exe PATH }
function FindExe: string;
function ResBitmap(const Name: RawByteString; Id: Word = 0): TBitmap;
function Utf8(const Raw: RawByteString): string;

implementation

uses
  Process;

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

{ -- TTemplateForm ---------------------------------------------------------- }

constructor TTemplateForm.CreateFromTemplate(AOwner: TComponent; const T: TDlgTemplate);
const
  Sample = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  I: Integer;
  It: TDlgItem;
  C: TControl;
  Kind: Byte;
  Bmp: TBitmap;
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
    Font.Size := T.FontSize;
  end;
  Canvas.Font := Font;
  FBaseX := (Canvas.TextWidth(Sample) div 26 + 1) div 2;
  FBaseY := Canvas.TextHeight(Sample);
  if FBaseX < 4 then FBaseX := 6;
  if FBaseY < 8 then FBaseY := 13;
  ClientWidth := DU(T.CX, True);
  ClientHeight := DU(T.CY, False);
  SetLength(FItems, Length(T.Items));
  SetLength(FIds, Length(T.Items));
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
          end;
        4, 9:
          begin
            C := TRadioButton.Create(Self);
            TRadioButton(C).Caption := Utf8(It.Text);
          end;
        7:
          begin
            C := TGroupBox.Create(Self);
            TGroupBox(C).Caption := Utf8(It.Text);
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
      end;
      TImage(C).AutoSize := Bmp <> nil;
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
    if not ((C is TImage) and TImage(C).AutoSize) then
    begin
      C.Width := DU(It.CX, True);
      C.Height := DU(It.CY, False);
    end;
    C.Visible := It.Style and $10000000 <> 0;               { WS_VISIBLE }
    C.Enabled := It.Style and $08000000 = 0;                { WS_DISABLED }
    if C is TGroupBox then
      C.SendToBack;
    FItems[I] := C;
    FIds[I] := It.Id;
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

procedure TTemplateForm.ButtonClick(Sender: TObject);
begin
  Command(TButton(Sender).Tag);
end;

procedure TTemplateForm.Command(Id: SmallInt);
begin
  EndId := Id;
  ModalResult := mrOK;
end;

function TTemplateForm.Run: SmallInt;
begin
  EndId := 2;
  ShowModal;
  Result := EndId;
end;

{ -- TLclUI ------------------------------------------------------------------ }

function ArgText(const A: TUIArg): RawByteString;
begin
  if (A.Kind = uaStr) and (PtrUInt(A.P) >= $10000) then
    Result := PChar(A.P)
  else
    Result := '';
end;

function TLclUI.FormOf(D: TDialog): TTemplateForm;
var
  I: Integer;
begin
  for I := 0 to High(FForms) do
    if FForms[I].D = D then
      Exit(FForms[I].F);
  Result := nil;
end;

function TLclUI.Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog;
var
  K, I: Integer;
  TplName: RawByteString;
  F: TTemplateForm;
begin
  Result := inherited Dialog(Name, VMT, Args);
  F := nil;
  if (Length(Args) >= 2) and (Name <> 'TButton') then
  begin
    TplName := ArgText(Args[1]);
    if (TplName <> '') and (Exe.Find(RT_DIALOG, TplName) <> nil) then
      F := TTemplateForm.CreateFromTemplate(MainForm, Exe.Dialog(TplName));
  end;
  K := Length(FForms);
  SetLength(FForms, K + 1);
  FForms[K].D := Result;
  FForms[K].F := F;
  SetLength(FForms[K].Args, Length(Args));
  for I := 0 to High(Args) do
    FForms[K].Args[I] := Args[I];
  if F = nil then
    Exit;
  { what the SetupWindow of the base types puts into the dialog }
  if (Name = 'MessageDlg') or (Name = 'HelpMessageDlg') then
    F.SetItemText(101, ArgText(Args[2]))
  else if (Name = 'Message2Dlg') or (Name = 'HelpChoice2Dlg') then
  begin
    F.SetItemText(101, ArgText(Args[2]));
    F.SetItemText(102, ArgText(Args[3]));
  end;
end;

function TLclUI.Execute(D: TDialog): SmallInt;
var
  F: TTemplateForm;
begin
  F := FormOf(D);
  if F = nil then
    Exit(inherited Execute(D));
  Result := F.Run;
  if (D.Name = 'HeroNameDlg') and (F.Item(101) is TEdit) then
    StrPLCopy(PChar(@D.Data[DialogTextOfs]), TEdit(F.Item(101)).Text, 24);
end;

procedure TLclUI.Done(D: TDialog; Flag: Word);
var
  I: Integer;
begin
  for I := 0 to High(FForms) do
    if FForms[I].D = D then
    begin
      FreeAndNil(FForms[I].F);
      FForms[I].D := nil;
    end;
end;

function TLclUI.ExecDialog(D: TDialog): SmallInt;
begin
  Result := Execute(D);
end;

function TLclUI.GetText(D: TDialog): PChar;
begin
  Result := D.Text;
end;

function TLclUI.Call(const Name: string; const Args: array of TUIArg): SmallInt;
var
  Data: TBytes;
  FN: string;
  S: TFileStream;
begin
  Result := 0;
  if Name = 'PlaySound' then
  begin
    { WAVEDATA resource n, played by afplay (sndPlaySound async) }
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

initialization
  BitmapCache := TStringList.Create;
  BitmapCache.CaseSensitive := True;
end.
