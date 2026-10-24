{ The remastered game's pictures: the original's sprites and bitmaps from
  kaiser.exe made N times larger by the pixel scaler (port/src/pixelscale.pas)
  and kept, one per picture and factor. }
unit RGraphics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, PixelScale;

{ a bitmap as 32-bit pixels (a transparent pixel: 0) and back (with alpha) }
function ToPix(B: TBitmap): TPixImage;
function FromPix(const P: TPixImage): TBitmap;
{ the sprite Id (with its mask, KaiserLCL.Sprite) N times larger; nil if
  missing. The bitmaps belong to the cache. }
function ScaledSprite(Id: Word; N: Integer): TBitmap;
{ the BITMAP resource (KaiserLCL.ResBitmap) N times larger }
function ScaledBitmap(const Name: RawByteString; Id: Word; N: Integer): TBitmap;
{ any bitmap N times larger, kept by its address: a bitmap that is freed
  must be forgotten first (ForgetScaled), or a new one at the same address
  would get its picture }
function ScaledOf(B: TBitmap; N: Integer): TBitmap;
procedure ForgetScaled(B: TBitmap);

implementation

uses
  IntfGraphics, FPImage, GraphType, KaiserLCL;

var
  Cache: TStringList;

function ToPix(B: TBitmap): TPixImage;
var
  Img: TLazIntfImage;
  X, Y: Integer;
  C: TFPColor;
begin
  Img := B.CreateIntfImage;
  try
    Result := NewPixImage(Img.Width, Img.Height);
    for Y := 0 to Img.Height - 1 do
      for X := 0 to Img.Width - 1 do
      begin
        C := Img.Colors[X, Y];
        if C.Alpha < $8000 then
          Result.Px[Y * Result.W + X] := 0        { all transparency alike }
        else
          Result.Px[Y * Result.W + X] := $FF000000 or (LongWord(C.Red shr 8) shl 16) or
            (LongWord(C.Green shr 8) shl 8) or LongWord(C.Blue shr 8);
      end;
  finally
    Img.Free;
  end;
end;

function FromPix(const P: TPixImage): TBitmap;
var
  Img: TLazIntfImage;
  X, Y: Integer;
  V: LongWord;
  C: TFPColor;
begin
  Img := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
  try
    Img.SetSize(P.W, P.H);
    for Y := 0 to P.H - 1 do
      for X := 0 to P.W - 1 do
      begin
        V := P.Px[Y * P.W + X];
        C.Red := ((V shr 16) and $FF) * $101;
        C.Green := ((V shr 8) and $FF) * $101;
        C.Blue := (V and $FF) * $101;
        C.Alpha := (V shr 24) * $101;
        Img.Colors[X, Y] := C;
      end;
    Result := TBitmap.Create;
    Result.LoadFromIntfImage(Img);
  finally
    Img.Free;
  end;
end;

function Cached(const Key: string; Src: TBitmap; N: Integer): TBitmap;
var
  K: Integer;
begin
  K := Cache.IndexOf(Key);
  if K >= 0 then
    Exit(TBitmap(Cache.Objects[K]));
  if Src = nil then
    Result := nil
  else if N <= 1 then
    Result := Src
  else
    Result := FromPix(ScalePix(ToPix(Src), N));
  Cache.AddObject(Key, Result);
end;

function ScaledSprite(Id: Word; N: Integer): TBitmap;
var
  K: Integer;
  Key: string;
begin
  N := SupportedFactor(N);
  Key := 'S' + IntToStr(Id) + 'x' + IntToStr(N);
  K := Cache.IndexOf(Key);
  if K >= 0 then
    Exit(TBitmap(Cache.Objects[K]));
  Result := Cached(Key, Sprite(Id), N);
end;

function ScaledBitmap(const Name: RawByteString; Id: Word; N: Integer): TBitmap;
var
  K: Integer;
  Key: string;
begin
  N := SupportedFactor(N);
  Key := 'B' + UpperCase(Name) + '#' + IntToStr(Id) + 'x' + IntToStr(N);
  K := Cache.IndexOf(Key);
  if K >= 0 then
    Exit(TBitmap(Cache.Objects[K]));
  Result := Cached(Key, ResBitmap(Name, Id), N);
end;

function ScaledOf(B: TBitmap; N: Integer): TBitmap;
var
  K: Integer;
  Key: string;
begin
  if B = nil then
    Exit(nil);
  N := SupportedFactor(N);
  if N <= 1 then
    Exit(B);
  Key := 'P' + IntToHex(PtrUInt(B), 16) + 'x' + IntToStr(N);
  K := Cache.IndexOf(Key);
  if K >= 0 then
    Exit(TBitmap(Cache.Objects[K]));
  Result := Cached(Key, B, N);
end;

procedure ForgetScaled(B: TBitmap);
var
  I: Integer;
  Prefix: string;
begin
  if B = nil then
    Exit;
  Prefix := 'P' + IntToHex(PtrUInt(B), 16) + 'x';
  for I := Cache.Count - 1 downto 0 do
    if Copy(Cache[I], 1, Length(Prefix)) = Prefix then
    begin
      if Cache.Objects[I] <> B then
        Cache.Objects[I].Free;
      Cache.Delete(I);
    end;
end;

initialization
  Cache := TStringList.Create;
  Cache.Sorted := True;
end.
