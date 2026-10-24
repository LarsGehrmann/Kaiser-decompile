{ A scroll bar that looks and works like the Windows 3.1 one the dialogs
  were made for: arrow buttons at both ends (one line, SmallChange), the
  trough (one page, LargeChange; both repeat while the button is held) and
  the thumb to drag. macOS' own scroll bar has no arrows (Steuern, Justiz:
  bugs.txt), so the GUI uses this one there; Windows keeps its native one. }
unit WinScroll;

{$mode objfpc}{$H+}

interface

uses
  Classes, Types, Controls, Graphics, ExtCtrls, Forms, LCLIntf;

type
  TWinScrollBar = class(TCustomControl)
  protected
    FMin, FMax, FPosition: Integer;
    FSmallChange, FLargeChange: Integer;
    FVertical: Boolean;
    FSpin: Boolean;
    FOnChange: TNotifyEvent;
    FRepeat: TTimer;
    FPart: Integer;           { what the button is held on: 1 / 2 arrows, 3 / 4 trough, 5 thumb }
    FPressed: Boolean;        { the held part is under the mouse }
    FDragOfs: Integer;        { thumb drag: the mouse in the thumb }
    procedure SetPosition(V: Integer);
    function Len: Integer;     { along the bar }
    function Thick: Integer;   { across it: the arrows and the thumb are squares }
    function ThumbAt: Integer;
    function PartAt(X, Y: Integer): Integer;
    procedure Step;
    procedure RepeatTick(Sender: TObject);
    procedure Move(Delta: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetParams(APosition, AMin, AMax: Integer);
    property Min: Integer read FMin;
    property Max: Integer read FMax;
    { set by the program: no OnChange (like SetScrollPos) }
    property Position: Integer read FPosition write SetPosition;
    property SmallChange: Integer read FSmallChange write FSmallChange;
    property LargeChange: Integer read FLargeChange write FLargeChange;
    property Vertical: Boolean read FVertical write FVertical;
    { only the two arrows, each half of it (a 9 x 9 unit scroll bar: the
      spin buttons of SABOTAGEBUDGETDLG; macOS' stepper keeps its size) }
    property Spin: Boolean read FSpin write FSpin;
    { the user moved it (WM_HSCROLL / WM_VSCROLL to the dialog) }
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

const
  ClFace = $C0C0C0;
  ClShadow = $808080;

constructor TWinScrollBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMax := 100;
  FSmallChange := 1;
  FLargeChange := 10;
  FRepeat := TTimer.Create(Self);
  FRepeat.Enabled := False;
  FRepeat.OnTimer := @RepeatTick;
end;

procedure TWinScrollBar.SetParams(APosition, AMin, AMax: Integer);
begin
  if AMax < AMin then
    AMax := AMin;
  FMin := AMin;
  FMax := AMax;
  SetPosition(APosition);
end;

procedure TWinScrollBar.SetPosition(V: Integer);
begin
  if V < FMin then
    V := FMin;
  if V > FMax then
    V := FMax;
  if V <> FPosition then
  begin
    FPosition := V;
    Invalidate;
  end;
end;

function TWinScrollBar.Len: Integer;
begin
  if FVertical then
    Result := Height
  else
    Result := Width;
end;

function TWinScrollBar.Thick: Integer;
begin
  if FVertical then
    Result := Width
  else
    Result := Height;
  if FSpin then
    Result := Len div 2
  else if Result * 2 + 4 > Len then
    Result := (Len - 4) div 2;
end;

function TWinScrollBar.ThumbAt: Integer;
var
  Room: Integer;
begin
  { the thumb's start along the bar, between the arrows }
  Room := Len - 3 * Thick;
  if (FMax <= FMin) or (Room <= 0) then
    Result := Thick
  else
    Result := Thick + Int64(FPosition - FMin) * Room div (FMax - FMin);
end;

function TWinScrollBar.PartAt(X, Y: Integer): Integer;
var
  P, T: Integer;
begin
  if FVertical then
    P := Y
  else
    P := X;
  T := ThumbAt;
  if FSpin then
    Result := 1 + Ord(P >= Len div 2)
  else if P < Thick then
    Result := 1
  else if P >= Len - Thick then
    Result := 2
  else if P < T then
    Result := 3
  else if P >= T + Thick then
    Result := 4
  else
    Result := 5;
end;

procedure TWinScrollBar.Move(Delta: Integer);
var
  Old: Integer;
begin
  Old := FPosition;
  SetPosition(FPosition + Delta);
  if (FPosition <> Old) and Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TWinScrollBar.Step;
begin
  case FPart of
    1: Move(-FSmallChange);                         { SB_LINEUP }
    2: Move(FSmallChange);                          { SB_LINEDOWN }
    3: Move(-FLargeChange);                         { SB_PAGEUP }
    4: Move(FLargeChange);                          { SB_PAGEDOWN }
  end;
end;

procedure TWinScrollBar.RepeatTick(Sender: TObject);
var
  P: TPoint;
begin
  FRepeat.Interval := 50;
  P := ScreenToClient(Mouse.CursorPos);
  { the trough repeats only while the thumb has not reached the mouse }
  if FPressed and (PartAt(P.X, P.Y) = FPart) then
    Step;
end;

procedure TWinScrollBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then
    Exit;
  FPart := PartAt(X, Y);
  FPressed := True;
  if FPart = 5 then
  begin
    if FVertical then
      FDragOfs := Y - ThumbAt
    else
      FDragOfs := X - ThumbAt;
  end
  else
  begin
    Step;
    FRepeat.Interval := 400;
    FRepeat.Enabled := True;
  end;
  Invalidate;
end;

procedure TWinScrollBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P, Room, V: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FPart = 0 then
    Exit;
  if FPart = 5 then
  begin
    { SB_THUMBTRACK: the position follows the thumb }
    if FVertical then
      P := Y - FDragOfs - Thick
    else
      P := X - FDragOfs - Thick;
    Room := Len - 3 * Thick;
    if Room > 0 then
    begin
      V := FMin + (Int64(P) * (FMax - FMin) + Room div 2) div Room;
      Move(V - FPosition);
    end;
  end
  else if FPressed <> (PartAt(X, Y) = FPart) then
  begin
    FPressed := PartAt(X, Y) = FPart;
    Invalidate;
  end;
end;

procedure TWinScrollBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FRepeat.Enabled := False;
  FPart := 0;
  FPressed := False;
  Invalidate;
end;

procedure TWinScrollBar.Paint;
var
  C: TCanvas;
  T, A: Integer;

  function R(P0, P1: Integer): TRect;
  begin
    { a rectangle from P0 to P1 along the bar, across all of it }
    if FVertical then
      Result := Rect(0, P0, Width, P1)
    else
      Result := Rect(P0, 0, P1, Height);
  end;

  procedure Button3D(Rc: TRect; Down: Boolean);
  begin
    C.Brush.Color := ClFace;
    C.Pen.Color := clBlack;
    C.Rectangle(Rc);
    InflateRect(Rc, -1, -1);
    if Down then
    begin
      C.Pen.Color := ClShadow;
      C.MoveTo(Rc.Left, Rc.Bottom - 1);
      C.LineTo(Rc.Left, Rc.Top);
      C.LineTo(Rc.Right, Rc.Top);
    end
    else
    begin
      C.Pen.Color := clWhite;
      C.MoveTo(Rc.Left, Rc.Bottom - 1);
      C.LineTo(Rc.Left, Rc.Top);
      C.LineTo(Rc.Right - 1, Rc.Top);
      C.Pen.Color := ClShadow;
      C.LineTo(Rc.Right - 1, Rc.Bottom - 1);
      C.LineTo(Rc.Left - 1, Rc.Bottom - 1);
    end;
  end;

  procedure Arrow(Rc: TRect; Dir: Integer; Down: Boolean);
  var
    Cx, Cy, K, S: Integer;
  begin
    { a solid triangle, pointing left/up (-1) or right/down (1) }
    Cx := (Rc.Left + Rc.Right) div 2 + Ord(Down);
    Cy := (Rc.Top + Rc.Bottom) div 2 + Ord(Down);
    S := T div 4;
    if S < 2 then
      S := 2;
    if Enabled then
      C.Pen.Color := clBlack
    else
      C.Pen.Color := ClShadow;
    for K := 0 to S - 1 do
      { the tip (K = 0) on the side Dir points to }
      if FVertical then
      begin
        C.MoveTo(Cx - K, Cy + Dir * (S div 2) - Dir * K);
        C.LineTo(Cx + K + 1, Cy + Dir * (S div 2) - Dir * K);
      end
      else
      begin
        C.MoveTo(Cx + Dir * (S div 2) - Dir * K, Cy - K);
        C.LineTo(Cx + Dir * (S div 2) - Dir * K, Cy + K + 1);
      end;
  end;

begin
  C := Canvas;
  T := Thick;
  { the trough: the light grey dither of COLOR_SCROLLBAR, in a black frame }
  C.Brush.Color := $E0E0E0;
  C.Pen.Color := clBlack;
  C.Rectangle(0, 0, Width, Height);
  Button3D(R(0, T), FPressed and (FPart = 1));
  Arrow(R(0, T), -1, FPressed and (FPart = 1));
  Button3D(R(Len - T, Len), FPressed and (FPart = 2));
  Arrow(R(Len - T, Len), 1, FPressed and (FPart = 2));
  if FPressed and (FPart in [3, 4]) then
  begin
    { the held part of the trough darker }
    C.Brush.Color := ClShadow;
    C.Pen.Color := ClShadow;
    A := ThumbAt;
    if FPart = 3 then
      C.Rectangle(R(T, A))
    else
      C.Rectangle(R(A + T, Len - T));
  end;
  if Enabled and (FMax > FMin) and not FSpin then
  begin
    A := ThumbAt;
    Button3D(R(A, A + T), False);
  end;
end;

end.
