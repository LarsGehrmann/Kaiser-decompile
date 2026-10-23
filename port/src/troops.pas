{ The troop dialog ANORDNENDLG ("Truppen aufstellen", segment 8, type
  DS:1776) and the two actions that open it: Do_TruppenAufstellen (the menu,
  the turn start, before a battle) and ChooseUnitToGive (Entwicklungshilfe).
  The dialog works on a copy of the player at +0x34; units are selected by
  clicking into the painted grids (Mouse), at most two at a time, and the
  buttons swap, dismiss, pay, knight / enfeoff and recruit them. Drawing is
  left to the UI (TroopDlg_Draw* calls); the dialogs it opens that are not
  ported yet (RecruitDialog, ShowPayDlg, Do_UnitEditDlg) are UI calls.
  Differential tests: tools/emu/dlg_driver.py runs the original's own
  object with the same user events (docs/phase3.md). }
unit Troops;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, Turn, KaiserUI;

{ Truppen aufstellen (1038:6a30): ANORDNENDLG on a copy of the player, taken
  over on OK. Mode: 0 own armies, 1/2 the Heer before a battle, 3 the Garde
  (before a city battle), 4 choose a unit to give away, 5 another player's
  armies (view only), 6 the census editor (Debug) }
procedure Do_TruppenAufstellen(Parent: Pointer; var P: TPlayer; Mode: Byte);
{ ChooseUnitToGive (1038:6a93): mode 4 ("Abschicken"); on OK the copy is
  taken over and Army (1 Heer, 2 Garde) / Slot name the chosen unit }
function ChooseUnitToGive(Parent: Pointer; var P: TPlayer; var Army, Slot: Byte): Boolean;

