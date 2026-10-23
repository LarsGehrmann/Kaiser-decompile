{ The turn loop of the main window (segment 1, KaiserWindow): the computer
  players move inside NextPlayer, between the human turns. The window object
  of the original is Parent here; the player array and the game record
  (DS.Game) are passed separately. }
unit Game;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, KaiserTypes, KaiserDS, Rules, KaiserUI, Turn, Ai;

procedure NextPlayer(Parent: Pointer; HWnd: Word; var Players: TPlayers);  { 1000:35ad }
procedure CpuTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);     { 1000:36d2 }
procedure ResolveWar(Parent: Pointer; var Players: TPlayers; Target: Byte);  { 1000:37c0 }
procedure BeginHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);  { 1000:33c0 }
procedure EndHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);    { 1000:2476 }

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
  end;
end;

procedure BeginHumanTurn(Parent: Pointer; HWnd: Word; var Players: TPlayers);
begin
  with DS.Game do
  begin
    GameState := 6;
    if PlayerTurnStart(Parent, HWnd, Players, CurrentPlayer, NumPlayers, Year) then
      GameState := 1
    else
    begin
      UI.Call('ShowPasswordFail', [APtr(Parent)]);
      GameState := 0;
    end;
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
        D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($04A4)), AStr(Title),
          AStr(Buf)])
      else
        D := UI.Dialog('Message2Dlg', $3472, [APtr(Parent), AStr(DSText($04A8)), AStr(Title),
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

end.
