{ The boundary between game logic and user interface.

  The original game code builds OWL dialog objects (KaiserDlg.Init,
  MessageDlg.Init, ...), runs them with Execute and reads result fields
  from the object. The port keeps this protocol: the logic asks the UI for
  a dialog by the original constructor name, executes it and reads the
  results from TDialog.Data at the original field offsets. Whole UI
  functions (menus, reports, the battle, sounds) are called by name.

  TGameUI does nothing (every dialog "OK", no input); the GUI overrides it,
  the differential tests replay the UI calls the original made. }
unit KaiserUI;

{$mode objfpc}{$H+}

interface

uses
  KaiserDS;

const
  DialogTextOfs = $100;        { where GetText finds the entered text }

type
  TUIArgKind = (uaPtr, uaStr, uaWord, uaByte, uaLong, uaRec);
  TUIArg = record
    Kind: TUIArgKind;
    P: Pointer;
    V: LongInt;
    Len: Integer;
  end;

  { a dialog object; Data mirrors the original object (result fields) }
  TDialog = class
    Index: Integer;            { 1, 2, ... in order of creation }
    Name: string;              { constructor, e.g. 'MessageDlg' }
    VMT: Word;                 { the original dialog type (VMT offset in DS) }
    Size: Word;                { its instance size (from the VMT) }
    Data: array[0..$1FF] of Byte;
    function Text: PChar;
  end;

  TGameUI = class
  protected
    FDialogs: array of TDialog;
    function Register(D: TDialog): TDialog;
    function FindDialog(P: Pointer): TDialog;
  public
    destructor Destroy; override;
    { constructor of an original dialog type }
    function Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog; virtual;
    function Execute(D: TDialog): SmallInt; virtual;
    procedure Done(D: TDialog; Flag: Word); virtual;
    { Application^.ExecDialog }
    function ExecDialog(D: TDialog): SmallInt; virtual;
    function GetText(D: TDialog): PChar; virtual;
    { a whole UI function of the original }
    function Call(const Name: string; const Args: array of TUIArg): SmallInt; virtual;
    procedure Reset;
  end;

function APtr(P: Pointer): TUIArg;
function AStr(S: PChar): TUIArg;
function AWord(V: Word): TUIArg;
function AByte(V: Byte): TUIArg;
function ALong(V: LongInt): TUIArg;
function ARec(P: Pointer; Len: Integer): TUIArg;

var
  UI: TGameUI;
  Window: Pointer;             { the parent window the original passes around }

implementation

function TDialog.Text: PChar;
begin
  Result := PChar(@Data[DialogTextOfs]);
end;

function APtr(P: Pointer): TUIArg;
begin
  Result.Kind := uaPtr; Result.P := P; Result.V := 0; Result.Len := 0;
end;

function AStr(S: PChar): TUIArg;
begin
  Result.Kind := uaStr; Result.P := S; Result.V := 0; Result.Len := 0;
end;

function AWord(V: Word): TUIArg;
begin
  Result.Kind := uaWord; Result.P := nil; Result.V := V; Result.Len := 0;
end;

function AByte(V: Byte): TUIArg;
begin
  Result.Kind := uaByte; Result.P := nil; Result.V := V; Result.Len := 0;
end;

function ALong(V: LongInt): TUIArg;
begin
  Result.Kind := uaLong; Result.P := nil; Result.V := V; Result.Len := 0;
end;

function ARec(P: Pointer; Len: Integer): TUIArg;
begin
  Result.Kind := uaRec; Result.P := P; Result.V := 0; Result.Len := Len;
end;

function TGameUI.Register(D: TDialog): TDialog;
begin
  SetLength(FDialogs, Length(FDialogs) + 1);
  FDialogs[High(FDialogs)] := D;
  D.Index := Length(FDialogs);
  Result := D;
end;

function TGameUI.FindDialog(P: Pointer): TDialog;
var
  I: Integer;
begin
  for I := 0 to High(FDialogs) do
    if Pointer(FDialogs[I]) = P then
      Exit(FDialogs[I]);
  Result := nil;
end;

destructor TGameUI.Destroy;
begin
  Reset;
  inherited Destroy;
end;

procedure TGameUI.Reset;
var
  I: Integer;
begin
  for I := 0 to High(FDialogs) do
    FDialogs[I].Free;
  FDialogs := nil;
end;

function TGameUI.Dialog(const Name: string; VMT: Word; const Args: array of TUIArg): TDialog;
begin
  Result := Register(TDialog.Create);
  Result.Name := Name;
  Result.VMT := VMT;
  Result.Size := PWord(@PByte(@DS)[VMT])^;
end;

function TGameUI.Execute(D: TDialog): SmallInt;
begin
  Result := 1;                 { IDOK }
end;

procedure TGameUI.Done(D: TDialog; Flag: Word);
begin
end;

function TGameUI.ExecDialog(D: TDialog): SmallInt;
begin
  Result := 1;
end;

function TGameUI.GetText(D: TDialog): PChar;
begin
  Result := D.Text;
end;

function TGameUI.Call(const Name: string; const Args: array of TUIArg): SmallInt;
begin
  Result := 0;
end;

initialization
  UI := TGameUI.Create;
finalization
  UI.Free;
end.
