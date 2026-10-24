{ An xBRZ-style pixel-art scaler (after the xBRZ algorithm by Zenju, GPL):
  colour distances in YCbCr (with alpha), the blend type of each pixel
  corner from the dominant gradient direction of a 4x4 neighbourhood, then
  per corner a corner blend or a shallow / steep / diagonal line blend with
  fixed gradients for the factors 2, 3 and 4. Pixels $AARRGGBB like
  PixelScale. }
unit XBRZ;

{$mode objfpc}{$H+}

interface

uses
  PixelScale;

{ N = 2, 3 or 4 }
function ScaleXBRZ(const S: TPixImage; N: Integer): TPixImage;

implementation

uses
  Math;

const
  LumaWeight = 1.0;
  EqualColorTolerance = 30.0;
  CenterDirectionBias = 4.0;
  DominantDirectionThreshold = 3.6;
  SteepDirectionThreshold = 2.2;

  BlendNone = 0;
  BlendNormal = 1;
  BlendDominant = 2;

function DistYCbCr(P1, P2: LongWord): Double;
const
  KB = 0.0593;
  KR = 0.2627;
  KG = 1 - KB - KR;
  ScaleB = 0.5 / (1 - KB);
  ScaleR = 0.5 / (1 - KR);
var
  RD, GD, BD, Y, CB, CR: Double;
begin
  RD := Integer((P1 shr 16) and $FF) - Integer((P2 shr 16) and $FF);
  GD := Integer((P1 shr 8) and $FF) - Integer((P2 shr 8) and $FF);
  BD := Integer(P1 and $FF) - Integer(P2 and $FF);
  Y := KR * RD + KG * GD + KB * BD;
  CB := ScaleB * (BD - Y);
  CR := ScaleR * (RD - Y);
  Result := Sqrt(Sqr(LumaWeight * Y) + Sqr(CB) + Sqr(CR));
end;

{ with alpha: a transparent pixel is as far from any colour as its alpha says }
function Dist(P1, P2: LongWord): Double;
var
  A1, A2, D: Double;
begin
  if P1 = P2 then
    Exit(0);
  A1 := (P1 shr 24) / 255;
  A2 := (P2 shr 24) / 255;
  D := DistYCbCr(P1, P2);
  if A1 < A2 then
    Result := A1 * D + 255 * (A2 - A1)
  else
    Result := A2 * D + 255 * (A1 - A2);
end;

function Eq(P1, P2: LongWord): Boolean; inline;
begin
  Result := Dist(P1, P2) < EqualColorTolerance;
end;

{ back := front * M / N + back * (N - M) / N, weighted by the alphas }
procedure AlphaGrad(var Back: LongWord; Front: LongWord; M, N: Integer);
var
  WF, WB, WS: Integer;

  function Ch(Sh: Integer): LongWord;
  begin
    Result := LongWord((Integer((Front shr Sh) and $FF) * WF + Integer((Back shr Sh) and $FF) * WB)
      div WS);
  end;

begin
  WF := Integer(Front shr 24) * M;
  WB := Integer(Back shr 24) * (N - M);
  WS := WF + WB;
  if WS = 0 then
  begin
    Back := 0;
    Exit;
  end;
  Back := (LongWord(WS div N) shl 24) or (Ch(16) shl 16) or (Ch(8) shl 8) or Ch(0);
end;

type
  { the output block of one pixel, seen through a rotation: Ref(I, J) is
    row I, column J of the rotated block }
  TOut = record
    Img: ^TPixImage;
    X0, Y0, N, Rot: Integer;
  end;

function Ref(var O: TOut; I, J: Integer): PLongWord;
var
  K, T: Integer;
begin
  { undo the rotation: 90 degrees at a time, (I, J) -> (N - 1 - J, I) }
  for K := 1 to O.Rot do
  begin
    T := I;
    I := O.N - 1 - J;
    J := T;
  end;
  Result := @O.Img^.Px[(O.Y0 + I) * O.Img^.W + O.X0 + J];
