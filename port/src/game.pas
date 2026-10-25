{ The turn loop of the main window (segment 1, KaiserWindow): the computer
  players move inside NextPlayer, between the human turns. The window object
  of the original is Parent here; the player array and the game record
  (DS.Game) are passed separately. }
unit Game;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, Real48, KaiserTypes, KaiserDS, Rules, KaiserUI, Turn, Ai;

procedure NextPlayer(Parent: Pointer; HWnd: Word; var Players: TPlayers);  { 1000:35ad }
procedure CpuTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);     { 1000:36d2 }
procedure ResolveWar(Parent: Pointer; var Players: TPlayers; Target: Byte);  { 1000:37c0 }
procedure BeginHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);  { 1000:33c0 }
procedure EndHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);    { 1000:2476 }
procedure NewGame(Parent: Pointer; HWnd: Word; var Players: TPlayers);         { 1000:0ce6 }
function NewGame_AskPlayerCounts(Parent: Pointer; var Players: TPlayers;
  var Level: Byte): Byte;                                   { 1040:1d98 }
procedure NewGame_AskPlayerData(Parent: Pointer; var Players: TPlayers; Humans: Byte);  { 1040:1f2a }

implementation

procedure NextPlayer(Parent: Pointer; HWnd: Word; var Players: TPlayers);
var
  Stop: Byte;
  Gains: THeroGains;
begin
  { on to the next player who is not skipped: computer players move right
    here; the loop stops at a human, at the end of the game or a victory }
  FillChar(Gains, SizeOf(Gains), 0);
  with DS.Game do
  begin
    if Players[CurrentPlayer].CpuLevel = 0 then
      LastHuman := CurrentPlayer;
    Inc(CurrentPlayer);
    if CurrentPlayer = NumPlayers then
    begin
      CurrentPlayer := 0;
      Inc(Year);
    end;
    Stop := 0;
    while Stop = 0 do
    begin
      if Players[CurrentPlayer].CpuLevel = 0 then
      begin
        if Players[CurrentPlayer].SkipTurn = 0 then
          Stop := 1
        else
          Players[CurrentPlayer].SkipTurn := 0;
      end
      else if Players[CurrentPlayer].SkipTurn = 0 then
      begin
        CpuTurn(Parent, HWnd, Players);
        if GameState = 0 then
        begin
          UI.Call('EndGame', [APtr(Parent)]);
          Exit;
        end;
        if Players[CurrentPlayer].Title = 10 then
        begin
          UI.Call('Victory', [APtr(Parent)]);
          Exit;
        end;
      end
      else
        Players[CurrentPlayer].SkipTurn := 0;
      if Stop = 0 then
      begin
        Inc(CurrentPlayer);
        if CurrentPlayer = NumPlayers then
        begin
          { a new year (only here, not for the first step above): the
            Avenger gains experience }
          CurrentPlayer := 0;
          Inc(Year);
          UnitGainExperience(Avenger, Gains, 2, 0);
        end;
      end;
    end;
  end;
end;

procedure CpuTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);
var
  Target: Byte;
begin
  Target := 100;
  with DS.Game do
  begin
    Ai_Turn(Parent, HWnd, Players, CurrentPlayer, NumPlayers, Year);
    if Ai_ChooseWarTarget(Parent, Players, CurrentPlayer, NumPlayers, Target) then
    begin
      if (EmailGameQ <> 0) and (Target <> LastHuman) then
      begin
        { e-mail game: the attacked human fights the battle on his turn;
          (the original also passes its save buffers, not modelled yet) }
        GameState := 2;
        WarTargetQ := Target;
        UI.Call('ShowEmailHandOver', [APtr(Parent), APtr(@Players[Target]), APtr(nil)]);
        UI.Call('SaveGame', [APtr(nil), APtr(@Players), APtr(nil)]);
        GameState := 0;
        UI.Call('InvalidateRect', []);
        Exit;                        { (no Ai_EndTurn) }
      end;
      ResolveWar(Parent, Players, Target);
    end;
    Ai_EndTurn(Players, CurrentPlayer, NumPlayers);
  end;
end;

