{ The drawing of the main window (segment 13, 1060:0527..2241) and its
  toolbar (segment 17, the OWLToolbar unit).

  The original draws into a memory DC of (ResolutionWidth - 33) x
  (ResolutionHeight - 40) pixels and blits it to x = 32 of the client area,
  right of the toolbar docked on the left. GDI is reproduced pixel for pixel
  where it matters: Rectangle (pen border inside the rectangle, brush
  inside), MoveTo/LineTo (end point excluded), 8x8 pattern brushes aligned to
  the memory DC's origin, BitBlt, StretchBlt (nearest neighbour) and the
  masked sprites of Bmp_DrawMasked (1078:00c4). Positions, tables and texts
  are read from the original data segment. }
unit MainPaint;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, LCLType, IntfGraphics, FPImage, GraphType,
  KaiserTypes, KaiserDS, Real48, Rules, KaiserLCL;

{ the window size of the current resolution (DS:4536 / DS:453c, by
  DS.OptResolution) }
function ResolutionWidth: Integer;
function ResolutionHeight: Integer;
{ the client size the original gets: SetupWindow fixes the client height at
  ResolutionHeight - 40; the window has a one-pixel border (no thick frame) }
function MainClientWidth: Integer;
function MainClientHeight: Integer;

{ game_state 2/6/7 (1060:0527): only the MUSTER pattern }
procedure PaintPatternBackground(C: TCanvas);
{ game_state 0 (1060:064b): MUSTER, WAPPEN and BIGLOGO stretched by the
  resolution factor DS:4542 }
procedure PaintTitleScreen(C: TCanvas);
{ game_state 1 (1060:0868): the realm of the current player. Like the
  original it recomputes birth/death rates and happiness of the player at
  800x600 and 1024x768 (UpdateBirthDeathRates may draw a random number). }
procedure DrawPlayerBuildings(C: TCanvas; var P: TPlayer; Year: Word);

type
  { the OWLToolbar window (VMT DS:4418) with its ToolSpacer / ToolButton
    tools, docked on the left (orientation 2) }
  TToolCommand = procedure(Id: Word) of object;

  TTool = record
    Button: Boolean;          { ToolButton (VMT DS:44c4), else ToolSpacer (DS:4484) }
    Bmp: TBitmap;
    Cmd: Word;
    Size: Integer;            { spacer: width = height }
    R: TRect;                 { button: +0d (X, Y, X + bmWidth + 4, Y + bmHeight + 4) }
    Enabled: Boolean;         { +0c }
    Down: Boolean;            { +0b drawn down }
  end;

  TKaiserToolbar = class(TCustomControl)
  private
    FTools: array of TTool;
    FW, FH: Integer;          { Attr.W / Attr.H }
    FCaptured: Integer;       { +51 }
    FPending: PtrInt;
    procedure LoadTools(const ResName: RawByteString);
    procedure DrawTool(C: TCanvas; I: Integer);
    function HitTest(I, X, Y: Integer): Boolean;
    procedure Post(Data: PtrInt);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    OnCommand: TToolCommand;
    constructor Create(AOwner: TComponent); override;
    { Toolbar::SetResource (1080:01df): a new set of tools, all enabled }
    procedure SetResource(const ResName: RawByteString);
    { Menu_Enable/DisableGameCommands: tools 0..Last by collection index }
    procedure EnableTools(Last: Integer; On: Boolean);
    function ToolCount: Integer;
    { the toolbar as the parent shows it, at the parent's client origin
      (the window sits at -1/-1 with a one-pixel border) }
    procedure PaintTo(C: TCanvas; ClientH: Integer);
    { the docked size: Attr.W wide, in parent coordinates 0..FW-2 }
    property BarWidth: Integer read FW;
  end;

{ the last toolbar index enabled with the game commands (DS:4554[res]);
  for 1024x768 the original reads 72 there and stops with runtime error
  213 (docs/functions/ui-infra.md), the port clamps to the last tool }
function LastGameTool(Bar: TKaiserToolbar): Integer;

implementation

uses
  HelpView;

const
  ClGray = $C0C0C0;           { RGB(192, 192, 192) pens, LTGRAY_BRUSH }
  ClDark = $808080;           { RGB(128, 128, 128) toolbar shadow pen }

function DSWord(Ofs: Word): SmallInt; inline;
begin
  Result := PSmallInt(@PByte(@DS)[Ofs])^;
