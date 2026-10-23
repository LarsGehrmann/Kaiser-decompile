{ The help: the original calls WinHelp on KAISER.HLP (HELP_CONTEXT with a
  topic number from the dialogs' "?" buttons, the battle's right click, the
  menu "Hilfe"). Here the topics come from the manual converted by
  tools/help_to_md.py (docs/manual.md, an anchor per context string) and the
  number -> context string map of extracted/help/KAISER.hpj ([MAP]); a topic
  is shown as text in a window. }
unit HelpView;

{$mode objfpc}{$H+}

interface

{ a file of the repository (docs/manual.md, ...) next to the program or up
  to six directories above it; '' if missing }
function FindDataFile(const Rel: string): string;
{ WinHelp(.., HELP_CONTEXT, Ctx): the topic in a window (False: unknown) }
function ShowHelpTopic(Ctx: LongInt): Boolean;

implementation

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, Graphics, LCLType;

var
  Map: TStringList;        { 'number=anchor' }
  Manual: TStringList;

function FindDataFile(const Rel: string): string;
var
  Dir: string;
  I: Integer;
begin
  Dir := ExtractFilePath(ParamStr(0));
  for I := 0 to 6 do
  begin
    if FileExists(Dir + Rel) then
      Exit(ExpandFileName(Dir + Rel));
    Dir := Dir + '../';
  end;
  Result := '';
end;

{ help_to_md.py's anchor(): other characters than A-Z a-z 0-9 _ - become _ }
function Anchor(const Ctx: string): string;
var
  I: Integer;
begin
  Result := LowerCase(Ctx);
  for I := 1 to Length(Result) do
    if not (Result[I] in ['a'..'z', '0'..'9', '_', '-']) then
      Result[I] := '_';
end;

function Load: Boolean;
var
  Hpj: TStringList;
  F, L: string;
  I, P: Integer;
  InMap: Boolean;
begin
  if Manual <> nil then
    Exit(True);
  F := FindDataFile('docs/manual.md');
  if F = '' then
    Exit(False);
  Manual := TStringList.Create;
  Manual.LoadFromFile(F);
  Map := TStringList.Create;
  F := FindDataFile('extracted/help/KAISER.hpj');
  if F <> '' then
  begin
    Hpj := TStringList.Create;
    try
      Hpj.LoadFromFile(F);
      InMap := False;
      for I := 0 to Hpj.Count - 1 do
      begin
        L := Trim(Hpj[I]);
        if Copy(L, 1, 1) = '[' then
          InMap := L = '[MAP]'
        else if InMap and (L <> '') then
        begin
          P := Pos(' ', L);
          if P > 0 then
            Map.Values[Trim(Copy(L, P + 1, 20))] := Anchor(Copy(L, 1, P - 1));
        end;
      end;
    finally
      Hpj.Free;
    end;
  end;
  Result := True;
end;

{ the Markdown of the converter as plain text: no pictures, links as their
  text, no keyword lines }
function Plain(const L: string): string;
var
  I, J, K: Integer;
begin
  Result := L;
  repeat
    I := Pos('{bm', Result);
    if I = 0 then
      Break;
    J := Pos('}', Copy(Result, I, Length(Result)));
    if J = 0 then
      Break;
    Delete(Result, I, J);
  until False;
  repeat
    I := Pos('](#', Result);
    if I = 0 then
      Break;
    J := I;
    while (J > 1) and (Result[J] <> '[') do
      Dec(J);
    K := Pos(')', Copy(Result, I, Length(Result)));
    if (Result[J] <> '[') or (K = 0) then
      Break;
    Result := Copy(Result, 1, J - 1) + Copy(Result, J + 1, I - J - 1) +
      Copy(Result, I + K, Length(Result));
  until False;
end;

function ShowHelpTopic(Ctx: LongInt): Boolean;
var
  A, Title, L: string;
  I, Start: Integer;
  Text: TStringList;
  F: TForm;
  M: TMemo;
  B: TButton;
  Img: TBitmap;
  P: TPortableNetworkGraphic;
begin
  Result := False;
  if not Load then
    Exit;
  A := Map.Values[IntToStr(Ctx)];
  if A = '' then
    Exit;
  Start := Manual.IndexOf('<a id="' + A + '"></a>');
  if Start < 0 then
    Exit;
  Title := 'Kaiser';
  Text := TStringList.Create;
  try
    for I := Start + 1 to Manual.Count - 1 do
    begin
      L := Manual[I];
      if L = '---' then
        Break;
      if Copy(L, 1, 6) = '<a id=' then
        Continue;
      if Copy(L, 1, 3) = '## ' then
      begin
        Title := Copy(L, 4, Length(L));
        Continue;
      end;
      if Copy(L, 1, 13) = '*Stichworte: ' then
        Continue;
      Text.Add(Plain(L));
    end;
    while (Text.Count > 0) and (Trim(Text[0]) = '') do
      Text.Delete(0);
    { the converter repeats the title as the first line }
    if (Text.Count > 0) and (Trim(Text[0]) = Title) then
      Text.Delete(0);
    F := TForm.CreateNew(nil);
    try
      F.Caption := Title;
      F.Position := poMainFormCenter;
      F.Width := 560;
      F.Height := 440;
      M := TMemo.Create(F);
      M.Parent := F;
      M.Align := alClient;
      M.ReadOnly := True;
      M.WordWrap := True;
      M.ScrollBars := ssAutoVertical;
      M.Font.Name := 'Comic Sans MS';
      M.Font.Size := 12;
      M.Color := $00ACFFFF;
      M.Lines.Assign(Text);
      B := TButton.Create(F);
      B.Parent := F;
      B.Align := alBottom;
      B.Caption := 'Schließen';
      B.ModalResult := mrOK;
      B.Default := True;
      B.Cancel := True;
      if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
      begin
        { the autopilot: a snapshot instead of waiting }
        F.Show;
        Application.ProcessMessages;
        Img := F.GetFormImage;
        P := TPortableNetworkGraphic.Create;
        try
          P.Assign(Img);
          P.SaveToFile(IncludeTrailingPathDelimiter(GetEnvironmentVariable('KAISER_AUTOPILOT')) +
            Format('help_%d.png', [Ctx]));
        finally
          P.Free;
          Img.Free;
        end;
      end
      else
        F.ShowModal;
    finally
      F.Free;
    end;
  finally
    Text.Free;
  end;
  Result := True;
end;

finalization
  Map.Free;
  Manual.Free;
end.
