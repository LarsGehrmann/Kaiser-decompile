{ The game's dialog types (OWL TDialog descendants of kaiser.exe), ported
  onto template forms. Each class works on the TDialog record of the logic
  (D.Data mirrors the original object: the logic writes the inputs before
  Execute and reads the results after it) and does what the original
  SetupWindow, control handlers (IdCtlNNN) and CanClose do. Registered by
  the constructor name the logic passes to UI.Dialog. }
unit KaiserDlgs;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Controls, StdCtrls, Forms, Strings, NERes, KaiserTypes, KaiserDS,
  KaiserUI, KaiserLCL;

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

  { KaiserDlg (DS:3364) and the plain message types of segment 12 }
  TMessageDlg = class(TKaiserDialog)
    procedure SetupWindow; override;
  end;

  { HumanCountDlg (DS:22e4, 1040:2017): number of humans, the options }
  THumanCountDlg = class(TKaiserDialog)
    procedure SetupWindow; override;
    procedure UpdateLabels;
    procedure Handle(Id: SmallInt); override;
    function CanClose: Boolean; override;
  end;

  { ComputerCountDlg (DS:2362, 1040:234c): number of computers, level }
  TComputerCountDlg = class(TKaiserDialog)
    procedure SetupWindow; override;
    procedure UpdateLevelRadios;
    procedure Handle(Id: SmallInt); override;
  end;

  { PlayerDataDlg (DS:195a, 1040:2569): name, sex, country of a human }
  TPlayerDataDlg = class(TKaiserDialog)
    procedure SetupWindow; override;
    procedure Handle(Id: SmallInt); override;
    function CanClose: Boolean; override;
  end;

function DialogClassOf(const Name: string): TKaiserDialogClass;

implementation

uses
  Rules;

{ -- TKaiserDialog ----------------------------------------------------------- }

function TKaiserDialog.GetCheck(Id: SmallInt): Boolean;
var
  C: TControl;
begin
  C := Item(Id);
  if C is TCheckBox then
    Result := TCheckBox(C).Checked
  else if C is TRadioButton then
    Result := TRadioButton(C).Checked
  else
    Result := False;
end;

procedure TKaiserDialog.SetCheck(Id: SmallInt; On: Boolean);
var
  C: TControl;
begin
  C := Item(Id);
  Inc(FQuiet);
  try
    if C is TCheckBox then
      TCheckBox(C).Checked := On
    else if C is TRadioButton then
      TRadioButton(C).Checked := On;
  finally
    Dec(FQuiet);
  end;
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

{ -- segment 12 ----------------------------------------------------------- }

function ArgText(const A: TUIArg): RawByteString;
begin
  if (A.Kind = uaStr) and (PtrUInt(A.P) >= $10000) then
    Result := PChar(A.P)
  else
    Result := '';
end;

procedure TMessageDlg.SetupWindow;
begin
  if (D.Name = 'MessageDlg') or (D.Name = 'HelpMessageDlg') then
    SetText(101, ArgText(Args[2]))
  else if (D.Name = 'Message2Dlg') or (D.Name = 'HelpChoice2Dlg') then
  begin
    SetText(101, ArgText(Args[2]));
    SetText(102, ArgText(Args[3]));
  end;
end;

{ -- HumanCountDlg -------------------------------------------------------- }

procedure THumanCountDlg.SetupWindow;
begin
  D.Data[$34] := D.Data[$35];
  SetRange(101, D.Data[$35], D.Data[$36]);
  SetPosition(101, D.Data[$34]);
  SetCheck(301, False);           { Spiel per E-Mail }
  SetCheck(302, False);           { Unsterblichkeit }
  SetCheck(303, True);            { Warenhandel }
  SetCheck(304, True);            { Initiativpunkte }
  UpdateLabels;
end;

procedure THumanCountDlg.UpdateLabels;
begin
  SetText(102, IntToStr(D.Data[$34]));
  if D.Data[$34] > 1 then
    EnableItem(301, True)
  else
  begin
    EnableItem(301, False);
    SetCheck(301, False);
  end;
end;

procedure THumanCountDlg.Handle(Id: SmallInt);
begin
  case Id of
    301..304: SetCheck(Id, not GetCheck(Id));
    101:
      begin
        D.Data[$34] := Byte(GetPosition(101));
        UpdateLabels;
      end;
  end;
