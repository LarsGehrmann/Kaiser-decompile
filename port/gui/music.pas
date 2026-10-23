{ The music ("Schalmeienklänge"): kaiser.mid next to kaiser.exe, played in a
  loop. The original (segment 1) opens it with MCI (MidiOpen 1000:0920),
  plays it with MCI_NOTIFY (MidiPlay 1000:0985) and starts it again when the
  notification says it ended (MMMciNotify 1000:09cf); MidiClose (1000:0a0e)
  stops it. Windows: MCI as well (mciSendString, the end found by polling the
  mode); macOS: AVMIDIPlayer with the system's General MIDI sound bank.
  Silent under the autopilot. }
unit Music;

{$mode objfpc}{$H+}
{$ifdef darwin}
{$modeswitch objectivec1}
{$linkframework AVFoundation}
{$endif}

interface

{ MidiOpen + MidiPlay: False when the file cannot be played }
function MusicPlay(const FileName: string): Boolean;
{ MidiClose }
procedure MusicStop;
function MusicOpen: Boolean;

implementation

uses
  SysUtils, ExtCtrls, Classes
  {$ifdef windows}, MMSystem{$endif}
  {$ifdef darwin}, CocoaAll{$endif};

{$ifdef darwin}
type
  AVMIDIPlayer = objcclass external (NSObject)
  public
    function initWithContentsOfURL_soundBankURL_error(InURL: NSURL; BankURL: NSURL;
      OutError: Pointer): id; message 'initWithContentsOfURL:soundBankURL:error:';
    procedure prepareToPlay; message 'prepareToPlay';
    procedure play(CompletionHandler: Pointer); message 'play:';
    procedure stop; message 'stop';
    function isPlaying: ObjCBOOL; message 'isPlaying';
    procedure setCurrentPosition(Pos: Double); message 'setCurrentPosition:';
  end;

var
  Player: AVMIDIPlayer;
{$endif}

type
  { the end of the piece: play it again (MMMciNotify) }
  TLoop = class
    procedure Tick(Sender: TObject);
  end;

var
  Opened: Boolean;
  Timer: TTimer;
  Loop: TLoop;

const
  Alias = 'kaisermusic';

procedure TLoop.Tick(Sender: TObject);
{$ifdef windows}
var
  Mode: array[0..31] of Char;
{$endif}
begin
  if not Opened then
    Exit;
  {$ifdef windows}
  if mciSendString('status ' + Alias + ' mode', Mode, SizeOf(Mode), 0) = 0 then
    if StrComp(Mode, 'stopped') = 0 then
    begin
      mciSendString('seek ' + Alias + ' to start', nil, 0, 0);
      mciSendString('play ' + Alias, nil, 0, 0);
    end;
  {$endif}
  {$ifdef darwin}
  if not Player.isPlaying then
  begin
    Player.setCurrentPosition(0);
    Player.play(nil);
  end;
  {$endif}
end;

function MusicOpen: Boolean;
begin
  Result := Opened;
end;

function MusicPlay(const FileName: string): Boolean;
{$ifdef darwin}
var
  Url: NSURL;
{$endif}
begin
  Result := False;
  MusicStop;
  if (GetEnvironmentVariable('KAISER_AUTOPILOT') <> '') or not FileExists(FileName) then
    Exit;
  {$ifdef windows}
  { (the wide version: a path with non-ASCII characters) }
  if mciSendStringW(PWideChar(UnicodeString('open "' + UTF8Decode(FileName) + '" type sequencer alias ' +
    Alias)), nil, 0, 0) <> 0 then
    Exit;
  mciSendString('play ' + Alias, nil, 0, 0);
  {$endif}
  {$ifdef darwin}
  Url := NSURL.fileURLWithPath(NSString.stringWithUTF8String(PChar(FileName)));
  Player := AVMIDIPlayer.alloc.initWithContentsOfURL_soundBankURL_error(Url, nil, nil);
  if Player = nil then
    Exit;
  Player.prepareToPlay;
  Player.play(nil);
  {$endif}
  {$if not defined(windows) and not defined(darwin)}
  Exit;
  {$endif}
  Opened := True;
  if Timer = nil then
  begin
    Loop := TLoop.Create;
    Timer := TTimer.Create(nil);
    Timer.Interval := 1000;
    Timer.OnTimer := @Loop.Tick;
  end;
  Timer.Enabled := True;
  Result := True;
end;

procedure MusicStop;
begin
  if not Opened then
    Exit;
  Opened := False;
  if Timer <> nil then
    Timer.Enabled := False;
  {$ifdef windows}
  mciSendString('stop ' + Alias, nil, 0, 0);
  mciSendString('close ' + Alias, nil, 0, 0);
  {$endif}
  {$ifdef darwin}
  Player.stop;
  Player.release;
  Player := nil;
  {$endif}
end;

finalization
  MusicStop;
  Timer.Free;
  Loop.Free;
end.