procedure ResolveWar(Parent: Pointer; var Players: TPlayers; Target: Byte);
var
  R: Byte;
begin
  { a computer player attacks a human: the tactical battle (result 3 =
    once more) }
  with DS.Game do
  begin
    GameState := 2;
    UI.Call('InvalidateRect', []);     { the main window: the pattern }
    Ai_ArrangeArmies(Players[CurrentPlayer], 1);
    R := Byte(UI.Call('Battle', [APtr(Parent), APtr(@Players[CurrentPlayer]),
      APtr(@Players[Target]), AByte(CurrentPlayer), AByte(Target), AByte(0)]));
    if R = 3 then
      R := Byte(UI.Call('Battle', [APtr(Parent), APtr(@Players[CurrentPlayer]),
        APtr(@Players[Target]), AByte(CurrentPlayer), AByte(Target), AByte(1)]));
    if R = 1 then
      AddNews(Players, NumPlayers, Target, CurrentPlayer, 8)
    else
      AddNews(Players, NumPlayers, Target, CurrentPlayer, 9);
    GameState := 1;
    UI.Call('InvalidateRect', []);
  end;
end;

procedure BeginHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);
begin
  with DS.Game do
  begin
    GameState := 6;
    { the main window greyed (the pattern) during the turn start's reports }
    UI.Call('InvalidateRect', []);
    if PlayerTurnStart(Parent, HWnd, Players, CurrentPlayer, NumPlayers, Year) then
      GameState := 1
    else
    begin
      UI.Call('ShowPasswordFail', [APtr(Parent)]);
      GameState := 0;
    end;
    UI.Call('InvalidateRect', []);
    { autosave.ksr (the original passes its save buffers) }
    if (DS.OptAutosave <> 0) and (EmailGameQ = 0) then
      UI.Call('SaveGame', [APtr(nil), APtr(@Players), APtr(nil)]);
  end;
end;

procedure EndHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);
var
  Title: array[0..81] of Char;
  Buf: array[0..7] of Char;
  D: TDialog;
begin
  { menu "Runde beenden" (CmBeenden): the end of the human's year, the
    computer players, then the next human's turn start }
  FillChar(Title, SizeOf(Title), 0);
  FillChar(Buf, SizeOf(Buf), 0);
  with DS.Game do
  begin
    if GameState <> 1 then
      Exit;
    PlayerTurnEnd(Parent, HWnd, Players, CurrentPlayer, NumPlayers, Year);
    if Players[CurrentPlayer].Title = 10 then
    begin
      UI.Call('Victory', [APtr(Parent)]);
      Exit;
    end;
    if (Immortality = 0) and (Players[CurrentPlayer].Lifetime <= 0) then
    begin
      { the ruler dies: a computer player takes the country over }
      FormatPlayerTitle(Players[CurrentPlayer], Title, 0, 0);
      IntToPChar(Buf, LongInt(Word(Year + 1400)));
      if Players[CurrentPlayer].IsFemale = 0 then
        D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($04A4)), AStr(Title),   { TOD }
          AStr(Buf)])
      else
        D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($04A8)), AStr(Title),   { TODFEM }
          AStr(Buf)]);
      UI.Execute(D);
      UI.Done(D, 1);
      InitComputerRuler(Players, CurrentPlayer);
      Dec(HumanPlayers);
      LastHuman := CurrentPlayer;
      AddNews(Players, NumPlayers, CurrentPlayer, CurrentPlayer, $10);
    end;
    NextPlayer(Parent, HWnd, Players);
    if GameState = 1 then
    begin
      if (EmailGameQ <> 0) and (CurrentPlayer <> LastHuman) then
      begin
        GameState := 5;
        UI.Call('EmailGameStep', [APtr(Parent)]);
      end
      else
        BeginHumanTurn(Parent, HWnd, Players);
    end;
    if (EmailGameQ <> 0) and (HumanPlayers < 2) then
    begin
      { e-mail mode ends with the last but one human }
      EmailGameQ := 0;
      UI.Call('Menu_DisableSave', [AWord(0), AWord(HWnd)]);
    end;
  end;
end;

procedure NewGame_AskPlayerData(Parent: Pointer; var Players: TPlayers; Humans: Byte);
var
  I, Last: Byte;
  D: TDialog;
