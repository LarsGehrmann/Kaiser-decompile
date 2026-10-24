{ The generic dialog types of segment 12 (1058:0002 .. 1058:0f91) and the
  dialog types of the turn (segment 3), the war (segment 6) and the new
  game (segment 9): KaiserDlg and its descendants that only fill their
  controls from the object, choose a button or read a few controls back.
  Each class is the original type's Init beyond creating the controls,
  SetupWindow, its DMT handlers, CanClose and the timer, working on D.Data
  laid out like the original object (the game writes its inputs there
  before Execute and reads the results after it). Registered by the
  constructor name the logic passes to UI.Dialog.

  Painting is the UI's: UnitInfoDlg's portrait is the UI call
  'UnitInfoDlg_DrawPortrait' (blink, the dialog). (Not named Dialogs: the
  LCL has a unit of that name.) }
unit GameDialogs;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserRes, KaiserUI;

type
  { KaiserDlg (VMT DS:3364, 1058:0002, size 0x2e): the base of all game
    dialogs. Init only adds a window style, SetupWindow centres the window
    and stores its size at +0x2a / +0x2c (the UI does both), WMSetFont /
    WMCtlColor / Done handle the font and colours: nothing for the logic }
  TKaiserDlg = class(TDialogLogic)
  end;

  { HelpDlg (1058:01bb, no type of its own): a KaiserDlg with the help
    button 999 and the help context +0x2e (the constructor's word
    argument, or a constant of the type). IdHelp (1058:0221): WinHelp on
    kaiser.hlp (HELP_CONTEXTPOPUP) when the context is not 0 }
  THelpDlg = class(TKaiserDlg)
  public
    procedure SetHelpContext(Ctx: Word);
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { MessageDlg (VMT DS:33c6, 1058:024d): the text (Args[2]) at +0x2e, shown
    in static 101 }
  TMessageDlg = class(TKaiserDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { HelpMessageDlg (VMT DS:341a, 1058:02d6): a HelpDlg (Args[3]) with the
    text (Args[2]) at +0x34 in static 101 }
  THelpMessageDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { Message2Dlg (VMT DS:3472, 1058:0364): texts +0x2e (Args[2]) and +0x7f
    (Args[3]) in statics 101 and 102 }
  TMessage2Dlg = class(TKaiserDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { HelpChoice2Dlg (VMT DS:34c6, 1058:043e, KRIEGSER*DLG): a HelpDlg
    (Args[4]) with texts +0x34 (Args[2]) and +0x85 (Args[3]) in statics
    101 and 102; buttons 1 and 2 are enabled while +0xe6 / +0xe7 are set
    (DisableButton2 1058:0591 clears +0xe7) }
  THelpChoice2Dlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { HeroNameDlg (VMT DS:351e, 1058:05a1, HELDDLG ...): a HelpDlg (Args[2])
    with edit 101; SetupWindow proposes a random name (string 101..320, so
    RandSeed moves on) at +0x38, CanClose reads the name back (15
    characters) and sets +0x49 for the Lindwurm's name when the census
    editor is enabled; GetName (VMT +0x58) is +0x38 }
  THeroNameDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
    function GetText: PChar; override;
  end;

  { UnitInfoDlg (VMT DS:35e6, 1058:0862, SOELDNERDLG ...): a HelpDlg
    (Args[4]) showing the unit record (Args[2], copied to +0x35) in statics
    101..108: name, rank ('e' at +0x34, Args[3]) or ability ('f'), attack,
    defence, hit points, range, steps, pay; its portrait blinks (WMTimer
    every 400 ms: now and then the other frame for one tick) }
  TUnitInfoDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    procedure Timer; override;
    function DoneFlag(Flag: Word): Word; override;
    procedure DrawPortrait(Blink: Byte);
  end;

  { Button2Dlg (VMT DS:3652, 1058:0d0d, LAGERVOLLDLG): buttons 101, 102
    end the dialog with their id }
  TButton2Dlg = class(TKaiserDlg)
  public
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { ButtonChoiceDlg (VMT DS:36ea, 1058:0da7, KAMPFOPTDLG): Args[2] buttons
    101.. (count +0x2e), enabled by the 10 flags of Args[3] (+0x2f); a
    button ends the dialog with its id }
  TButtonChoiceDlg = class(TKaiserDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { segment 3: PromotionDlg (VMT DS:05f0, 1010:58d3, BEFDLG / FEMBEFDLG):
    the year +0x7f (+1400), the name +0x2e, the new title +0x81 (female
    +0x82) in statics 101..103 }
  TPromotionDlg = class(TKaiserDlg)
  public
    procedure SetupWindow; override;
  end;

  { StartFinanzDlg (VMT DS:0916, 1010:59ef, a HelpDlg 0x72): ten longints
    +0x34.. in statics 101..110 (the 4th and the 10th negated) }
  TStartFinanzDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
  end;

  { StartPopDlg (VMT DS:0536, 1010:5c1a): births +0x2e, deaths +0x32,
    immigrants +0x36, emigrants +0x3a with their texts in statics
    101..104, the happiness +0x3e (Real) as Str(x * 100:2:0) % in 105 }
  TStartPopDlg = class(TKaiserDlg)
  public
    procedure SetupWindow; override;
  end;

  { HexenDlg (VMT DS:0598, 1010:5e43, a HelpDlg 0x96): the 13 spells in
    combo box 101; a selection sets the help context 0x96 + index, CanClose
    the index +0x38 }
  THexenDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { segment 6: MassacreDlg (VMT DS:0cec, 1028:0461, MASSAKERDLG): longints
    +0x2e, +0x32 and the text +0x42 in statics 101..103 }
  TMassacreDlg = class(TKaiserDlg)
  public
    procedure SetupWindow; override;
  end;

  { PlunderResultDlg (VMT DS:0c98, 1028:0c00, PLUENDERNDLG): longints
    +0x36, +0x32, +0x2e in statics 101..103 }
  TPlunderResultDlg = class(TKaiserDlg)
  public
    procedure SetupWindow; override;
  end;

  { PlunderChoiceDlg (VMT DS:0d60, 1028:1290, LOOTDLG / LOOT2DLG, a HelpDlg
    0x7d): texts +0x34, +0x67 in statics 101, 102; buttons 201..204
    (plunder, burn, massacre, mercy) end with 10..13 }
  TPlunderChoiceDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { segment 9: HumanCountDlg (VMT DS:22e4, 1040:2017, SPIELERZAHLDLG, a
    HelpDlg 3): the number of humans +0x34 (range +0x35..+0x36) on scroll
    bar 101 and static 102, the options 301..304 (e-mail game only with
    two humans or more), CanClose writes them into the game header }
  THumanCountDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    procedure UpdateLabels;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

  { ComputerCountDlg (VMT DS:2362, 1040:234c, COMPUTERZAHLDLG, a HelpDlg
    4): the number of computers +0x34 (range +0x35..+0x36) on scroll bar
    101 and static 102, the level +0x3b on radios 201..204 }
  TComputerCountDlg = class(THelpDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    procedure UpdateCountLabel;
    procedure UpdateLevelRadios;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { PlayerDataDlg (VMT DS:195a, 1040:2569, SPIELERNAMEDLG): human Args[3]
    of the players Args[2]: the name +0x2e (edit 101, from DS:659c), the
    number +0x47 (static 105), the sex +0x4c (radios 102 / 103), the
    countries not taken by the humans before (+0x4f, count +0x4e) in combo
    box 201, the chosen one +0x4d; CanClose wants a name }
  TPlayerDataDlg = class(TKaiserDlg)
  public
    procedure Init; override;
    procedure SetupWindow; override;
    function Handle(Id: SmallInt): Boolean; override;
    function CanClose: Boolean; override;
  end;

{ DisableButton2 (1058:0591): HelpChoice2Dlg's button 2 stays disabled }
procedure DisableButton2(D: TDialog);

implementation

{ the number as the original's IntToStr (1068:6b29) / Str writes it }
procedure SetNumber(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

function GetLong(D: TDialog; Off: Word): LongInt;
begin
  Move(D.Data[Off], Result, 4);
end;

{ StrCopy of a string argument into the object's 81-byte text (nil:
  nothing). Remastered: at most 80 characters (the original copied without
  a limit into the next text and the static control's pointer behind it) }
procedure CopyArg(D: TDialog; Off: Word; const A: TUIArg);
begin
  if (A.Kind = uaStr) and (PtrUInt(A.P) >= $10000) then
    StrLCopy(PChar(@D.Data[Off]), PChar(A.P), 80);
end;

procedure DisableButton2(D: TDialog);
begin
  D.Data[$E7] := 0;
end;

{ -- HelpDlg ------------------------------------------------------------------ }

procedure THelpDlg.SetHelpContext(Ctx: Word);
begin
  PWord(@D.Data[$2E])^ := Ctx;
end;

function THelpDlg.Handle(Id: SmallInt): Boolean;
var
  Ctx: Word;
begin
  if Id <> 999 then
    Exit(False);
  Ctx := PWord(@D.Data[$2E])^;
  if Ctx <> 0 then
    UI.Call('WinHelp', [AStr(DSText($373E)), AWord(8), ALong(Ctx)]);
  Result := True;
end;

{ -- MessageDlg, HelpMessageDlg, Message2Dlg, HelpChoice2Dlg ------------------- }

procedure TMessageDlg.Init;
begin
  CopyArg(D, $2E, Args[2]);
end;

procedure TMessageDlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$2E]));
end;

procedure THelpMessageDlg.Init;
begin
  SetHelpContext(Word(Args[3].V));
  CopyArg(D, $34, Args[2]);
end;

procedure THelpMessageDlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$34]));
end;

procedure TMessage2Dlg.Init;
begin
  CopyArg(D, $2E, Args[2]);
  CopyArg(D, $7F, Args[3]);
end;

procedure TMessage2Dlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$2E]));
  C.SetText(102, PChar(@D.Data[$7F]));
