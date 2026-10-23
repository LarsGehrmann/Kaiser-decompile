{ Geheimdienst (segment 8, 1038:0002 .. 1038:1a12): the intelligence
  dialog GEHEIMDLG. Four dossier columns (players page .. page+3) with title,
  name, country, spell, fame, population, land, Landausbau, palace,
  cathedral, net income, treasury, army class, heavy artillery, hero,
  agents, trade volume and peace; the buttons look at an army
  (Do_TruppenAufstellen), strike with the agents (SabotageStrike) or open
  the sabotage budget (own column). Works on a copy of all players that is
  taken over when the dialog ends. Tested like the dialogs of Actions. }
unit Intel;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI, Actions;

{ Geheimdienst (1038:0002): GEHEIMDLG on a copy of all players; the copy is
  taken over at the end (sabotage from the dialog changes it) }
procedure Do_Geheimdienst(Parent: Pointer; var Players: TPlayers; NumPlayers, Me: Byte;
  Year: Word);

type
  { GEHEIMDLG (VMT DS:10ca, 1038:0060, a HelpDlg): all players at +0x34,
    Me +0x4486, the number of players +0x4487, the first column's player
    (page) +0x4488, the year +0x4489, the year for the estimates +0x448b
    (0 with the spell Botschafter: exact values), per player: ArmyStrength
    +0x448d, net income and Taler rounded to 1000 +0x44b5 / +0x44dd, trade
    volume +0x4505, hero name +0x452d (25 bytes), heavy artillery +0x4627.
    Column j: statics 101+100j .. 117+100j, buttons 501+j (army), 701+j
    (agents / strike); 601 / 602 page back / on }
  TGeheimDlg = class(TDialogLogic)
  public
    function Players: PPlayers;
    function Me: PPlayer;
    function L(Off: Integer): PLongInt;
    procedure Init; override;
    procedure SetupWindow; override;
    procedure ShowPage;
    function Handle(Id: SmallInt): Boolean; override;
  end;

implementation

const
  ColStatics: array[0..15] of SmallInt =       { the order ShowPage clears them }
    (102, 103, 101, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 116, 117);

procedure Do_Geheimdienst(Parent: Pointer; var Players: TPlayers; NumPlayers, Me: Byte;
  Year: Word);
var
  D: TDialog;
  I, Last: Byte;
begin
  D := UI.Dialog('GeheimDlg', $10CA, [APtr(Parent), AStr(DSText($1122)), APtr(@Players),
    AByte(NumPlayers), AByte(Me), AWord(Year)]);
  UI.Execute(D);
  if NumPlayers > 0 then
  begin
    Last := Byte(NumPlayers - 1);
    I := 0;
    repeat
      Move(D.Data[$34 + I * PlayerSize], Players[I], PlayerSize);
      if I = Last then
        Break;
      Inc(I);
    until False;
  end;
  UI.Done(D, 1);
end;

function TGeheimDlg.Players: PPlayers;
begin
  Result := PPlayers(@D.Data[$34]);
end;

function TGeheimDlg.Me: PPlayer;
begin
  Result := @Players^[D.Data[$4486]];
end;

function TGeheimDlg.L(Off: Integer): PLongInt;
begin
  Result := PLongInt(@D.Data[Off]);
end;

{ the rest of the constructor: the players, the precomputed values }
procedure TGeheimDlg.Init;
var
  I, Last, N: Byte;
  V: LongInt;
  P: PPlayer;
  Hero: PUnit;
  Name: PChar;
  Buf: array[0..31] of Char;