const
  { object fields of ANORDNENDLG }
  TdMode = $709;
  TdHeerSel1 = $70A;     { the selected Heer slots (0 = none) }
  TdHeerSel2 = $70B;
  TdGardeSel1 = $70C;    { the selected Garde slots }
  TdGardeSel2 = $70D;
  TdHoverArmy = $70E;    { the unit under the mouse (info card): army 1/2 }
  TdHoverSlot = $70F;    { and slot (0 = none) }
  TdHeerX = $710;        { client pixel positions (words): Heer grid 64 x 160 }
  TdHeerY = $712;
  TdGardeX = $714;       { Garde grid 112 x 112 (8 pixels of wall) }
  TdGardeY = $716;
  TdInfoX = $718;        { the unit's info card }
  TdInfoY = $71A;
  TdSelState = $71C;     { 0 none, 4 one Heer unit, 5 one Garde unit,
                           1 two Heer, 2 two Garde, 3 one of each }
  TdScaleX = $71D;       { Real48: window width / 440, height / 401 }
  TdScaleY = $723;

type
  { ANORDNENDLG (VMT DS:1776, 1038:6b38, a HelpDlg): the player at +0x34,
    the fields above; buttons 101 swap, 102 Entlassen, 103 Spezial, 104 /
    105 Rekrutieren (Heer / Garde), 106 Alle tauschen, 107 Sold; statics
    201 Heer (ausser Landes), 202 the caption, 203..205 Taler, Waffen,
    Sold with their labels 301..303 }
  TTroopDlg = class(TDialogLogic)
  public
    function Me: PPlayer;
    function Mode: Byte;
    function HeerUnit(I: Byte): PUnit;
    function GardeUnit(I: Byte): PUnit;
    function W(Off: Integer): PWord;
    procedure Init; override;
    procedure SetupWindow; override;
    function CanClose: Boolean; override;
    procedure UpdateButtons;
    procedure ShowTreasury;
    procedure UpdateSelState;
    function CountSelected: Byte;
    procedure ToggleHeerUnit(Slot: Byte);
    procedure ToggleGardeUnit(Slot: Byte);
    procedure DrawHeer;
    procedure DrawGarde;
    procedure Swap;
    procedure Dismiss;
    procedure Special;
    procedure Recruit(Army: Byte);
    procedure SwapAll;
    procedure Pay;
    function Handle(Id: SmallInt): Boolean; override;
    function Mouse(X, Y: SmallInt): Boolean; override;
    function MouseMove(X, Y: SmallInt): Boolean; override;
  end;

implementation

type
  PReal48 = ^TReal48;

procedure SetNumber(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

{ the original compares a sign-extended pixel with a zero-extended word
  position: Lo <= V < Hi }
function Within(V: SmallInt; Lo, Hi: Word): Boolean;
begin
  Result := (LongInt(V) >= LongInt(Lo)) and (LongInt(V) < LongInt(Hi));
end;

{ -- the actions ------------------------------------------------------------ }

procedure Do_TruppenAufstellen(Parent: Pointer; var P: TPlayer; Mode: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('TroopDlg', $1776, [APtr(Parent), AStr(DSText($17CE)), AByte(Mode), APtr(@P)]);
  if UI.Execute(D) = 1 then
    Move(D.Data[$34], P, SizeOf(TPlayer));
  UI.Done(D, 1);
end;

function ChooseUnitToGive(Parent: Pointer; var P: TPlayer; var Army, Slot: Byte): Boolean;
var
  D: TDialog;
begin
  D := UI.Dialog('TroopDlg', $1776, [APtr(Parent), AStr(DSText($17DA)), AByte(4), APtr(@P)]);
  Result := UI.Execute(D) = 1;
  if Result then
  begin
    Move(D.Data[$34], P, SizeOf(TPlayer));
    if D.Data[TdHeerSel1] = 0 then
    begin
      Army := 2;
      Slot := D.Data[TdGardeSel1];
    end
    else
    begin
      Army := 1;
      Slot := D.Data[TdHeerSel1];
    end;
  end;
  UI.Done(D, 1);
end;

{ -- ANORDNENDLG ------------------------------------------------------------ }

function TTroopDlg.Me: PPlayer;
begin
  Result := PPlayer(@D.Data[$34]);
end;

function TTroopDlg.Mode: Byte;
begin
  Result := D.Data[TdMode];
end;

{ unit I of the copy's Heer / Garde, addressed as the original does (slot 0
  and a Garde slot 9 lie next to the arrays) }
function TTroopDlg.HeerUnit(I: Byte): PUnit;
begin
  Result := PUnit(@D.Data[$130 + I * $3D]);
end;

function TTroopDlg.GardeUnit(I: Byte): PUnit;
begin
  Result := PUnit(@D.Data[$355 + I * $3D]);
end;

function TTroopDlg.W(Off: Integer): PWord;
begin
  Result := PWord(@D.Data[Off]);
end;

{ the constructor (1038:6b38) beyond the controls: Args = parent, name,
  mode, the player }
procedure TTroopDlg.Init;
begin
  Move(PPlayer(Args[3].P)^, D.Data[$34], SizeOf(TPlayer));
  D.Data[TdMode] := Byte(Args[2].V);
  D.Data[TdHeerSel1] := 0;
  D.Data[TdHeerSel2] := 0;
  D.Data[TdGardeSel1] := 0;
  D.Data[TdGardeSel2] := 0;
  D.Data[TdSelState] := 0;
  D.Data[TdHoverArmy] := 1;
  D.Data[TdHoverSlot] := 0;
end;

procedure TTroopDlg.SetupWindow;
var
  Buf: array[0..255] of Char;
  Title: array[0..255] of Char;
  SX, SY: TReal48;

  { a grid position: the design position times the scale, made odd + 1 }
  procedure Place(Off: Integer; const Design, Scale: TReal48);
  var
    V: Word;
  begin
    V := Word(R48Round(R48Mul(Design, Scale)));
    W(Off)^ := Word(V + V mod 2 + 1);
  end;

begin
  if Me^.ArmyAway <> 0 then
    C.SetText(201, DSText($17E6));                    { Heer (ausser Landes) }
  case Mode of
    1, 2, 3:
      begin
        FormatPlayerTitle(Me^, Buf, 0, 0);
        StrCat(Buf, DSText($17FA));                     { ' - stellt Eu' }
        if Mode = 3 then
          StrCat(Buf, DSText($1807))                    { 're GARDE' }
        else
          StrCat(Buf, DSText($1810));                   { 'er HEER' }
        StrCat(Buf, DSText($1818));                     { ' auf' }
      end;
    4: StrCopy(Buf, DSText($181D));                   { 'Waehlt eine Einheit zum Verschenken:' }
    5:
      begin
        StrCopy(Buf, DSText($1841));                    { 'Truppenuebersicht ' }
        FormatPlayerTitle(Me^, Title, 0, 0);
        StrCat(Buf, Title);
      end;
  else
    StrCopy(Buf, DSText($17F9));                      { '' }
  end;
  C.SetText(202, Buf);
  { Abbrechen: only for the own armies, the census and the gift, and not
    with a Garde of 9 (one must go) }
  C.Enable(2, (Mode in [0, 6, 4]) and (Me^.Army2Count <= 8));
  if Mode = 4 then
  begin
    C.SetItemCaption(1, DSText($1853));               { 'Abschicken' }
    C.Enable(1, False);
  end;
  UpdateButtons;
  ShowTreasury;
  { the grids scale with the window (designed for 440 x 401 pixels) }
  if PSmallInt(@D.Data[$2A])^ < 1 then
    SX := RC($81, 0, 0)
  else
    SX := R48Div(R48FromLong(PSmallInt(@D.Data[$2A])^), RC($89, 0, $5C00));
  PReal48(@D.Data[TdScaleX])^ := SX;
  if PSmallInt(@D.Data[$2C])^ < 1 then
    SY := RC($81, 0, 0)
  else
    SY := R48Div(R48FromLong(PSmallInt(@D.Data[$2C])^), RC($89, 0, $4880));
  PReal48(@D.Data[TdScaleY])^ := SY;
  Place(TdHeerX, RC($86, 0, $2000), SX);              { 40 }
  Place(TdHeerY, RC($87, 0, $6C00), SY);              { 118 }
  Place(TdGardeX, RC($89, 0, $0E00), SX);             { 284 }
  Place(TdGardeY, RC($88, 0, $0F00), SY);             { 143 }
  Place(TdInfoX, RC($86, 0, $2800), SX);              { 42 }
  Place(TdInfoY, RC($85, 0, $7000), SY);              { 30 }
end;

function TTroopDlg.CanClose: Boolean;
var
  E: TDialog;
begin
  Result := False;
  case Mode of
    0, 6:
      begin
        Result := Me^.Army2Count < 9;
        if not Result then
        begin
          E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($185E))]);   { MUSTDISMISSDLG }
          UI.Execute(E);
          UI.Done(E, 1);
        end;
      end;
    1, 2:
      if (Me^.Army1Count = 0) and (Me^.Army2Count <> 0) then
      begin
        E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($186D))]);     { NOHEERDLG }
        UI.Execute(E);
        UI.Done(E, 1);
        Result := False;
      end
      else
        Result := True;
    3:
      if (Me^.Army1Count = 0) or (Me^.Army2Count <> 0) or (Me^.ArmyAway <> 0) then
        Result := True
      else
      begin
        { an empty Garde while the Heer is at home: the Miliz defends }
        E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($1877))]);     { MILIZDLG }
        Result := UI.Execute(E) = 1;
        UI.Done(E, 1);
      end;
    4, 5: Result := True;
  end;
