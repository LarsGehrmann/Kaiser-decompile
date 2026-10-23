{ The menu actions of the main window (segments 8 and 9, Do_*) and their
  dialog types. A dialog type's methods (TDialogLogic descendants, registered
  by the constructor name the action passes to UI.Dialog) work on D.Data,
  laid out like the original object; they reach the controls through
  TDlgControls. Differential tests: the original's own dialog objects run
  in the emulator (tools/emu/dlg_driver.py) with the same user events. }
unit Actions;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI;

{ Land handeln (1040:7e4b): LANDDLG on a copy of all players; on OK the
  copy is taken over and buildings that no longer fit are lost }
procedure Do_LandHandeln(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);

type
  PPlayers = ^TPlayers;

  { LANDDLG (VMT DS:1cec, 1040:7f10): all players at +0x34, me +0x4486,
    the number of players +0x4487; buttons 101..105 sell, 106..110 buy
    10000 .. 1 Hufen }
  TLandDlg = class(TDialogLogic)
  public
    function Players: PPlayers;
    function Me: PPlayer;
    procedure SetupWindow; override;
    procedure UpdateLabels;
    procedure Buy(N: LongInt);
    procedure Sell(N: LongInt);
    function Handle(Id: SmallInt): Boolean; override;
  end;

implementation

{ the number as the original's IntToStr (1068:6b29) writes it }
procedure SetNumber(C: TDlgControls; Id: SmallInt; V: LongInt);
var
  Buf: array[0..15] of Char;
begin
  IntToPChar(Buf, V);
  C.SetText(Id, Buf);
end;

{ -- Do_LandHandeln ------------------------------------------------------- }

procedure Do_LandHandeln(Parent: Pointer; var Players: TPlayers; Me, NumPlayers: Byte);
var
  D: TDialog;
  L: TLandLoss;
  Shown: TLandLoss;
begin
  D := UI.Dialog('LandDlg', $1CEC, [APtr(Parent), AStr(DSText($2B46))]);
  Move(Players, D.Data[$34], $4452);
  D.Data[$4486] := Me;
  D.Data[$4487] := NumPlayers;
  if UI.Execute(D) = 1 then
  begin
    Move(D.Data[$34], Players, $4452);
    FillChar(L, SizeOf(L), 0);
    BuildingsLostForLand(Players[Me], L);
    if L.Total > 0 then
    begin
      Shown := L;
      Shown.Unused4 := 0;
      UI.Call('ShowBuildingLossDlg', [APtr(Parent), AStr(DSText($2B4E)), ARec(@Shown, SizeOf(Shown)),
        AByte(0)]);
    end;
  end;
  UI.Done(D, 1);
end;

{ -- LANDDLG -------------------------------------------------------------- }

function TLandDlg.Players: PPlayers;
begin
  Result := PPlayers(@D.Data[$34]);
end;

function TLandDlg.Me: PPlayer;
begin
  Result := @Players^[D.Data[$4486]];
end;

procedure TLandDlg.SetupWindow;
begin
  SetNumber(C, 203, Me^.LandPrice);
  UpdateLabels;
end;

procedure TLandDlg.UpdateLabels;
var
  Unclaimed, Reserve, Amt: LongInt;
  K: Integer;
begin
  { treasury, land, unclaimed land; a purchase needs unclaimed land and
    must leave the treasury above the credit limit, a sale leaves 2000
    Hufen of farmland }
  SetNumber(C, 201, Me^.Taler);
  SetNumber(C, 202, Me^.Land);
  SetNumber(C, 204, UnclaimedLand(Players^, D.Data[$4487]));
  Unclaimed := UnclaimedLand(Players^, D.Data[$4487]);
  Reserve := -CreditLimit(Me^);
  for K := 0 to 4 do
  begin
    Amt := DS.LandTradeAmounts[K];
    C.Enable(106 + K, not ((Amt > Unclaimed) or
      (LongInt(Me^.Taler - LongInt(Int64(Me^.LandPrice) * Amt) div 10) < Reserve)));
    C.Enable(101 + K, not (LongInt(Amt + 2000) > LongInt(Me^.Land - Me^.LandUsed)));
  end;
end;

procedure TLandDlg.Buy(N: LongInt);
var
  Cost: LongInt;
begin
  UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  Me^.Land := Me^.Land + N;
  Cost := LongInt(Int64(Me^.LandPrice) * N) div 10;
  if N > 0 then
    Inc(Cost);
  if Cost = 0 then
    Cost := 1;
  Me^.Taler := Me^.Taler - Cost;
  Me^.TotalLandTrade := Me^.TotalLandTrade - Cost;
  UpdateLabels;
end;

procedure TLandDlg.Sell(N: LongInt);
var
  Gain: LongInt;
begin
  UI.Call('PlaySound', [AWord($0A), AWord(1)]);
  Me^.Land := Me^.Land - N;
  Gain := LongInt(Int64(Me^.LandPrice - 1) * N) div 10;
  Me^.Taler := Me^.Taler + Gain;
  Me^.TotalLandTrade := Me^.TotalLandTrade + Gain;
  UpdateLabels;
end;

function TLandDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    101..105: Sell(DS.LandTradeAmounts[Id - 101]);
    106..110: Buy(DS.LandTradeAmounts[Id - 106]);
  else
    Result := False;
  end;
end;

initialization
  RegisterDialogLogic('LandDlg', TLandDlg);
end.
