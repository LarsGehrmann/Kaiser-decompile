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

  { segment 3 (turn) }
  TPromotionDlg = class(TKaiserDialog)       { BEFDLG / FEMBEFDLG (DS:05f0) }
    procedure SetupWindow; override;
  end;
  TStartFinanzDlg = class(TKaiserDialog)     { STARTFINANZDLG (DS:0916) }
    procedure SetupWindow; override;
  end;
  TStartPopDlg = class(TKaiserDialog)        { STARTPOPDLG (DS:0536) }
    procedure SetupWindow; override;
  end;
  THexenDlg = class(TKaiserDialog)           { HEXENDLG (DS:0598) }
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
  end;

  { segment 12 }
  THeroNameDlg = class(TKaiserDialog)        { HELDDLG ... (DS:351e) }
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
  end;
  TUnitInfoDlg = class(TKaiserDialog)        { SOELDNERDLG ... (DS:35e6) }
  private
    FFrame: Byte;
    FPortrait: TImage;
    FTimer: TTimer;
    procedure Tick(Sender: TObject);
    procedure DrawPortrait;
  public
    procedure SetupWindow; override;
  end;
  TPlayerSelectDlg = class(TKaiserDialog)    { SPENDE/TRADE/TRIBUT/SABOAUSWAHLDLG (DS:357a) }
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
  end;
  TChoiceDlg = class(TKaiserDialog)          { Button2Dlg (DS:3652), ChoiceDlg (DS:36ea) }
    procedure SetupWindow; override;
    procedure Handle(Id: SmallInt); override;
  end;

  { segment 6 }
  TMassacreDlg = class(TKaiserDialog)        { MASSAKERDLG (DS:0cec) }
    procedure SetupWindow; override;
  end;
  TPlunderResultDlg = class(TKaiserDialog)   { PLUENDERNDLG (DS:0c98) }
    procedure SetupWindow; override;
  end;
  TPlunderChoiceDlg = class(TKaiserDialog)   { LOOTDLG / LOOT2DLG (DS:0d60) }
    procedure SetupWindow; override;
    procedure Handle(Id: SmallInt); override;
  end;

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
    FTimer: TTimer;                 { REKRUTDLG: WMTimer every 400 ms }
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TimerTick(Sender: TObject);
  public
    { TroopDlg_DrawHeer / DrawGarde (1038:84a1 / 8699): the grids of the
      Heer (65 x 161) and the Garde (113 x 113, in walls) with the unit
      icons (sprites 1100+type / 1200+type, a hero 1150+picture), the
      selected cells red }
    procedure DrawTroops;
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

{ -- helpers --------------------------------------------------------------- }

function GetLong(D: TDialog; Off: Word): LongInt;
begin
  Move(D.Data[Off], Result, 4);
end;

function LongText(V: LongInt): RawByteString;
begin
  Result := IntToStr(V);
end;

{ -- segment 3 --------------------------------------------------------------- }

procedure TPromotionDlg.SetupWindow;
var
  T: Byte;
begin
  SetText(101, LongText(PWord(@D.Data[$7F])^ + 1400));
  SetText(102, PChar(@D.Data[$2E]));
  T := D.Data[$81];
  if D.Data[$82] = 0 then
    SetText(103, DSText($58E8 + 25 * (T + 1)))
  else
    SetText(103, DSText($59FC + 25 * (T + 1)));
end;

procedure TStartFinanzDlg.SetupWindow;
begin
  SetText(101, LongText(GetLong(D, $34)));
  SetText(102, LongText(GetLong(D, $38)));
  SetText(103, LongText(GetLong(D, $3C)));
  SetText(104, LongText(-GetLong(D, $40)));
  SetText(105, LongText(GetLong(D, $44)));
  SetText(106, LongText(GetLong(D, $48)));
  SetText(107, LongText(GetLong(D, $4C)));
  SetText(108, LongText(GetLong(D, $50)));
  SetText(109, LongText(GetLong(D, $54)));
  SetText(110, LongText(-GetLong(D, $58)));
end;

procedure TStartPopDlg.SetupWindow;
var
  R: TReal48;
begin
  { the number, then the text }
  SetText(101, LongText(GetLong(D, $2E)) + DSText($0A4C));
  SetText(102, LongText(GetLong(D, $32)) + DSText($0A80));
  SetText(103, LongText(GetLong(D, $36)) + DSText($0AA8));
  SetText(104, LongText(GetLong(D, $3A)) + DSText($0ADB));
  Move(D.Data[$3E], R, 6);
  { Str(happiness * 100 :0:2) }
  SetText(105, FormatFloat('0.00', R48ToDouble(R48Mul(R, RC($0087, 0, $4800)))) + DSText($0B0E));
end;

