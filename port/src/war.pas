{ War: a battle from its setup to its aftermath (segment 4, 1018:xxxx) and
  the winner's choices after it (segment 6, 1028:xxxx: plunder, burning,
  massacre, mercy, the losses of a retreat). The battle itself is the
  battle window (unit Battle); its modal run is the UI call 'Battle_Execute'
  (the GUI plays it, see Battle.WMTimer / WMLButtonDown). }
unit War;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI, Turn, Ai, Battle;

type
  { the battle info block (0x192 bytes, the e-mail extra block) }
  TBattleInfo = packed record
    City: Byte;                { +0x00 city battle }
    Second: Byte;              { +0x01 the march on the capital }
    NoArmy: Byte;              { +0x02 the defender has no units at all }
    Winter: Byte;              { +0x03 (e-mail) }
    Pad4: Byte;
    AttStrength: LongInt;      { +0x05 ArmyStrength(attacker) }
    DefStrength: LongInt;      { +0x09 }
    AttIdx, DefIdx: Byte;      { +0x0d / +0x0e }
    Rest: array[$0F..$191] of Byte;   { e-mail resume data }
  end;

  { the results of a battle (window +0xdd8, 0x37 bytes); the first 44 bytes
    are a TLandLoss (buildings destroyed or handed over) }
  TBattleResults = packed record
    Loss: TLandLoss;           { +0x00 total, +0x04 civilians killed, +0x08.. buildings }
    Land: LongInt;             { +0x2c land taken }
    Taler: LongInt;            { +0x30 Taler taken }
    Choice: Byte;              { +0x34 the winner's choice (10..13) }
    Killed0, Killed1: Byte;    { +0x35 / +0x36 units lost by side 0 / 1 }
  end;

{ segment 6 }
function AskBattlefield(Parent: Pointer; var Att, Def: TPlayer; AttIdx, DefIdx: Byte): Boolean;  { 1028:0002 }
procedure RetreatLosses(Parent: Pointer; var P: TPlayer);       { 1028:011c }
procedure Massacre(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);  { 1028:020a }
procedure ShowMassacre(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);  { 1028:038e }
procedure BurnBuildings(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);  { 1028:057e }
procedure ShowBurnResult(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);  { 1028:0996 }
procedure PlunderTalerAndLand(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);  { 1028:09c8 }
procedure ShowPlunderResult(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);  { 1028:0b6b }
procedure Ai_PlunderChoice(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);  { 1028:0d46 }
procedure PlunderDialog(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);  { 1028:0eaf }

{ segment 4 }
procedure BattleSetup(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  AttIdx, DefIdx, Second: Byte);                                 { 1018:0225 }
procedure BattleFameAndXp(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  Code: Byte);                                                   { 1018:094a }
procedure BattleAftermath(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  var R: TBattleResults; Code: Byte);                            { 1018:0664 }
{ 1 won (city), 3 won in the field (the caller may march on the capital),
  2 lost }
function Battle(Parent: Pointer; var Att, Def: TPlayer; AttIdx, DefIdx, Second: Byte): Byte;  { 1018:0558 }
{ the marauders (mode 1) or the Lindwurm (mode 2) against P; 1 = won }
function FightRaiders(Parent: Pointer; var P: TPlayer; Unused, Mode: Byte): Byte;  { 1018:0c5f }

{ a battle window with room behind it: a human's attack on a tree reaches
  far past the window (Battle.WMLButtonDown) }
type
  TBattleArena = packed record
    W: TBattleWnd;
    Spill: array[0..$7FFF] of Byte;
  end;
  PBattleArena = ^TBattleArena;

implementation

{ dialog helpers }
procedure ShowDlg(Parent: Pointer; NameOfs: Word);
var
  D: TDialog;
begin
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText(NameOfs))]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure ShowMessage(Parent: Pointer; NameOfs: Word; Text: PChar);
var
  D: TDialog;