end;

procedure Grad(var O: TOut; I, J, M, N: Integer; Col: LongWord); inline;
begin
  AlphaGrad(Ref(O, I, J)^, Col, M, N);
end;

procedure Put(var O: TOut; I, J: Integer; Col: LongWord); inline;
begin
  Ref(O, I, J)^ := Col;
end;

procedure BlendLineShallow(var O: TOut; Col: LongWord);
var
  S: Integer;
begin
  S := O.N;
  case S of
    2:
      begin
        Grad(O, S - 1, 0, 1, 4, Col);
        Grad(O, S - 1, 1, 3, 4, Col);
      end;
    3:
      begin
        Grad(O, S - 1, 0, 1, 4, Col);
        Grad(O, S - 2, 2, 1, 4, Col);
        Grad(O, S - 1, 1, 3, 4, Col);
        Put(O, S - 1, 2, Col);
      end;
    4:
      begin
        Grad(O, S - 1, 0, 1, 4, Col);
        Grad(O, S - 2, 2, 1, 4, Col);
        Grad(O, S - 1, 1, 3, 4, Col);
        Grad(O, S - 2, 3, 3, 4, Col);
        Put(O, S - 1, 2, Col);
        Put(O, S - 1, 3, Col);
      end;
  end;
end;

procedure BlendLineSteep(var O: TOut; Col: LongWord);
var
  S: Integer;
begin
  S := O.N;
  case S of
    2:
      begin
        Grad(O, 0, S - 1, 1, 4, Col);
        Grad(O, 1, S - 1, 3, 4, Col);
      end;
    3:
      begin
        Grad(O, 0, S - 1, 1, 4, Col);
        Grad(O, 2, S - 2, 1, 4, Col);
        Grad(O, 1, S - 1, 3, 4, Col);
        Put(O, 2, S - 1, Col);
      end;
    4:
      begin
        Grad(O, 0, S - 1, 1, 4, Col);
        Grad(O, 2, S - 2, 1, 4, Col);
        Grad(O, 1, S - 1, 3, 4, Col);
        Grad(O, 3, S - 2, 3, 4, Col);
        Put(O, 2, S - 1, Col);
        Put(O, 3, S - 1, Col);
      end;
  end;
end;

procedure BlendLineSteepAndShallow(var O: TOut; Col: LongWord);
begin
  case O.N of
    2:
      begin
        Grad(O, 1, 0, 1, 4, Col);
        Grad(O, 0, 1, 1, 4, Col);
        Grad(O, 1, 1, 5, 6, Col);
      end;
    3:
      begin
        Grad(O, 2, 0, 1, 4, Col);
        Grad(O, 0, 2, 1, 4, Col);
        Grad(O, 2, 1, 3, 4, Col);
        Grad(O, 1, 2, 3, 4, Col);
        Put(O, 2, 2, Col);
      end;
    4:
      begin
        Grad(O, 3, 1, 3, 4, Col);
        Grad(O, 1, 3, 3, 4, Col);
        Grad(O, 3, 0, 1, 4, Col);
        Grad(O, 0, 3, 1, 4, Col);
        Grad(O, 2, 2, 1, 3, Col);
        Put(O, 3, 3, Col);
        Put(O, 3, 2, Col);
        Put(O, 2, 3, Col);
      end;
  end;
end;

procedure BlendLineDiagonal(var O: TOut; Col: LongWord);
var
  S: Integer;
begin
  S := O.N;
  case S of
    2: Grad(O, 1, 1, 1, 2, Col);
    3:
      begin
        Grad(O, 1, 2, 1, 8, Col);
        Grad(O, 2, 1, 1, 8, Col);
        Grad(O, 2, 2, 7, 8, Col);
      end;
    4:
      begin
        Grad(O, S - 1, S div 2, 1, 2, Col);
        Grad(O, S - 2, S div 2 + 1, 1, 2, Col);
        Put(O, S - 1, S - 1, Col);
      end;
  end;
end;

