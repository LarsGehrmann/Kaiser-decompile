{ A TGameUI for the differential tests: formats every UI call like
  tools/emu/ui_stubs.py and answers it from the recorded calls of the
  original (the ui= field of a vector). Log holds what the port did, with
  '!' after a call that does not match the recording. }
unit ReplayUI;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, KaiserTypes, KaiserDS, KaiserUI, NERes, ScriptControls;

type
  TReplayUI = class(TGameUI)
  private
    FExpected: TStringList;
    FPos: Integer;
    FLog: TStringList;
    function Sym(P: Pointer): string;
    function FormatArgs(const Args: array of TUIArg): string;
    { match the next recorded call; returns the recorded result part
      after '=' ('' if none) }
    function Take(const Entry: string): string;
    function Answer(const R: string; D: TDialog): SmallInt;
  public
    PlayersBase: PByte;
    Exe: TNEFile;                    { the templates of the ported dialog types }
    DlgScripts: TStringList;         { the user events per real dialog (dlg=) }
    BattleBase: PByte;               { the battle window object: B<offset> }
    { the dialog type a Dlg_ vector runs for real: the emulator fakes the
      other types of its CTORS (tools/emu/ui_stubs.py), so does the replay }
    Unstubbed: string;
    constructor Create;
    destructor Destroy; override;
    procedure Start(const Recorded: string);
    function LogText: string;
    function LogicFor(const Name: string): TDialogLogicClass; override;
    function Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog; override;
    function Execute(D: TDialog): SmallInt; override;
    procedure Done(D: TDialog; Flag: Word); override;
    function ExecDialog(D: TDialog): SmallInt; override;
    function GetText(D: TDialog): PChar; override;
    function Call(const Name: string; const Args: array of TUIArg): SmallInt; override;
    procedure Note(const Entry: string); override;
  end;

implementation