end;

procedure TTroopDlg.UpdateButtons;
var
  P: PPlayer;
  U: PUnit;
  K: LongInt;

  { 102 Entlassen, the gift's OK, 107 Sold, 103 Spezial for one selected unit }
  procedure OneUnit(Hero: Boolean);
  begin
    C.Enable(102, not Hero);
    if Mode = 4 then
      C.Enable(1, PByte(@DS.UnitCanDesert)[ShortInt(U^.UnitType)] <> 0);
    C.Enable(107, (Mode = 0) and (U^.Pay > 0) and (U^.UnconsciousRounds > 0));
    K := FiefSize(P^, U^);
    { a fief for a knight of rank >= 2 who still gets pay, if the free
      land suffices; a Knappe of rank >= 2 can be knighted; anything in the
      census editor }
    C.Enable(103, ((PByte(@DS.UnitKnight)[ShortInt(U^.UnitType)] <> 0) and (U^.Level >= 2) and
      (U^.Pay > 0) and (LongInt(P^.Land - P^.LandUsed) >= K)) or
      ((U^.UnitType = $22) and (U^.Level >= 2)) or (Mode = 6));
    C.Enable(106, False);
  end;

begin
  P := Me;
  case D.Data[TdSelState] of
    0:
      begin
        C.SetItemCaption(101, DSText($1880));           { '<=>' }
        C.Enable(101, False);
        C.Enable(102, False);
        C.Enable(107, False);
        C.Enable(103, False);
        C.Enable(106, (P^.Army2Count <= 8) and (P^.ArmyAway = 0));
      end;
    4:
      begin
        U := HeerUnit(D.Data[TdHeerSel1]);
        C.SetItemCaption(101, DSText($1881));           { '=>' }
        C.Enable(101, (P^.Army2Count < 8) and (P^.ArmyAway = 0));
        OneUnit((U^.UnitType = 9) and (Mode <> 6));
      end;
    5:
      begin
        U := GardeUnit(D.Data[TdGardeSel1]);
        C.SetItemCaption(101, DSText($1884));           { '<=' }
        C.Enable(101, (P^.Army1Count < 8) and (P^.ArmyAway = 0));
        OneUnit(U^.UnitType = 9);                       { (a Held even in the census) }
      end;
    3, 1, 2:
      begin
        C.SetItemCaption(101, DSText($1880));
        if D.Data[TdSelState] = 3 then
          C.Enable(101, P^.ArmyAway = 0)
        else
          C.Enable(101, True);
        C.Enable(102, False);
        C.Enable(107, False);
        C.Enable(103, False);
        if Mode = 4 then
          C.Enable(1, False);
        C.Enable(106, False);
      end;
  end;
  C.Enable(104, (Mode in [0, 6]) and (P^.Army1Count < 8) and (P^.ArmyAway = 0));
  C.Enable(105, (Mode in [0, 6]) and (P^.Army2Count <= 8));
  if Mode = 5 then
  begin
    C.Enable(101, False);
    C.Enable(102, False);
    C.Enable(103, False);
    C.Enable(106, False);
  end;
  if Mode = 4 then
    C.Enable(102, False);
end;

procedure TTroopDlg.ShowTreasury;
begin
  if not (Mode in [0, 6]) then
    Exit;
  C.SetText(301, DSText($1888));                      { 'Taler:' }
  SetNumber(C, 203, Me^.Taler);
  C.SetText(302, DSText($188F));                      { 'Waffen:' }
  SetNumber(C, 204, Me^.Weapons);
  C.SetText(303, DSText($1897));                      { 'Sold:' }
  SetNumber(C, 205, ArmyPay(Me^));
end;

procedure TTroopDlg.UpdateSelState;
begin
  case CountSelected of
    0: D.Data[TdSelState] := 0;
    1:
      if D.Data[TdHeerSel1] = 0 then
        D.Data[TdSelState] := 5
      else
        D.Data[TdSelState] := 4;
    2:
      if D.Data[TdHeerSel1] = 0 then
        D.Data[TdSelState] := 2
      else if D.Data[TdHeerSel2] = 0 then
        D.Data[TdSelState] := 3
      else
        D.Data[TdSelState] := 1;
  end;
end;

function TTroopDlg.CountSelected: Byte;
var
  N: Byte;
begin
  N := 0;
  if D.Data[TdHeerSel1] <> 0 then
  begin
    N := 1;
    if D.Data[TdHeerSel2] <> 0 then
      N := 2;
  end;
  if D.Data[TdGardeSel1] <> 0 then
  begin
    Inc(N);
    if D.Data[TdGardeSel2] <> 0 then
      Inc(N);
  end;
  Result := N;
end;

{ (de)select a unit: at most two units at a time }
procedure TTroopDlg.ToggleHeerUnit(Slot: Byte);
var
  Changed: Boolean;
begin
  Changed := False;
  if (D.Data[TdHeerSel1] = Slot) or (D.Data[TdHeerSel2] = Slot) then
  begin
    if D.Data[TdHeerSel1] = Slot then
      D.Data[TdHeerSel1] := D.Data[TdHeerSel2];
    D.Data[TdHeerSel2] := 0;
    Changed := True;
  end
  else if CountSelected < 2 then
  begin
    if D.Data[TdHeerSel1] = 0 then
    begin
      D.Data[TdHeerSel1] := Slot;
      Changed := True;
    end
    else if D.Data[TdHeerSel2] = 0 then
    begin
      D.Data[TdHeerSel2] := Slot;
      Changed := True;
    end;
  end;
  if Changed then
  begin
    DrawHeer;
    UpdateSelState;
    UpdateButtons;
  end;
end;

procedure TTroopDlg.ToggleGardeUnit(Slot: Byte);
var
  Changed: Boolean;
begin
  Changed := False;
  if (D.Data[TdGardeSel1] = Slot) or (D.Data[TdGardeSel2] = Slot) then
  begin
    if D.Data[TdGardeSel1] = Slot then
      D.Data[TdGardeSel1] := D.Data[TdGardeSel2];
    D.Data[TdGardeSel2] := 0;
    Changed := True;
  end
  else if CountSelected < 2 then
  begin
    if D.Data[TdGardeSel1] = 0 then
    begin
      D.Data[TdGardeSel1] := Slot;
      Changed := True;
    end
    else if D.Data[TdGardeSel2] = 0 then
    begin
      D.Data[TdGardeSel2] := Slot;
      Changed := True;
    end;
  end;
  if Changed then
  begin
    DrawGarde;
    UpdateSelState;
    UpdateButtons;
  end;
end;

{ the painted grids (GetDC; Draw*(DC, Self); ReleaseDC): the UI repaints }
procedure TTroopDlg.DrawHeer;
begin
  UI.Call('TroopDlg_DrawHeer', [AWord(0), APtr(D)]);
end;

procedure TTroopDlg.DrawGarde;
begin
  UI.Call('TroopDlg_DrawGarde', [AWord(0), APtr(D)]);
end;

{ 101: one unit to the other army, or exchange the two selected units }
procedure TTroopDlg.Swap;
var
  P: PPlayer;
  Tmp: TUnit;
  Heer, Garde: Boolean;
begin
  P := Me;
  Heer := False;
  Garde := False;
  case D.Data[TdSelState] of
    4:
      begin
        P^.Army2Count := Byte(P^.Army2Count + 1);
        Move(HeerUnit(D.Data[TdHeerSel1])^, GardeUnit(P^.Army2Count)^, SizeOf(TUnit));
        RemoveArmy1Unit(P^, D.Data[TdHeerSel1]);
        D.Data[TdHeerSel1] := 0;
        Heer := True;
        Garde := True;
      end;
    5:
      begin
        P^.Army1Count := Byte(P^.Army1Count + 1);
        Move(GardeUnit(D.Data[TdGardeSel1])^, HeerUnit(P^.Army1Count)^, SizeOf(TUnit));
        RemoveArmy2Unit(P^, D.Data[TdGardeSel1]);
        D.Data[TdGardeSel1] := 0;
        Heer := True;
        Garde := True;
      end;
    1:
      begin
        Move(HeerUnit(D.Data[TdHeerSel1])^, Tmp, SizeOf(TUnit));
        Move(HeerUnit(D.Data[TdHeerSel2])^, HeerUnit(D.Data[TdHeerSel1])^, SizeOf(TUnit));
        Move(Tmp, HeerUnit(D.Data[TdHeerSel2])^, SizeOf(TUnit));
        D.Data[TdHeerSel1] := 0;
        D.Data[TdHeerSel2] := 0;
        Heer := True;
      end;
    2:
      begin
        Move(GardeUnit(D.Data[TdGardeSel1])^, Tmp, SizeOf(TUnit));
        Move(GardeUnit(D.Data[TdGardeSel2])^, GardeUnit(D.Data[TdGardeSel1])^, SizeOf(TUnit));
        Move(Tmp, GardeUnit(D.Data[TdGardeSel2])^, SizeOf(TUnit));
        D.Data[TdGardeSel1] := 0;
        D.Data[TdGardeSel2] := 0;
        Garde := True;
      end;
    3:
      begin
        Move(HeerUnit(D.Data[TdHeerSel1])^, Tmp, SizeOf(TUnit));
        Move(GardeUnit(D.Data[TdGardeSel1])^, HeerUnit(D.Data[TdHeerSel1])^, SizeOf(TUnit));
        Move(Tmp, GardeUnit(D.Data[TdGardeSel1])^, SizeOf(TUnit));
        D.Data[TdHeerSel1] := 0;
        D.Data[TdGardeSel1] := 0;
        Heer := True;
        Garde := True;
      end;
  end;
  if Heer then
    DrawHeer;
  if Garde then
    DrawGarde;
  UpdateSelState;
  UpdateButtons;
end;

{ 102 Entlassen: the unit's weapons go back to the stock }
procedure TTroopDlg.Dismiss;
var
  P: PPlayer;
  Heer: Boolean;
begin
  P := Me;
  Heer := D.Data[TdHeerSel1] <> 0;
  if Heer then
  begin
    AddGoodsCapped(P^, 4, PByte(@DS.UnitWeapons)[ShortInt(HeerUnit(D.Data[TdHeerSel1])^.UnitType)]);
    RemoveArmy1Unit(P^, D.Data[TdHeerSel1]);
    D.Data[TdHeerSel1] := 0;
  end
  else
  begin
    AddGoodsCapped(P^, 4, PByte(@DS.UnitWeapons)[ShortInt(GardeUnit(D.Data[TdGardeSel1])^.UnitType)]);
    RemoveArmy2Unit(P^, D.Data[TdGardeSel1]);
    D.Data[TdGardeSel1] := 0;
  end;
  if Heer then
    DrawHeer
  else
    DrawGarde;
  P^.UnitsGivenOrDismissed := SmallInt(P^.UnitsGivenOrDismissed + 1);
  UpdateSelState;
  UpdateButtons;
  ShowTreasury;
end;

{ 103 Spezial: the census editor's unit editor, knighting a Knappe, or a
  fief for a knight }
procedure TTroopDlg.Special;
var
  P: PPlayer;
  U: PUnit;
  E: TDialog;
  K: LongInt;
  Buf: array[0..151] of Char;
  Gains: THeroGains;
  L: TLandLoss;
begin
  P := Me;
  if D.Data[TdHeerSel1] <> 0 then
    U := HeerUnit(D.Data[TdHeerSel1])
  else
    U := GardeUnit(D.Data[TdGardeSel1]);
  if Mode = 6 then
  begin
    UI.Call('Do_UnitEditDlg', [APtr(D), APtr(P), APtr(U)]);     { UNITEDITDLG }
    Exit;
  end;
  if U^.UnitType = $22 then
  begin
    E := UI.Dialog('KaiserDlg', $3364, [APtr(D), AStr(DSText($189E))]);       { RITTERSCHLAGDLG }
    if UI.Execute(E) = 1 then
      KnightSquire(P^, U^);
    UI.Done(E, 1);
    DrawHeer;
    DrawGarde;
  end
  else
  begin
    K := FiefSize(P^, U^);
    IntToPChar(Buf, K);
    StrCat(Buf, DSText($18AE));                       { ' Hufen werden die ' }
    StrCat(Buf, PChar(@U^.Name));
    StrCat(Buf, DSText($18C1));                       { ' zu Lehnsnehmern' }
    E := UI.Dialog('HelpMessageDlg', $341A, [APtr(D), AStr(DSText($18D2)), AStr(Buf), AWord($14)]);
    if UI.Execute(E) = 1 then
    begin
      { the fief: land without harvest, the knight serves without pay }
      P^.LandUsed := LongInt(P^.LandUsed + K);
      U^.Pay := 0;
      FillChar(Gains, SizeOf(Gains), 0);
      UnitGainExperience(U^, Gains, 24, 9);
      GainFame(P^.Fame, 2);
      FillChar(L, SizeOf(L), 0);
      BuildingsLostForLand(P^, L);
      if L.Total > 0 then
        UI.Call('ShowBuildingLossDlg', [APtr(D), AStr(DSText($18DE)), ARec(@L, SizeOf(L)), AByte(0)]);
    end;
    UI.Done(E, 1);
  end;
  UpdateButtons;
  ShowTreasury;
end;

{ 104 / 105 Rekrutieren (RecruitDialog 1040:5108; free in the census) }
procedure TTroopDlg.Recruit(Army: Byte);
begin
  UI.Call('RecruitDialog', [APtr(D), APtr(Me), AByte(Army), AByte(Ord(Mode = 6))]);
  if Army = 1 then
    DrawHeer
  else
    DrawGarde;
  UpdateButtons;
  ShowTreasury;
end;

{ 106 Alle tauschen: Heer and Garde change places (the selection stays) }
procedure TTroopDlg.SwapAll;
begin
  SwapArmies(Me^);
  DrawHeer;
  DrawGarde;
  UpdateButtons;
end;

{ 107 Sold (SOLDDLG, ShowPayDlg 1040:00f7) }
procedure TTroopDlg.Pay;
var
  U: PUnit;
begin
  if D.Data[TdHeerSel1] <> 0 then
    U := HeerUnit(D.Data[TdHeerSel1])
  else
    U := GardeUnit(D.Data[TdGardeSel1]);
  UI.Call('ShowPayDlg', [APtr(D), APtr(U)]);
  UpdateButtons;
end;

function TTroopDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    101: Swap;
    102: Dismiss;
    103: Special;
    104: Recruit(1);
    105: Recruit(2);
    106: SwapAll;
    107: Pay;
  else
    Result := False;
  end;
end;

{ WMLButtonDown (1038:8fc8): a click into the Heer grid (2 columns x 5 rows
  of 32 pixels) or the Garde grid (3 x 3 inside the wall) toggles the unit
  of that cell; not when viewing another player }
function TTroopDlg.Mouse(X, Y: SmallInt): Boolean;
var
  Col, Row: SmallInt;
  Slot: Byte;
begin
  Result := True;
  if Mode = 5 then
    Exit;
  if Within(X, W(TdHeerX)^, Word(W(TdHeerX)^ + $40)) and
     Within(Y, W(TdHeerY)^, Word(W(TdHeerY)^ + $A0)) then
  begin
    Col := SmallInt((LongInt(X) - W(TdHeerX)^) div 32);
    Row := SmallInt((LongInt(Y) - W(TdHeerY)^) div 32);
    Slot := PByte(@DS)[Word($105E + Word(Col * 5 + Row))];
    if Slot <= Me^.Army1Count then
      ToggleHeerUnit(Slot);
    Exit;
  end;
  if Within(X, W(TdGardeX)^, Word(W(TdGardeX)^ + $60)) and
     Within(Y, W(TdGardeY)^, Word(W(TdGardeY)^ + $68)) then
  begin
    { (the 8 pixels of wall count as the first column / row) }
    Col := SmallInt((LongInt(X) - W(TdGardeX)^ - 8) div 32);
    Row := SmallInt((LongInt(Y) - W(TdGardeY)^ - 8) div 32);
    Slot := PByte(@DS)[Word($107C + Word(Col * 3 + Row))];
    if Slot <= Me^.Army2Count then
      ToggleGardeUnit(Slot);
  end;
end;

{ WMMouseMove (1038:91ff): the unit under the mouse gets the info card
  (TroopDlg_DrawUnitInfo); leaving the units clears it }
function TTroopDlg.MouseMove(X, Y: SmallInt): Boolean;
var
  Changed, OnUnit: Boolean;
  Slot: Byte;
begin
  Result := True;
  if Mode = 5 then
    Exit;
  Changed := False;
  OnUnit := False;
  if Within(X, W(TdHeerX)^, Word(W(TdHeerX)^ + $40)) and
     Within(Y, W(TdHeerY)^, Word(W(TdHeerY)^ + $A0)) then
  begin
    { (the original keeps the cell in the pixel variables, which the
      Garde test below then reads) }
    X := SmallInt((LongInt(X) - W(TdHeerX)^) div 32);
    Y := SmallInt((LongInt(Y) - W(TdHeerY)^) div 32);
    Slot := PByte(@DS)[Word($105E + Word(X * 5 + Y))];
    if (Slot > Me^.Army1Count) or ((Slot = D.Data[TdHoverSlot]) and (D.Data[TdHoverArmy] = 1)) then
      OnUnit := Slot <= Me^.Army1Count
    else
    begin
      D.Data[TdHoverSlot] := Slot;
      D.Data[TdHoverArmy] := 1;
      Changed := True;
    end;
  end;
  if Within(X, Word(W(TdGardeX)^ + 8), Word(W(TdGardeX)^ + $68)) and
     Within(Y, Word(W(TdGardeY)^ + 8), Word(W(TdGardeY)^ + $68)) then
  begin
    Slot := PByte(@DS)[Word($107C + Word(SmallInt((LongInt(X) - W(TdGardeX)^ - 8) div 32) * 3 +
      SmallInt((LongInt(Y) - W(TdGardeY)^ - 8) div 32)))];
    if (Slot > Me^.Army2Count) or ((Slot = D.Data[TdHoverSlot]) and (D.Data[TdHoverArmy] = 2)) then
      OnUnit := Slot <= Me^.Army2Count
    else
    begin
      D.Data[TdHoverSlot] := Slot;
      D.Data[TdHoverArmy] := 2;
      Changed := True;
    end;
  end;
  if not Changed and not OnUnit and (D.Data[TdHoverSlot] <> 0) then
  begin
    D.Data[TdHoverSlot] := 0;
    D.Data[TdHoverArmy] := 0;
    Changed := True;
  end;
  if Changed then
    UI.Call('TroopDlg_DrawUnitInfo', [AWord(0), APtr(D)]);
end;

initialization
  RegisterDialogLogic('TroopDlg', TTroopDlg);
end.
