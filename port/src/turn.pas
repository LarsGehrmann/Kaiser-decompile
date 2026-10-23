{ Turn processing: the yearly functions of segment 3 (1010:xxxx), ported in
  the original order of operations. Dialogs and UI functions go through
  KaiserUI exactly where the original opens them; differential tests:
  port/tests/ruletest.pas with the UI calls replayed. }
unit Turn;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  Strings, KaiserTypes, KaiserDS, Real48, Rules, KaiserUI;

procedure RulerFallsIll(Parent: Pointer);                   { 1010:3777 }
procedure WitchChoosesSpell(Parent: Pointer; var P: TPlayer);  { 1010:372a }

implementation

procedure RulerFallsIll(Parent: Pointer);
var
  D: TDialog;
begin
  D := UI.Dialog('KaiserDlg', $3364, [APtr(Parent), AStr(DSText($099E))]);   { KRANKDLG }
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure WitchChoosesSpell(Parent: Pointer; var P: TPlayer);
var
  D: TDialog;
begin
  D := UI.Dialog('HexenDlg', $0598, [APtr(Parent), AStr(DSText($0994))]);    { HEXENDLG }
  UI.Execute(D);
  P.Spell := D.Data[$38];
  UI.Done(D, 1);
end;

end.