end;

procedure THelpChoice2Dlg.Init;
begin
  SetHelpContext(Word(Args[4].V));
  D.Data[$E6] := 1;
  D.Data[$E7] := 1;
  CopyArg(D, $34, Args[2]);
  CopyArg(D, $85, Args[3]);
end;

procedure THelpChoice2Dlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$34]));
  C.SetText(102, PChar(@D.Data[$85]));
  if D.Data[$E6] = 0 then
    C.Enable(1, False);
  if D.Data[$E7] = 0 then
    C.Enable(2, False);
end;

{ -- HeroNameDlg ------------------------------------------------------------------ }

procedure THeroNameDlg.Init;
begin
  SetHelpContext(Word(Args[2].V));
  D.Data[$49] := 0;
end;

procedure THeroNameDlg.SetupWindow;
begin
  LoadString(Random(220) + 101, PChar(@D.Data[$38]), 16);
  C.SetText(101, PChar(@D.Data[$38]));
  SetHelpContext($D1);
end;

function THeroNameDlg.CanClose: Boolean;
var
  Lindwurm: array[0..25] of Char;
begin
  StrCopy(Lindwurm, DSText($374A));                      { 'guams ' + 'dlo' }
  StrCat(Lindwurm, DSText($3751));
  C.GetText(101, PChar(@D.Data[$38]), 16);
  if (DS.Game.CensusEditorEnabled <> 0) and (StrComp(PChar(@D.Data[$38]), Lindwurm) = 0) then
    D.Data[$49] := 1;
  Result := True;