begin
  N := Byte(Args[3].V);
  D.Data[$4487] := N;
  D.Data[$4486] := Byte(Args[4].V);
  PWord(@D.Data[$4489])^ := Word(Args[5].V);
  if N > 0 then
  begin
    Last := Byte(N - 1);
    I := 0;
    repeat
      Move(PPlayers(Args[2].P)^[I], D.Data[$34 + I * PlayerSize], PlayerSize);
      if I = Last then
        Break;
      Inc(I);
    until False;
  end;
  Last := Byte(N - 1);
  I := 0;
  repeat
    P := @Players^[I];
    { the trade volume with a trade partner, rounded to 100 / 500 }
    if PByte(@Me^.TradeAgreement)[I] = 0 then
      L($4505 + I * 4)^ := 0
    else
    begin
      V := LongInt(LongInt(P^.Markets * 155) + LongInt(P^.Mills * 330)) div (N + 6);
      if V < 1000 then
        V := (V div 100) * 100
      else
        V := (V div 500) * 500;
      L($4505 + I * 4)^ := V;
    end;
    D.Data[$4627 + I] := Ord(ArtilleryClass(P^, 1) = 2);
    L($448D + I * 4)^ := ArmyStrength(P^, 1);
    L($44B5 + I * 4)^ := (P^.NetIncome div 1000) * 1000;
    L($44DD + I * 4)^ := (P^.Taler div 1000) * 1000;
    Name := PChar(@D.Data[$452D + I * 25]);
    Hero := nil;
    if FindHero(P^, Hero, 1) then
    begin
      StrCopy(Name, PChar(@Hero^.Name));
      if Hero^.Level > 6 then
      begin
        IntToPChar(Buf, Hero^.Level - 6);
        StrCat(Name, DSText($112C));                   { ' (+' }
        StrCat(Name, Buf);
        StrCat(Name, DSText($1130));                   { ')' }
      end;
    end
    else
      StrCopy(Name, DSText($1132));                    { '-' }
    if I = Last then
      Break;
    Inc(I);
  until False;
  if Me^.Spell = 1 then                                { Botschafter: exact values }
    PWord(@D.Data[$448B])^ := 0
  else
    PWord(@D.Data[$448B])^ := PWord(@D.Data[$4489])^;
  D.Data[$4488] := 0;
end;

procedure TGeheimDlg.SetupWindow;
begin
  ShowPage;
end;

