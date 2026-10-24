{ Tests of the remastered pixel scaler (port/src/pixelscale.pas): sizes,
  uniform pictures stay uniform, the factor choice, and the corners of Scale2x
  / Scale3x worked out by hand. }
program ScaleTest;

{$mode objfpc}{$H+}

uses
  SysUtils, PixelScale;

var
  Failed: Integer = 0;

procedure Check(Cond: Boolean; const What: string);
begin
  if not Cond then
  begin
    WriteLn('FAILED: ', What);
    Inc(Failed);
  end;
end;

const
  W = $FFFFFFFF;
  B = $FF000000;
  T = $00000000;                { transparent }

function Img(AW, AH: Integer; const P: array of LongWord): TPixImage;
var
  I: Integer;
begin
  Result := NewPixImage(AW, AH);
  for I := 0 to High(P) do
    Result.Px[I] := P[I];
end;

function Rows(const S: TPixImage; Y0, X0, N: Integer): string;
var
  X, Y: Integer;
begin
  { the N x N block at (X0, Y0) as W / B / T letters, rows by '/' }
  Result := '';
  for Y := Y0 to Y0 + N - 1 do
  begin
    for X := X0 to X0 + N - 1 do
      case S.Px[Y * S.W + X] of
        W: Result := Result + 'W';
        B: Result := Result + 'B';
        T: Result := Result + 'T';
      else
        Result := Result + '?';
      end;
    if Y < Y0 + N - 1 then
      Result := Result + '/';
  end;
end;

var
  S, R: TPixImage;
  N, I: Integer;
  M: TScaleMethod;
  Same: Boolean;
begin
  { a white corner on black: W B / B B }
  S := Img(2, 2, [W, B, B, B]);
  R := Scale2x(S);
  Check((R.W = 4) and (R.H = 4), 'Scale2x size');
  Check(Rows(R, 0, 0, 2) = 'WW/WB', 'Scale2x corner: ' + Rows(R, 0, 0, 2));
  R := Scale3x(S);
  Check((R.W = 6) and (R.H = 6), 'Scale3x size');
  Check(Rows(R, 0, 0, 3) = 'WWW/WWB/WBB', 'Scale3x corner: ' + Rows(R, 0, 0, 3));
  { transparency is a colour of its own: a sprite corner against it }
  S := Img(2, 2, [B, T, T, T]);
  Check(Rows(Scale2x(S), 0, 0, 2) = 'BB/BT', 'Scale2x transparent corner');
  { uniform stays uniform, every factor and method; the sizes }
  S := Img(3, 2, [B, B, B, B, B, B]);
  for M := Low(TScaleMethod) to High(TScaleMethod) do
  begin
    ScaleMethod := M;
    for N := 1 to 12 do
    begin
      R := ScalePix(S, N);
      Check((R.W = 3 * SupportedFactor(N)) and (R.H = 2 * SupportedFactor(N)),
        'ScalePix size ' + IntToStr(N));
      Same := True;
      for I := 0 to High(R.Px) do
        if R.Px[I] <> B then
          Same := False;
      Check(Same, 'uniform at ' + IntToStr(N));
    end;
  end;
  ScaleMethod := smScaleNx;
  Check(SupportedFactor(5) = 6, 'factor 5 -> 6');
  Check(SupportedFactor(7) = 8, 'factor 7 -> 8');
  Check(SupportedFactor(10) = 12, 'factor 10 -> 12');
  Check((LowerFactor(6) = 4) and (LowerFactor(2) = 1) and (LowerFactor(1) = 1) and
    (LowerFactor(12) = 9), 'LowerFactor');
  { a vertical edge stays straight (no diagonal there) }
  S := Img(2, 3, [W, B, W, B, W, B]);
  R := Scale2x(S);
  Check(Rows(R, 0, 0, 4) = 'WWBB/WWBB/WWBB/WWBB', 'Scale2x straight edge: ' + Rows(R, 0, 0, 4));
  { xBRZ: a diagonal edge gets blended pixels, a straight one does not }
  ScaleMethod := smXBRZ;
  S := Img(4, 4, [W, W, W, B,  W, W, B, B,  W, B, B, B,  B, B, B, B]);
  R := ScalePix(S, 4);
  Same := True;
  for I := 0 to High(R.Px) do
    if (R.Px[I] <> W) and (R.Px[I] <> B) then
      Same := False;
  Check(not Same, 'xBRZ blends a diagonal');
  S := Img(2, 3, [W, B, W, B, W, B]);
  R := ScalePix(S, 3);
  Check(Rows(R, 0, 0, 6) = 'WWWBBB/WWWBBB/WWWBBB/WWWBBB/WWWBBB/WWWBBB', 'xBRZ straight edge: ' + Rows(R, 0, 0, 6));
  S := Img(2, 2, [B, T, T, T]);
  R := ScalePix(S, 2);
  Check(R.Px[0] = B, 'xBRZ keeps the corner pixel');
  { photos: smooth scaling, a colour count }
  S := Img(2, 1, [W, B]);
  R := ScaleSmooth(S, 4);
  Check((R.W = 8) and (R.Px[0] = W) and (R.Px[7] = B) and (R.Px[3] <> W) and (R.Px[3] <> B),
    'ScaleSmooth blends');
  Check(ColourCount(Img(2, 2, [W, B, W, T]), 100) = 3, 'ColourCount');
  Check(not IsPhoto(Img(2, 2, [W, B, W, T])), 'IsPhoto pixel art');
  if Failed = 0 then
    WriteLn('scaletest: all passed')
  else
    WriteLn('scaletest: ', Failed, ' failed');
  if Failed > 0 then
    Halt(1);
end.
