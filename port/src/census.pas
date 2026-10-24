{ The census editor (segment 8, the hidden command 802 / Ctrl+P): after the
  password (the hero's name of the first player) and only with the game
  option census_editor_enabled, CENSUSDLG edits every player record; its
  buttons open the troop dialog in mode 6, the scenario texts (SZENARIENDLG)
  and, from the troop dialog, the unit editor (UNITEDITDLG). }
unit Census;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Rules, KaiserUI;

type
  PPlayers = ^TPlayers;

{ CensusEditor (1038:4d68) }
procedure CensusEditor(Parent: Pointer; var Players: TPlayers; NumPlayers: Byte);
{ Do_SzenarioDlg (1038:4e45): the game year and the scenario texts }
procedure Do_SzenarioDlg(Parent: Pointer);
{ Do_UnitEditDlg (1038:503d): a unit of P; taken over on OK }
procedure Do_UnitEditDlg(Parent: Pointer; const P: TPlayer; var U: TUnit);

type
  { PASSWORDDLG (VMT DS:155a, 1038:698d): edit 101, the text +0x32 }
  TPasswordDlg = class(TDialogLogic)
  public
    function CanClose: Boolean; override;
  end;

  { CENSUSDLG (VMT DS:15ec, 1038:590a): all players at +0x2e, the number
    +0x4480, the player shown +0x4481; edits 101..115, combos 201 title /
    202 spell, radios 501/502 sex, scroll bars 601 computer level / 701
    aggression with statics 602 / 702; buttons 301 next, 302 previous,
    303 apply, 401 troops, 402 the scenario }
  TCensusDlg = class(TDialogLogic)
  public
    function Shown: PPlayer;
    procedure Init; override;
    procedure SetupWindow; override;
    procedure ShowPlayer;
    procedure ApplyPlayer;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { SZENARIENDLG (VMT DS:1640, 1038:4e84): edits 101 year, 102 title,
    103 description, 104 author }
  TSzenarioDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
  end;

  { UNITEDITDLG (VMT DS:16ae, 1038:50a0): the player at +0x2e, the unit at
    +0x703; edit 101 name, static 102 rank, scroll bar 103 hero picture,
    combo 104 ability, button 105 training, edits 201..207 attack, defence,
    hit points, range, steps, ammunition, pay }
  TUnitEditDlg = class(TDialogLogic)
  public
    function U: PUnit;
    procedure SetupWindow; override;
    procedure ShowValues;
    procedure ApplyValues;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

implementation

{ GetText of an edit, then Val (the result 0 on bad input) }
function EditValue(C: TDlgControls; Id: SmallInt; MaxChars: Integer): LongInt;
var
  Buf: array[0..255] of Char;
  Code: SmallInt;
begin
  C.GetText(Id, Buf, MaxChars);
  Result := ValLong(StrPas(Buf), Code);
end;

procedure SetNum(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

{ -- the password and the editor ------------------------------------------------ }

function TPasswordDlg.CanClose: Boolean;
begin
  C.GetText(101, PChar(@D.Data[$32]), $14);
  Result := True;
end;

procedure CensusEditor(Parent: Pointer; var Players: TPlayers; NumPlayers: Byte);
var
  D: TDialog;
  Pass: array[0..25] of Char;
  H: PUnit;
begin
  Pass[0] := #0;
  D := UI.Dialog('PasswordDlg', $155A, [APtr(Parent), AStr(DSText($1702))]);
  if UI.Execute(D) = 1 then
    StrCopy(Pass, PChar(@D.Data[$32]));
  UI.Done(D, 1);
  { the password: the name of the first player's hero }
  if FindHero(Players[0], H, 1) and (StrComp(H^.Name, Pass) = 0) and
     (DS.Game.CensusEditorEnabled <> 0) then
  begin
    D := UI.Dialog('CensusDlg', $15EC, [APtr(Parent), AStr(DSText($170E)), AByte(NumPlayers),
      APtr(@Players)]);
    if UI.Execute(D) = 1 then
      Move(D.Data[$2E], Players, SizeOf(TPlayers));
    UI.Done(D, 1);
  end;
end;

function TCensusDlg.Shown: PPlayer;
begin
  { "zurück" on the first player (the button is enabled at first) makes the
    original show player 255: 16-bit wrapped garbage of the heap; the port
    stays inside the ten players }
  Result := PPlayer(@D.Data[$2E + (D.Data[$4481] mod 10) * SizeOf(TPlayer)]);
end;

procedure TCensusDlg.Init;
begin
  Move(PPlayers(Args[3].P)^, D.Data[$2E], SizeOf(TPlayers));
  D.Data[$4480] := Byte(Args[2].V);
  D.Data[$4481] := 0;
end;

procedure TCensusDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 0 to 10 do
    C.AddString(201, DS.TitleNames[I]);
  for I := 0 to 12 do
    C.AddString(202, DS.SpellNames[I]);
  C.SetRange(601, 0, 6);
  C.SetRange(701, 1, 6);
  ShowPlayer;
end;

procedure TCensusDlg.ShowPlayer;
var
  P: PPlayer;
begin
  P := Shown;
  C.SetText(101, P^.Name);
  SetNum(C, 102, P^.Population);
  SetNum(C, 103, P^.Land);
  SetNum(C, 104, P^.Taler);
  SetNum(C, 105, P^.Fame);
  SetNum(C, 106, MaxLong(P^.Markets, P^.Mills));
  SetNum(C, 107, P^.PalaceParts);
  SetNum(C, 108, P^.CathedralParts);
  SetNum(C, 109, P^.Granaries);
  SetNum(C, 110, P^.Warehouses);
  SetNum(C, 111, P^.UniversityParts);
  SetNum(C, 112, P^.Taverns);
  SetNum(C, 113, P^.Smithies);
  SetNum(C, 114, P^.Weapons);
  SetNum(C, 115, P^.Lifetime);
  C.SetSelIndex(201, P^.Title);
  C.SetSelIndex(202, P^.Spell);
  { (radio +0x44da + sex*4); remastered: a sex byte other than 0/1 picked
    a garbage radio button: it counts as female }
  C.SetCheck(501 + Ord(P^.IsFemale <> 0), 1);
  C.SetCheck(501 + Ord(P^.IsFemale = 0), 0);
  C.SetPosition(601, P^.CpuLevel);
  C.SetPosition(701, P^.AiAggressionQ);
  SetNum(C, 602, P^.CpuLevel);
  SetNum(C, 702, P^.AiAggressionQ);
end;

procedure TCensusDlg.ApplyPlayer;
var
  P: PPlayer;
  Buf: array[0..25] of Char;
  V, Low, Need, High: LongInt;
begin
  P := Shown;
  C.GetText(101, Buf, $10);
  StrCopy(P^.Name, Buf);
  P^.Population := EditValue(C, 102, $10);
  P^.Land := EditValue(C, 103, $10);
  P^.Taler := EditValue(C, 104, $10);
  P^.Fame := SmallInt(EditValue(C, 105, $10));
  V := EditValue(C, 106, $10);                      { markets and mills alike }
  P^.Markets := V;
  P^.Mills := V;
  P^.PalaceParts := Byte(EditValue(C, 107, $10));
  P^.CathedralParts := Byte(EditValue(C, 108, $10));
  P^.Granaries := EditValue(C, 109, $10);
  P^.Warehouses := EditValue(C, 110, $10);
  P^.UniversityParts := Byte(EditValue(C, 111, $10));
  P^.Taverns := EditValue(C, 112, $10);
  P^.Smithies := EditValue(C, 113, $10);
  P^.Weapons := EditValue(C, 114, $10);
  P^.Lifetime := SmallInt(EditValue(C, 115, $10));
  P^.Title := Byte(C.GetSelIndex(201));
  P^.Spell := Byte(C.GetSelIndex(202));
  if C.GetCheck(501) = 1 then
    P^.IsFemale := 0
  else
    P^.IsFemale := 1;
  P^.CpuLevel := Byte(C.GetPosition(601));
  P^.AiAggressionQ := Byte(C.GetPosition(701));
  GrainNeedMinMax(P^, Low, Need, High);
  P^.GrainDistributed := Need;
end;

function TCensusDlg.Handle(Id: SmallInt): Boolean;
var
  Buf: array[0..15] of Char;
begin
  Result := True;
  case Id of
    501:
      begin
        C.SetCheck(501, 1);
        C.SetCheck(502, 0);
      end;
    502:
      begin
        C.SetCheck(502, 1);
        C.SetCheck(501, 0);
      end;
    601, 701:
      begin
        IntToPChar(Buf, C.GetPosition(Id));
        C.SetText(Id + 1, Buf);
      end;
    301:
      begin
        Inc(D.Data[$4481]);
        ShowPlayer;
        if D.Data[$4480] - 1 <= D.Data[$4481] then
          C.Enable(301, False);
        C.Enable(302, True);
      end;
    302:
      begin
        Dec(D.Data[$4481]);
        ShowPlayer;
        if D.Data[$4481] = 0 then
          C.Enable(302, False);
        C.Enable(301, True);
      end;
    303: ApplyPlayer;
    401: UI.Call('Do_TruppenAufstellen', [APtr(D), APtr(Shown), AByte(6)]);
    402: Do_SzenarioDlg(D);
  else
    Result := False;
  end;
end;

function TCensusDlg.CanClose: Boolean;
begin
  ApplyPlayer;
  Result := True;
end;

{ -- the scenario --------------------------------------------------------------- }

procedure Do_SzenarioDlg(Parent: Pointer);
var
  D: TDialog;
begin
  D := UI.Dialog('SzenarioDlg', $1640, [APtr(Parent), AStr(DSText($1718))]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TSzenarioDlg.SetupWindow;
begin
  SetNum(C, 101, DS.Game.Year);
  C.SetText(102, DS.Game.ScenarioTitle);
  C.SetText(103, PChar(@DS.Game.ScenarioDescription));
  C.SetText(104, DS.Game.ScenarioAuthor);
end;

function TSzenarioDlg.CanClose: Boolean;
begin
  DS.Game.Year := Word(EditValue(C, 101, 8));
  C.GetText(102, DS.Game.ScenarioTitle, $28);
  C.GetText(103, PChar(@DS.Game.ScenarioDescription), $200);
  C.GetText(104, DS.Game.ScenarioAuthor, $18);
  Result := True;
end;

{ -- the unit editor ------------------------------------------------------------- }

procedure Do_UnitEditDlg(Parent: Pointer; const P: TPlayer; var U: TUnit);
var
  D: TDialog;
begin
  D := UI.Dialog('UnitEditDlg', $16AE, [APtr(Parent), AStr(DSText($1726))]);
  Move(U, D.Data[$703], SizeOf(TUnit));
  Move(P, D.Data[$2E], SizeOf(TPlayer));
  if UI.Execute(D) = 1 then
    Move(D.Data[$703], U, SizeOf(TUnit));
  UI.Done(D, 1);
end;

function TUnitEditDlg.U: PUnit;
begin
  Result := PUnit(@D.Data[$703]);
end;

procedure TUnitEditDlg.SetupWindow;
var
  I: Integer;
begin
  if U^.UnitType = 9 then
  begin
    C.Enable(103, True);
    C.SetRange(103, 1, 18);                    { the hero pictures }
    C.SetPosition(103, PByte(U)[$1A]);
  end
  else
    C.Enable(103, False);
  for I := 0 to 29 do
    C.AddString(104, DSText($53D8 + I * 25));   { the abilities }
  ShowValues;
end;

procedure TUnitEditDlg.ShowValues;
var
  Buf: array[0..25] of Char;
  B: PByte;
begin
  B := PByte(U);
  C.SetText(101, U^.Name);
  UnitRankName(U^, Buf);
  C.SetText(102, Buf);
  C.SetSelIndex(104, B[$2F]);
  SetNum(C, 201, B[$1B]);
  SetNum(C, 202, B[$1C]);
  SetNum(C, 203, ShortInt(B[$1D]));
  SetNum(C, 204, B[$1F]);
  SetNum(C, 205, B[$20]);
  SetNum(C, 206, B[$22]);
  SetNum(C, 207, PSmallInt(@B[$2B])^);
end;

procedure TUnitEditDlg.ApplyValues;
var
  Buf: array[0..25] of Char;
  B: PByte;
begin
  B := PByte(U);
  C.GetText(101, Buf, $18);
  StrCopy(U^.Name, Buf);
  B[$2F] := Byte(C.GetSelIndex(104));
  B[$1B] := Byte(EditValue(C, 201, $10));
  B[$1C] := Byte(EditValue(C, 202, $10));
  B[$1D] := Byte(EditValue(C, 203, $10));
  B[$1F] := Byte(EditValue(C, 204, $10));
  B[$20] := Byte(EditValue(C, 205, $10));
  B[$22] := Byte(EditValue(C, 206, $10));
  PSmallInt(@B[$2B])^ := SmallInt(EditValue(C, 207, $10));
end;

function TUnitEditDlg.Handle(Id: SmallInt): Boolean;
var
  Gains: THeroGains;
begin
  Result := True;
  case Id of
    103:
      begin
        PByte(U)[$1A] := Byte(C.GetPosition(103));
        UI.Call('UnitEditDlg_DrawPortrait', [APtr(D)]);
      end;
    105:
      begin
        { training: experience by the rank }
        FillChar(Gains, SizeOf(Gains), 0);
        UnitGainExperience(U^, Gains, Byte(U^.Level * 2 + 10), PPlayer(@D.Data[$2E])^.Spell);
        ShowValues;
      end;
  else
    Result := False;
  end;
end;

function TUnitEditDlg.CanClose: Boolean;
begin
  ApplyValues;
  Result := True;
end;

initialization
  RegisterDialogLogic('PasswordDlg', TPasswordDlg);
  RegisterDialogLogic('CensusDlg', TCensusDlg);
  RegisterDialogLogic('SzenarioDlg', TSzenarioDlg);
  RegisterDialogLogic('UnitEditDlg', TUnitEditDlg);
end.