procedure TGeheimDlg.ShowPage;
var
  I, J, Page, Last, MeIdx: Byte;
  K: Integer;
  Y: Word;
  V: LongInt;
  P, M: PPlayer;
  Buf: array[0..81] of Char;
  Buf2: array[0..81] of Char;

  { the exact value or the estimate (times Me's year factor) }
  function Estimate(Exact: Boolean; X: LongInt): LongInt;
  begin
    if Exact then
      Result := X
    else
      Result := R48Round(R48Mul(R48FromLong(X), M^.YearFactorQ));
  end;

begin
  Page := D.Data[$4488];
  MeIdx := D.Data[$4486];
  M := Me;
  Y := PWord(@D.Data[$448B])^;
  Last := Byte(Page + 3);
  if Page <= Last then
  begin
    I := Page;
    repeat
      J := Byte(I - Page);
      if SmallInt(I) > SmallInt(D.Data[$4487]) - 1 then
      begin                                            { an empty column }
        for K := 0 to High(ColStatics) do
          C.SetText(ColStatics[K] + 100 * J, DSText($116A));
        C.Show(501 + J, 0);
        C.Show(701 + J, 0);
      end
      else
      begin
        P := @Players^[I];
        if P^.IsFemale = 0 then
          C.SetText(101 + 100 * J, DSText($4556 + P^.Title * 25))
        else
          C.SetText(101 + 100 * J, DSText($466A + P^.Title * 25));
        C.SetText(102 + 100 * J, PChar(@P^.Name));
        StrCopy(Buf, DSText($116B));                   { 'von ' }
        StrCat(Buf, DSText($63A8 + P^.Country * 25));
        C.SetText(103 + 100 * J, Buf);
        if P^.Spell <> 0 then
          C.SetText(104 + 100 * J, DSText($497C + P^.Spell * 25))
        else
          C.SetText(104 + 100 * J, DSText($116A));
        FameText(Buf, Byte(P^.Fame));
        C.SetText(105 + 100 * J, Buf);
        { population: exact in odd years (from the player's index on) }
        V := Estimate((Y = 0) or (I = MeIdx) or (Word(I + Y) mod 2 = 1), P^.Population);
        if V > 1999 then
          V := LongInt((V div 1000 + 1) * 1000)
        else
          V := LongInt((V div 200 + 1) * 200);
        IntToPChar(Buf, V);
        C.SetText(106 + 100 * J, Buf);
        { land: exact in the other years }
        V := Estimate((Y = 0) or (I = MeIdx) or (Word(I + Y) mod 2 = 0), P^.Land);
        RealmName(Buf, V);
        C.SetText(107 + 100 * J, Buf);
        { Landausbau: markets or mills (the more) per 1000 Hufen, in % }
        V := MaxLong(P^.Markets, P^.Mills);
        if P^.Land <> 0 then
          V := LongInt(Int64(V) * 100000) div P^.Land
        else
          V := 0;                       { the original: division by zero (runtime error 200) }
        IntToPChar(Buf, (V div 10) * 10);
        StrCat(Buf, DSText($1170));                    { '%' }
        C.SetText(108 + 100 * J, Buf);
        BuildingProgressText(Buf, P^.PalaceParts);
        C.SetText(109 + 100 * J, Buf);
        BuildingProgressText(Buf, P^.CathedralParts);
        C.SetText(110 + 100 * J, Buf);
        V := Estimate((Y = 0) or (I = MeIdx) or (Word(I + Y) mod 3 = 1), L($44B5 + I * 4)^);
        MagnitudeText(Buf, V);
        C.SetText(111 + 100 * J, Buf);
        V := Estimate((Y = 0) or (I = MeIdx) or (Word(I + Y) mod 3 = 2), L($44DD + I * 4)^);
        MagnitudeText(Buf, V);
        C.SetText(112 + 100 * J, Buf);
        { the army's class }
        C.Show(501 + J, 5);
        V := L($448D + I * 4)^;
        if V < 30 then
          StrCopy(Buf, DSText($1172))                  { baeuerlich }
        else if V < 60 then
          StrCopy(Buf, DSText($117C))                  { tuechtig }
        else if V < 100 then
          StrCopy(Buf, DSText($1184))                  { fuerstlich }
        else
          StrCopy(Buf, DSText($118E));                 { koeniglich }
        C.SetItemCaption(501 + J, Buf);
        C.Enable(501 + J, (I = MeIdx) or (M^.Spell = 1));
        C.SetText(113 + 100 * J, DSText($1134 + ShortInt(D.Data[$4627 + I]) * 25));
        C.SetText(114 + 100 * J, PChar(@D.Data[$452D + I * 25]));
        C.Show(701 + J, 5);
        if I = MeIdx then
        begin
          C.Enable(701 + J, True);
          C.SetItemCaption(701 + J, DSText($1198));    { '$': the sabotage budget }
          C.SetText(116 + 100 * J, DSText($119A));
          C.SetText(117 + 100 * J, DSText($119A));
        end
        else
        begin
          if PByte(@M^.SabotageAgents)[I] > 0 then
          begin
            C.Enable(701 + J, True);
            IntToPChar(Buf, PByte(@M^.SabotageAgents)[I]);
            C.SetItemCaption(701 + J, Buf);
          end
          else
          begin
            C.Enable(701 + J, False);
            C.SetItemCaption(701 + J, DSText($119A));
          end;
          if PByte(@M^.TradeAgreement)[I] <> 0 then
            IntToPChar(Buf, L($4505 + I * 4)^)
          else
            StrCopy(Buf, DSText($1134));
          C.SetText(116 + 100 * J, Buf);
          if ShortInt(PByte(@M^.PeaceYears)[I]) > 0 then
          begin
            StrCopy(Buf, DSText($119C));               { 'bis ' }
            IntToPChar(Buf2, LongInt(Word(PWord(@D.Data[$4489])^ + $578)) +
              ShortInt(PByte(@M^.PeaceYears)[I]) - 1);
            StrCat(Buf, Buf2);
          end
          else
            StrCopy(Buf, DSText($1134));
          C.SetText(117 + 100 * J, Buf);
        end;
      end;
      if I = Last then
        Break;
      Inc(I);
    until False;
  end;
  C.Enable(602, SmallInt(Page) + 3 < SmallInt(D.Data[$4487]) - 1);
  C.Enable(601, Page > 0);
end;

function TGeheimDlg.Handle(Id: SmallInt): Boolean;
var
  K: Integer;
  Mode: Byte;
begin
  Result := True;
  case Id of
    601:
      begin
        Dec(D.Data[$4488]);
        ShowPage;
      end;
    602:
      begin
        Inc(D.Data[$4488]);
        ShowPage;
      end;
    501..504:                                          { look at the army }
      begin
        K := D.Data[$4488] + (Id - 501);
        if K = D.Data[$4486] then
          Mode := 0
        else
          Mode := 5;
        UI.Call('Do_TruppenAufstellen', [APtr(D), APtr(@D.Data[$34 + Word(K * PlayerSize)]),
          AByte(Mode)]);
      end;
    701..704:                                          { the agents }
      begin
        K := D.Data[$4488] + (Id - 701);
        if K = D.Data[$4486] then
          Do_Sabotage(D, Players^, D.Data[$4486], D.Data[$4487])
        else
          SabotageStrike(D, Players^, D.Data[$4486], D.Data[$4487], Byte(K));
        ShowPage;
      end;
  else
    Result := False;
  end;
end;

initialization
  RegisterDialogLogic('GeheimDlg', TGeheimDlg);
end.