end;

function THeroNameDlg.GetText: PChar;
begin
  Result := PChar(@D.Data[$38]);
end;

{ -- UnitInfoDlg ------------------------------------------------------------------- }

procedure TUnitInfoDlg.Init;
begin
  SetHelpContext(Word(Args[4].V));
  Move(Args[2].P^, D.Data[$35], SizeOf(TUnit));
  D.Data[$34] := Byte(Args[3].V);
end;

procedure TUnitInfoDlg.SetupWindow;
var
  U: PUnit;
  Buf: array[0..81] of Char;
begin
  U := PUnit(@D.Data[$35]);
  C.SetText(101, PChar(@U^.Name));
  FillChar(Buf, SizeOf(Buf), 0);
  if D.Data[$34] = $65 then
    UnitRankName(U^, Buf)
  else if D.Data[$34] = $66 then
    StrCopy(Buf, DSText($53D8 + 25 * U^.Ability));
  C.SetText(102, Buf);
  SetNumber(C, 103, U^.Attack);
  SetNumber(C, 104, U^.Defence);
  SetNumber(C, 105, ShortInt(U^.MaxHp));
  SetNumber(C, 106, U^.Range);
  SetNumber(C, 107, U^.MaxSteps);
  SetNumber(C, 108, U^.Pay);
  D.Data[$74] := 0;
  DrawPortrait(D.Data[$74]);
  PWord(@D.Data[$72])^ := 1;                           { SetTimer(.., 1, 400, nil) }
  TimerInterval := 400;
end;