procedure THexenDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 0 to 12 do
    AddString(101, DS.SpellNames[I]);
  SetSelIndex(101, 0);
end;

function THexenDlg.CanClose: Boolean;
begin
  PWord(@D.Data[$38])^ := Word(GetSelIndex(101));
  Result := True;
end;

{ -- segment 12 --------------------------------------------------------------- }

procedure THeroNameDlg.SetupWindow;
var
  Buf: array[0..16] of Char;
begin
  { a random name proposal (the game's RandSeed moves on) }
  LoadString(Random(220) + 101, Buf, 16);
  StrCopy(PChar(@D.Data[$38]), Buf);
  SetText(101, Buf);
  PWord(@D.Data[$2E])^ := $D1;
  D.Data[$49] := 0;
end;

function THeroNameDlg.CanClose: Boolean;
var
  S: RawByteString;
begin
  S := Copy(GetText(101), 1, 15);
  FillChar(D.Data[$38], 16, 0);
  if S <> '' then
    Move(S[1], D.Data[$38], Length(S));
  if (DS.Game.CensusEditorEnabled <> 0) and (S = 'guams dlo') then
    D.Data[$49] := 1;
  StrCopy(PChar(@D.Data[DialogTextOfs]), PChar(@D.Data[$38]));
  Result := True;
end;

procedure TUnitInfoDlg.SetupWindow;
var
  U: ^TUnit;
  Buf: array[0..81] of Char;
begin
  { the unit record (+0x35) and the mode ('e' rank, 'f' ability) }
  U := Args[2].P;
  Move(U^, D.Data[$35], SizeOf(TUnit));
  D.Data[$34] := Byte(Args[3].V);
  U := @D.Data[$35];
  SetText(101, PChar(@U^.Name));
  Buf[0] := #0;
  if D.Data[$34] = Ord('e') then
    UnitRankName(U^, Buf)
  else if D.Data[$34] = Ord('f') then
    StrCopy(Buf, DSText($53D8 + 25 * U^.Ability));
  SetText(102, Buf);
  SetText(103, LongText(U^.Attack));
  SetText(104, LongText(U^.Defence));
  SetText(105, LongText(ShortInt(U^.MaxHp)));
  SetText(106, LongText(U^.Range));
  SetText(107, LongText(U^.MaxSteps));
  SetText(108, LongText(U^.Pay));
  FPortrait := TImage.Create(Self);
  FPortrait.Parent := Self;
  FPortrait.Stretch := True;
  FPortrait.Transparent := True;
  FPortrait.SetBounds(ClientWidth - 80, 12, 64, 64);
  FFrame := 0;
  DrawPortrait;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 400;
  FTimer.OnTimer := @Tick;
end;

procedure TUnitInfoDlg.DrawPortrait;
var
  B: TBitmap;
  Base: Word;
begin
  if FFrame = 0 then
    Base := 1100
  else
    Base := 1300;
  B := Sprite(Base + PUnit(@D.Data[$35])^.UnitType);
  if B <> nil then
    FPortrait.Picture.Assign(B);
end;

procedure TUnitInfoDlg.Tick(Sender: TObject);
begin
  { WMTimer (1058:0ca1): now and then the other frame for one tick }
  if FFrame <> 0 then
    FFrame := 0
  else if Random(4) = 0 then
    FFrame := 1;
  DrawPortrait;
end;

procedure TPlayerSelectDlg.SetupWindow;
var
  Players: ^TPlayers;
  Num, Excl, I, K: Byte;
  Title: array[0..65] of Char;
begin
  { the formatted titles of all players but Exclude; +0x35 maps the entries }
  Players := Args[2].P;
  Num := Byte(Args[3].V);
  Excl := Byte(Args[4].V);
  K := 0;
  for I := 0 to Num - 1 do
    if I <> Excl then
    begin
      FormatPlayerTitle(Players^[I], Title, 0, 0);
      AddString(101, Title);
      D.Data[$35 + K] := I;
      Inc(K);
    end;
  SetSelIndex(101, D.Data[$32]);
end;

function TPlayerSelectDlg.CanClose: Boolean;
begin
  if GetSelIndex(101) >= 0 then
    D.Data[$32] := D.Data[$35 + GetSelIndex(101)];
  Result := True;
end;

procedure TChoiceDlg.SetupWindow;
var
  I, N: Integer;
  Flags: PByte;
begin
  if D.Name = 'ButtonChoiceDlg' then
  begin
    N := Args[2].V;
    Flags := Args[3].P;
    for I := 0 to N - 1 do
      EnableItem(101 + I, Flags[I] <> 0);
  end;
end;

procedure TChoiceDlg.Handle(Id: SmallInt);
begin
  if (Id >= 101) and (Id <= 110) then
    inherited Command(Id)              { EndDlg(id) }
  else
    inherited Handle(Id);
end;

{ -- segment 6 ------------------------------------------------------------------ }

procedure TMassacreDlg.SetupWindow;
begin
  SetText(101, LongText(GetLong(D, $2E)));
  SetText(102, LongText(GetLong(D, $32)));
  SetText(103, PChar(@D.Data[$42]));
end;

procedure TPlunderResultDlg.SetupWindow;
begin
  SetText(101, LongText(GetLong(D, $36)));
  SetText(102, LongText(GetLong(D, $32)));
  SetText(103, LongText(GetLong(D, $2E)));
end;

procedure TPlunderChoiceDlg.SetupWindow;
begin
  SetText(101, PChar(@D.Data[$34]));
  SetText(102, PChar(@D.Data[$67]));
end;

procedure TPlunderChoiceDlg.Handle(Id: SmallInt);
begin
  { buttons 201..204: plunder, burn, massacre, mercy -> EndDlg(10..13) }
  if (Id >= 201) and (Id <= 204) then
    inherited Command(Id - 201 + 10)
  else
    inherited Handle(Id);
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
  if D.Name = 'RecruitDlg' then
  begin
    FTimer := TTimer.Create(Self);
    FTimer.Interval := 400;
    FTimer.OnTimer := @TimerTick;
  end;
end;

procedure TLogicDialog.TimerTick(Sender: TObject);
begin
  if Logic is TRecruitDlg then
    TRecruitDlg(Logic).Timer;
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
    Img.Picture.Bitmap.SetSize(W, H);
    Result := Img.Picture.Bitmap.Canvas;
    Result.Brush.Color := clWhite;
    Result.Pen.Color := clBlack;
    Result.Rectangle(0, 0, W, H);
  end;

  procedure Icon(Cv: TCanvas; const U: TUnit; Base, X, Y: Integer; Selected: Boolean);
  var
    B: TBitmap;
    N: Integer;
  begin
    if Selected then
    begin
      Cv.Brush.Color := clRed;
      Cv.Pen.Color := clBlack;
      Cv.Rectangle(X, Y, X + 32, Y + 32);
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
  Cv := Grid(FHeer, PSmallInt(@D.Data[$710])^, PSmallInt(@D.Data[$712])^, 65, 161);
  for I := 1 to P^.Army1Count do
    if I <= 8 then
      Icon(Cv, P^.Army1[I], 1100, DS.TroopHeerX[I] * 32, DS.TroopHeerY[I] * 32,
        (D.Data[$70A] = I) or (D.Data[$70B] = I));
  Cv := Grid(FGarde, PSmallInt(@D.Data[$714])^, PSmallInt(@D.Data[$716])^, 113, 113);
  Wall := ResBitmap('MAUER');
  if Wall <> nil then
  begin
    Cv.Brush.Bitmap := Wall;
    Cv.FillRect(0, 0, 8, 113);
    Cv.FillRect(105, 0, 113, 113);
    Cv.FillRect(0, 105, 113, 113);
    Cv.FillRect(0, 0, 40, 8);
    Cv.FillRect(72, 0, 113, 8);
    Cv.Brush.Bitmap := nil;
  end;
  for I := 1 to P^.Army2Count do
    if I <= 9 then
      Icon(Cv, P^.Army2[I], 1200, DS.TroopGardeX[I] * 32 + 8, DS.TroopGardeY[I] * 32 + 8,
        (D.Data[$70C] = I) or (D.Data[$70D] = I));
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
    Exit(TLogicDialog);
  case Name of
    'KaiserDlg', 'MessageDlg', 'Message2Dlg', 'HelpMessageDlg', 'HelpChoice2Dlg':
      Result := TMessageDlg;
    'HumanCountDlg': Result := THumanCountDlg;
    'ComputerCountDlg': Result := TComputerCountDlg;
    'PlayerDataDlg': Result := TPlayerDataDlg;
    'PromotionDlg': Result := TPromotionDlg;
    'StartFinanzDlg': Result := TStartFinanzDlg;
    'StartPopDlg': Result := TStartPopDlg;
    'HexenDlg': Result := THexenDlg;
    'HeroNameDlg': Result := THeroNameDlg;
    'UnitInfoDlg': Result := TUnitInfoDlg;
    'PlayerSelectDlg': Result := TPlayerSelectDlg;
    'Button2Dlg', 'ButtonChoiceDlg': Result := TChoiceDlg;
    'MassacreDlg': Result := TMassacreDlg;
    'PlunderResultDlg': Result := TPlunderResultDlg;
    'PlunderChoiceDlg': Result := TPlunderChoiceDlg;
  else
    Result := TKaiserDialog;
  end;
end;

end.
