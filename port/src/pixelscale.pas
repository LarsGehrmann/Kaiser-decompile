{ The remastered game's pixel-art scaler: the original's 256-colour pictures
  (sprites with their masks, bitmaps, patterns) made N times larger with the
  edges kept sharp and smoothed along their direction. Scale2x and Scale3x
  (AdvMAME) on 32-bit pixels, a transparent pixel (alpha 0) being a colour of
  its own, so a sprite's outline scales like any other edge; larger factors
  chain them (4 = 2x2x, 6 = 3x2x, ... 12). The renderer asks for the next
  supported factor and scales the frame down smoothly from there. No LCL:
  the tests use it on the console. }
unit PixelScale;

{$mode objfpc}{$H+}

interface

type
  { pixels $AARRGGBB, row by row from the top }
  TPixImage = record
    W, H: Integer;
    Px: array of LongWord;
  end;

function NewPixImage(W, H: Integer): TPixImage;
function Scale2x(const S: TPixImage): TPixImage;
function Scale3x(const S: TPixImage): TPixImage;
function ScaleNearest(const S: TPixImage; N: Integer): TPixImage;
{ SupportedFactor(N) times larger }
function ScalePix(const S: TPixImage; N: Integer): TPixImage;
{ the smallest factor >= N made of 2x and 3x steps (1, 2, 3, 4, 6, 8, 9, 12) }
function SupportedFactor(N: Integer): Integer;
{ the largest supported factor below N (at least 1) }
function LowerFactor(N: Integer): Integer;

implementation

function NewPixImage(W, H: Integer): TPixImage;
begin
  Result.W := W;
  Result.H := H;
  SetLength(Result.Px, W * H);
end;

{ the pixel at (X, Y), the border repeated outside }
function At(const S: TPixImage; X, Y: Integer): LongWord; inline;
begin
  if X < 0 then X := 0 else if X >= S.W then X := S.W - 1;
  if Y < 0 then Y := 0 else if Y >= S.H then Y := S.H - 1;
  Result := S.Px[Y * S.W + X];
end;

function Scale2x(const S: TPixImage): TPixImage;
var
  X, Y, O: Integer;
  A, B, C, D, P: LongWord;
begin
  { EPX: P's neighbours A above, B right, C left, D below }
  Result := NewPixImage(S.W * 2, S.H * 2);
  for Y := 0 to S.H - 1 do
    for X := 0 to S.W - 1 do
    begin
      P := S.Px[Y * S.W + X];
      A := At(S, X, Y - 1);
      B := At(S, X + 1, Y);
      C := At(S, X - 1, Y);
      D := At(S, X, Y + 1);
      O := (Y * 2) * Result.W + X * 2;
      if (C = A) and (C <> D) and (A <> B) then Result.Px[O] := A else Result.Px[O] := P;
      if (A = B) and (A <> C) and (B <> D) then Result.Px[O + 1] := B else Result.Px[O + 1] := P;
      Inc(O, Result.W);
      if (D = C) and (D <> B) and (C <> A) then Result.Px[O] := C else Result.Px[O] := P;
      if (B = D) and (B <> A) and (D <> C) then Result.Px[O + 1] := D else Result.Px[O + 1] := P;
    end;
end;

function Scale3x(const S: TPixImage): TPixImage;
var
  X, Y, O, RW: Integer;
  A, B, C, D, E, F, G, H, I: LongWord;
  E0, E1, E2, E3, E5, E6, E7, E8: LongWord;
begin
  { AdvMAME3x: the 3x3 neighbourhood A B C / D E F / G H I }
  Result := NewPixImage(S.W * 3, S.H * 3);
  RW := Result.W;
  for Y := 0 to S.H - 1 do
    for X := 0 to S.W - 1 do
    begin
      A := At(S, X - 1, Y - 1); B := At(S, X, Y - 1); C := At(S, X + 1, Y - 1);
      D := At(S, X - 1, Y);     E := S.Px[Y * S.W + X]; F := At(S, X + 1, Y);
      G := At(S, X - 1, Y + 1); H := At(S, X, Y + 1); I := At(S, X + 1, Y + 1);
      E0 := E; E1 := E; E2 := E; E3 := E; E5 := E; E6 := E; E7 := E; E8 := E;
      if (B <> H) and (D <> F) then
      begin
        if D = B then E0 := D;
        if ((D = B) and (E <> C)) or ((B = F) and (E <> A)) then E1 := B;
        if B = F then E2 := F;
        if ((D = B) and (E <> G)) or ((D = H) and (E <> A)) then E3 := D;
        if ((B = F) and (E <> I)) or ((H = F) and (E <> C)) then E5 := F;
        if D = H then E6 := D;
        if ((D = H) and (E <> I)) or ((H = F) and (E <> G)) then E7 := H;
        if H = F then E8 := F;
      end;
      O := (Y * 3) * RW + X * 3;
      Result.Px[O] := E0; Result.Px[O + 1] := E1; Result.Px[O + 2] := E2;
      Inc(O, RW);
      Result.Px[O] := E3; Result.Px[O + 1] := E; Result.Px[O + 2] := E5;
      Inc(O, RW);
      Result.Px[O] := E6; Result.Px[O + 1] := E7; Result.Px[O + 2] := E8;
    end;
end;

function ScaleNearest(const S: TPixImage; N: Integer): TPixImage;
var
  X, Y: Integer;
begin
  Result := NewPixImage(S.W * N, S.H * N);
  for Y := 0 to Result.H - 1 do
    for X := 0 to Result.W - 1 do
      Result.Px[Y * Result.W + X] := S.Px[(Y div N) * S.W + X div N];
end;

function ScalePix(const S: TPixImage; N: Integer): TPixImage;
begin
  { the factors of 2x and 3x steps; others the next larger of them }
  case SupportedFactor(N) of
    1: Result := S;
    2: Result := Scale2x(S);
    3: Result := Scale3x(S);
    4: Result := Scale2x(Scale2x(S));
    6: Result := Scale2x(Scale3x(S));
    8: Result := Scale2x(Scale2x(Scale2x(S)));
    9: Result := Scale3x(Scale3x(S));
  else
    Result := Scale2x(Scale2x(Scale3x(S)));          { 12 }
  end;
end;

function SupportedFactor(N: Integer): Integer;
const
  F: array[0..7] of Integer = (1, 2, 3, 4, 6, 8, 9, 12);
var
  I: Integer;
begin
  for I := 0 to High(F) do
    if F[I] >= N then
      Exit(F[I]);
  Result := 12;
end;

function LowerFactor(N: Integer): Integer;
const
  F: array[0..7] of Integer = (1, 2, 3, 4, 6, 8, 9, 12);
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to High(F) do
    if F[I] < N then
      Result := F[I];
end;

end.