procedure TUnitInfoDlg.DrawPortrait(Blink: Byte);
begin
  { 1058:0af8: the type's sprite 1100 + type (blinking: 1300 + type) at
    (132, 64) of 237 x 254, scaled to the window }
  UI.Call('UnitInfoDlg_DrawPortrait', [AByte(Blink), APtr(D)]);
end;

procedure TUnitInfoDlg.Timer;
begin
  { WMTimer (1058:0ca1) }
  if Random(4) = 0 then
    D.Data[$74] := Ord(D.Data[$74] = 0);
  DrawPortrait(D.Data[$74]);
  D.Data[$74] := 0;
end;

function TUnitInfoDlg.DoneFlag(Flag: Word): Word;
begin
  { Done (1058:0cdb): KillTimer, then KaiserDlg.Done(0) }
  TimerInterval := 0;
  Result := 0;
end;

{ -- Button2Dlg, ButtonChoiceDlg --------------------------------------------------- }

function TButton2Dlg.Handle(Id: SmallInt): Boolean;
begin
  Result := (Id = 101) or (Id = 102);
  if Result then
    C.EndDlg(Id);
end;

procedure TButtonChoiceDlg.Init;
var
  N: Integer;
begin
  D.Data[$2E] := Byte(Args[2].V);
  { BlockCopy of 10 flags (the battle passes 5: the rest is never read) }
  N := 10;
  if (Args[3].Kind = uaRec) and (Args[3].Len < N) then
    N := Args[3].Len;
  Move(Args[3].P^, D.Data[$2F], N);
end;

procedure TButtonChoiceDlg.SetupWindow;
var
  I, Last: Byte;
begin
  { remastered: 1..10 buttons (0 made the original's byte loop create 256
    and write past the object) }
  if D.Data[$2E] = 0 then
    D.Data[$2E] := 1;
  if D.Data[$2E] > 10 then
    D.Data[$2E] := 10;
  Last := Byte(D.Data[$2E] - 1);
  I := 0;
  repeat
    C.Enable(101 + I, D.Data[$2F + I] <> 0);
    if I = Last then
      Break;
    Inc(I);
  until False;
end;

function TButtonChoiceDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := (Id >= 101) and (Id <= 110);
  if Result then
    C.EndDlg(Id);
end;

{ -- segment 3 ------------------------------------------------------------------------ }

procedure TPromotionDlg.SetupWindow;
var
  T: Word;
begin
  SetNumber(C, 101, Word(PWord(@D.Data[$7F])^ + $578));
  C.SetText(102, PChar(@D.Data[$2E]));
  T := Word(D.Data[$81]) + 1;
  if D.Data[$82] = 0 then
    C.SetText(103, DSText($58E8 + 25 * T))
  else
    C.SetText(103, DSText($59FC + 25 * T));
end;

procedure TStartFinanzDlg.Init;
begin
  SetHelpContext($72);
end;

procedure TStartFinanzDlg.SetupWindow;
begin
  SetNumber(C, 101, GetLong(D, $34));
  SetNumber(C, 102, GetLong(D, $38));
  SetNumber(C, 103, GetLong(D, $3C));
  SetNumber(C, 104, LongInt(LongWord(0) - LongWord(GetLong(D, $40))));
  SetNumber(C, 105, GetLong(D, $44));
  SetNumber(C, 106, GetLong(D, $48));
  SetNumber(C, 107, GetLong(D, $4C));
  SetNumber(C, 108, GetLong(D, $50));
  SetNumber(C, 109, GetLong(D, $54));
  SetNumber(C, 110, LongInt(LongWord(0) - LongWord(GetLong(D, $58))));
end;

procedure TStartPopDlg.SetupWindow;
var
  Buf: array[0..299] of Char;
  R: TReal48;

  procedure Line(Id: SmallInt; Ofs, TextOfs: Word);
  begin
    IntToPChar(Buf, GetLong(D, Ofs));
    StrCat(Buf, DSText(TextOfs));
    C.SetText(Id, Buf);
  end;

begin
  Line(101, $2E, $0A4C);
  Line(102, $32, $0A80);
  Line(103, $36, $0AA8);
  Line(104, $3A, $0ADB);
  { Str(happiness * 100:2:0, S) }
  Move(D.Data[$3E], R, 6);
  StrPCopy(Buf, R48Str(R48Mul(RC($0087, 0, $4800), R), 2, 0));
  StrCat(Buf, DSText($0B0E));
  C.SetText(105, Buf);
end;

