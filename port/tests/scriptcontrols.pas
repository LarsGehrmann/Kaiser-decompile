{ The controls of a dialog in the differential tests: the same state model
  as tools/emu/dlg_driver.py (texts from the template, check states, scroll
  ranges and positions, list entries and selections), every method logged
  through UI.Note in the same format, and the script driver that plays the
  user events of a vector (dlg=) on a dialog type. }
unit ScriptControls;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, NERes, KaiserUI;

type
  TCtl = class
    Id: SmallInt;
    Cls: RawByteString;
    Style: LongWord;
    Text: RawByteString;
    Check: Word;
    Lo, Hi, Pos: SmallInt;
    Items: TStringList;
    Sel: SmallInt;
    Enabled: Boolean;
    destructor Destroy; override;
  end;

  TScriptControls = class(TDlgControls)
  private
    FCtls: array of TCtl;
    FTemplate: TDlgTemplate;
    FDlgIndex: Integer;
    function Ctl(Id: SmallInt): TCtl;
    function Known(Id: SmallInt): Boolean;
  public
    EndCode: SmallInt;
    Ended: Boolean;
    constructor Create(const Template: TDlgTemplate; DlgIndex: Integer);
    destructor Destroy; override;
    procedure SetText(Id: SmallInt; S: PChar); override;
    function GetText(Id: SmallInt; Buf: PChar; MaxChars: Integer): Integer; override;
    procedure Enable(Id: SmallInt; On: Boolean); override;
    procedure Show(Id: SmallInt; Cmd: SmallInt); override;
    procedure SetCaption(S: PChar); override;
    procedure SetCheck(Id: SmallInt; V: Word); override;
    function GetCheck(Id: SmallInt): Word; override;
    procedure SetRange(Id: SmallInt; Lo, Hi: SmallInt); override;
    procedure SetPosition(Id: SmallInt; V: SmallInt); override;
    function GetPosition(Id: SmallInt): SmallInt; override;
    function AddString(Id: SmallInt; S: PChar): SmallInt; override;
    function GetSelIndex(Id: SmallInt): SmallInt; override;
    function SetSelIndex(Id: SmallInt; I: SmallInt): SmallInt; override;
    procedure ComboSetText(Id: SmallInt; S: PChar); override;
    procedure EndDlg(Code: SmallInt); override;
    { a user event of the script; the id whose handler runs, or 0 }
    function Apply(const Ev: string): SmallInt;
  end;

{ Execute a dialog with a ported type: SetupWindow, then the events of
  Script (';'-separated), as tools/emu/dlg_driver.py does; the end code }
function RunScript(D: TDialog; const Template: TDlgTemplate; const Script: string): SmallInt;

implementation

function Hex(const S: RawByteString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + LowerCase(IntToHex(Ord(S[I]), 2));
end;

function UnHex(const S: string): RawByteString;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 1 to Length(Result) do
    Result[I] := Chr(StrToInt('$' + Copy(S, 2 * I - 1, 2)));
end;

destructor TCtl.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

constructor TScriptControls.Create(const Template: TDlgTemplate; DlgIndex: Integer);
begin
  inherited Create;
  FTemplate := Template;
  FDlgIndex := DlgIndex;
end;

destructor TScriptControls.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FCtls) do
    FCtls[I].Free;
  inherited Destroy;
end;

function TScriptControls.Ctl(Id: SmallInt): TCtl;
var
  I: Integer;
begin
  for I := 0 to High(FCtls) do
    if FCtls[I].Id = Id then
      Exit(FCtls[I]);
  Result := TCtl.Create;
  Result.Id := Id;
  Result.Items := TStringList.Create;
  Result.Lo := 0;
  Result.Hi := 100;
  Result.Sel := -1;
  Result.Enabled := True;
  for I := 0 to High(FTemplate.Items) do
    if FTemplate.Items[I].Id = Id then
    begin
      Result.Cls := FTemplate.Items[I].ClassName;
      Result.Style := FTemplate.Items[I].Style;
      Result.Enabled := FTemplate.Items[I].Style and $08000000 = 0;
      if ((Result.Cls = 'STATIC') or (Result.Cls = 'EDIT')) and
         (FTemplate.Items[I].TextOrd < 0) then
        Result.Text := FTemplate.Items[I].Text;
    end;
  SetLength(FCtls, Length(FCtls) + 1);
  FCtls[High(FCtls)] := Result;
