{ The program's start-up globals (segment 18, 1088:0002) and KAISER.INI
  (segment 11: Ini_ReadSettings 1050:0ade, Ini_WriteSettings 1050:0e65,
  Ini_ReadLastGame / Ini_WriteLastGame). Keys and values are CP1252 like the
  original file. The original KAISER.INI is only read; the port writes its
  own copy (IniFileName). }
unit KaiserIni;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, IniFiles, Strings, KaiserDS, PixelScale;

{ Unit18_InitGlobals: background RGB(255,255,172), Delta 0/0, Schlacht-Timer
  400, the runtime name tables from the built-in names, no human names }
procedure InitGlobals;
procedure ReadSettings(const FileName: string);
procedure WriteSettings(const FileName: string);
function ReadLastGame(const FileName: string): string;
procedure WriteLastGame(const FileName, Path, Name: string);

implementation

const
  Section = 'Kaiser';

procedure InitGlobals;
var
  I: Integer;
begin
  DS.Game.Magic := $7B;
  DS.OptBackground[0] := $FF;
  DS.OptBackground[1] := $FF;
  DS.OptBackground[2] := $AC;
  DS.OptDeltaX := 0;
  DS.OptDeltaY := 0;
  for I := 0 to 9 do
  begin
    StrCopy(DS.CountryNamesRt[I], DS.CountryNames[I]);
    StrCopy(DS.CountryAdjectives[I], DS.CountryNames[10 + I]);
    StrCopy(DS.CpuRulerNames[I], DS.UnitNames[I - 10]);
    DS.HumanNames[I][0] := #0;
  end;
  DS.OptBattleTimer := 400;
end;

{ GetPrivateProfileString into a char[25] table entry (at most 24 chars) }
procedure ReadName(Ini: TIniFile; const Key, Default: RawByteString; Dest: PChar);
var
  S: RawByteString;
begin
  S := Ini.ReadString(Section, Key, Default);
  StrPLCopy(Dest, S, 24);
end;

function OnOff(Ini: TIniFile; const Key: RawByteString; const Default: RawByteString): Byte;
begin
  Result := Ord(CompareText(Ini.ReadString(Section, Key, Default), 'an') = 0);
end;

procedure ReadSettings(const FileName: string);
var
  Ini: TIniFile;
  S: RawByteString;
  I: Integer;
