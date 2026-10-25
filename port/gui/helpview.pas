{ The help: the original calls WinHelp on KAISER.HLP (HELP_CONTEXT with a
  topic number from the dialogs' "?" buttons, the battle's right click, the
  menu "Hilfe"). Here the topics come from the manual converted by
  tools/help_to_md.py (docs/manual.md, an anchor per context string) and the
  number -> context string map of the help project KAISER.HPJ ([MAP], in
  docs/help-map.txt); a topic is shown as text in a window. }
unit HelpView;

{$mode objfpc}{$H+}

interface

{ a file of the repository (docs/manual.md, ...) next to the program, up to
  six directories above it or in the macOS app's Resources; '' if missing }
function FindDataFile(const Rel: string): string;
{ WinHelp(.., HELP_CONTEXT, Ctx): the topic in a window (False: unknown) }
function ShowHelpTopic(Ctx: LongInt): Boolean;
{ the menu "Hilfe": the contents in the help window (not in another program,
  which on Windows has none for .md) }
function ShowHelpContents: Boolean;

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
  if FileExists(Dir + '../Resources/' + Rel) then
    Exit(ExpandFileName(Dir + '../Resources/' + Rel));
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
begin
  if Manual <> nil then
    Exit(True);
  F := FindDataFile('docs/manual.md');
  if F = '' then
    Exit(False);
  Manual := TStringList.Create;
  Manual.LoadFromFile(F);
  Map := TStringList.Create;
  F := FindDataFile('docs/help-map.txt');
  if F <> '' then
  begin
    Hpj := TStringList.Create;
    try
      Hpj.LoadFromFile(F);
      for I := 0 to Hpj.Count - 1 do
      begin
        L := Trim(Hpj[I]);
        if (L <> '') and (L[1] <> ';') then             { 'CONTEXT number' }
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

{ the links [text](#anchor) of a line as 'text=anchor' }
procedure AddLinks(const L: string; Links: TStrings);
var
  I, J, K: Integer;
  R: string;
begin
  R := L;
  repeat
    I := Pos('](#', R);
    if I = 0 then
      Break;
    J := I;
    while (J > 1) and (R[J] <> '[') do
      Dec(J);
    K := Pos(')', Copy(R, I, Length(R)));
    if (R[J] <> '[') or (K = 0) then
      Break;
    if Links.IndexOfName(Copy(R, J + 1, I - J - 1)) < 0 then
      Links.Add(Copy(R, J + 1, I - J - 1) + '=' + Copy(R, I + 3, K - 4));
    R := Copy(R, I + K, Length(R));
  until False;
end;

{ the topic at the anchor ('': the contents, the manual's first topic) }
function ReadTopic(const A: string; out Title: string; Text, Links: TStrings): Boolean;
var
  I, Start: Integer;
  L: string;
begin
  Result := False;
  if A = '' then
  begin
    Start := 0;
    while (Start < Manual.Count) and (Copy(Manual[Start], 1, 3) <> '## ') do
      Inc(Start);
    Dec(Start);
  end
  else
    Start := Manual.IndexOf('<a id="' + A + '"></a>');
  if (Start < -1) or (Start >= Manual.Count - 1) then
    Exit;
  Title := '';
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
    AddLinks(L, Links);
    Text.Add(Plain(L));
  end;
  while (Text.Count > 0) and (Trim(Text[0]) = '') do
    Text.Delete(0);
  { without a heading the first line is the title }
  if (Title = '') and (Text.Count > 0) then
    Title := Trim(Text[0]);
  { the converter repeats the title as the first line }
  if (Text.Count > 0) and (Trim(Text[0]) = Title) then
    Text.Delete(0);
  while (Text.Count > 0) and (Trim(Text[0]) = '') do
    Text.Delete(0);
  if Title = '' then
    Title := 'Kaiser';
  Result := True;
end;

{ the topic's text and its links to follow, the contents and the way back
  (WinHelp's buttons) }
const
  DialogScale = 1;                      { (the remastered game scales it) }

type
  THelpWindow = class(TForm)
  private
    FMemo: TMemo;
    FLinks: TListBox;
    FBack: TButton;
    FAnchors: TStringList;
    FHistory: TStringList;
    FCurrent: string;
    procedure LinkClick(Sender: TObject);
    procedure LinkDraw(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ContentsClick(Sender: TObject);
    procedure BackClick(Sender: TObject);
  public
    constructor CreateHelp;
    destructor Destroy; override;
    function Go(const A: string; Remember: Boolean): Boolean;
  end;

constructor THelpWindow.CreateHelp;

  function Btn(const C: string; X: Integer; H: TNotifyEvent; P: TWinControl): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := P;
    Result.Caption := C;
    Result.SetBounds(Round(X * DialogScale), Round(6 * DialogScale),
      Round(100 * DialogScale), Round(28 * DialogScale));
    Result.OnClick := H;
  end;

var
  P: TPanel;
  B: TButton;
begin
  inherited CreateNew(nil);
  FAnchors := TStringList.Create;
  FHistory := TStringList.Create;
  Position := poMainFormCenter;
  Width := Round(820 * DialogScale);
  Height := Round(480 * DialogScale);
  Font.Size := Round(11 * DialogScale);
  P := TPanel.Create(Self);
  P.Parent := Self;
  P.Align := alBottom;
  P.Height := Round(40 * DialogScale);
  P.BevelOuter := bvNone;
  Btn('Inhalt', 8, @ContentsClick, P);
  FBack := Btn('Zurück', 116, @BackClick, P);
  B := Btn('Schließen', 224, nil, P);
  B.ModalResult := mrOK;
  B.Default := True;
  B.Cancel := True;
  FLinks := TListBox.Create(Self);
  FLinks.Parent := Self;
  FLinks.Align := alRight;
  FLinks.Width := Round(290 * DialogScale);
  FLinks.Font.Name := 'Comic Sans MS';
  FLinks.Font.Size := Round(11 * DialogScale);
  { drawn here: the Cocoa list box keeps the system font }
  FLinks.Style := lbOwnerDrawFixed;
  FLinks.ItemHeight := Round(22 * DialogScale);
  FLinks.OnDrawItem := @LinkDraw;
  FLinks.OnClick := @LinkClick;
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.WordWrap := True;
  FMemo.ScrollBars := ssAutoVertical;
  FMemo.Font.Name := 'Comic Sans MS';
  FMemo.Font.Size := Round(12 * DialogScale);
  FMemo.Color := $00ACFFFF;
end;

destructor THelpWindow.Destroy;
begin
  FAnchors.Free;
  FHistory.Free;
  inherited Destroy;
end;

function THelpWindow.Go(const A: string; Remember: Boolean): Boolean;
var
  Title: string;
  Lines, Links: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  Links := TStringList.Create;
  try
    Result := ReadTopic(A, Title, Lines, Links);
    if not Result then
      Exit;
    if Remember then
      FHistory.Add(FCurrent);
    FCurrent := A;
    Caption := 'Kaiser-Hilfe - ' + Title;
    FMemo.Lines.Assign(Lines);
    FMemo.SelStart := 0;
    FAnchors.Clear;
    FLinks.Items.BeginUpdate;
    FLinks.Items.Clear;
    for I := 0 to Links.Count - 1 do
    begin
      FLinks.Items.Add(Links.Names[I]);
      FAnchors.Add(Links.ValueFromIndex[I]);
    end;
    FLinks.Items.EndUpdate;
    FLinks.Visible := Links.Count > 0;
    FBack.Enabled := FHistory.Count > 0;
  finally
    Lines.Free;
    Links.Free;
  end;
end;

procedure THelpWindow.LinkClick(Sender: TObject);
begin
  if (FLinks.ItemIndex >= 0) and (FLinks.ItemIndex < FAnchors.Count) then
    Go(FAnchors[FLinks.ItemIndex], True);
end;

procedure THelpWindow.LinkDraw(Control: TWinControl; Index: Integer; ARect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
begin
  C := FLinks.Canvas;
  C.Font := FLinks.Font;
  if odSelected in State then
  begin
    C.Brush.Color := clHighlight;
    C.Font.Color := clHighlightText;
  end
  else
  begin
    C.Brush.Color := clWindow;
    C.Font.Color := clWindowText;
  end;
  C.FillRect(ARect);
  C.TextOut(ARect.Left + Round(6 * DialogScale),
    ARect.Top + (ARect.Bottom - ARect.Top - C.TextHeight('Ag')) div 2, FLinks.Items[Index]);
end;

procedure THelpWindow.ContentsClick(Sender: TObject);
begin
  if FCurrent <> '' then
    Go('', True);
end;

procedure THelpWindow.BackClick(Sender: TObject);
var
  A: string;
begin
  if FHistory.Count = 0 then
    Exit;
  A := FHistory[FHistory.Count - 1];
  FHistory.Delete(FHistory.Count - 1);
  Go(A, False);
end;

function ShowAnchor(const A, ShotName: string): Boolean;
var
  F: THelpWindow;
  Img: TBitmap;
  P: TPortableNetworkGraphic;
begin
  Result := False;
  if not Load then
    Exit;
  F := THelpWindow.CreateHelp;
  try
    if not F.Go(A, False) then
      Exit;
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
          ShotName);
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
  Result := True;
end;

function ShowHelpTopic(Ctx: LongInt): Boolean;
begin
  Result := Load and (Map.Values[IntToStr(Ctx)] <> '') and
    ShowAnchor(Map.Values[IntToStr(Ctx)], Format('help_%d.png', [Ctx]));
end;

function ShowHelpContents: Boolean;
begin
  Result := ShowAnchor('', 'help_contents.png');
end;

finalization
  Map.Free;
  Manual.Free;
end.