procedure BlendCorner(var O: TOut; Col: LongWord);
begin
  { the area of the quarter circle's corner: 1 - pi / 4 = 0.2146 }
  case O.N of
    2: Grad(O, 1, 1, 21, 100, Col);
    3: Grad(O, 2, 2, 45, 100, Col);
    4:
      begin
        Grad(O, 3, 3, 68, 100, Col);
        Grad(O, 3, 2, 9, 100, Col);
        Grad(O, 2, 3, 9, 100, Col);
      end;
  end;
end;

{ the blend info of a pixel: 2 bits per corner, top-left, top-right,
  bottom-right, bottom-left }
function TopL(B: Byte): Byte; inline; begin Result := B and 3; end;
function TopR(B: Byte): Byte; inline; begin Result := (B shr 2) and 3; end;
function BottomR(B: Byte): Byte; inline; begin Result := (B shr 4) and 3; end;
function BottomL(B: Byte): Byte; inline; begin Result := (B shr 6) and 3; end;

function RotateBlend(B: Byte; Rot: Integer): Byte;
begin
  case Rot of
    1: Result := Byte((B shl 2) or (B shr 6));
    2: Result := Byte((B shl 4) or (B shr 4));
    3: Result := Byte((B shl 6) or (B shr 2));
  else
    Result := B;
  end;
end;

function ScaleXBRZ(const S: TPixImage; N: Integer): TPixImage;
var
  Blend: array of Byte;
  W, H, X, Y, I, J, Rot: Integer;
  O: TOut;
  K: array[0..8] of LongWord;        { a .. i }
  R: array[0..8] of LongWord;        { rotated }
  B: Byte;

  function At(PX, PY: Integer): LongWord; inline;
  begin
    if PX < 0 then PX := 0 else if PX >= W then PX := W - 1;
    if PY < 0 then PY := 0 else if PY >= H then PY := H - 1;
    Result := S.Px[PY * W + PX];
  end;

  procedure AddBlend(PX, PY: Integer; Shift: Integer; V: Byte);
  begin
    if (PX >= 0) and (PX < W) and (PY >= 0) and (PY < H) then
      Blend[PY * W + PX] := Blend[PY * W + PX] or (V shl Shift);
  end;

  { the four corners around the 2x2 block F G / J K with F at (PX, PY) }
  procedure PreProcess(PX, PY: Integer);
  var
    BB, C, E, F, G, HH, II, JJ, KK, L, NN, OO: LongWord;
    JG, FK: Double;
    Dom: Boolean;
    V: Byte;
  begin
    BB := At(PX, PY - 1); C := At(PX + 1, PY - 1);
    E := At(PX - 1, PY); F := At(PX, PY); G := At(PX + 1, PY); HH := At(PX + 2, PY);
    II := At(PX - 1, PY + 1); JJ := At(PX, PY + 1); KK := At(PX + 1, PY + 1); L := At(PX + 2, PY + 1);
    NN := At(PX, PY + 2); OO := At(PX + 1, PY + 2);
    if ((F = G) and (JJ = KK)) or ((F = JJ) and (G = KK)) then
      Exit;
    JG := Dist(II, F) + Dist(F, C) + Dist(NN, KK) + Dist(KK, HH) + CenterDirectionBias * Dist(JJ, G);
    FK := Dist(E, JJ) + Dist(JJ, OO) + Dist(BB, G) + Dist(G, L) + CenterDirectionBias * Dist(F, KK);
    if JG < FK then
    begin
      Dom := DominantDirectionThreshold * JG < FK;
      if Dom then V := BlendDominant else V := BlendNormal;
      if (F <> G) and (F <> JJ) then
        AddBlend(PX, PY, 4, V);                       { F's bottom-right }
      if (KK <> JJ) and (KK <> G) then
        AddBlend(PX + 1, PY + 1, 0, V);               { K's top-left }
    end
    else if FK < JG then
    begin
      Dom := DominantDirectionThreshold * FK < JG;
      if Dom then V := BlendDominant else V := BlendNormal;
      if (JJ <> F) and (JJ <> KK) then
        AddBlend(PX, PY + 1, 2, V);                   { J's top-right }
      if (G <> F) and (G <> KK) then
        AddBlend(PX + 1, PY, 6, V);                   { G's bottom-left }
    end;
  end;

  { the kernel turned by Rot x 90 degrees (a b c / d e f / g h i) }
  procedure Rotate(Rot: Integer);
  const
    R90: array[0..8] of Integer = (6, 3, 0, 7, 4, 1, 8, 5, 2);
  var
    T: array[0..8] of LongWord;
    Q, Z: Integer;
  begin
    for Q := 0 to 8 do
      R[Q] := K[Q];
    for Z := 1 to Rot do
    begin
      for Q := 0 to 8 do
        T[Q] := R[R90[Q]];
      for Q := 0 to 8 do
        R[Q] := T[Q];
    end;
  end;

  procedure ScalePixel(BlendRot: Byte);
  var
    B_, C_, D_, E_, F_, G_, H_, I_: LongWord;
    Px: LongWord;
    Line, Shallow, Steep: Boolean;
    FG, HC: Double;
  begin
    if BottomR(BlendRot) < BlendNormal then
      Exit;
    B_ := R[1]; C_ := R[2]; D_ := R[3]; E_ := R[4]; F_ := R[5];
    G_ := R[6]; H_ := R[7]; I_ := R[8];
    if BottomR(BlendRot) >= BlendDominant then
      Line := True
    else if (TopR(BlendRot) <> BlendNone) and not Eq(E_, G_) then
      Line := False                                 { no second blending next to it }
    else if (BottomL(BlendRot) <> BlendNone) and not Eq(E_, C_) then
      Line := False
    else if not Eq(E_, I_) and Eq(G_, H_) and Eq(H_, I_) and Eq(I_, F_) and Eq(F_, C_) then
      Line := False                                 { an L-shape: only the corner }
    else
      Line := True;
    if Dist(E_, F_) <= Dist(E_, H_) then
      Px := F_
    else
      Px := H_;
    if Line then
    begin
      FG := Dist(F_, G_);
      HC := Dist(H_, C_);
      Shallow := (SteepDirectionThreshold * FG <= HC) and (E_ <> G_) and (D_ <> G_);
      Steep := (SteepDirectionThreshold * HC <= FG) and (E_ <> C_) and (B_ <> C_);
      if Shallow and Steep then
        BlendLineSteepAndShallow(O, Px)
      else if Shallow then
        BlendLineShallow(O, Px)
      else if Steep then
        BlendLineSteep(O, Px)
      else
        BlendLineDiagonal(O, Px);
    end
    else
      BlendCorner(O, Px);
  end;

begin
  W := S.W;
  H := S.H;
  Result := NewPixImage(W * N, H * N);
  SetLength(Blend, W * H);
  for I := 0 to W * H - 1 do
    Blend[I] := 0;
  for Y := -1 to H - 1 do
    for X := -1 to W - 1 do
      PreProcess(X, Y);
  O.Img := @Result;
  O.N := N;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      for J := 0 to N - 1 do
        for I := 0 to N - 1 do
          Result.Px[(Y * N + J) * Result.W + X * N + I] := S.Px[Y * W + X];
      B := Blend[Y * W + X];
      if B = 0 then
        Continue;
      K[0] := At(X - 1, Y - 1); K[1] := At(X, Y - 1); K[2] := At(X + 1, Y - 1);
      K[3] := At(X - 1, Y);     K[4] := At(X, Y);     K[5] := At(X + 1, Y);
      K[6] := At(X - 1, Y + 1); K[7] := At(X, Y + 1); K[8] := At(X + 1, Y + 1);
      O.X0 := X * N;
      O.Y0 := Y * N;
      for Rot := 0 to 3 do
      begin
        O.Rot := Rot;
        Rotate(Rot);
        ScalePixel(RotateBlend(B, Rot));
      end;
    end;
end;

end.