procedure THexenDlg.Init;
begin
  SetHelpContext($96);
end;

procedure THexenDlg.SetupWindow;
var
  I: Integer;
begin
  for I := 0 to 12 do
    C.AddString(101, DS.SpellNames[I]);
  C.SetSelIndex(101, 0);
  C.ComboSetText(101, DS.SpellNames[0]);
end;

function THexenDlg.Handle(Id: SmallInt): Boolean;
begin
  if Id <> 101 then
    Exit(inherited Handle(Id));
  SetHelpContext(Word(C.GetSelIndex(101) + $96));
  Result := True;
end;

function THexenDlg.CanClose: Boolean;
begin
  PWord(@D.Data[$38])^ := Word(C.GetSelIndex(101));
  Result := True;
end;

{ -- segment 6 ------------------------------------------------------------------------ }

procedure TMassacreDlg.SetupWindow;
begin
  SetNumber(C, 101, GetLong(D, $2E));
  SetNumber(C, 102, GetLong(D, $32));
  C.SetText(103, PChar(@D.Data[$42]));
end;

procedure TPlunderResultDlg.SetupWindow;
begin
  SetNumber(C, 101, GetLong(D, $36));
  SetNumber(C, 102, GetLong(D, $32));
  SetNumber(C, 103, GetLong(D, $2E));
end;

procedure TPlunderChoiceDlg.Init;
begin
  SetHelpContext($7D);
end;

procedure TPlunderChoiceDlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$34]));
  C.SetText(102, PChar(@D.Data[$67]));
end;

function TPlunderChoiceDlg.Handle(Id: SmallInt): Boolean;
begin
  if (Id < 201) or (Id > 204) then
    Exit(inherited Handle(Id));
  C.EndDlg(Id - 201 + 10);
  Result := True;
end;

{ -- segment 9 ------------------------------------------------------------------------ }

procedure THumanCountDlg.Init;
begin
  SetHelpContext(3);
end;

procedure THumanCountDlg.SetupWindow;
begin
  D.Data[$34] := D.Data[$35];
  C.SetRange(101, D.Data[$35], D.Data[$36]);
  C.SetPosition(101, D.Data[$34]);
  C.SetCheck(301, 0);                                  { Spiel per E-Mail }
  C.SetCheck(302, 0);                                  { Unsterblichkeit }
  C.SetCheck(303, 1);                                  { Warenhandel }
  C.SetCheck(304, 1);                                  { Initiativpunkte }
  UpdateLabels;
end;

procedure THumanCountDlg.UpdateLabels;
begin
  SetNumber(C, 102, D.Data[$34]);
  if D.Data[$34] > 1 then
    C.Enable(301, True)
  else
  begin
    C.Enable(301, False);
    C.SetCheck(301, 0);
  end;
end;

function THumanCountDlg.Handle(Id: SmallInt): Boolean;
begin
  case Id of
    301..304:
      if C.GetCheck(Id) = 1 then
        C.SetCheck(Id, 0)
      else
        C.SetCheck(Id, 1);
    101:
      begin
        D.Data[$34] := Byte(C.GetPosition(101));
        UpdateLabels;
      end;
  else
    Exit(inherited Handle(Id));
  end;
  Result := True;
end;

function THumanCountDlg.CanClose: Boolean;
begin
  DS.Game.EmailGameQ := Ord(C.GetCheck(301) = 1);
  DS.Game.Immortality := Ord(C.GetCheck(302) = 1);
  DS.Game.GoodsTradeEnabled := Ord(C.GetCheck(303) = 1);
  DS.Game.InitiativeEnabled := Ord(C.GetCheck(304) = 1);
  Result := True;
end;

procedure TComputerCountDlg.Init;
begin
  SetHelpContext(4);
  D.Data[$3B] := 0;
end;

procedure TComputerCountDlg.SetupWindow;
begin
  D.Data[$34] := D.Data[$35];
  C.SetRange(101, D.Data[$35], D.Data[$36]);
  C.SetPosition(101, D.Data[$34]);
  UpdateLevelRadios;
  UpdateCountLabel;
end;

procedure TComputerCountDlg.UpdateCountLabel;
begin
  SetNumber(C, 102, D.Data[$34]);
end;

procedure TComputerCountDlg.UpdateLevelRadios;
var
  I: Integer;
begin
  for I := 0 to 3 do
    C.SetCheck(201 + I, Ord(I = D.Data[$3B]));
end;

