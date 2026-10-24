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
  { uniform stays uniform, every factor; the sizes }
  S := Img(3, 2, [B, B, B, B, B, B]);
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
  Check(SupportedFactor(5) = 6, 'factor 5 -> 6');
  Check(SupportedFactor(7) = 8, 'factor 7 -> 8');
  Check(SupportedFactor(10) = 12, 'factor 10 -> 12');
  { a vertical edge stays straight (no diagonal there) }
  S := Img(2, 3, [W, B, W, B, W, B]);
  R := Scale2x(S);
  Check(Rows(R, 0, 0, 4) = 'WWBB/WWBB/WWBB/WWBB', 'Scale2x straight edge: ' + Rows(R, 0, 0, 4));
  if Failed = 0 then
    WriteLn('scaletest: all passed')
  else
    WriteLn('scaletest: ', Failed, ' failed');
  if Failed > 0 then
    Halt(1);
end.