begin
  { per human SPIELERNAMEDLG: name (+0x2e), sex (+0x4c), country (+0x4d) }
  Last := Byte(Humans - 1);
  for I := 0 to Last do
  begin
    D := UI.Dialog('PlayerDataDlg', $195A, [APtr(Parent), AStr(DSText($23DA)), APtr(@Players),
      AByte(I)]);
    UI.Execute(D);
    StrCopy(Players[I].Name, PChar(@D.Data[$2E]));
    Players[I].IsFemale := D.Data[$4C];
    Players[I].CpuLevel := 0;
    Players[I].Country := D.Data[$4D];
    StrCopy(DS.HumanNames[I], PChar(@D.Data[$2E]));
    UI.Done(D, 1);
  end;
end;

function NewGame_AskPlayerCounts(Parent: Pointer; var Players: TPlayers;
  var Level: Byte): Byte;
var
  D: TDialog;
  Humans, Cpus, I: Byte;
begin
  { SPIELERZAHLDLG: humans (+0x34) and the game options (its CanClose
    writes them into the game record); COMPUTERZAHLDLG: computers (+0x34)
    and their level (+0x3b, 0-based). Result: the number of players, 0 when
    cancelled }
  D := UI.Dialog('HumanCountDlg', $22E4, [APtr(Parent), AStr(DSText($23BA))]);
  D.Data[$35] := 1;
  D.Data[$36] := 10;
  if UI.Execute(D) <> 1 then
    Exit(0);
  for I := 0 to 9 do
    FillChar(Players[I], SizeOf(TPlayer), 0);
  Humans := D.Data[$34];
  UI.Done(D, 1);
  Level := 0;
  if Humans < 10 then
  begin
    D := UI.Dialog('ComputerCountDlg', $2362, [APtr(Parent), AStr(DSText($23C9))]);
    if Humans = 1 then
      D.Data[$35] := 1
    else
      D.Data[$35] := 0;
    D.Data[$36] := Byte(10 - Humans);
    UI.Execute(D);
    Cpus := D.Data[$34];
    if Cpus > 0 then
      Level := D.Data[$3B] + 1;
    UI.Done(D, 1);
  end
  else
    Cpus := 0;
  DS.Game.NumPlayers := Byte(Humans + Cpus);
  DS.Game.HumanPlayers := Humans;
  DS.Game.CpuDifficulty := Level;
  if DS.Game.EmailGameQ = 0 then
  begin
    NewGame_AskPlayerData(Parent, Players, Humans);
    if Cpus > 0 then
      CreateComputerPlayers(Players, Humans, Cpus, Level);
  end;
  Result := Byte(Humans + Cpus);
end;

procedure NewGame(Parent: Pointer; HWnd: Word; var Players: TPlayers);
begin
  { menu "Neues Spiel" (CmNeuesSpiel) }
  with DS.Game do
  begin
    if GameState = 1 then
      if UI.Call('MessageBox', [AWord(HWnd), AStr(DSText($02D6)), AStr(DSText($030F)),
        AWord($24)]) <> 6 then            { IDYES }
        Exit;
    GameState := 0;
    NumPlayers := NewGame_AskPlayerCounts(Parent, Players, CpuDifficulty);
    if NumPlayers < 2 then
    begin
      GameState := 0;
      UI.Call('Menu_DisableGameCommands', [AWord(HWnd)]);
      UI.Call('Menu_DisableSave', [AWord(0), AWord(HWnd)]);
      Exit;
    end;
    CurrentPlayer := 0;
    Year := 0;
    UI.Call('Randomize', []);           { RandSeed from the clock }
    GameId := Random($FFFF) + 1;
    InitAvenger(Avenger);
    CensusEditorEnabled := DS.OptDebug;
    if EmailGameQ <> 0 then
    begin
      GameState := 4;
      UI.Call('EmailGameStep', [APtr(Parent)]);
      Exit;
    end;
    GameState := 1;
    InitPlayers(Players, NumPlayers, CpuDifficulty);
    BeginHumanTurn(Parent, HWnd, Players);
  end;
end;

end.
