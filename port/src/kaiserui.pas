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
    Data: array of Byte;       { the object: at least 512 bytes, else the instance size }
    Logic: TObject;            { the dialog type's methods (TDialogLogic), if ported }
    function Text: PChar;
    destructor Destroy; override;
  end;

  { the controls of a dialog, as OWL's TStatic, TCheckBox, TScrollBar ...
    methods see them (by resource id) }
  TDlgControls = class
  public
    procedure SetText(Id: SmallInt; S: PChar); virtual; abstract;
    function GetText(Id: SmallInt; Buf: PChar; MaxChars: Integer): Integer; virtual; abstract;
    procedure Enable(Id: SmallInt; On: Boolean); virtual; abstract;
    procedure Show(Id: SmallInt; Cmd: SmallInt); virtual; abstract;
    procedure SetCaption(S: PChar); virtual; abstract;
    { TWindow.SetCaption on a control (a button's text) }
    procedure SetItemCaption(Id: SmallInt; S: PChar); virtual; abstract;
    procedure SetCheck(Id: SmallInt; V: Word); virtual; abstract;
    function GetCheck(Id: SmallInt): Word; virtual; abstract;
    procedure SetRange(Id: SmallInt; Lo, Hi: SmallInt); virtual; abstract;
    procedure SetPosition(Id: SmallInt; V: SmallInt); virtual; abstract;
    function GetPosition(Id: SmallInt): SmallInt; virtual; abstract;
    function AddString(Id: SmallInt; S: PChar): SmallInt; virtual; abstract;
    function GetSelIndex(Id: SmallInt): SmallInt; virtual; abstract;
    function SetSelIndex(Id: SmallInt; I: SmallInt): SmallInt; virtual; abstract;
    procedure ComboSetText(Id: SmallInt; S: PChar); virtual; abstract;
    procedure EndDlg(Code: SmallInt); virtual; abstract;
    { the scroll bar's LineMagnitude (no notification, nothing logged) }
    procedure SetLineStep(Id: SmallInt; N: SmallInt); virtual;
  end;

  { the methods of a game dialog type (TDialog descendant of the original):
    Init is the constructor's part beyond creating the controls, SetupWindow,
    the control handlers (Handle returns False when the type has none: OK
    and Cancel then do what TDialog does) and CanClose. They work on D.Data,
    laid out like the original object. }
  TDialogLogic = class
  public
    D: TDialog;
    Args: array of TUIArg;
    C: TDlgControls;
    constructor Create(AD: TDialog; const AArgs: array of TUIArg); virtual;
    procedure Init; virtual;
    procedure SetupWindow; virtual;
    function CanClose: Boolean; virtual;
    function Handle(Id: SmallInt): Boolean; virtual;
  end;
  TDialogLogicClass = class of TDialogLogic;

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
    { a control method of a dialog (for the test log) }
    procedure Note(const Entry: string); virtual;
    procedure Reset;
  end;

procedure RegisterDialogLogic(const Name: string; C: TDialogLogicClass);
function DialogLogicOf(const Name: string): TDialogLogicClass;

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

procedure TDlgControls.SetLineStep(Id: SmallInt; N: SmallInt);
begin
end;

var
  LogicNames: array of string;
  LogicClasses: array of TDialogLogicClass;

procedure RegisterDialogLogic(const Name: string; C: TDialogLogicClass);
begin
  SetLength(LogicNames, Length(LogicNames) + 1);
  SetLength(LogicClasses, Length(LogicClasses) + 1);
  LogicNames[High(LogicNames)] := Name;
  LogicClasses[High(LogicClasses)] := C;
end;

function DialogLogicOf(const Name: string): TDialogLogicClass;
var
  I: Integer;
begin
  for I := 0 to High(LogicNames) do
    if LogicNames[I] = Name then
      Exit(LogicClasses[I]);
  Result := nil;
end;

function TDialog.Text: PChar;
begin
  Result := PChar(@Data[DialogTextOfs]);
end;

destructor TDialog.Destroy;
begin
  Logic.Free;
  inherited Destroy;
end;

constructor TDialogLogic.Create(AD: TDialog; const AArgs: array of TUIArg);
var
  I: Integer;
begin
  inherited Create;
  D := AD;
  SetLength(Args, Length(AArgs));
  for I := 0 to High(AArgs) do
    Args[I] := AArgs[I];
end;

procedure TDialogLogic.Init;
begin
end;

procedure TDialogLogic.SetupWindow;
begin
end;

function TDialogLogic.CanClose: Boolean;
begin
  Result := True;
end;

function TDialogLogic.Handle(Id: SmallInt): Boolean;
begin
  Result := False;
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
var
  LC: TDialogLogicClass;
begin
  Result := Register(TDialog.Create);
  Result.Name := Name;
  Result.VMT := VMT;
  Result.Size := PWord(@PByte(@DS)[VMT])^;
  if Result.Size > $200 then
    SetLength(Result.Data, Result.Size + $10)
  else
    SetLength(Result.Data, $210);
  LC := DialogLogicOf(Name);
  if LC <> nil then
  begin
    Result.Logic := LC.Create(Result, Args);
    TDialogLogic(Result.Logic).Init;
  end;
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

procedure TGameUI.Note(const Entry: string);
begin
end;

initialization
  UI := TGameUI.Create;
finalization
  UI.Free;
end.