function HexOfMem(P: PByte; N: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to N - 1 do
    Result := Result + LowerCase(IntToHex(P[I], 2));
end;

constructor TReplayUI.Create;
begin
  inherited Create;
  DlgScripts := TStringList.Create;
  DlgScripts.Delimiter := '/';
  DlgScripts.StrictDelimiter := True;
  FExpected := TStringList.Create;
  FExpected.Delimiter := '|';
  FExpected.StrictDelimiter := True;
  FLog := TStringList.Create;
end;

destructor TReplayUI.Destroy;
begin
  FExpected.Free;
  FLog.Free;
  inherited Destroy;
end;

procedure TReplayUI.Start(const Recorded: string);
begin
  Reset;
  FLog.Clear;
  FPos := 0;
  if (Recorded = '-') or (Recorded = '') then
    FExpected.Clear
  else
    FExpected.DelimitedText := Recorded;
end;

function TReplayUI.LogText: string;
var
  I: Integer;
begin
  if FLog.Count = 0 then
    Exit('-');
  Result := FLog[0];
  for I := 1 to FLog.Count - 1 do
    Result := Result + '|' + FLog[I];
end;

function TReplayUI.Sym(P: Pointer): string;
var
  A, B: PtrUInt;
  I: Integer;
begin
  A := PtrUInt(P);
  if P = Window then
    Exit('W');
  B := PtrUInt(BattleBase);
  if (BattleBase <> nil) and (A >= B) and (A < B + BattleSize) then
    Exit('B' + IntToStr(A - B));
  B := PtrUInt(PlayersBase);
  if (A >= B) and (A < B + 10 * PlayerSize) then
    Exit(Format('P%d:%d', [(A - B) div PlayerSize, (A - B) mod PlayerSize]));
  B := PtrUInt(@DS);
  if (A >= B) and (A < B + SizeOf(DS)) then
    Exit('D' + IntToStr(A - B));
  if P = nil then
    Exit('nil');
  { into a ported dialog's object (e.g. its copy of the player) }
  for I := 0 to High(FDialogs) do
    if FDialogs[I].Logic <> nil then
    begin
      B := PtrUInt(@FDialogs[I].Data[0]);
      if (A > B) and (A < B + FDialogs[I].Size) then
        Exit(Format('O%d+%d', [FDialogs[I].Index, A - B]));
    end;
  Result := 'S';
end;

function TReplayUI.FormatArgs(const Args: array of TUIArg): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := 0 to High(Args) do
  begin
    case Args[I].Kind of
      uaPtr:
        if FindDialog(Args[I].P) <> nil then
          S := 'O' + IntToStr(FindDialog(Args[I].P).Index)
        else
          S := Sym(Args[I].P);
      uaStr:
        if PtrUInt(Args[I].P) < $10000 then                 { MAKEINTRESOURCE }
          S := 'i:' + IntToStr(PtrUInt(Args[I].P))
        else
          S := 's:' + HexOfMem(PByte(Args[I].P), StrLen(PChar(Args[I].P)));
      uaWord: S := IntToStr(Word(Args[I].V));
      uaByte: S := IntToStr(Byte(Args[I].V));
      uaLong: S := IntToStr(Args[I].V);
      uaRec: S := 'r' + IntToStr(Args[I].Len) + ':' + HexOfMem(PByte(Args[I].P), Args[I].Len);
    end;
    if I > 0 then
      Result := Result + ',';
    Result := Result + S;
  end;
end;

function TReplayUI.Take(const Entry: string): string;
var
  E: string;
begin
  Result := '';
  if FPos < FExpected.Count then
    E := FExpected[FPos]
  else
    E := '';
  Inc(FPos);
  if (E = Entry) then
    Exit('');
  if Copy(E, 1, Length(Entry) + 1) = Entry + '=' then
    Exit(Copy(E, Length(Entry) + 2, MaxInt));
  Result := '!';
end;

function TReplayUI.Answer(const R: string; D: TDialog): SmallInt;
var
  Parts: TStringList;
  I, Off, K, Colon: Integer;
  H: string;
begin
  { "ax+off:hex+off:hex" }
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '+';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := R;
    if Parts.Count = 0 then
      Exit(0);
    Result := StrToIntDef(Parts[0], 0);
    for I := 1 to Parts.Count - 1 do
    begin
      Colon := Pos(':', Parts[I]);
      Off := StrToInt('$' + Copy(Parts[I], 1, Colon - 1));
      H := Copy(Parts[I], Colon + 1, MaxInt);
      if D <> nil then
        for K := 0 to Length(H) div 2 - 1 do
          D.Data[Off + K] := StrToInt('$' + Copy(H, 2 * K + 1, 2));
    end;
  finally
    Parts.Free;
  end;
end;

const
  { the constructors tools/emu/ui_stubs.py fakes (CTORS) }
  FakedCtors: array[0..18] of string = ('KaiserDlg', 'MessageDlg', 'HelpMessageDlg',
    'Message2Dlg', 'HeroNameDlg', 'UnitInfoDlg', 'PromotionDlg', 'StartFinanzDlg',
    'StartPopDlg', 'HexenDlg', 'HumanCountDlg', 'ComputerCountDlg', 'PlayerDataDlg',
    'TButton', 'ButtonChoiceDlg', 'HelpChoice2Dlg', 'MassacreDlg', 'PlunderResultDlg',
    'PlunderChoiceDlg');

function TReplayUI.LogicFor(const Name: string): TDialogLogicClass;
var
  I: Integer;
begin
  if Name <> Unstubbed then
    for I := 0 to High(FakedCtors) do
      if FakedCtors[I] = Name then
        Exit(nil);
  Result := inherited LogicFor(Name);
end;

function TReplayUI.Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog;
var
  Entry: string;
begin
  Result := inherited Dialog(Name, VMT, Args);
  if Result.Logic <> nil then
    { a ported dialog type: the emulator sees its constructor's call of
      KaiserDlg.Init (parent, name) as an inherited constructor }
    Entry := Format('KaiserDlg[0](%s)', [FormatArgs(Slice(Args, 2))])
  else
    Entry := Format('%s[%s](%s)', [Name, LowerCase(IntToHex(VMT, 1)), FormatArgs(Args)]);
  if Take(Entry) = '!' then
    FLog.Add(Entry + '!')
  else
    FLog.Add(Entry + '=O' + IntToStr(Result.Index));
end;

{ bytes 2..size of the dialog object, trailing zeros dropped }
function Contents(D: TDialog): string;
var
  N: Integer;
begin
  N := D.Size;
  if N > Length(D.Data) then
    N := Length(D.Data);
  while (N > 2) and (D.Data[N - 1] = 0) do
    Dec(N);
  if N <= 2 then
    Exit('');
  Result := HexOfMem(@D.Data[2], N - 2);
end;

function TReplayUI.Execute(D: TDialog): SmallInt;
var
  Entry, R, Script: string;
begin
  if D.Logic <> nil then
  begin
    { play the recorded user events on the ported dialog type }
    Script := '';
    if DlgScripts.Count > 0 then
    begin
      Script := DlgScripts[0];
      DlgScripts.Delete(0);
    end;
    Exit(RunScript(D, Exe.DialogRes(PChar(TDialogLogic(D.Logic).Args[1].P)), Script));
  end;
  Entry := 'Execute(O' + IntToStr(D.Index) + ');d:' + Contents(D);
  R := Take(Entry);
  if R = '!' then
  begin
    FLog.Add(Entry + '!');
    Exit(0);
  end;
  FLog.Add(Entry + '=' + R);
  Result := Answer(R, D);
end;

procedure TReplayUI.Done(D: TDialog; Flag: Word);
var
  Entry: string;
begin
  if D.Logic <> nil then
    Flag := TDialogLogic(D.Logic).DoneFlag(Flag);
  Entry := Format('Done(O%d,%d)', [D.Index, Byte(Flag)]);
  if Take(Entry) = '!' then
    Entry := Entry + '!';
  FLog.Add(Entry);
end;

function TReplayUI.ExecDialog(D: TDialog): SmallInt;
var
  Entry, R: string;
begin
  Entry := 'ExecDialog(A,O' + IntToStr(D.Index) + ');d:' + Contents(D);
  R := Take(Entry);
  if R = '!' then
  begin
    FLog.Add(Entry + '!');
    Exit(0);
  end;
  FLog.Add(Entry + '=' + R);
  Result := Answer(R, D);
end;

function TReplayUI.GetText(D: TDialog): PChar;
var
  Entry: string;
begin
  Entry := 'GetText(O' + IntToStr(D.Index) + ')';
  if Take(Entry) = '!' then
    Entry := Entry + '!';
  FLog.Add(Entry);
  if D.Logic <> nil then
    Result := TDialogLogic(D.Logic).GetText
  else
    Result := D.Text;
end;

procedure TReplayUI.Note(const Entry: string);
begin
  if Take(Entry) = '!' then
    FLog.Add(Entry + '!')
  else
    FLog.Add(Entry);
end;

function TReplayUI.Call(const Name: string; const Args: array of TUIArg): SmallInt;
var
  Entry, R: string;
begin
  Entry := Format('%s(%s)', [Name, FormatArgs(Args)]);
  R := Take(Entry);
  if R = '!' then
  begin
    FLog.Add(Entry + '!');
    Exit(0);
  end;
  if R = '' then
    FLog.Add(Entry)
  else
    FLog.Add(Entry + '=' + R);
  Result := Answer(R, nil);
end;

end.
