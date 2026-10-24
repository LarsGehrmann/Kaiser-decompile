{ The game's sounds (WAVEDATA of kaiser.exe, written to temp files) played
  in the process, like the original's sndPlaySound (MMSYSTEM.2): Sync waits
  for the end (SND_SYNC: the battle's strikes), a new sound stops the one
  before (sndPlaySound has one sound at a time). macOS: NSSound, each file
  loaded once (starting afplay for every sound took up to a second: the
  battle stalled after every strike); Windows: sndPlaySoundW. }
unit WaveSound;

{$mode objfpc}{$H+}
{$ifdef darwin}
{$modeswitch objectivec1}
{$endif}

interface

procedure PlayWaveFile(const FileName: string; Sync: Boolean);

implementation

uses
  SysUtils, Classes
  {$ifdef windows}, MMSystem{$endif}
  {$ifdef darwin}, CocoaAll{$endif};

{$ifdef darwin}
var
  Sounds: TStringList;           { file name -> NSSound }
  Current: NSSound;

procedure PlayWaveFile(const FileName: string; Sync: Boolean);
var
  K: Integer;
  S: NSSound;
begin
  if Sounds = nil then
    Sounds := TStringList.Create;
  K := Sounds.IndexOf(FileName);
  if K >= 0 then
    S := NSSound(Sounds.Objects[K])
  else
  begin
    S := NSSound.alloc.initWithContentsOfFile_byReference(
      NSString.stringWithUTF8String(PChar(FileName)), False);
    if S = nil then
      Exit;
    Sounds.AddObject(FileName, TObject(S));
  end;
  if Current <> nil then
    Current.stop;
  S.stop;
  S.setCurrentTime(0);
  Current := S;
  if not S.play then
    Exit;
  if Sync then
    { SND_SYNC: until the end (isPlaying needs a run loop to change) }
    Sleep(Round(S.duration * 1000));
end;

procedure FreeSounds;
var
  I: Integer;
begin
  if Sounds = nil then
    Exit;
  for I := 0 to Sounds.Count - 1 do
    NSSound(Sounds.Objects[I]).release;
  Sounds.Free;
end;
{$endif}

{$ifdef windows}
procedure PlayWaveFile(const FileName: string; Sync: Boolean);
begin
  { the wide version: a temp folder with non-ASCII characters }
  if Sync then
    sndPlaySoundW(PWideChar(UnicodeString(UTF8Decode(FileName))), SND_SYNC or SND_NODEFAULT)
  else
    sndPlaySoundW(PWideChar(UnicodeString(UTF8Decode(FileName))), SND_ASYNC or SND_NODEFAULT);
end;
{$endif}

{$if not defined(darwin) and not defined(windows)}
procedure PlayWaveFile(const FileName: string; Sync: Boolean);
begin
end;
{$endif}

{$ifdef darwin}
finalization
  FreeSounds;
{$endif}
end.