end;

procedure TScriptControls.SetText(Id: SmallInt; S: PChar);
begin
  UI.Note(Format('SetText(c%d,s:%s)', [Id, Hex(S)]));
  Ctl(Id).Text := S;
end;

function TScriptControls.GetText(Id: SmallInt; Buf: PChar; MaxChars: Integer): Integer;
var
  T: RawByteString;
begin
  T := Copy(Ctl(Id).Text, 1, MaxChars - 1);
  StrPCopy(Buf, T);
  UI.Note(Format('GetText(c%d)=s:%s', [Id, Hex(T)]));
  Result := Length(T);
end;

procedure TScriptControls.Enable(Id: SmallInt; On: Boolean);
begin
  Ctl(Id).Enabled := On;
  if On then
    UI.Note(Format('Enable(c%d)', [Id]))
  else
    UI.Note(Format('Disable(c%d)', [Id]));
end;

procedure TScriptControls.Show(Id: SmallInt; Cmd: SmallInt);
begin
  UI.Note(Format('Show(c%d,%d)', [Id, Word(Cmd)]));
end;

procedure TScriptControls.SetCaption(S: PChar);
begin
  UI.Note(Format('SetCaption(O%d,s:%s)', [FDlgIndex, Hex(S)]));
end;

procedure TScriptControls.SetCheck(Id: SmallInt; V: Word);
begin
  Ctl(Id).Check := V;
  UI.Note(Format('SetCheck(c%d,%d)', [Id, V]));
end;

function TScriptControls.GetCheck(Id: SmallInt): Word;
begin
  Result := Ctl(Id).Check;
  UI.Note(Format('GetCheck(c%d)=%d', [Id, Result]));
end;

procedure TScriptControls.SetRange(Id: SmallInt; Lo, Hi: SmallInt);
var
  C: TCtl;
begin
  C := Ctl(Id);
  C.Lo := Lo;
  C.Hi := Hi;
  if C.Pos < Lo then C.Pos := Lo;
  if C.Pos > Hi then C.Pos := Hi;
  UI.Note(Format('SetRange(c%d,%d,%d)', [Id, Lo, Hi]));
end;

procedure TScriptControls.SetPosition(Id: SmallInt; V: SmallInt);
var
  C: TCtl;
begin
  C := Ctl(Id);
  C.Pos := V;
  if C.Pos < C.Lo then C.Pos := C.Lo;
  if C.Pos > C.Hi then C.Pos := C.Hi;
  UI.Note(Format('SetPosition(c%d,%d)', [Id, V]));
end;

function TScriptControls.GetPosition(Id: SmallInt): SmallInt;
begin
  Result := Ctl(Id).Pos;
  UI.Note(Format('GetPosition(c%d)=%d', [Id, Result]));
end;

function TScriptControls.AddString(Id: SmallInt; S: PChar): SmallInt;
var
  C: TCtl;
begin
  UI.Note(Format('AddString(c%d,s:%s)', [Id, Hex(S)]));
  C := Ctl(Id);
  C.Items.Add(S);
  Result := C.Items.Count - 1;
end;

function TScriptControls.GetSelIndex(Id: SmallInt): SmallInt;
begin
  Result := Ctl(Id).Sel;
  UI.Note(Format('GetSelIndex(c%d)=%d', [Id, Result]));
end;

function TScriptControls.SetSelIndex(Id: SmallInt; I: SmallInt): SmallInt;
var
  C: TCtl;
begin
  C := Ctl(Id);
  if (I >= 0) and (I < C.Items.Count) then
    C.Sel := I
  else
    C.Sel := -1;
  UI.Note(Format('SetSelIndex(c%d,%d)', [Id, I]));
  Result := I;
end;