function TComputerCountDlg.Handle(Id: SmallInt): Boolean;
begin
  case Id of
    101:
      begin
        D.Data[$34] := Byte(C.GetPosition(101));
        UpdateCountLabel;
      end;
    201..204:
      begin
        D.Data[$3B] := Id - 201;
        UpdateLevelRadios;
      end;
  else
    Exit(inherited Handle(Id));
  end;
  Result := True;
end;

procedure TPlayerDataDlg.Init;
var
  Players: ^TPlayers;
  Me, Country, K, Last: Byte;
  Taken: Boolean;
begin
  Players := Args[2].P;
  Me := Byte(Args[3].V);
  D.Data[$4C] := 0;
  D.Data[$4E] := 0;
  IntToPChar(PChar(@D.Data[$47]), Me + 1);
  StrCopy(PChar(@D.Data[$2E]), DS.HumanNames[Me]);
  for Country := 0 to 9 do
  begin
    Taken := False;
    if Me > 0 then
    begin
      Last := Me - 1;
      K := 0;
      repeat
        if Players^[K].Country = Country then
          Taken := True;
        if K = Last then
          Break;
        Inc(K);
      until False;
    end;
    if not Taken then
    begin
      D.Data[$4F + D.Data[$4E]] := Country;
      Inc(D.Data[$4E]);
    end;
  end;
end;

procedure TPlayerDataDlg.SetupWindow;
var
  I, Last: Byte;
begin
  C.SetCheck(102, 1);
  C.SetCheck(103, 0);
  Last := Byte(D.Data[$4E] - 1);
  I := 0;
  repeat
    C.AddString(201, DS.CountryNamesRt[D.Data[$4F + I]]);
    if I = Last then
      Break;
    Inc(I);
  until False;
  C.SetSelIndex(201, 0);
  C.SetText(101, PChar(@D.Data[$2E]));
  C.SetText(105, PChar(@D.Data[$47]));
end;

function TPlayerDataDlg.Handle(Id: SmallInt): Boolean;
begin
  if (Id <> 102) and (Id <> 103) then
    Exit(inherited Handle(Id));
  { the two radios toggle each other (103 goes to 102's handler) }
  if C.GetCheck(102) = 1 then
  begin
    C.SetCheck(102, 0);
    C.SetCheck(103, 1);
  end
  else
  begin
    C.SetCheck(102, 1);
    C.SetCheck(103, 0);
  end;
  Result := True;
end;

function TPlayerDataDlg.CanClose: Boolean;
begin
  C.GetText(101, PChar(@D.Data[$2E]), 16);
  if C.GetCheck(102) = 1 then
    D.Data[$4C] := 0
  else
    D.Data[$4C] := 1;
  D.Data[$4D] := D.Data[$4F + C.GetSelIndex(201)];
  Result := StrLen(PChar(@D.Data[$2E])) > 0;
end;

initialization
  RegisterDialogLogic('KaiserDlg', TKaiserDlg);
  RegisterDialogLogic('MessageDlg', TMessageDlg);
  RegisterDialogLogic('HelpMessageDlg', THelpMessageDlg);
  RegisterDialogLogic('Message2Dlg', TMessage2Dlg);
  RegisterDialogLogic('HelpChoice2Dlg', THelpChoice2Dlg);
  RegisterDialogLogic('HeroNameDlg', THeroNameDlg);
  RegisterDialogLogic('UnitInfoDlg', TUnitInfoDlg);
  RegisterDialogLogic('Button2Dlg', TButton2Dlg);
  RegisterDialogLogic('ButtonChoiceDlg', TButtonChoiceDlg);
  RegisterDialogLogic('PromotionDlg', TPromotionDlg);
  RegisterDialogLogic('StartFinanzDlg', TStartFinanzDlg);
  RegisterDialogLogic('StartPopDlg', TStartPopDlg);
  RegisterDialogLogic('HexenDlg', THexenDlg);
  RegisterDialogLogic('MassacreDlg', TMassacreDlg);
  RegisterDialogLogic('PlunderResultDlg', TPlunderResultDlg);
  RegisterDialogLogic('PlunderChoiceDlg', TPlunderChoiceDlg);
  RegisterDialogLogic('HumanCountDlg', THumanCountDlg);
  RegisterDialogLogic('ComputerCountDlg', TComputerCountDlg);
  RegisterDialogLogic('PlayerDataDlg', TPlayerDataDlg);
end.
