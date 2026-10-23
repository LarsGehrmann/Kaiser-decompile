{ The end of a game: the coronation, the annals (KAISER.SCO, five high-score
  tables by computer level) and the records (KAISER.REC), segment 9
  (1040:3f44 .. 1040:4d4c) and segment 11 (1050:000d .. 1050:030f). The files
  are read and written through the UI (UI.Call 'Annals_Load' / 'Annals_Save'
  / 'Records_Load' / 'Records_Save'): the GUI does the file I/O (AnnalsIO
  below), the tests replay them. }
unit Annals;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Strings, KaiserTypes, KaiserDS, Rules, KaiserUI, Turn;

const
  AnnalsSize = $ABE;     { 5 tables x 0x226 (11 entries of 50 bytes) }
  RecordsSize = $187;

type
  { one entry of a high-score table }
  PScoreEntry = ^TScoreEntry;
  TScoreEntry = packed record
    Name: array[0..40] of Char;   { +0x00 FormatPlayerTitle }
    Spell: Byte;                  { +0x29 }
    Score: LongInt;               { +0x2a ComputeScore }
    Year: Word;                   { +0x2e year + 1400 }
    GameId: Word;                 { +0x30 one entry per game }
  end;
  TAnnals = packed array[0..AnnalsSize - 1] of Byte;

  { KAISER.REC: checksums, the fastest coronation, most land, people, Taler
    and the best hero, each with the ruler's name, a date and the game id }
  TRecords = packed record
    Check1: LongInt;              { +0x000 years + people - land + Taler - level - kills }
    YearsName: array[0..40] of Char;   { +0x004 }
    Years: Word;                  { +0x02d }
    YearsDate: array[0..24] of Char;   { +0x02f }
    YearsId: Word;                { +0x048 }
    LandName: array[0..40] of Char;    { +0x04a }
    Land: LongInt;                { +0x073 }
    LandDate: array[0..24] of Char;    { +0x077 }
    LandId: Word;                 { +0x090 }
    PopName: array[0..40] of Char;     { +0x092 }
    Pop: LongInt;                 { +0x0bb }
    PopDate: array[0..24] of Char;     { +0x0bf }
    PopId: Word;                  { +0x0d8 }
    Check2: LongInt;              { +0x0da the sum of all }
    TalerName: array[0..40] of Char;   { +0x0de }
    Taler: LongInt;               { +0x107 }
    TalerDate: array[0..24] of Char;   { +0x10b }
    TalerId: Word;                { +0x124 }
    HeroRuler: array[0..40] of Char;   { +0x126 }
    HeroName: array[0..24] of Char;    { +0x14f }
    HeroLevel: Byte;              { +0x168 }
    Marker: Char;                 { +0x169 'V' }
    HeroKills: SmallInt;          { +0x16a }
    HeroDate: array[0..24] of Char;    { +0x16c }
    HeroId: Word;                 { +0x185 }
  end;

{ CmAnnalen (1000:1541): the annals of table 0 }
procedure Do_Annalen(Parent: Pointer);
{ CmRekorde (1000:1575) }
procedure Do_Rekorde(Parent: Pointer);
{ 1040:3f44: HIGHSCOREDLG on Table (Mode: the table shown first), then the
  annals are saved }
procedure ShowHighScoreDlg(Parent: Pointer; var Table: TAnnals; Mode: Byte);
{ 1040:44f8: REKORDDLG, then the records are saved }
procedure ShowRecordsDlg(Parent: Pointer; var R: TRecords);
{ 1040:4bc7: KROENUNGSDLG / KROENCOMPDLG }
procedure ShowCoronation(Parent: Pointer; const P: TPlayer; Me, Year: Byte);
{ 1040:3fc4: the winner into table Difficulty (once per game) }
procedure AddHighScore(Parent: Pointer; var Players: TPlayers; Me, NumPlayers,
  Difficulty: Byte; Year: Word);
{ 1040:4557: the winner's records }
procedure UpdateRecords(const P: TPlayer; Year: Word);
{ Victory (1000:3459) without the e-mail game: coronation, annals, records }
procedure Victory(Parent: Pointer; var Players: TPlayers);

{ the file part (segment 11), for the GUI }
function AnnalsLoad(const FileName: string; var Table: TAnnals): Boolean;      { 1050:0070 }
procedure AnnalsSave(const FileName: string; const Table: TAnnals);           { 1050:000d }
procedure RecordsDefaults(var R: TRecords);
procedure RecordsLoad(const FileName: string; var R: TRecords);               { 1050:011d }
procedure RecordsSave(const FileName: string; var R: TRecords);               { 1050:030f }

type
  { HIGHSCOREDLG (VMT DS:248c, 1040:40f8): the tables at +0x2e, the table
    shown +0xaf0; statics 401 title, 101+i names, 601+i spells, 201+i scores,
    301+i years; 501 next table, 701 clear the table }
  THighScoreDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
    procedure ShowTable;
    function Handle(Id: SmallInt): Boolean; override;
  end;

  { REKORDDLG (VMT DS:1e76, 1040:484f): the records at +0x2e; statics 101..109 }
  TRecordsDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

  { KROENUNGSDLG (VMT DS:1e22, 1040:4cd7): the title +0x36, the text +0x136 }
  TCoronationDlg = class(TDialogLogic)
  public
    procedure SetupWindow; override;
  end;

implementation

uses
  Game;

{ -- files -------------------------------------------------------------------- }

function AnnalsLoad(const FileName: string; var Table: TAnnals): Boolean;
var
  F: File;
  Magic: Char;
  N: LongInt;
begin
  Result := False;
  if not FileExists(FileName) then
    Exit;
  AssignFile(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then
    Exit;
  try
    BlockRead(F, Magic, 1, N);
    if (N = 1) and (Magic = '{') then
    begin
      BlockRead(F, Table, AnnalsSize, N);
      Result := N >= AnnalsSize;
    end;
  finally
    CloseFile(F);
  end;
end;

procedure AnnalsSave(const FileName: string; const Table: TAnnals);
var
  F: File;
begin
  ForceDirectories(ExtractFilePath(FileName));
  AssignFile(F, FileName);
  Rewrite(F, 1);
  try
    BlockWrite(F, DS.Game.Magic, 1);           // the magic byte (an opening brace)
    BlockWrite(F, Table, AnnalsSize);
  finally
    CloseFile(F);
  end;
end;

procedure RecordsDefaults(var R: TRecords);
var
  Date, Name: array[0..40] of Char;
begin
  StrCopy(Date, DSText($3170));
  StrCopy(Name, DSText($317B));               { Kaiser Arno Nymus von Niemandsland }
  StrCopy(R.YearsName, Name);
  R.Years := 100;
  R.YearsId := 0;
  StrCopy(R.YearsDate, Date);
  StrCopy(R.LandName, Name);
  R.Land := 100000;
  R.LandId := 0;
  StrCopy(R.LandDate, Date);
  StrCopy(R.PopName, Name);
  R.Pop := 10000;
  R.PopId := 0;
  StrCopy(R.PopDate, Date);
  StrCopy(R.TalerName, Name);
  R.Taler := 1000000;
  R.TalerId := 0;
  StrCopy(R.TalerDate, Date);
  StrCopy(R.HeroRuler, Name);
  StrCopy(R.HeroName, DSText($319E));          { Sir Iggy }
  R.HeroLevel := 6;
  R.HeroKills := 1;
  R.HeroId := 0;
  StrCopy(R.HeroDate, Date);
end;

procedure RecordsLoad(const FileName: string; var R: TRecords);
var
  F: File;
  N: LongInt;
  Bad: Boolean;
begin
  Bad := True;
  if FileExists(FileName) then
  begin
    AssignFile(F, FileName);
    {$I-} Reset(F, 1); {$I+}
    if IOResult = 0 then
    begin
      BlockRead(F, R, RecordsSize, N);
      CloseFile(F);
      Bad := N < RecordsSize;
    end;
  end;
  if not Bad and (R.Marker <> 'V') then
    Bad := True;
  if Bad then
    RecordsDefaults(R);
end;

procedure RecordsSave(const FileName: string; var R: TRecords);
var
  F: File;
begin
  R.Marker := 'V';
  R.Check1 := LongInt(LongInt(R.Years) + R.Pop - R.Land + R.Taler - R.HeroLevel - R.HeroKills);
  R.Check2 := LongInt(LongInt(R.Years) + R.Pop + R.Land + R.Taler + R.HeroLevel + R.HeroKills);
  ForceDirectories(ExtractFilePath(FileName));
  AssignFile(F, FileName);
  Rewrite(F, 1);
  try
    BlockWrite(F, R, RecordsSize);
  finally
    CloseFile(F);
  end;
end;

{ -- the dialogs --------------------------------------------------------------- }

procedure ShowHighScoreDlg(Parent: Pointer; var Table: TAnnals; Mode: Byte);
var
  D: TDialog;
begin
  D := UI.Dialog('HighScoreDlg', $248C, [APtr(Parent), AStr(DSText($24E0))]);
  Move(Table, D.Data[$2E], AnnalsSize);
  D.Data[$AF0] := Mode;
  UI.Execute(D);
  Move(D.Data[$2E], Table, AnnalsSize);
  UI.Done(D, 1);
  UI.Call('Annals_Save', [ARec(@Table, AnnalsSize)]);
end;

procedure THighScoreDlg.SetupWindow;
begin
  ShowTable;
end;

procedure THighScoreDlg.ShowTable;
const
  Titles: array[0..4] of Word = ($24EE, $2502, $2519, $252D, $253F);
var
  T, I: Integer;
  E: PScoreEntry;
  Buf: array[0..80] of Char;
begin
  T := D.Data[$AF0];
  if T <= 4 then
    C.SetText(401, DSText(Titles[T]))
  else
    C.SetText(401, '');                 { (the original shows its stale buffer) }
  for I := 0 to 9 do
  begin
    E := PScoreEntry(@D.Data[$2E + T * $226 + I * $32]);
    C.SetText(101 + I, E^.Name);
    if E^.Spell = 0 then
      C.SetText(601 + I, DSText($24EE + $13))
    else
      C.SetText(601 + I, DSText($497C + E^.Spell * 25));     { SpellNames }
    IntToPChar(Buf, E^.Score);
    C.SetText(201 + I, Buf);
    IntToPChar(Buf, E^.Year);
    C.SetText(301 + I, Buf);
  end;
end;

function THighScoreDlg.Handle(Id: SmallInt): Boolean;
begin
  Result := True;
  case Id of
    501: D.Data[$AF0] := (D.Data[$AF0] + 1) mod 5;
    701: FillChar(D.Data[$2E + D.Data[$AF0] * $226], $226, 0);
  else
    Exit(False);
  end;
  ShowTable;
end;

procedure ShowRecordsDlg(Parent: Pointer; var R: TRecords);
var
  D: TDialog;
begin
  D := UI.Dialog('RecordsDlg', $1E76, [APtr(Parent), AStr(DSText($2552))]);
  Move(R, D.Data[$2E], RecordsSize);
  UI.Execute(D);
  UI.Done(D, 1);
  UI.Call('Records_Save', [ARec(@R, RecordsSize)]);
end;

procedure TRecordsDlg.SetupWindow;
var
  R: ^TRecords;
  S: array[0..127] of Char;
  N: array[0..21] of Char;
begin
  R := @D.Data[$2E];
  { "<ruler> konnte es in lediglich n Jahren ...", the largest realm, the
    most subjects, the richest, the best hero and whom he served }
  StrCopy(S, R^.YearsName);
  StrCat(S, DSText($255E));
  C.SetText(101, S);
  StrCopy(S, DSText($2569));
  IntToPChar(N, R^.Years);
  StrCat(S, N);
  StrCat(S, DSText($2574));
  C.SetText(102, S);
  StrCopy(S, R^.LandName);
  StrCat(S, DSText($257C));
  C.SetText(103, S);
  FormatThousands(N, R^.Land);
  StrCopy(S, N);
  StrCat(S, DSText($258A));
  C.SetText(104, S);
  StrCopy(S, R^.PopName);
  StrCat(S, DSText($25B8));
  FormatThousands(N, R^.Pop);
  StrCat(S, N);
  StrCat(S, DSText($25DE));
  C.SetText(105, S);
  StrCopy(S, DSText($25EB));
  FormatThousands(N, R^.Taler);
  StrCat(S, N);
  StrCat(S, DSText($25F7));
  C.SetText(106, S);
  StrCopy(S, R^.TalerName);
  StrCat(S, DSText($257A));
  C.SetText(107, S);
  StrCopy(S, R^.HeroName);
  StrCat(S, DSText($2617));
  HeroRankName(R^.HeroLevel, N);
  StrCat(S, N);
  StrCat(S, DSText($261E));
  IntToPChar(N, R^.HeroKills);
  StrCat(S, N);
  StrCat(S, DSText($2629));
  C.SetText(108, S);
  StrCopy(S, DSText($2637));
  StrCat(S, R^.HeroRuler);
  StrCat(S, DSText($2645));
  C.SetText(109, S);
end;

procedure ShowCoronation(Parent: Pointer; const P: TPlayer; Me, Year: Byte);
var
  D: TDialog;
  S, N: array[0..255] of Char;
begin
  if P.CpuLevel = 0 then
    D := UI.Dialog('CoronationDlg', $1E22, [APtr(Parent), AStr(DSText($2648))])
  else
    D := UI.Dialog('CoronationDlg', $1E22, [APtr(Parent), AStr(DSText($2655))]);
  FormatPlayerTitle(P, PChar(@D.Data[$36]), 0, 0);
  { "Wisset, dass im Jahre <year> ..." (the year passed as a byte) }
  StrCopy(S, DSText($2662));
  IntToPChar(N, Year + 1400);
  StrCat(S, N);
  StrCopy(N, DSText($2678));
  StrCat(S, N);
  StrCopy(PChar(@D.Data[$136]), S);
  UI.Call('PlaySound', [AWord($0D), AWord(1)]);
  UI.Execute(D);
  UI.Done(D, 1);
end;

procedure TCoronationDlg.SetupWindow;
begin
  C.SetText(101, PChar(@D.Data[$136]));
  C.SetText(102, PChar(@D.Data[$36]));
end;

{ -- the game's end ---------------------------------------------------------------- }

procedure Do_Annalen(Parent: Pointer);
var
  T: TAnnals;
begin
  if UI.Call('Annals_Load', [ARec(@T, AnnalsSize)]) = 0 then
    ClearHighScores(T);
  ShowHighScoreDlg(Parent, T, 0);
end;

procedure Do_Rekorde(Parent: Pointer);
var
  R: TRecords;
begin
  UI.Call('Records_Load', [ARec(@R, RecordsSize)]);
  ShowRecordsDlg(Parent, R);
end;

procedure AddHighScore(Parent: Pointer; var Players: TPlayers; Me, NumPlayers,
  Difficulty: Byte; Year: Word);
var
  T: TAnnals;
  K: Integer;
  Found: Boolean;
  E: PScoreEntry;
  Name: array[0..81] of Char;
begin
  if UI.Call('Annals_Load', [ARec(@T, AnnalsSize)]) = 0 then
    ClearHighScores(T);
  Found := False;
  K := 0;
  while (K < 10) and not Found do
  begin
    Found := PScoreEntry(@T[Difficulty * $226 + K * $32])^.GameId = DS.Game.GameId;
    Inc(K);
  end;
  if Found then
    Exit;
  E := PScoreEntry(@T[Difficulty * $226 + 10 * $32]);     { the 11th entry }
  FormatPlayerTitle(Players[Me], Name, 0, 0);
  StrCopy(E^.Name, Name);
  E^.Spell := Players[Me].Spell;
  E^.Score := ComputeScore(Players[Me], NumPlayers, Year);
  E^.Year := Word(Year + 1400);
  E^.GameId := DS.Game.GameId;
  SortHighScoreTable(T[Difficulty * $226]);
  ShowHighScoreDlg(Parent, T, Difficulty);
end;

procedure UpdateRecords(const P: TPlayer; Year: Word);
var
  R: TRecords;
  Y, M, D, W: Word;
  Date, N: array[0..25] of Char;
  Changed: Boolean;
  U: PUnit;
  Q: TPlayer;
begin
  DecodeDate(SysUtils.Date, Y, M, D);
  W := 0;
  IntToPChar(N, D);
  StrCopy(Date, N);
  StrCat(Date, DSText($255C));
  IntToPChar(N, M);
  StrCat(Date, N);
  StrCat(Date, DSText($255C));
  IntToPChar(N, Y);
  StrCat(Date, N);
  UI.Call('Records_Load', [ARec(@R, RecordsSize)]);
  Changed := False;
  if (Year < R.Years) and (DS.Game.GameId <> R.YearsId) then
  begin
    FormatPlayerTitle(P, R.YearsName, 0, 0);
    R.Years := Year;
    R.YearsId := DS.Game.GameId;
    StrCopy(R.YearsDate, Date);
    Changed := True;
  end;
  if (P.Land > R.Land) and (DS.Game.GameId <> R.LandId) then
  begin
    FormatPlayerTitle(P, R.LandName, 0, 0);
    R.Land := P.Land;
    R.LandId := DS.Game.GameId;
    StrCopy(R.LandDate, Date);
    Changed := True;
  end;
  if (P.Population > R.Pop) and (DS.Game.GameId <> R.PopId) then
  begin
    FormatPlayerTitle(P, R.PopName, 0, 0);
    R.Pop := P.Population;
    R.PopId := DS.Game.GameId;
    StrCopy(R.PopDate, Date);
    Changed := True;
  end;
  if (P.Taler > R.Taler) and (DS.Game.GameId <> R.TalerId) then
  begin
    FormatPlayerTitle(P, R.TalerName, 0, 0);
    R.Taler := P.Taler;
    R.TalerId := DS.Game.GameId;
    StrCopy(R.TalerDate, Date);
    Changed := True;
  end;
  Q := P;
  if FindHero(Q, U, 1) and
     (SmallInt(U^.Level * 3 + SmallInt(U^.Kills)) > SmallInt(R.HeroLevel * 3 + R.HeroKills)) and
     (DS.Game.GameId <> R.HeroId) then
  begin
    FormatPlayerTitle(P, R.HeroRuler, 0, 0);
    StrCopy(R.HeroName, U^.Name);
    R.HeroLevel := U^.Level;
    R.HeroKills := SmallInt(U^.Kills);
    R.HeroId := DS.Game.GameId;
    StrCopy(R.HeroDate, Date);
    Changed := True;
  end;
  if Changed then
    UI.Call('Records_Save', [ARec(@R, RecordsSize)]);
end;

procedure Victory(Parent: Pointer; var Players: TPlayers);
var
  Me: Byte;
begin
  Me := DS.Game.CurrentPlayer;
  ShowCoronation(Parent, Players[Me], Me, Byte(DS.Game.Year));
  if (Players[Me].CpuLevel = 0) and (DS.Game.Immortality = 0) and
     (DS.Game.InitiativeEnabled <> 0) and (DS.Game.CensusEditorEnabled = 0) then
  begin
    AddHighScore(Parent, Players, Me, DS.Game.NumPlayers, DS.Game.CpuDifficulty, DS.Game.Year);
    UpdateRecords(Players[Me], DS.Game.Year);
  end;
end;

initialization
  RegisterDialogLogic('HighScoreDlg', THighScoreDlg);
  RegisterDialogLogic('RecordsDlg', TRecordsDlg);
  RegisterDialogLogic('CoronationDlg', TCoronationDlg);
end.