end;

function DSByte(Ofs: Word): Byte; inline;
begin
  Result := PByte(@DS)[Ofs];
end;

function ResolutionWidth: Integer;
begin
  Result := DSWord($4536 + 2 * DS.OptResolution);
end;

function ResolutionHeight: Integer;
begin
  Result := DSWord($453C + 2 * DS.OptResolution);
end;

function MainClientWidth: Integer;
begin
  Result := ResolutionWidth - 2;
end;

function MainClientHeight: Integer;
begin
  Result := ResolutionHeight - 40;
end;

function LastGameTool(Bar: TKaiserToolbar): Integer;
begin
  Result := DSByte($4554 + DS.OptResolution);
  if Result > Bar.ToolCount - 1 then
    Result := Bar.ToolCount - 1;
end;

{ -- GDI primitives ---------------------------------------------------------- }

procedure Fill(C: TCanvas; X1, Y1, X2, Y2: Integer; Color: TColor);
begin
  if (X2 <= X1) or (Y2 <= Y1) then
    Exit;
  C.Brush.Style := bsSolid;
  C.Brush.Color := Color;
  C.FillRect(X1, Y1, X2, Y2);
end;

var
  Tiled: TStringList;         { pattern name -> the pattern tiled over 1100x800 }

function TiledPattern(const Name: RawByteString): TBitmap;
const
  TW = 1100; TH = 800;
var
  K, X, Y, N: Integer;
  Pat: TBitmap;
begin
  K := Tiled.IndexOf(Name);
  if K >= 0 then
    Exit(TBitmap(Tiled.Objects[K]));
  Result := TBitmap.Create;
  Result.SetSize(TW, TH);
  Pat := ResBitmap(Name);
  if Pat <> nil then
  begin
    { an 8x8 pattern brush; doubling copies }
    Result.Canvas.Draw(0, 0, Pat);
    N := 8;
    while N < TW do
    begin
      X := N;
      if X > TW - N then
        X := TW - N;
      Result.Canvas.CopyRect(Rect(N, 0, N + X, 8), Result.Canvas, Rect(0, 0, X, 8));
      Inc(N, X);
    end;
    N := 8;
    while N < TH do
    begin
      Y := N;
      if Y > TH - N then
        Y := TH - N;
      Result.Canvas.CopyRect(Rect(0, N, TW, N + Y), Result.Canvas, Rect(0, 0, TW, Y));
      Inc(N, Y);
    end;
  end;
  Tiled.AddObject(Name, Result);
end;