procedure TScriptControls.ComboSetText(Id: SmallInt; S: PChar);
begin
  UI.Note(Format('ComboSetText(c%d,s:%s)', [Id, Hex(S)]));
  Ctl(Id).Text := S;
end;

procedure TScriptControls.EndDlg(Code: SmallInt);
begin
  UI.Note(Format('EndDlg(O%d,%d)', [FDlgIndex, Word(Code)]));
  EndCode := Code;
  Ended := True;
end;

function TScriptControls.Known(Id: SmallInt): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FCtls) do
    if FCtls[I].Id = Id then
      Exit(True);
  Result := False;
end;

function TScriptControls.Apply(const Ev: string): SmallInt;
var
  Kind: Char;
  Rest, Val: string;
  K: Integer;
  C: TCtl;
  Id: SmallInt;
begin
  Result := 0;
  if (Ev = 'ok') or (Ev = 'cancel') then
  begin
    if Ev = 'ok' then Result := 1 else Result := 2;
    if Known(Result) and not Ctl(Result).Enabled then
      Result := 0;
    Exit;
  end;
  Kind := Ev[1];
  Rest := Copy(Ev, 2, MaxInt);
  K := Pos(':', Rest);
  if K = 0 then K := Length(Rest) + 1;
  Id := StrToInt(Copy(Rest, 1, K - 1));
  if Known(Id) and not Ctl(Id).Enabled then
    Exit(0);                                         { a disabled control }
  if Kind = 'c' then
  begin
    Result := StrToInt(Rest);
    C := Ctl(Result);
    if C.Cls = 'BUTTON' then
      case C.Style and $F of
        3, 6: C.Check := Ord(C.Check = 0);           { BS_AUTOCHECKBOX }
        9: C.Check := 1;                             { BS_AUTORADIOBUTTON }
      end;
    Exit;
  end;
  K := Pos(':', Rest);
  Val := Copy(Rest, K + 1, MaxInt);
  Result := StrToInt(Copy(Rest, 1, K - 1));
  C := Ctl(Result);
  case Kind of
    's':
      begin
        C.Pos := StrToInt(Val);
        if C.Pos < C.Lo then C.Pos := C.Lo;
        if C.Pos > C.Hi then C.Pos := C.Hi;
      end;
    'l':
      if (StrToInt(Val) >= 0) and (StrToInt(Val) < C.Items.Count) then
        C.Sel := StrToInt(Val)
      else
        C.Sel := -1;
    't':
      begin
        C.Text := UnHex(Val);
        Result := 0;
      end;
  else
    Result := 0;
  end;
end;

function RunScript(D: TDialog; const Template: TDlgTemplate; const Script: string): SmallInt;
var
  L: TDialogLogic;
  Ctls: TScriptControls;
  Events: TStringList;
  I: Integer;
  Id: SmallInt;
begin
  L := TDialogLogic(D.Logic);
  Ctls := TScriptControls.Create(Template, D.Index);
  L.C := Ctls;
  Events := TStringList.Create;
  try
    Events.Delimiter := ';';
    Events.StrictDelimiter := True;
    if Script <> '' then
      Events.DelimitedText := Script;
    UI.Note(Format('Execute(O%d)', [D.Index]));
    L.SetupWindow;
    I := 0;
    while not Ctls.Ended do
    begin
      if I >= Events.Count then
      begin
        Ctls.EndCode := 2;
        Break;
      end;
      UI.Note('[' + Events[I] + ']');
      Id := Ctls.Apply(Events[I]);
      Inc(I);
      if Id = 0 then
        Continue;
      if L.Handle(Id) then
        Continue;
      if Id = 1 then
      begin
        if L.CanClose and not Ctls.Ended then
        begin
          Ctls.EndCode := 1;
          Ctls.Ended := True;
        end;
      end
      else if Id = 2 then
      begin
        Ctls.EndCode := 2;
        Ctls.Ended := True;
      end;
    end;
    UI.Note(Format('=>%d', [Ctls.EndCode]));
    Result := Ctls.EndCode;
  finally
    Events.Free;
    L.C := nil;
    Ctls.Free;
  end;
end;

end.