begin
  { a missing file gives the defaults, as GetPrivateProfileString does (a
    fresh installation: autosave, sound and music on) }
  Ini := TIniFile.Create(FileName);
  try
    DS.OptAutosave := OnOff(Ini, 'Geschichtsschreibung', 'an');
    DS.OptSound := OnOff(Ini, 'Krach & Geschrei', 'an');
    DS.OptMusic := OnOff(Ini, 'Schalmeienkl'#$E4'nge', 'an');
    DS.OptDebug := OnOff(Ini, 'Debug', 'aus');
    { remastered: how the pictures are made larger }
    S := Ini.ReadString(Section, 'Grafik', 'xBRZ');
    if CompareText(S, 'ScaleNx') = 0 then
      ScaleMethod := smScaleNx
    else if CompareText(S, 'Pixel') = 0 then
      ScaleMethod := smNearest
    else
      ScaleMethod := smXBRZ;
    S := Ini.ReadString(Section, 'Aufl'#$F6'sung', '640x480');
    if CompareText(S, '800x600') = 0 then
      DS.OptResolution := 1
    else if CompareText(S, '1024x768') = 0 then
      DS.OptResolution := 2
    else
      DS.OptResolution := 0;
    DS.OptBackground[0] := Byte(Ini.ReadInteger(Section, 'Hintergrund rot', DS.OptBackground[0]));
    DS.OptBackground[1] := Byte(Ini.ReadInteger(Section, 'Hintergrund gr'#$FC'n', DS.OptBackground[1]));
    DS.OptBackground[2] := Byte(Ini.ReadInteger(Section, 'Hintergrund blau', DS.OptBackground[2]));
    DS.OptDeltaX := SmallInt(Ini.ReadInteger(Section, 'Delta X', DS.OptDeltaX));
    DS.OptDeltaY := SmallInt(Ini.ReadInteger(Section, 'Delta Y', DS.OptDeltaY));
    DS.OptBattleTimer := Word(Ini.ReadInteger(Section, 'Schlacht-Timer', DS.OptBattleTimer));
    if DS.OptBattleTimer < 50 then
      DS.OptBattleTimer := 50;
    for I := 0 to 9 do
    begin
      ReadName(Ini, DS.CountryNames[I], DS.CountryNames[I], DS.CountryNamesRt[I]);
      ReadName(Ini, DS.CountryNames[10 + I], DS.CountryNames[10 + I], DS.CountryAdjectives[I]);
    end;
    for I := 0 to 9 do
      ReadName(Ini, 'Spieler' + IntToStr(I), '', DS.HumanNames[I]);
    for I := 0 to 9 do
      ReadName(Ini, DS.UnitNames[I - 10], DS.UnitNames[I - 10], DS.CpuRulerNames[I]);
  finally
    Ini.Free;
  end;
end;

procedure WriteSettings(const FileName: string);
const
  AnAus: array[Boolean] of RawByteString = ('aus', 'an');
  Res: array[0..2] of RawByteString = ('640x480', '800x600', '1024x768');
  Methods: array[TScaleMethod] of RawByteString = ('xBRZ', 'ScaleNx', 'Pixel');
var
  Ini: TIniFile;
  I: Integer;
begin
  ForceDirectories(ExtractFilePath(FileName));
  Ini := TIniFile.Create(FileName);
  try
    Ini.WriteString(Section, 'Geschichtsschreibung', AnAus[DS.OptAutosave <> 0]);
    Ini.WriteString(Section, 'Krach & Geschrei', AnAus[DS.OptSound <> 0]);
    Ini.WriteString(Section, 'Schalmeienkl'#$E4'nge', AnAus[DS.OptMusic <> 0]);
    Ini.WriteString(Section, 'Aufl'#$F6'sung', Res[DS.OptResolution mod 3]);
    Ini.WriteString(Section, 'Grafik', Methods[ScaleMethod]);
    Ini.WriteInteger(Section, 'Hintergrund rot', DS.OptBackground[0]);
    Ini.WriteInteger(Section, 'Hintergrund gr'#$FC'n', DS.OptBackground[1]);
    Ini.WriteInteger(Section, 'Hintergrund blau', DS.OptBackground[2]);
    Ini.WriteInteger(Section, 'Delta X', DS.OptDeltaX);
    Ini.WriteInteger(Section, 'Delta Y', DS.OptDeltaY);
    Ini.WriteInteger(Section, 'Schlacht-Timer', DS.OptBattleTimer);
    for I := 0 to 9 do
    begin
      Ini.WriteString(Section, DS.CountryNames[I], DS.CountryNamesRt[I]);
      Ini.WriteString(Section, DS.CountryNames[10 + I], DS.CountryAdjectives[I]);
    end;
    for I := 0 to 9 do
      Ini.WriteString(Section, 'Spieler' + IntToStr(I), DS.HumanNames[I]);
    for I := 0 to 9 do
      Ini.WriteString(Section, DS.UnitNames[I - 10], DS.CpuRulerNames[I]);
  finally
    Ini.Free;
  end;
end;

function ReadLastGame(const FileName: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  if not FileExists(FileName) then
    Exit;
  Ini := TIniFile.Create(FileName);
  try
    Result := Ini.ReadString(Section, 'Letzter Pfad', '');
  finally
    Ini.Free;
  end;
end;

procedure WriteLastGame(const FileName, Path, Name: string);
var
  Ini: TIniFile;
begin
  ForceDirectories(ExtractFilePath(FileName));
  Ini := TIniFile.Create(FileName);
  try
    Ini.WriteString(Section, 'Letzter Pfad', Path);
    Ini.WriteString(Section, 'Letzte Datei', Name);
  finally
    Ini.Free;
  end;
end;

end.