{ fill with a pattern brush whose origin is the DC's origin }
procedure FillPattern(C: TCanvas; X1, Y1, X2, Y2: Integer; const Name: RawByteString);
var
  T: TBitmap;
begin
  if (X2 <= X1) or (Y2 <= Y1) then
    Exit;
  T := TiledPattern(Name);
  C.CopyRect(Rect(X1, Y1, X2, Y2), T.Canvas, Rect(X1, Y1, X2, Y2));
end;

type
  TBrushKind = (bkNull, bkSolid, bkPattern);

{ GDI Rectangle with a one-pixel pen: border on X1, Y1, X2 - 1, Y2 - 1, the
  brush inside }
procedure GdiRectangle(C: TCanvas; X1, Y1, X2, Y2: Integer; Pen: TColor;
  Brush: TBrushKind; BrushColor: TColor = 0; const Pattern: RawByteString = '');
begin
  case Brush of
    bkSolid: Fill(C, X1 + 1, Y1 + 1, X2 - 1, Y2 - 1, BrushColor);
    bkPattern: FillPattern(C, X1 + 1, Y1 + 1, X2 - 1, Y2 - 1, Pattern);
  end;
  Fill(C, X1, Y1, X2, Y1 + 1, Pen);
  Fill(C, X1, Y2 - 1, X2, Y2, Pen);
  Fill(C, X1, Y1, X1 + 1, Y2, Pen);
  Fill(C, X2 - 1, Y1, X2, Y2, Pen);
end;

{ LineTo for horizontal and vertical lines: from the current position to
  (X, Y), the end point excluded }
procedure LineTo(C: TCanvas; var Cur: TPoint; X, Y: Integer; Pen: TColor);
begin
  if Cur.Y = Y then
  begin
    if X > Cur.X then
      Fill(C, Cur.X, Y, X, Y + 1, Pen)
    else
      Fill(C, X + 1, Y, Cur.X + 1, Y + 1, Pen);
  end
  else if Cur.X = X then
  begin
    if Y > Cur.Y then
      Fill(C, X, Cur.Y, X + 1, Y, Pen)
    else
      Fill(C, X, Y + 1, X + 1, Cur.Y + 1, Pen);
  end
  else
  begin
    C.Pen.Color := Pen;
    C.Pen.Width := 1;
    C.Line(Cur.X, Cur.Y, X, Y);
  end;
  Cur := Point(X, Y);
end;

{ Bmp_Draw (1078:0002) / Bmp_DrawPart (1078:0062): BitBlt SRCCOPY }
procedure BmpDrawPart(C: TCanvas; B: TBitmap; X, Y, SX, SY, W, H: Integer);
begin
  if B = nil then
    Exit;
  C.CopyRect(Rect(X, Y, X + W, Y + H), B.Canvas, Rect(SX, SY, SX + W, SY + H));
end;

procedure BmpDraw(C: TCanvas; B: TBitmap; X, Y, W, H: Integer);
begin
  BmpDrawPart(C, B, X, Y, 0, 0, W, H);
end;

{ Bmp_DrawMasked (1078:00c4): mask Id + 1000 SRCAND, then Id SRCPAINT }
procedure BmpDrawMasked(C: TCanvas; Id: Integer; X, Y: Integer);
var
  B: TBitmap;
begin
  if (Id < 0) or (Id > $FFFF - 1000) then
    Exit;
  B := Sprite(Id);
  if B <> nil then
    C.Draw(X, Y, B);
end;

var
  Stretched: TStringList;

{ Bmp_DrawStretched (1078:0228): StretchBlt SRCCOPY of (0, 0, W, H) to
  Round(W * Scale) x Round(H * Scale), nearest neighbour }
procedure BmpDrawStretched(C: TCanvas; const Name: RawByteString; X, Y, W, H: Integer;
  const Scale: TReal48);
var
  DW, DH, I, J, K: Integer;
  Src: TBitmap;
  SI, DI: TLazIntfImage;
  Key: string;
  B: TBitmap;
begin
  Src := ResBitmap(Name);
  if Src = nil then
    Exit;
  DW := R48Round(R48Mul(R48FromLong(W), Scale));
  DH := R48Round(R48Mul(R48FromLong(H), Scale));
  Key := Name + '#' + IntToStr(DW) + 'x' + IntToStr(DH);
  K := Stretched.IndexOf(Key);
  if K >= 0 then
    B := TBitmap(Stretched.Objects[K])
  else
  begin
    SI := Src.CreateIntfImage;
    DI := TLazIntfImage.Create(DW, DH, [riqfRGB]);
    try
      DI.CreateData;
      for J := 0 to DH - 1 do
        for I := 0 to DW - 1 do
          DI.Colors[I, J] := SI.Colors[I * W div DW, J * H div DH];
      B := TBitmap.Create;
      B.LoadFromIntfImage(DI);
    finally
      DI.Free;
      SI.Free;
    end;
    Stretched.AddObject(Key, B);
  end;
  C.Draw(X, Y, B);
end;

{ TextOut with TA_TOP and TA_LEFT or TA_RIGHT, transparent background }
procedure TextAt(C: TCanvas; X, Y: Integer; const Raw: RawByteString; Right: Boolean;
  Color: TColor);
var
  S: string;
begin
  S := Utf8(Raw);
  C.Brush.Style := bsClear;
  C.Font.Color := Color;
  if Right then
    Dec(X, C.TextWidth(S));
  C.TextOut(X, Y, S);
end;

{ the LOGFONT DS:60c8 of Unit13_Init (1060:2241): -12 px, bold, Comic Sans MS }
procedure SelectMapFont(C: TCanvas);
begin
  C.Font.Name := 'Comic Sans MS';
  C.Font.Height := -12;
  C.Font.Style := [fsBold];
  C.Font.Quality := fqNonAntialiased;
end;

{ -- the three pictures --------------------------------------------------------- }

procedure PaintPatternBackground(C: TCanvas);
var
  W, H: Integer;
  M: TBitmap;
begin
  W := ResolutionWidth - 33;
  H := ResolutionHeight - 40;
  M := TBitmap.Create;
  try
    M.SetSize(W, H);
    GdiRectangle(M.Canvas, 0, 0, W, H, ClGray, bkPattern, 0, 'MUSTER');
    C.Draw(32, 0, M);
  finally
    M.Free;
  end;
end;

procedure PaintTitleScreen(C: TCanvas);
var
  W, H: Integer;
  M: TBitmap;
  S: TReal48;

  function Sc(V: Integer): Integer;
  begin
    Result := R48Round(R48Mul(S, R48FromLong(V)));
  end;

begin
  W := ResolutionWidth - 33;
  H := ResolutionHeight - 40;
  Move(PByte(@DS)[$4542 + 6 * DS.OptResolution], S, 6);    { 1.0 / 1.25 / 1.6 }
  M := TBitmap.Create;
  try
    M.SetSize(W, H);
    GdiRectangle(M.Canvas, 0, 0, W, H, ClGray, bkPattern, 0, 'MUSTER');
    BmpDrawStretched(M.Canvas, 'WAPPEN', Sc(188), Sc(30), 200, 250, S);
    BmpDrawStretched(M.Canvas, 'BIGLOGO', Sc(163), Sc(290), 250, 125, S);
    C.Draw(32, 0, M);
  finally
    M.Free;
  end;
end;

procedure DrawPlayerBuildings(C: TCanvas; var P: TPlayer; Year: Word);
const
  Red = $0000FF;              { RGB(255, 0, 0) }
var
  W, H, PX, OX, OY, I, N, T, Hap: Integer;
  Farm: LongInt;              { (land - land_used) div 1000 }
  M: TBitmap;
  C2: TCanvas;
  Cur: TPoint;
  S, Num: RawByteString;
  U: ^TUnit;

  procedure Lbl(Y: Integer; Ofs: Word);
  begin
    TextAt(C2, PX + 8, Y, DSText(Ofs), False, clBlack);
  end;

  procedure Val(Y: Integer; V: LongInt; Warn: Boolean);
  begin
    Str(V, Num);
    if Warn then
      TextAt(C2, W - $2A, Y, Num, True, Red)
    else
      TextAt(C2, W - $2A, Y, Num, True, clBlack);
  end;

  function Tile(Base, D: Integer): Integer;
  begin
    Result := (Base + D) * 32;
  end;

begin
  W := ResolutionWidth;
  H := ResolutionHeight;
  PX := W - $AC;                                   { the panel's left edge }
  OX := DSWord($41A2 + 2 * DS.OptResolution);      { map origin in tiles }
  OY := DSWord($41A8 + 2 * DS.OptResolution);
  Farm := (P.Land - P.LandUsed) div 1000;
  M := TBitmap.Create;
  try
    M.SetSize(W - $21, H - $28);
    C2 := M.Canvas;
    { the land: LAND pattern, green pen }
    GdiRectangle(C2, 0, 0, PX, H - $28, $00FF00, bkPattern, 0, 'LAND');
    { the town wall (MAUER, grey pen), gate on the left in row 6 }
    GdiRectangle(C2, Tile(OX, 6) - 8, Tile(OY, 5) - 8, Tile(OX, 9) + 8, Tile(OY, 5) - 1,
      ClGray, bkPattern, 0, 'MAUER');
    GdiRectangle(C2, Tile(OX, 9) + 1, Tile(OY, 5) - 1, Tile(OX, 9) + 8, Tile(OY, 8) + 1,
      ClGray, bkPattern, 0, 'MAUER');
    GdiRectangle(C2, Tile(OX, 6) - 8, Tile(OY, 8) + 1, Tile(OX, 9) + 8, Tile(OY, 8) + 8,
      ClGray, bkPattern, 0, 'MAUER');
    GdiRectangle(C2, Tile(OX, 6) - 8, Tile(OY, 5) - 1, Tile(OX, 6) - 1, Tile(OY, 6) - 1,
      ClGray, bkPattern, 0, 'MAUER');
    GdiRectangle(C2, Tile(OX, 6) - 8, Tile(OY, 7) - 1, Tile(OX, 6) - 1, Tile(OY, 8) + 1,
      ClGray, bkPattern, 0, 'MAUER');
    { villages: one per 4 markets beyond the 5th (DS:395c / DS:398c) }
    if P.Markets > 4 then
    begin
      N := SmallInt(Word((P.Markets - 5) div 4 + 1));
      if DSWord($39BE + 2 * DS.OptResolution) < N then
        N := DSWord($39BE + 2 * DS.OptResolution);
      for I := 1 to N do
        BmpDraw(C2, ResBitmap('VILLAGE'), Tile(OX, DSWord($395C + 2 * I)) - 7,
          Tile(OY, DSWord($398C + 2 * I)) - 7, $4E, $4E);
    end;
    { the panel: INI background brush, grey pen, raised frame }
    GdiRectangle(C2, PX, 0, W - $21, H - $28, ClGray, bkSolid,
      RGBToColor(DS.OptBackground[0], DS.OptBackground[1], DS.OptBackground[2]));
    Cur := Point(PX + 2, H - $2B);
    LineTo(C2, Cur, PX + 2, 2, clWhite);
    LineTo(C2, Cur, W - $25, 2, clWhite);
    LineTo(C2, Cur, W - $25, H - $2B, clBlack);
    LineTo(C2, Cur, PX + 2, H - $2B, clBlack);
    { the sunken boxes of the palace and the cathedral }
    Cur := Point(W - $2B, 10);
    LineTo(C2, Cur, W - $2B, $5A, clWhite);
    LineTo(C2, Cur, PX + 8, $5A, clWhite);
    Cur := Point(W - $2B, 100);
    LineTo(C2, Cur, W - $2B, $B4, clWhite);
    LineTo(C2, Cur, PX + 8, $B4, clWhite);
    LineTo(C2, Cur, PX + 8, $63, clBlack);
    LineTo(C2, Cur, W - $2B, $63, clBlack);
    Cur := Point(PX + 8, $5A);
    LineTo(C2, Cur, PX + 8, 9, clBlack);
    LineTo(C2, Cur, W - $2B, 9, clBlack);
    { the texts }
    SelectMapFont(C2);
    if P.IsFemale = 0 then
      S := DS.TitleNames[P.Title]
    else
      S := DS.FemaleTitleNames[P.Title];
    TextAt(C2, PX + 8, $BE, S, False, clBlack);
    TextAt(C2, PX + 8, $CC, PChar(@P.Name), False, clBlack);
    TextAt(C2, PX + 8, $DA, DSText($41C1) + RawByteString(PChar(@DS.CountryNamesRt[P.Country])),
      False, clBlack);
    Str(Year + $578, Num);
    TextAt(C2, PX + 8, $E8, DSText($41C6) + Num, False, clBlack);
    if DS.OptResolution = 0 then
    begin
      Lbl($100, $41D0);                            { Einwohner }
      Lbl($10E, $41DA);                            { Land }
      Lbl($11C, $41DF);                            { Marktplaetze }
      Lbl($12A, $41EB);                            { Kornmuehlen }
      Lbl($138, $41F6);                            { Initiativpunkte }
      Lbl($146, $4206);                            { Ruhm }
      Lbl($154, $420B);                            { Taler }
      Val($100, P.Population, False);
      Val($10E, P.Land, False);
      Val($11C, P.Markets, P.Markets > Farm);
      Val($12A, P.Mills, P.Mills > Farm);
      Val($138, P.Initiative, False);
      Val($146, P.Fame, False);
      Val($154, P.Taler, P.Taler < 0);
    end
    else if DS.OptResolution in [1, 2] then
    begin
      Lbl($100, $41D0);                            { Einwohner }
      Lbl($10E, $4211);                            { Zufriedenheit }
      Lbl($120, $41DA);                            { Land }
      Lbl($12E, $421F);                            { Bauland }
      Lbl($13C, $4227);                            { Landpreis }
      Lbl($14E, $41DF);                            { Marktplaetze }
      Lbl($15C, $41EB);                            { Kornmuehlen }
      Lbl($16E, $4231);                            { Salz }
      Lbl($17C, $4236);                            { Bier }
      Lbl($18A, $423B);                            { Wein }
      Lbl($198, $4240);                            { Waffen }
      Lbl($1AA, $4206);                            { Ruhm }
      Lbl($1B8, $41F6);                            { Initiativpunkte }
      Lbl($1CC, $420B);                            { Taler }
      Val($100, P.Population, False);
      UpdateBirthDeathRates(P);
      Hap := SmallInt(UpdateHappiness(P));
      Val($10E, Hap, Hap <= $1E);
      Val($120, P.Land, False);
      Val($12E, P.Land - P.LandUsed, False);
      Val($13C, P.LandPrice, False);
      Val($14E, P.Markets, P.Markets > Farm);
      Val($15C, P.Mills, P.Mills > Farm);
      for I := 1 to 4 do                           { salt, beer, wine, weapons }
        Val($160 + I * $E, PLongInt(@PByte(@P)[$F1 + I * 4])^, False);
      Val($1AA, P.Fame, False);
      Val($1B8, P.Initiative, False);
      Val($1CC, P.Taler, P.Taler < 0);
    end;
    { markets (DS:37cc / DS:3894) }
    if P.Markets > 0 then
    begin
      N := Word(P.Markets);
      if DSWord($39C4 + 2 * DS.OptResolution) < SmallInt(N) then
        N := DSWord($39C4 + 2 * DS.OptResolution);
      for I := 1 to SmallInt(N) do
        BmpDrawMasked(C2, $3EA, Tile(OX, DSWord($37CC + 2 * I)), Tile(OY, DSWord($3894 + 2 * I)));
    end;
    { mills, one per 5 (DS:3754 / DS:3790) }
    if P.Mills > 0 then
    begin
      if P.Mills <= 5 then
        N := 1
      else
        N := SmallInt(Word(P.Mills div 5));
      if DSWord($39CA + 2 * DS.OptResolution) < N then
        N := DSWord($39CA + 2 * DS.OptResolution);
      for I := 1 to N do
        BmpDrawMasked(C2, $3EB, Tile(OX, DSWord($3754 + 2 * I)), Tile(OY, DSWord($3790 + 2 * I)));
    end;
    { the palace: its built parts (40x20 pieces of PALAST at DS:3e89 /
      DS:3e95) in the upper box, and the icon }
    if P.PalaceParts > 0 then
    begin
      for I := 1 to P.PalaceParts do
        BmpDrawPart(C2, ResBitmap('PALAST'), PX + 9 + DSByte($3E89 + I), DSByte($3E95 + I) + 10,
          DSByte($3E89 + I), DSByte($3E95 + I), $28, $14);
      BmpDrawMasked(C2, $3EC, Tile(OX, 8), Tile(OY, 5));
    end;
    if P.CathedralParts > 0 then
    begin
      for I := 1 to P.CathedralParts do
        BmpDrawPart(C2, ResBitmap('KATHEDRALE'), PX + 9 + DSByte($3E89 + I),
          DSByte($3E95 + I) + 100, DSByte($3E89 + I), DSByte($3E95 + I), $28, $14);
      BmpDrawMasked(C2, $3ED, Tile(OX, 8), Tile(OY, 7));
    end;
    if P.Granaries > 0 then
      BmpDrawMasked(C2, $3EE, Tile(OX, 8), Tile(OY, 4) - $10);
    if P.Warehouses > 0 then
      BmpDrawMasked(C2, $3EF, Tile(OX, 6), Tile(OY, 8) + $10);
    if P.UniversityParts > 0 then
      BmpDrawMasked(C2, $3F3, Tile(OX, 8), Tile(OY, 6));
    if P.Taverns > 0 then
      BmpDrawMasked(C2, $3F4, Tile(OX, 7), Tile(OY, 5));
    if P.Smithies > 0 then
      BmpDrawMasked(C2, $3F5, Tile(OX, 7), Tile(OY, 7));
    BmpDraw(C2, ResBitmap('LOGO'), PX + 9, H - $77, $78, $46);
    { the Heer along the bottom, from the right; the Garde in the town }
    N := 0;
    if (P.ArmyAway = 0) and (P.Army1Count >= 1) then
      for I := P.Army1Count downto 1 do
      begin
        Inc(N);
        U := @P.Army1[I];
        if U^.UnitType = 9 then
          T := U^.HeroPortrait + $32
        else
          T := ShortInt(U^.UnitType);
        BmpDrawMasked(C2, T + $4B0, PX - 4 - N * 32, H - $4C);
      end;
    for I := 1 to P.Army2Count do
    begin
      U := @P.Army2[I];
      if U^.UnitType = 9 then
        T := U^.HeroPortrait + $32
      else
        T := ShortInt(U^.UnitType);
      BmpDrawMasked(C2, T + $4B0, Tile(OX, DSWord($39CE + 2 * I)), Tile(OY, DSWord($39DE + 2 * I)));
    end;
    C.Draw(32, 0, M);
  finally
    M.Free;
  end;
end;

{ -- the toolbar ----------------------------------------------------------------- }

constructor TKaiserToolbar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaptured := -1;
  FPending := 0;
  ControlStyle := ControlStyle + [csOpaque];
end;

function TKaiserToolbar.ToolCount: Integer;
begin
  Result := Length(FTools);
end;

procedure TKaiserToolbar.LoadTools(const ResName: RawByteString);
var
  D: TBytes;
  N, I, PX, PY, Id, Arg: Integer;
  T: TTool;
begin
  { Toolbar::LoadTools (1080:0229): word N, N x (bitmap id, command);
    bitmap 0 is a spacer of that size; tools from (2, 2); +8 px border }
  SetLength(FTools, 0);
  FW := 5;
  FH := 5;
  D := Exe.FindNamedType('TOOLBARDATA', ResName);
  if Length(D) < 2 then
    Exit;
  N := D[0] or (D[1] shl 8);
  PX := 2;
  PY := 2;
  for I := 1 to N do
  begin
    if 2 + I * 4 > Length(D) then
      Break;
    Id := D[I * 4 - 2] or (D[I * 4 - 1] shl 8);
    Arg := D[I * 4] or (D[I * 4 + 1] shl 8);
    FillChar(T, SizeOf(T), 0);
    if Id = 0 then
    begin
      T.Size := Arg;
      T.R := Rect(PX, PY, PX + Arg, PY + Arg);
    end
    else
    begin
      T.Button := True;
      T.Bmp := ResBitmap('', Id);
      T.Cmd := Arg;
      T.Enabled := True;
      if T.Bmp <> nil then
        T.R := Rect(PX, PY, PX + T.Bmp.Width + 4, PY + T.Bmp.Height + 4)
      else
        T.R := Rect(PX, PY, PX + 4, PY + 4);
    end;
    { AdvanceToolPos (orientation 2): down, the width is the widest tool }
    Inc(PY, T.R.Bottom - T.R.Top);
    if T.R.Right - T.R.Left > FW then
      FW := T.R.Right - T.R.Left;
    SetLength(FTools, Length(FTools) + 1);
    FTools[High(FTools)] := T;
  end;
  Inc(FW, 8);
  Inc(FH, 8);
end;

procedure TKaiserToolbar.SetResource(const ResName: RawByteString);
begin
  FCaptured := -1;
  LoadTools(ResName);
  Width := FW - 1;
  Invalidate;
end;

procedure TKaiserToolbar.EnableTools(Last: Integer; On: Boolean);
var
  I: Integer;
begin
  for I := 0 to Last do
    if (I <= High(FTools)) and FTools[I].Button and (FTools[I].Enabled <> On) then
    begin
      FTools[I].Enabled := On;                     { SetEnabled invalidates }
      Invalidate;
    end;
end;

function TKaiserToolbar.HitTest(I, X, Y: Integer): Boolean;
begin
  Result := FTools[I].Button and (X >= FTools[I].R.Left) and (X < FTools[I].R.Right) and
    (Y >= FTools[I].R.Top) and (Y < FTools[I].R.Bottom);
end;

var
  GrayImg: TLazIntfImage;

{ ToolButton::Draw (1080:0d59) }
procedure TKaiserToolbar.DrawTool(C: TCanvas; I: Integer);
var
  L, T, R, B, Off, X, Y: Integer;
  Cur: TPoint;
  SI, DI: TLazIntfImage;
  Pc, Sc: TFPColor;
  Dis: TBitmap;
begin
  if not FTools[I].Button then
    Exit;
  L := FTools[I].R.Left;
  T := FTools[I].R.Top;
  R := FTools[I].R.Right;
  B := FTools[I].R.Bottom;
  { black pen, LTGRAY brush: Rectangle(L, T, R + 1, B + 1) }
  GdiRectangle(C, L, T, R + 1, B + 1, clBlack, bkSolid, ClGray);
  if not FTools[I].Down then
  begin
    Off := 2;
    Cur := Point(L + 1, B - 1);
    LineTo(C, Cur, L + 1, T + 1, clWhite);
    LineTo(C, Cur, R - 1, T + 1, clWhite);
    Cur := Point(R - 1, T + 1);
    LineTo(C, Cur, R - 1, B - 1, ClDark);
    LineTo(C, Cur, L + 1, B - 1, ClDark);
  end
  else
  begin
    Off := 3;
    Cur := Point(L + 1, B - 1);
    LineTo(C, Cur, L + 1, T + 1, ClDark);
    LineTo(C, Cur, R, T + 1, ClDark);
  end;
  if FTools[I].Bmp = nil then
    Exit;
  if FTools[I].Enabled then
    C.Draw(L + Off, T + Off, FTools[I].Bmp)                       { SRCCOPY }
  else
  begin
    { ROP 00A803A9 = D and (P or S) with the GrayingBitmap pattern (origin
      0, 0 of the toolbar) over the LTGRAY face }
    if GrayImg = nil then
      if ResBitmap('GRAYINGBITMAP') <> nil then
        GrayImg := ResBitmap('GRAYINGBITMAP').CreateIntfImage;
    SI := FTools[I].Bmp.CreateIntfImage;
    DI := TLazIntfImage.Create(SI.Width, SI.Height, [riqfRGB]);
    try
      DI.CreateData;
      for Y := 0 to SI.Height - 1 do
        for X := 0 to SI.Width - 1 do
        begin
          Sc := SI.Colors[X, Y];
          if GrayImg <> nil then
            Pc := GrayImg.Colors[(L + Off + X) and 7, (T + Off + Y) and 7]
          else
            Pc := colBlack;
          Sc.Red := (Sc.Red or Pc.Red) and $C0C0;
          Sc.Green := (Sc.Green or Pc.Green) and $C0C0;
          Sc.Blue := (Sc.Blue or Pc.Blue) and $C0C0;
          Sc.Alpha := $FFFF;
          DI.Colors[X, Y] := Sc;
        end;
      Dis := TBitmap.Create;
      try
        Dis.LoadFromIntfImage(DI);
        C.Draw(L + Off, T + Off, Dis);
      finally
        Dis.Free;
      end;
    finally
      DI.Free;
      SI.Free;
    end;
  end;
end;

procedure TKaiserToolbar.PaintTo(C: TCanvas; ClientH: Integer);
var
  I: Integer;
begin
  { the window at (-1, -1), FW wide, one-pixel black border: client 0..FW-3,
    the right border at FW-2; LTGRAY class brush }
  Fill(C, 0, 0, FW - 2, ClientH, ClGray);
  Fill(C, FW - 2, 0, FW - 1, ClientH, clBlack);
  { Toolbar::Paint (1080:05a5): white line along the top edge }
  Fill(C, 0, 0, FW - 2, 1, clWhite);
  for I := 0 to High(FTools) do
    DrawTool(C, I);
end;

procedure TKaiserToolbar.Paint;
begin
  PaintTo(Canvas, Height);
end;

procedure TKaiserToolbar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbRight then
  begin
    { the context help (1080:0991 / VMT DS:44c4: WinHelp HELP_CONTEXTPOPUP,
      the command + 1000) }
    for I := 0 to High(FTools) do
      if HitTest(I, X, Y) then
        ShowHelpTopic(FTools[I].Cmd + 1000);
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  FCaptured := -1;
  for I := 0 to High(FTools) do
    if HitTest(I, X, Y) then
    begin
      FCaptured := I;
      Break;
    end;
  if FCaptured < 0 then
    Exit;
  { ToolButton::BeginPress / PressDown }
  FTools[FCaptured].Down := False;
  if FTools[FCaptured].Enabled then
  begin
    FTools[FCaptured].Down := True;
    Invalidate;
  end;
end;

procedure TKaiserToolbar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  D: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  if FCaptured < 0 then
    Exit;
  D := HitTest(FCaptured, X, Y) and FTools[FCaptured].Enabled;
  if D <> FTools[FCaptured].Down then
  begin
    FTools[FCaptured].Down := D;
    Invalidate;
  end;
end;

procedure TKaiserToolbar.Post(Data: PtrInt);
begin
  if Assigned(OnCommand) then
    OnCommand(Word(Data));
end;

procedure TKaiserToolbar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FCaptured < 0) then
    Exit;
  I := FCaptured;
  FCaptured := -1;
  { ToolButton::EndPress: inside the button the command is posted (also for
    a disabled button, the main window's handlers check the game state) }
  if HitTest(I, X, Y) then
  begin
    if FTools[I].Down then
    begin
      FTools[I].Down := False;
      Invalidate;
    end;
    Application.QueueAsyncCall(@Post, FTools[I].Cmd);
  end;
end;

initialization
  Tiled := TStringList.Create;
  Stretched := TStringList.Create;
end.
