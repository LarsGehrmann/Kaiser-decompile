{ Command-line tool for Kaiser savegames.

  ksrtool check FILE...        load every file, report errors
  ksrtool roundtrip FILE...    load and write to a temp file, compare bytes
  ksrtool show FILE            print a few fields per player }
program KsrTool;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, KaiserTypes, KaiserSave;

function ResultText(R: TLoadResult): string;
begin
  case R of
    lrOk: Result := 'ok';
    lrCannotOpen: Result := 'cannot open';
    lrBadMagic: Result := 'not a Kaiser savegame';
    lrShortRead: Result := 'file too short';
    lrBadChecksum: Result := 'checksum mismatch';
  end;
end;

function FilesEqual(const A, B: string): Boolean;
var
  SA, SB: TMemoryStream;
begin
  SA := TMemoryStream.Create;
  SB := TMemoryStream.Create;
  try
    SA.LoadFromFile(A);
    SB.LoadFromFile(B);
    Result := (SA.Size = SB.Size) and CompareMem(SA.Memory, SB.Memory, SA.Size);
  finally
    SA.Free;
    SB.Free;
  end;
end;

function CString(const A: array of Char): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do
  begin
    if A[I] = #0 then
      Break;
    Result := Result + A[I];
  end;
end;

var
  Mode, TempName: string;
  Save: TSaveGame;
  R: TLoadResult;
  I, P, Failed: Integer;
begin
  if ParamCount < 2 then
  begin
    WriteLn('usage: ksrtool check|roundtrip|show FILE...');
    Halt(2);
  end;
  Mode := ParamStr(1);
  Failed := 0;
  for I := 2 to ParamCount do
  begin
    R := LoadSaveGame(ParamStr(I), Save);
    if R <> lrOk then
    begin
      WriteLn('FAIL ', ParamStr(I), ': ', ResultText(R));
      Inc(Failed);
      Continue;
    end;
    if Mode = 'roundtrip' then
    begin
      TempName := GetTempFileName('', 'ksr');
      WriteSaveGame(TempName, Save);
      if FilesEqual(ParamStr(I), TempName) then
        WriteLn('same ', ParamStr(I))
      else
      begin
        WriteLn('DIFF ', ParamStr(I));
        Inc(Failed);
      end;
      DeleteFile(TempName);
    end
    else if Mode = 'show' then
    begin
      WriteLn(ParamStr(I), ': year ', 1400 + Save.Header.Year, ', ',
        Save.Header.NumPlayers, ' players');
      for P := 0 to Save.Header.NumPlayers - 1 do
        with Save.Players[P] do
          WriteLn(Format('  %-16s title %2d  pop %7d  taler %9d  land %7d  grain %7d',
            [CString(Name), Title, Population, Taler, Land, Grain]));
    end
    else
      WriteLn('ok   ', ParamStr(I));
  end;
  if Failed > 0 then
  begin
    WriteLn(Failed, ' failed');
    Halt(1);
  end;
  WriteLn(ParamCount - 1, ' files ok');
end.