begin
  D := UI.Dialog('MessageDlg', $33C6, [APtr(Parent), AStr(DSText(NameOfs)), AStr(Text)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ KAPUTTDLG / VERLUSTDLG (the emulator does not see bytes 4..7 of the loss
  record, so they are logged as 0) }
procedure ShowLoss(Parent: Pointer; NameOfs: Word; const L: TLandLoss; Flag: Byte);
var
  C: TLandLoss;
begin
  C := L;
  C.Unused4 := 0;
  UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText(NameOfs)), ARec(@C, SizeOf(C)),
    AByte(Flag)]);
end;

{ A * B div D with the original's 32-bit product (it wraps) }
function MulDiv(A, B, D: LongInt): LongInt; inline;
begin
  Result := LongInt(Int64(A) * B) div D;
end;

procedure PutLong(D: TDialog; Off: Word; V: LongInt);
begin
  Move(V, D.Data[Off], 4);
end;

function AskBattlefield(Parent: Pointer; var Att, Def: TPlayer; AttIdx, DefIdx: Byte): Boolean;
var
  AttTitle, DefTitle: array[0..65] of Char;
  D: TDialog;
  NameOfs: Word;
begin
  { KRIEGSERNADLG / ..LA.. / ..HA.. by the attacker's artillery: True =
    the field, False = the city (OK); the field needs an army at home }
  FillChar(AttTitle, SizeOf(AttTitle), 0);
  FillChar(DefTitle, SizeOf(DefTitle), 0);
  FormatPlayerTitle(Att, AttTitle, 0, 0);
  FormatPlayerTitle(Def, DefTitle, 0, 0);
  case ArtilleryClass(Att, 0) of
    0: NameOfs := $0DB8;
    1: NameOfs := $0DC6;
  else
    NameOfs := $0DD4;
  end;
  D := UI.Dialog('HelpChoice2Dlg', $34C6, [APtr(Parent), AStr(DSText(NameOfs)), AStr(DefTitle),
    AStr(AttTitle), AWord($7C)]);
  if not HasAnyUnits(Def) or (Def.ArmyAway <> 0) then
    UI.Call('DisableButton2', [APtr(D)]);
  Result := UI.Execute(D) <> 1;
  UI.Done(D, 1);
end;

procedure RetreatLosses(Parent: Pointer; var P: TPlayer);
var
  I, Last, Lost: Byte;
  Buf: array[0..13] of Char;
begin
  { each Heer unit is lost with 1/5, except the Held, units with Fortune
    and all with the spell Karma; (a removed unit's successor is skipped,
    the loop runs on to the old count) }
  Lost := 0;
  Last := P.Army1Count;
  for I := 1 to Last do
    if (Random(5) = 0) and (P.Army1[I].UnitType <> 9) and (P.Spell <> 10) and
       (P.Army1[I].Ability <> 9) then
    begin
      Inc(Lost);
      RemoveArmy1Unit(P, I);
    end;
  P.OwnUnitsKilled := SmallInt(P.OwnUnitsKilled + Lost);
  FillChar(Buf, SizeOf(Buf), 0);
  if Lost > 0 then
    IntToPChar(Buf, Lost)
  else
    StrCopy(Buf, DSText($0DE2));                       { keine }
  ShowMessage(Parent, $0DE8, Buf);                       { FLUCHTDLG }
end;

procedure Massacre(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);
begin
  { killed (+4) and deported to the winner (+0) }
  if City <> 0 then
  begin
    R.Loss.Unused4 := MulDiv(Random(15) + 10, Loser.Population, 100);
    R.Loss.Total := MulDiv(Random(5) + 5, Loser.Population, 100);
  end
  else
  begin
    R.Loss.Unused4 := MulDiv(Random(5) + 1, Loser.Population, 100);
    R.Loss.Total := MulDiv(Random(5) + 1, Loser.Population, 100);
  end;
  if LongInt(Loser.Population - R.Loss.Unused4) < 50 then
    R.Loss.Unused4 := Loser.Population - 50;
  Loser.Population := Loser.Population - R.Loss.Unused4;
  if LongInt(Loser.Population - R.Loss.Total) < 50 then
    R.Loss.Total := Loser.Population - 50;
  Loser.Population := Loser.Population - R.Loss.Total;
  Winner.Population := Winner.Population + R.Loss.Total;
end;

procedure ShowMassacre(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);
var
  D: TDialog;
begin
  { MASSAKERDLG for a human on either side; the winner's new epithet }
  if (Loser.CpuLevel <> 0) and (Winner.CpuLevel <> 0) then
    Exit;
  D := UI.Dialog('MassacreDlg', $0CEC, [APtr(Parent), AStr(DSText($0DF2))]);
  PutLong(D, $2E, R.Loss.Unused4);
  PutLong(D, $32, R.Loss.Total);
  if Winner.IsFemale = 0 then
    StrCopy(PChar(@D.Data[$42]), DSText($0DFE))
  else
    StrCopy(PChar(@D.Data[$42]), DSText($0E0E));
  StrCat(PChar(@D.Data[$42]), @DS.CountryNamesRt[Winner.Country]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

{ Counter += (Random(N) + K) * (Have - Counter) div 100 }
procedure Burn(var Counter: LongInt; Have: LongInt; N, K: Word);
begin
  Counter := LongInt(Counter + MulDiv(Random(N) + K, LongInt(Have - Counter), 100));
end;

procedure BurnBuildings(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);
begin
  { a share of every building type burns (counted in R, applied by
    PlunderDialog), and some of the people die }
  if City <> 0 then
  begin
    Burn(R.Loss.Markets, Loser.Markets, 30, 20);
    Burn(R.Loss.Mills, Loser.Mills, 20, 10);
    Burn(R.Loss.PalaceParts, Loser.PalaceParts, 30, 20);
    Burn(R.Loss.CathedralParts, Loser.CathedralParts, 30, 20);
    Burn(R.Loss.Granaries, Loser.Granaries, 40, 20);
    Burn(R.Loss.Warehouses, Loser.Warehouses, 30, 20);
    Burn(R.Loss.UniversityParts, Loser.UniversityParts, 30, 20);
    Burn(R.Loss.Taverns, Loser.Taverns, 20, 10);
    Burn(R.Loss.Smithies, Loser.Smithies, 30, 20);
    R.Loss.Unused4 := LongInt(R.Loss.Unused4 + MulDiv(Random(5) + 1, Loser.Population, 100));
  end
  else
  begin
    Burn(R.Loss.Markets, Loser.Markets, 10, 10);
    Burn(R.Loss.Mills, Loser.Mills, 20, 10);
    Burn(R.Loss.Granaries, Loser.Granaries, 20, 10);
    Burn(R.Loss.Warehouses, Loser.Warehouses, 10, 10);
    R.Loss.Unused4 := LongInt(R.Loss.Unused4 + MulDiv(Random(3) + 1, Loser.Population, 100));
  end;
  if LongInt(Loser.Population - R.Loss.Unused4) < 50 then
    R.Loss.Unused4 := Loser.Population - 50;
  R.Loss.Total := R.Loss.Unused4;
end;

procedure ShowBurnResult(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);
begin
  if (Loser.CpuLevel = 0) or (Winner.CpuLevel = 0) then
    ShowLoss(Parent, $0E20, R.Loss, 1);                  { BRANDDLG }
end;

procedure PlunderTalerAndLand(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);
var
  Pct: LongInt;
begin
  { Taler (city battles only) and, from a neighbour, land; the loser keeps
    at least 12000 }
  if (City <> 0) and (Loser.Taler > 0) then
    R.Taler := MulDiv(Random(20) + 5, Loser.Taler, 100)
  else
    R.Taler := 0;
  Winner.Taler := Winner.Taler + R.Taler;
  Winner.TotalWarLoot := Winner.TotalWarLoot + R.Taler;
  Loser.Taler := Loser.Taler - R.Taler;
  Loser.TotalWarLoot := Loser.TotalWarLoot - R.Taler;
  if AttackInitiativeCost(Winner.Country, Loser.Country) <= 2 then
  begin
    if City <> 0 then
      Pct := Random(13) + 5
    else
      Pct := Random(6) + 3;
    R.Land := MulDiv(Loser.Land, Pct, 100);
    if LongInt(Loser.Land - R.Land) < 12000 then
      R.Land := Loser.Land - 12000;
    if R.Land < 0 then
      R.Land := 0;
  end
  else
    R.Land := 0;
end;

procedure ShowPlunderResult(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults);
var
  D: TDialog;
begin
  { PLUENDERNDLG for a human on either side }
  if (Loser.CpuLevel <> 0) and (Winner.CpuLevel <> 0) then
    Exit;
  D := UI.Dialog('PlunderResultDlg', $0C98, [APtr(Parent), AStr(DSText($0E2A))]);
  PutLong(D, $2E, R.Loss.Unused4);
  PutLong(D, $36, R.Taler);
  PutLong(D, $32, R.Land);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure Ai_PlunderChoice(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);
var
  Choice: Word;
begin
  { a computer winner: plunder 51 %, burn 30 %, mercy 9 %, massacre 9 %,
    nothing 1 % (90); burning and massacre are only shown here }
  Choice := Random(100);
  if Choice <= 50 then
  begin
    PlunderTalerAndLand(Parent, Winner, Loser, R, City);
    ShowPlunderResult(Parent, Winner, Loser, R);
    if R.Land > 0 then
    begin
      TransferLand(Loser, Winner, R.Loss, R.Land, 1);
      if (Loser.CpuLevel = 0) and (R.Loss.Total > 0) then
        ShowLoss(Parent, $0E38, R.Loss, 0);              { VERLUSTDLG }
    end;
  end
  else if Choice <= 80 then
  begin
    BurnBuildings(Parent, Winner, Loser, R, City);
    ShowBurnResult(Parent, Winner, Loser, R);
  end
  else if Choice <= 89 then
    GainFame(Winner.Fame, 2)
  else if Choice >= 91 then
  begin
    Massacre(Parent, Winner, Loser, R, City);
    ShowMassacre(Parent, Winner, Loser, R);
    LoseFame(Winner.Fame, 30);
  end;
end;

procedure PlunderDialog(Parent: Pointer; var Winner, Loser: TPlayer; var R: TBattleResults; City: Byte);
var
  D: TDialog;
  WinTitle, LoseTitle: array[0..65] of Char;
  Choice: Byte;
  L: TLandLoss;
begin
  { a human winner chooses (LOOTDLG; LOOT2DLG in the field); then the
    losses in R are applied to the loser }
  if City <> 0 then
    D := UI.Dialog('PlunderChoiceDlg', $0D60, [APtr(Parent), AStr(DSText($0E44))])
  else
    D := UI.Dialog('PlunderChoiceDlg', $0D60, [APtr(Parent), AStr(DSText($0E4C))]);
  FillChar(WinTitle, SizeOf(WinTitle), 0);
  FillChar(LoseTitle, SizeOf(LoseTitle), 0);
  FormatPlayerTitle(Winner, WinTitle, 0, 0);
  FormatPlayerTitle(Loser, LoseTitle, 0, 0);
  StrCopy(PChar(@D.Data[$34]), WinTitle);
  StrCopy(PChar(@D.Data[$67]), LoseTitle);
  Choice := Byte(UI.Execute(D));
  UI.Done(D, 1);
  case Choice of
    $0A:
      begin
        PlunderTalerAndLand(Parent, Winner, Loser, R, City);
        ShowPlunderResult(Parent, Winner, Loser, R);
        if R.Land > 0 then
        begin
          FillChar(L, SizeOf(L), 0);
          TransferLand(Loser, Winner, L, R.Land, 1);
          if (Loser.CpuLevel = 0) and (L.Total > 0) then
            ShowLoss(Parent, $0E55, L, 0);               { VERLUSTDLG }
        end;
      end;
    $0B:
      begin
        BurnBuildings(Parent, Winner, Loser, R, City);
        ShowBurnResult(Parent, Winner, Loser, R);
      end;
    $0C:
      begin
        Massacre(Parent, Winner, Loser, R, City);
        ShowMassacre(Parent, Winner, Loser, R);
        LoseFame(Winner.Fame, 30);
      end;
    $0D: GainFame(Winner.Fame, 2);
  end;
  Loser.Population := MaxLong(Loser.Population div 2, Loser.Population - R.Loss.Unused4);
  Loser.Markets := MaxLong(0, Loser.Markets - R.Loss.Markets);
  Loser.Mills := MaxLong(0, Loser.Mills - R.Loss.Mills);
  Loser.PalaceParts := Byte(MaxLong(0, LongInt(Loser.PalaceParts) - R.Loss.PalaceParts));
  Loser.CathedralParts := Byte(MaxLong(0, LongInt(Loser.CathedralParts) - R.Loss.CathedralParts));
  Loser.UniversityParts := Byte(MaxLong(0, LongInt(Loser.UniversityParts) - R.Loss.UniversityParts));
  Loser.Taverns := MaxLong(0, Loser.Taverns - R.Loss.Taverns);
  Loser.Smithies := MaxLong(0, Loser.Smithies - R.Loss.Smithies);
  R.Loss.Granaries := MinLong(R.Loss.Granaries, Loser.Granaries);
  R.Loss.Warehouses := MinLong(R.Loss.Warehouses, Loser.Warehouses);
  RemoveGranaries(Loser, R.Loss.Granaries);
  RemoveWarehouses(Loser, R.Loss.Warehouses);
  R.Choice := Choice;
end;

procedure BattleSetup(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  AttIdx, DefIdx, Second: Byte);
var
  Pre: TBattleResults;
  Title: array[0..65] of Char;
  D: TDialog;
  Go: Boolean;
  Mode, Total: Byte;
begin
  { before the battle (battle.md 2) }
  FillChar(Pre, SizeOf(Pre), 0);
  Info.AttIdx := AttIdx;
  Info.DefIdx := DefIdx;
  Info.Second := Second;
  Info.NoArmy := Ord((Def.Army1Count = 0) and (Def.Army2Count = 0));
  { war ends a trade agreement }
  if (Second = 0) and (DS.Game.EmailGameQ = 0) and (Att.TradeAgreement[DefIdx] = 1) then
  begin
    if Att.CpuLevel = 0 then
      ShowDlg(Parent, $0B40);                            { NOTRADEDLG }
    Att.TradeAgreement[DefIdx] := 0;
    Def.TradeAgreement[AttIdx] := 0;
    PWord(@Def.AttitudeQ[2 * AttIdx])^ := 0;
  end;
  { the battlefield }
  if Second <> 0 then
    Info.City := 1
  else
  begin
    if Def.CpuLevel = 0 then
      Info.City := Ord(not AskBattlefield(Parent, Att, Def, AttIdx, DefIdx))
    else
    begin
      Total := Byte(Def.Army1Count + Def.Army2Count);
      Info.City := Ord(not ((Def.ArmyAway = 0) and (Total >= 8) and Chance(5 * Total)));
    end;
    { the countryside before a city battle }
    if (Info.City <> 0) and (DS.Game.EmailGameQ = 0) then
      if Att.CpuLevel = 0 then
        PlunderDialog(Parent, Att, Def, Pre, 0)
      else
        Ai_PlunderChoice(Parent, Att, Def, Pre, 0);
  end;
  Go := (Second <> 0) or (Info.City = 0) or (DS.Game.EmailGameQ = 0);
  if not Go then
    Exit;
  AvengerJoinsWeaker(Att, Def, DS.Game.Avenger);
  if (Second <> 0) and (Def.CpuLevel = 0) then
  begin
    FillChar(Title, SizeOf(Title), 0);
    FormatPlayerTitle(Def, Title, 0, 0);
    ShowMessage(Parent, $0B4B, Title);                   { CITYATTACKDLG }
  end;
  if Info.City <> 0 then
    Mode := 3
  else
    Mode := 2;
  if Info.NoArmy = 0 then
    if Def.CpuLevel = 0 then
      UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(@Def), AByte(Mode)])
    else if Info.City <> 0 then
      Ai_ArrangeArmies(Def, 2)
    else
      Ai_ArrangeArmies(Def, 1);
  if Info.City <> 0 then
  begin
    SwapArmies(Def);                                     { the Garde defends the city }
    Def.GarrisonSwapped := 1;
    FillWithMilitia(Def);
  end
  else
    Def.GarrisonSwapped := 0;
  Info.AttStrength := ArmyStrength(Att, 0);
  Info.DefStrength := ArmyStrength(Def, 0);
end;

procedure BattleFameAndXp(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  Code: Byte);
var
  Gains: THeroGains;
  I, Last: Byte;
begin
  { counters and fame by the result (battle.md 11), +8 XP for army1 }
  case Code of
    10:
      begin
        Inc(Att.AttacksLost);
        Inc(Def.DefencesWon);
        if Info.AttStrength > Info.DefStrength then
        begin
          Dec(Att.Fame, 10);
          Inc(Def.Fame, 10);
        end
        else
        begin
          Dec(Att.Fame, 3);
          Inc(Def.Fame, 7);
        end;
        if Def.Title < Att.Title then
          Inc(Def.Fame, 2);
      end;
    11:
      begin
        Inc(Att.AttacksWon);
        Inc(Def.DefencesLost);
        if Info.DefStrength > Info.AttStrength then
        begin
          Dec(Def.Fame, 7);
          Inc(Att.Fame, 3);
        end
        else
        begin
          Inc(Def.Fame);
          Inc(Att.Fame);
        end;
        if Att.Title < Def.Title then
          Inc(Att.Fame);
        Dec(Def.Fame, 3);
        Def.Lifetime := SmallInt(Def.Lifetime - Random(2));
      end;
    12:
      begin
        Inc(Att.AttacksLost);
        Inc(Def.DefencesWon);
        if Info.AttStrength > Info.DefStrength then
        begin
          Dec(Att.Fame, 5);
          Inc(Def.Fame, 5);
        end
        else
        begin
          Dec(Att.Fame, 2);
          Inc(Def.Fame, 4);
        end;
        if Def.Title < Att.Title then
          Inc(Def.Fame);
      end;
    13:
      begin
        Inc(Att.AttacksWon);
        Inc(Def.DefencesLost);
        if Info.DefStrength > Info.AttStrength then
        begin
          Dec(Def.Fame, 7);
          Inc(Att.Fame, 3);
        end
        else
        begin
          Inc(Def.Fame);
          Inc(Att.Fame);
        end;
        if Att.Title < Def.Title then
          Inc(Att.Fame);
        Dec(Def.Fame, 2);
        Def.Lifetime := SmallInt(Def.Lifetime - Random(2));
      end;
  end;
  FillChar(Gains, SizeOf(Gains), 0);
  if (Att.CpuLevel = 0) and (Code <> 12) then
  begin
    Last := Att.Army1Count;
    for I := 1 to Last do
      UnitGainExperience(Att.Army1[I], Gains, 8, Att.Spell);
  end;
  if Code <> 13 then
  begin
    Last := Def.Army1Count;
    for I := 1 to Last do
      UnitGainExperience(Def.Army1[I], Gains, 8, Def.Spell);
  end;
  if Info.AttStrength > Info.DefStrength then
    Dec(Att.Fame, 5);
  if Att.Title > Def.Title then
    Dec(Att.Fame, 4);
  if Info.NoArmy <> 0 then
    Dec(Att.Fame, 20);
  if Info.City = 0 then
    Inc(Def.Fame, 3);
  GainFame(Att.Fame, 0);
  LoseFame(Att.Fame, 0);
  GainFame(Def.Fame, 0);
  LoseFame(Def.Fame, 0);
end;

procedure BattleAftermath(Parent: Pointer; var Att, Def: TPlayer; var Info: TBattleInfo;
  var R: TBattleResults; Code: Byte);
var
  TwoHumansEmail: Boolean;
  Title: array[0..65] of Char;
begin
  { weapons loot, the winner's choice, the initiative cost, the Avenger and
    the militia leave (battle.md 11) }
  TwoHumansEmail := (DS.Game.EmailGameQ <> 0) and (Att.CpuLevel = 0) and (Def.CpuLevel = 0);
  FillChar(Title, SizeOf(Title), 0);
  case Code of
    10:
      begin
        AddGoodsCapped(Def, 4, R.Killed1);
        if (Info.City <> 0) and not TwoHumansEmail then
          ShowLoss(Parent, $0B60, R.Loss, 1);            { KAPUTTDLG }
      end;
    11:
      begin
        AddGoodsCapped(Att, 4, R.Killed0);
        if not TwoHumansEmail then
          if Att.CpuLevel = 0 then
            PlunderDialog(Parent, Att, Def, R, Info.City)
          else
            Ai_PlunderChoice(Parent, Att, Def, R, Info.City);
      end;
    12:
      begin
        if Att.CpuLevel = 0 then
          RetreatLosses(Parent, Att)
        else
        begin
          FormatPlayerTitle(Def, Title, 0, 0);
          ShowMessage(Parent, $0B6A, Title);             { ATKCOMPFLEDDLG }
        end;
        AddGoodsCapped(Def, 4, R.Killed1);
        if (Info.City <> 0) and not TwoHumansEmail then
          ShowLoss(Parent, $0B60, R.Loss, 1);
      end;
    13:
      begin
        if (Def.CpuLevel <> 0) and not TwoHumansEmail then
        begin
          FormatPlayerTitle(Att, Title, 0, 0);
          ShowMessage(Parent, $0B79, Title);             { DEFCOMPLOSTDLG }
        end;
        AddGoodsCapped(Att, 4, R.Killed0);
        if not TwoHumansEmail then
          if Att.CpuLevel = 0 then
            PlunderDialog(Parent, Att, Def, R, Info.City)
          else
            Ai_PlunderChoice(Parent, Att, Def, R, Info.City);
      end;
  end;
  if Info.Second = 0 then
  begin
    Att.Initiative := ShortInt(Att.Initiative - AttackInitiativeCost(Att.Country, Def.Country));
    if Att.Initiative < 0 then
      Att.ArmyAway := 1;
  end;
  AvengerLeaves(Att, Def, DS.Game.Avenger);
  if Info.City <> 0 then
    RemoveMilitia(Def);
  if Def.GarrisonSwapped <> 0 then
  begin
    SwapArmies(Def);
    Def.GarrisonSwapped := 0;
  end;
end;

function Battle(Parent: Pointer; var Att, Def: TPlayer; AttIdx, DefIdx, Second: Byte): Byte;
var
  Info: TBattleInfo;
  R: TBattleResults;
  A: PBattleArena;
  Code: Byte;
begin
  FillChar(Info, SizeOf(Info), 0);
  FillChar(R, SizeOf(R), 0);
  BattleSetup(Parent, Att, Def, Info, AttIdx, DefIdx, Second);
  UI.Call('PlaySound', [AWord(8), AWord(1)]);
  New(A);
  FillChar(A^, SizeOf(A^), 0);
  BattleInit(A^.W, Parent, DSText($0B5A), Att, Def, 0, Info.City);       { KRIEG }
  Code := Byte(UI.Call('Battle_Execute', [APtr(@A^.W)]));
  GetResults(A^.W, Att, Def, R);
  Dispose(A);
  BattleFameAndXp(Parent, Att, Def, Info, Code);
  BattleAftermath(Parent, Att, Def, Info, R, Code);
  Result := 0;
  case Code of
    10, 12: Result := 2;
    11, 13:
      if Info.City <> 0 then
        Result := 1
      else
        Result := 3;
  end;
end;

function FightRaiders(Parent: Pointer; var P: TPlayer; Unused, Mode: Byte): Byte;
var
  Raiders: TPlayer;
  R: TBattleResults;
  A: PBattleArena;
  Gains: THeroGains;
  Title: array[0..65] of Char;
  Code, I, Last: Byte;
begin
  { battle.md 12 }
  Result := 0;
  if P.ArmyAway = 0 then
    UI.Call('Do_TruppenAufstellen', [APtr(Parent), APtr(@P), AByte(1)]);
  if (P.ArmyAway <> 0) or (P.Army1Count = 0) then
  begin
    LoseFame(P.Fame, 7);
    ShowDlg(Parent, $0B88);                              { NOUNITSDLG }
    if Mode = 1 then
      ShowDlg(Parent, $0B93)                             { BARBLOOSEDLG }
    else if Mode = 2 then
      ShowDlg(Parent, $0BA0);                            { LINDWURMDLG_I }
    Exit;
  end;
  FillChar(Raiders, SizeOf(Raiders), 0);
  FillChar(R, SizeOf(R), 0);
  if Mode = 1 then
    GenerateMarauders(Raiders, SmallInt(ArmyStrength(P, 1)))
  else if Mode = 2 then
    GenerateLindwurm(Raiders);
  UI.Call('PlaySound', [AWord(8), AWord(1)]);
  New(A);
  FillChar(A^, SizeOf(A^), 0);
  BattleInit(A^.W, Parent, DSText($0BAE), P, Raiders, Mode, 0);          { KRIEG }
  Code := Byte(UI.Call('Battle_Execute', [APtr(@A^.W)]));
  GetResults(A^.W, P, Raiders, R);
  case Code of
    10:
      begin
        Inc(P.RaiderFightsLost);
        LoseFame(P.Fame, 5);
        if Mode = 1 then
        begin
          FillChar(Title, SizeOf(Title), 0);
          FormatPlayerTitle(P, Title, 0, 0);
          ShowMessage(Parent, $0BB4, Title);             { GESCHLAGENDLG }
          ShowDlg(Parent, $0B93);
        end
        else if Mode = 2 then
          ShowDlg(Parent, $0BA0);
        Result := 0;
      end;
    11:
      begin
        Inc(P.RaiderFightsWon);
        GainFame(P.Fame, 5);
        Result := 1;
        AddGoodsCapped(P, 4, R.Killed0);
        if Mode = 1 then
          ShowDlg(Parent, $0BC2)
        else if Mode = 2 then
          ShowDlg(Parent, $0BCD);
      end;
    12:
      begin
        Inc(P.RaiderFightsLost);
        LoseFame(P.Fame, 7);
        RetreatLosses(Parent, P);
        Result := 0;
        if Mode = 1 then
          ShowDlg(Parent, $0B93)
        else if Mode = 2 then
          ShowDlg(Parent, $0BA0);
      end;
    13:
      begin
        Inc(P.RaiderFightsWon);
        GainFame(P.Fame, 5);
        AddGoodsCapped(P, 4, R.Killed0);
        Result := 1;
        if Mode = 1 then
          ShowDlg(Parent, $0BDC)
        else if Mode = 2 then
          ShowDlg(Parent, $0BCD);
      end;
  end;
  if (Code = 11) or (Code = 13) then
  begin
    FillChar(Gains, SizeOf(Gains), 0);          { (not cleared between units) }
    Last := P.Army1Count;
    for I := 1 to Last do
    begin
      if UnitGainExperience(P.Army1[I], Gains, 8, P.Spell) then
        UI.Call('ShowHeroLevelUp', [APtr(Parent), ARec(@Gains, SizeOf(Gains))]);
    end;
  end;
  if DS.Game.InitiativeEnabled <> 0 then
    Dec(P.Initiative);
  Dispose(A);
end;

end.