end;

function THumanCountDlg.CanClose: Boolean;
begin
  DS.Game.EmailGameQ := Ord(GetCheck(301));
  DS.Game.Immortality := Ord(GetCheck(302));
  DS.Game.GoodsTradeEnabled := Ord(GetCheck(303));
  DS.Game.InitiativeEnabled := Ord(GetCheck(304));
  Result := True;
end;

{ -- ComputerCountDlg ----------------------------------------------------- }

procedure TComputerCountDlg.SetupWindow;
begin
  D.Data[$34] := D.Data[$35];
  SetRange(101, D.Data[$35], D.Data[$36]);
  SetPosition(101, D.Data[$34]);
  UpdateLevelRadios;
  SetText(102, IntToStr(D.Data[$34]));
end;

procedure TComputerCountDlg.UpdateLevelRadios;
var
  I: Integer;
begin
  for I := 0 to 3 do
    SetCheck(201 + I, I = D.Data[$3B]);
end;

procedure TComputerCountDlg.Handle(Id: SmallInt);
begin
  case Id of
    101:
      begin
        D.Data[$34] := Byte(GetPosition(101));
        SetText(102, IntToStr(D.Data[$34]));
      end;
    201..204:
      begin
        D.Data[$3B] := Id - 201;
        UpdateLevelRadios;
      end;
  end;
end;

{ -- PlayerDataDlg -------------------------------------------------------- }

procedure TPlayerDataDlg.SetupWindow;
var
  Me, C, K: Byte;
  Num: array[0..11] of Char;
  Taken: Boolean;
  Players: ^TPlayers;
begin
  { the constructor's part: the default name, the player number, the
    countries not taken by the humans before }
  Players := Args[2].P;
  Me := Byte(Args[3].V);
  D.Data[$4C] := 0;
  D.Data[$4E] := 0;
  IntToPChar(@Num, Me + 1);
  StrCopy(PChar(@D.Data[$47]), Num);
  StrCopy(PChar(@D.Data[$2E]), DS.HumanNames[Me]);
  for C := 0 to 9 do
  begin
    Taken := False;
    if Me > 0 then
      for K := 0 to Me - 1 do
        if Players^[K].Country = C then
          Taken := True;
    if not Taken then
    begin
      D.Data[$4F + D.Data[$4E]] := C;
      Inc(D.Data[$4E]);
    end;
  end;
  { SetupWindow }
  SetCheck(102, True);
  SetCheck(103, False);
  for K := 0 to D.Data[$4E] - 1 do
    AddString(201, PChar(@DS.CountryNamesRt[D.Data[$4F + K]]));
  SetSelIndex(201, 0);
  SetText(101, PChar(@D.Data[$2E]));
  SetText(105, PChar(@D.Data[$47]));
end;

procedure TPlayerDataDlg.Handle(Id: SmallInt);
begin
  if (Id = 102) or (Id = 103) then
  begin
    { the two sex radios toggle each other (103 goes to 102's handler) }
    if GetCheck(102) then
    begin
      SetCheck(102, False);
      SetCheck(103, True);
    end
    else
    begin
      SetCheck(102, True);
      SetCheck(103, False);
    end;
  end;
end;

function TPlayerDataDlg.CanClose: Boolean;
var
  S: RawByteString;
begin
  S := Copy(GetText(101), 1, 15);
  FillChar(D.Data[$2E], 16, 0);
  if S <> '' then
    Move(S[1], D.Data[$2E], Length(S));
  if GetCheck(102) then
    D.Data[$4C] := 0
  else
    D.Data[$4C] := 1;
  D.Data[$4D] := D.Data[$4F + GetSelIndex(201)];
  Result := S <> '';
end;

function DialogClassOf(const Name: string): TKaiserDialogClass;
begin
  case Name of
    'KaiserDlg', 'MessageDlg', 'Message2Dlg', 'HelpMessageDlg', 'HelpChoice2Dlg':
      Result := TMessageDlg;
    'HumanCountDlg': Result := THumanCountDlg;
    'ComputerCountDlg': Result := TComputerCountDlg;
    'PlayerDataDlg': Result := TPlayerDataDlg;
  else
    Result := TKaiserDialog;
  end;
end;

end.
