{ The battle window (segment 10, BattleWnd 1048:xxxx) on the LCL: the
  drawing of the original (DrawMap 1048:1068, DrawPanelFrames 17fd,
  ClearTargetPanel 196c, DrawUnitStatus 1a60, DrawCell 2803, RedrawUnit
  6192), the cursors and the hover panel (WMMouseMove 91ae), the buttons,
  the window timer and the clicks. The logic is unit Battle (the same code
  the differential tests run); its drawing calls (UI 'Battle_*') come here
  through LclUI.

  The window is drawn into an off-screen bitmap of the client area (the
  original draws straight onto the window DC); OnPaint shows it. The
  coordinates are the original's pixels: a 15 x 11 map of 32-pixel cells,
  the status panels below (the current unit left, the target right), the
  buttons Warten / Fertig / Aufgeben between them.

  Autopilot (KAISER_AUTOPILOT=DIR): PNGs DIR/battle_NNN_<tick>.png at a few
  moments; KAISER_AUTOBATTLE=ai lets the AI play the human sides too,
  otherwise the human sides are played by scripted clicks (attack what can
  be attacked, else step towards the nearest enemy, else Fertig). }
unit BattleForm;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, LCLType, LCLIntf,
  Math, IntfGraphics, FPImage, GraphType,
  NERes, KaiserTypes, KaiserDS, KaiserUI, Real48, Rules, Battle, KaiserLCL, HelpView, RGraphics;

const
  MapW = 480;               { 15 cells of 32 pixels }
  MapH = 352;               { 11 cells }
  ClientW = 480;            { MoveWindow 0x1e2 x 0x1ca minus the frame and caption }
  ClientH = 437;

type
  PBattleWnd = ^TBattleWnd;

  TBattleForm = class(TForm)
  private
    FScreen: TBitmap;
    FGrass: TBitmap;
    FButtons: array[0..2] of TButton;
    FTimer: TTimer;
    FBusy: Integer;
    FTicks: LongInt;
    FAuto: Boolean;           { autopilot }
    FAutoAi: Boolean;         { the AI plays the human sides }
    FAutoRight: Boolean;      { the scripted right click was done }
    { remastered: the window FS times larger than the original's, the
      picture drawn FF times larger (DialogScale / DialogFactor) }
    FS: Double;
    FF: Integer;
    function Z(V: Integer): Integer; inline;
    procedure Bar(Cv: TCanvas; X1, Y1, X2, Y2: Integer; Fill: TColor);
    procedure FormPaint(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ButtonClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    function Enter: Boolean;
    procedure Leave;
    procedure AutoAct;
    procedure AutoHover;
    procedure Snapshot(const What: string);
    { drawing helpers (pixels of the off-screen bitmap) }
    procedure Masked(Id: Integer; X, Y: Integer);
    procedure Silhouette(Id: Integer; X, Y: Integer);
    procedure Terrain(X, Y: Integer);
    procedure UnitSprite(S, I: Byte; Base: Integer; Shade: Boolean; X, Y: Integer);
  public
    B: PBattleWnd;
    { a dialog ran during the battle: WM_PAINT follows (WMPaint) }
    NeedPaint: Boolean;
    constructor CreateBattle(AOwner: TComponent; W: PBattleWnd);
    destructor Destroy; override;
    procedure WMPaint;
    procedure DrawMap;
    procedure DrawPanelFrames;
    procedure DrawCell(X, Y: SmallInt; Code: Byte);
    procedure RedrawUnit(S, I: Byte);
    procedure DrawUnitStatus(S, I, Panel: Byte);
    procedure ClearTargetPanel;
    procedure EnableButtons(On: Boolean);
    procedure WMMouseMove(PX, PY: Integer);
    { show what was drawn now (before a synchronous sound or a pause) }
    procedure Flush;
  end;

var
  ActiveBattle: TBattleForm;

{ the modal battle window (Battle_Execute): its end code }
function RunBattle(W: PBattleWnd): Byte;

implementation

const
  Grey = $C0C0C0;

var
  { the cursors of SetupWindow (0bc3): Screen.Cursors[1..4] when loaded }
  crStop: TCursor = crNo;
  crSword: TCursor = crCross;
  crGo: TCursor = crHandPoint;
  crHeal: TCursor = crHandPoint;
  CursorsLoaded: Boolean = False;
  FShots: Integer = 0;              { autopilot snapshots (all battles) }
  SilhouetteCache: TStringList;

{ -- resources ------------------------------------------------------------ }

{ a .cur file from RT_GROUP_CURSOR Name and its RT_CURSOR (hot spot first) }
function CursorFile(const Name: RawByteString): TBytes;
var
  G, C: TBytes;
  Img: Integer;
begin
  Result := nil;
  G := Exe.Find(RT_GROUP_CURSOR, Name);
  if Length(G) < 6 + 14 then
    Exit;
  C := Exe.Find(RT_CURSOR, '', G[6 + 12] or (G[6 + 13] shl 8));
  if Length(C) < 4 + 40 then
    Exit;
  Img := Length(C) - 4;
  SetLength(Result, 6 + 16 + Img);
  FillChar(Result[0], 6 + 16, 0);
  Result[2] := 2;                               { type: cursor }
  Result[4] := 1;                               { one image }
  Result[6] := G[6];                            { width }
  Result[7] := G[6 + 2] div 2;                  { height (the group gives the doubled height) }
  Result[10] := C[0]; Result[11] := C[1];       { hot spot x }
  Result[12] := C[2]; Result[13] := C[3];       { hot spot y }
  PLongWord(@Result[14])^ := NtoLE(LongWord(Img));
  PLongWord(@Result[18])^ := NtoLE(LongWord(6 + 16));
  Move(C[4], Result[22], Img);
end;

procedure LoadCursors;

  procedure One(N: Integer; const Name: RawByteString; var Kind: TCursor);
  var
    Data: TBytes;
    S: TMemoryStream;
    Cur: TCursorImage;
  begin
    Data := CursorFile(Name);
    if Data = nil then
      Exit;
    S := TMemoryStream.Create;
    Cur := TCursorImage.Create;
    try
      S.WriteBuffer(Data[0], Length(Data));
      S.Position := 0;
      try
        Cur.LoadFromStream(S);
        Screen.Cursors[N] := Cur.ReleaseHandle;
        Kind := N;
      except
      end;
    finally
      Cur.Free;
      S.Free;
    end;
  end;

begin
  if CursorsLoaded then
    Exit;
  CursorsLoaded := True;
  One(1, 'STOPCURSOR', crStop);
  One(2, 'SWORDCURSOR', crSword);
  One(3, 'GOCURSOR', crGo);
  One(4, 'HEALCURSOR', crHeal);
  if GetEnvironmentVariable('KAISER_AUTOPILOT') <> '' then
    WriteLn('battle cursors: ', crStop, ' ', crSword, ' ', crGo, ' ', crHeal);
end;

{ Bmp_DrawSilhouette32 (1078:0199): only the mask (Id + 2100) with SRCAND:
  a black shape }
function SilhouetteBitmap(Id: Integer): TBitmap;
var
  Mask: TBitmap;
  Src, Dst: TLazIntfImage;
  X, Y, K: Integer;
  C: TFPColor;
begin
  K := SilhouetteCache.IndexOf(IntToStr(Id));
  if K >= 0 then
    Exit(TBitmap(SilhouetteCache.Objects[K]));
  Result := nil;
  Mask := ResBitmap('', Id + 2100);
  if Mask <> nil then
  begin
    Src := Mask.CreateIntfImage;
    Dst := TLazIntfImage.Create(Mask.Width, Mask.Height, [riqfRGB, riqfAlpha]);
    try
      Dst.CreateData;
      for Y := 0 to Mask.Height - 1 do
        for X := 0 to Mask.Width - 1 do
        begin
          C := colBlack;
          if Src.Colors[X, Y].Red > $8000 then
            C.Alpha := 0
          else
            C.Alpha := $FFFF;
          Dst.Colors[X, Y] := C;
        end;
      Result := TBitmap.Create;
      Result.LoadFromIntfImage(Dst);
    finally
      Dst.Free;
      Src.Free;
    end;
  end;
  SilhouetteCache.AddObject(IntToStr(Id), Result);
end;

function UnitOf(W: PBattleWnd; S, I: Byte): PUnit; inline;
begin
  Result := BattleUnit(W^, S, I);
end;

{ the picture of a unit: a hero (type 9) his portrait + 50, else the type }
function PictureOf(const U: TUnit): Integer;
begin
  if U.UnitType = 9 then
    Result := U.HeroPortrait + $32
  else
    Result := ShortInt(U.UnitType);
end;

function IsBuilding(C: Byte): Boolean; inline;
begin
  Result := ((C >= 2) and (C <= 7)) or ((C >= $0B) and (C <= $0D));
end;

function IsRiver(C: Byte): Boolean; inline;
begin
  Result := (C >= $33) and (C <= $40);
end;

{ -- the form --------------------------------------------------------------- }

constructor TBattleForm.CreateBattle(AOwner: TComponent; W: PBattleWnd);
const
  Captions: array[0..2] of Word = ($2D98, $2DA0, $2DA8);    { &Warten &Fertig &Aufgeben }
var
  T: TDlgTemplate;
  K: Integer;
  Bmp: TBitmap;
  X, Y: Integer;
begin
  inherited CreateNew(AOwner);
  B := W;
  FS := DialogScale;
  FF := DialogFactor;
  LoadCursors;
  T := Exe.Dialog('KRIEG');
  Caption := Utf8(T.Caption);
  BorderStyle := bsSingle;
  BorderIcons := [];                          { WS_POPUP | WS_CAPTION: no system menu }
  Position := poScreenCenter;
  ClientWidth := Round(ClientW * FS);
  ClientHeight := Round(ClientH * FS);
  Color := DialogBackground;
  DoubleBuffered := True;
  OnPaint := @FormPaint;
  OnShow := @FormShow;
  OnCloseQuery := @FormCloseQuery;
  OnMouseDown := @FormMouseDown;
  OnMouseMove := @FormMouseMove;
  Cursor := crStop;
  FScreen := TBitmap.Create;
  FScreen.SetSize(Z(ClientW), Z(ClientH));
  FScreen.Canvas.Brush.Color := DialogBackground;
  FScreen.Canvas.FillRect(0, 0, Z(ClientW), Z(ClientH));
  { the pattern brush of the map (LAND, in winter SCHNEE: 8 x 8) }
  FGrass := TBitmap.Create;
  FGrass.SetSize(Z(MapW), Z(MapH));
  if B^.Winter <> 0 then
    Bmp := ScaledBitmap('SCHNEE', 0, FF)
  else
    Bmp := ScaledBitmap('LAND', 0, FF);
  if Bmp <> nil then
  begin
    Y := 0;
    while Y < Z(MapH) do
    begin
      X := 0;
      while X < Z(MapW) do
      begin
        FGrass.Canvas.Draw(X, Y, Bmp);
        Inc(X, Bmp.Width);
      end;
      Inc(Y, Bmp.Height);
    end;
  end;
  { the buttons of Init (TButton.Init at 201, 352 / 378 / 404, 80 x 26) }
  for K := 0 to 2 do
  begin
    FButtons[K] := TButton.Create(Self);
    FButtons[K].Parent := Self;
    FButtons[K].Caption := Utf8(PChar(@PByte(@DS)[Captions[K]]));
    FButtons[K].SetBounds(Round($C9 * FS), Round(($160 + K * $1A) * FS), Round($50 * FS),
      Round($1A * FS));
    { the dialog's font (KRIEG: Comic Sans MS 8), as large as the window }
    FButtons[K].Font.Name := 'Comic Sans MS';
    {$ifdef darwin}
    FButtons[K].Font.Size := Round(8 * 96 / 72 * FS);
    {$else}
    FButtons[K].Font.Size := Round(8 * FS);
    {$endif}
    FButtons[K].Tag := $65 + K;
    FButtons[K].OnClick := @ButtonClick;
    FButtons[K].Cursor := crDefault;
  end;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := Max(DS.OptBattleTimer, 1);
  FTimer.OnTimer := @TimerTick;
  FAuto := GetEnvironmentVariable('KAISER_AUTOPILOT') <> '';
  FAutoAi := FAuto and (GetEnvironmentVariable('KAISER_AUTOBATTLE') = 'ai');
  if FAuto then
    FTimer.Interval := 30;
end;

destructor TBattleForm.Destroy;
begin
  FScreen.Free;
  FGrass.Free;
  inherited Destroy;
end;

function TBattleForm.Enter: Boolean;
begin
  Result := FBusy = 0;
  if Result then
    Inc(FBusy);
end;

procedure TBattleForm.Leave;
begin
  { after the message: EndDlg ends the modal loop; a dialog that covered
    the window leaves a WM_PAINT }
  if (BattleEndCode = 0) and NeedPaint then
    WMPaint;
  Dec(FBusy);
  if BattleEndCode <> 0 then
  begin
    FTimer.Enabled := False;
    if FAuto then
      Snapshot('end' + IntToStr(BattleEndCode));
    ModalResult := mrOK;
  end;
  Invalidate;
end;

function TBattleForm.Z(V: Integer): Integer;
begin
  Result := V * FF;
end;

{ a filled rectangle in logical coordinates (X2, Y2 excluded) }
procedure TBattleForm.Bar(Cv: TCanvas; X1, Y1, X2, Y2: Integer; Fill: TColor);
begin
  Cv.Brush.Style := bsSolid;
  Cv.Brush.Color := Fill;
  Cv.FillRect(Z(X1), Z(Y1), Z(X2), Z(Y2));
end;

procedure TBattleForm.FormPaint(Sender: TObject);
begin
  if (FScreen.Width = ClientWidth) and (FScreen.Height = ClientHeight) then
    Canvas.Draw(0, 0, FScreen)
  else
    Canvas.StretchDraw(Rect(0, 0, ClientWidth, ClientHeight), FScreen);
end;

procedure TBattleForm.FormShow(Sender: TObject);
begin
  { the first WM_PAINT comes before the first WM_TIMER }
  Inc(FBusy);
  WMPaint;
  Dec(FBusy);
  if FButtons[0].Enabled and FButtons[0].CanFocus then
    FButtons[0].SetFocus;                     { SetFocus(button 101) }
  FTimer.Enabled := True;
end;

procedure TBattleForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := BattleEndCode <> 0;             { WMClose 9ad6 does nothing }
end;

procedure TBattleForm.Flush;
begin
  Invalidate;
  Update;
  Application.ProcessMessages;
end;

procedure TBattleForm.Snapshot(const What: string);
var
  Img: TBitmap;
  P: TPortableNetworkGraphic;
begin
  Inc(FShots);
  Img := GetFormImage;
  P := TPortableNetworkGraphic.Create;
  try
    P.Assign(Img);
    P.SaveToFile(IncludeTrailingPathDelimiter(GetEnvironmentVariable('KAISER_AUTOPILOT')) +
      Format('battle_%.3d_%s.png', [FShots, What]));
  finally
    P.Free;
    Img.Free;
  end;
end;

procedure TBattleForm.TimerTick(Sender: TObject);
begin
  if not Enter then
    Exit;
  try
    Inc(FTicks);
    if FAuto and ((FTicks = 4) or (FTicks = 40) or (FTicks mod 150 = 0)) then
    begin
      if not FAutoAi then
        AutoHover;                  { the mouse over the nearest enemy: its panel }
      Snapshot(IntToStr(FTicks));
    end;
    if FAuto and not FAutoAi and (B^.StartTicks >= 3) and (B^.Human[B^.SideToMove] <> 0) then
      AutoAct
    else
      WMTimer(B^);
  finally
    Leave;
  end;
end;

procedure TBattleForm.ButtonClick(Sender: TObject);
begin
  if not Enter then
    Exit;
  try
    case TButton(Sender).Tag of
      $65: CmWarten(B^);
      $66: CmFertig(B^);
      $67: CmAufgeben(B^);
    end;
  finally
    Leave;
  end;
end;

procedure TBattleForm.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Topic: LongInt;
begin
  if (X < 0) or (Y < 0) or not Enter then
    Exit;
  X := Trunc(X / FS);                               { the logical pixel }
  Y := Trunc(Y / FS);
  try
    if Button = mbLeft then
      Battle.WMLButtonDown(B^, Word(X), Word(Y))
    else if Button = mbRight then
    begin
      Topic := Battle.WMRButtonDown(B^, Word(X), Word(Y));
      if Topic <> 0 then
        ShowHelpTopic(Topic);                         { WinHelp(.., HELP_CONTEXT, topic) }
    end;
  finally
    Leave;
  end;
end;

procedure TBattleForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if (X < 0) or (Y < 0) or not Enter then
    Exit;
  try
    WMMouseMove(Trunc(X / FS), Trunc(Y / FS));
  finally
    Leave;
  end;
end;

{ WMMouseMove (1048:91ae): the cursor for the cell (STOP, GO, SWORD, HEAL),
  the target panel for a unit }
procedure TBattleForm.WMMouseMove(PX, PY: Integer);
var
  X, Y: Word;
  Code: Byte;

  procedure Pick(Can: Boolean; Yes: TCursor);
  begin
    if Can then
      Cursor := Yes
    else
      Cursor := crStop;
  end;

begin
  X := Word(PX) shr 5;
  Y := Word(PY) shr 5;
  if (X >= 15) or (Y >= 11) then
  begin
    Cursor := crDefault;
    Exit;
  end;
  Code := B^.Grid[X * 11 + Y];
  if Code = 0 then
  begin
    Battle.ClearTargetPanel(B^);
    Pick(CanMoveTo(B^, X, Y), crGo);
  end
  else if (Code >= $5B) and (Code <= $63) then
  begin
    Battle.ClearTargetPanel(B^);
    Pick(CanAttack(B^, X, Y), crSword);
  end
  else if IsBuilding(Code) then
  begin
    Battle.ClearTargetPanel(B^);
    if CanMoveTo(B^, X, Y) then
      Cursor := crGo
    else
      Pick(CanAttack(B^, X, Y), crSword);
  end
  else if (Code = 8) or (Code = 9) then
  begin
    Battle.ClearTargetPanel(B^);
    if CanAttack(B^, X, Y) then
      Cursor := crSword
    else
      Pick(CanMoveTo(B^, X, Y), crGo);
  end
  else if IsRiver(Code) then
  begin
    Battle.ClearTargetPanel(B^);
    Pick(CanMoveTo(B^, X, Y), crGo);
  end
  else if ((Code >= $6F) and (Code <= $76)) or ((Code >= $79) and (Code <= $80)) then
  begin
    if Code <= $76 then
      Battle.DrawUnitStatus(B^, 0, 1, Code - $6E, 0)
    else
      Battle.DrawUnitStatus(B^, 0, 0, Code - $78, 0);
    if CanAttack(B^, X, Y) then
      Cursor := crSword
    else
      Pick(CanHeal(B^, X, Y), crHeal);
  end;
end;

{ the autopilot moves the mouse onto the enemy nearest to the unit to move }
procedure TBattleForm.AutoHover;
var
  U, E: PUnit;
  J, Best, D: Integer;
  Enemy: Byte;
  T: PUnit;
begin
  U := UnitOf(B, B^.SideToMove, B^.UnitToMove);
  Enemy := 1 - B^.SideToMove;
  T := nil;
  Best := 1000;
  for J := 1 to B^.Side[Enemy].Army1Count do
  begin
    E := UnitOf(B, Enemy, J);
    D := Distance(U^.PosX, U^.PosY, E^.PosX, E^.PosY);
    if D < Best then
    begin
      Best := D;
      T := E;
    end;
  end;
  if T <> nil then
    WMMouseMove(T^.PosX * 32 + 16, T^.PosY * 32 + 16);
end;

{ the scripted human (autopilot): one action per tick }
procedure TBattleForm.AutoAct;
var
  U, E: PUnit;
  X, Y, BX, BY, Best, D, K: Integer;
  Enemy: Byte;

  function Nearest(PX, PY: Integer): Integer;
  var
    J: Integer;
  begin
    Result := 1000;
    for J := 1 to B^.Side[Enemy].Army1Count do
    begin
      E := UnitOf(B, Enemy, J);
      Result := Min(Result, Distance(PX, PY, E^.PosX, E^.PosY));
    end;
  end;

begin
  U := UnitOf(B, B^.SideToMove, B^.UnitToMove);
  Enemy := 1 - B^.SideToMove;
  if not FAutoRight then
  begin
    { once: the combat options of the current unit (KAMPFOPTDLG) }
    FAutoRight := True;
    Battle.WMRButtonDown(B^, Word(U^.PosX * 32 + 16), Word(U^.PosY * 32 + 16));
    Exit;
  end;
  for X := 0 to 14 do
    for Y := 0 to 10 do
      if (B^.Grid[X * 11 + Y] in [$6F..$76, $79..$80]) and CanAttack(B^, X, Y) then
      begin
        Battle.WMLButtonDown(B^, X * 32 + 16, Y * 32 + 16);
        Exit;
      end;
  Best := Nearest(U^.PosX, U^.PosY);
  BX := -1;
  BY := -1;
  for K := 0 to 8 do
  begin
    X := U^.PosX + K mod 3 - 1;
    Y := U^.PosY + K div 3 - 1;
    if (X < 0) or (Y < 0) or (X > 14) or (Y > 10) or not CanMoveTo(B^, X, Y) then
      Continue;
    D := Nearest(X, Y);
    if D < Best then
    begin
      Best := D;
      BX := X;
      BY := Y;
    end;
  end;
  if BX >= 0 then
    Battle.WMLButtonDown(B^, BX * 32 + 16, BY * 32 + 16)
  else
    CmFertig(B^);
end;

{ -- drawing ---------------------------------------------------------------- }

procedure TBattleForm.Masked(Id: Integer; X, Y: Integer);
var
  Bmp: TBitmap;
begin
  { Bmp_DrawMasked (1078:00c4): mask Id + 1000 SRCAND, Id SRCPAINT }
  Bmp := ScaledSprite(Id, FF);
  if Bmp <> nil then
    FScreen.Canvas.Draw(Z(X), Z(Y), Bmp);
end;

procedure TBattleForm.Silhouette(Id: Integer; X, Y: Integer);
var
  Bmp: TBitmap;
begin
  Bmp := ScaledOf(SilhouetteBitmap(Id), FF);
  if Bmp <> nil then
    FScreen.Canvas.Draw(Z(X), Z(Y), Bmp);
end;

{ the building or river under a unit (DrawMap, DrawCell) }
procedure TBattleForm.Terrain(X, Y: Integer);
var
  T: Byte;
begin
  T := B^.Terrain[X * 11 + Y];
  if IsBuilding(T) or IsRiver(T) then
    Masked(20 * B^.Winter + 1000 + T, X * 32, Y * 32);
end;

{ unit I of side S with the bitmaps Base + picture; Shade: a unit in a
  stance is a black silhouette (mask 2100 + / 2200 + picture) }
procedure TBattleForm.UnitSprite(S, I: Byte; Base: Integer; Shade: Boolean; X, Y: Integer);
var
  U: PUnit;
begin
  U := UnitOf(B, S, I);
  if Shade and (U^.Stance <> 0) then
    Silhouette(PictureOf(U^) + (Base - 1100), X, Y)
  else
    Masked(Base + PictureOf(U^), X, Y);
end;

{ DrawMap (1048:1068, VMT +0x54): the whole map; camouflaged units
  (ability 29) outside the city are not drawn }
procedure TBattleForm.DrawMap;
var
  X, Y: Integer;
  G: Byte;
  Snow: Integer;
  Cv: TCanvas;
begin
  Snow := 20 * B^.Winter;
  Cv := FScreen.Canvas;
  Cv.CopyRect(Rect(0, 0, Z(MapW), Z(MapH)), FGrass.Canvas, Rect(0, 0, Z(MapW), Z(MapH)));
  { Rectangle(0, 0, 480, 352) with the pen RGB(0, 255, 0), in winter white
    (the pen inside: four bars) }
  if B^.Winter <> 0 then
    Snow := clWhite
  else
    Snow := $00FF00;
  Bar(Cv, 0, 0, MapW, 1, Snow);
  Bar(Cv, 0, MapH - 1, MapW, MapH, Snow);
  Bar(Cv, 0, 0, 1, MapH, Snow);
  Bar(Cv, MapW - 1, 0, MapW, MapH, Snow);
  Snow := 20 * B^.Winter;
  for X := 0 to 14 do
    for Y := 0 to 10 do
    begin
      G := B^.Grid[X * 11 + Y];
      if (G >= 2) and (G <= $0D) then
        Masked(Snow + 1000 + G, X * 32, Y * 32)
      else if IsRiver(G) then
        Masked(Snow + 1000 + G, X * 32, Y * 32)
      else if (G >= $5B) and (G <= $63) then
        Masked(1000 + G, X * 32, Y * 32)
      else if (G >= $6F) and (G <= $76) then
      begin
        Terrain(X, Y);
        if not ((UnitOf(B, 1, G - $6E)^.Ability = $1D) and not IsInCity(B^, UnitOf(B, 1, G - $6E)^)) then
          UnitSprite(1, G - $6E, 1100, True, X * 32, Y * 32);
      end
      else if (G >= $79) and (G <= $80) then
      begin
        Terrain(X, Y);
        if not ((UnitOf(B, 0, G - $78)^.Ability = $1D) and not IsInCity(B^, UnitOf(B, 0, G - $78)^)) then
          UnitSprite(0, G - $78, 1200, True, X * 32, Y * 32);
      end;
    end;
end;

{ DrawPanelFrames (1048:17fd): two sunken grey frames 200 x 80 at (0, 352)
  and (280, 352) }
procedure TBattleForm.DrawPanelFrames;
var
  K, X0: Integer;
  Cv: TCanvas;
begin
  Cv := FScreen.Canvas;
  for K := 0 to 1 do
  begin
    X0 := K * $118;
    Bar(Cv, X0, $160, X0 + 200, $160 + 80, Grey);
    { black (2,78)-(2,2)-(198,2), white (2,78)-(198,78)-(198,2) }
    Bar(Cv, X0 + 2, $160 + 3, X0 + 3, $160 + 79, clBlack);
    Bar(Cv, X0 + 2, $160 + 2, X0 + 198, $160 + 3, clBlack);
    Bar(Cv, X0 + 2, $160 + 78, X0 + 198, $160 + 79, clWhite);
    Bar(Cv, X0 + 198, $160 + 3, X0 + 199, $160 + 79, clWhite);
  end;
end;

{ WMPaint (1048:9add): the map, the frames, the current unit's panel }
procedure TBattleForm.WMPaint;
begin
  NeedPaint := False;
  DrawMap;
  DrawPanelFrames;
  Battle.DrawUnitStatus(B^, 0, B^.SideToMove, B^.UnitToMove, 1);
  Invalidate;
end;

{ DrawCell (1048:2803): one cell for a code: terrain, a unit, the frames of
  the animations (0x83.. side 1 / 0x8d.. side 0 ...), 10 = the hit }
procedure TBattleForm.DrawCell(X, Y: SmallInt; Code: Byte);
var
  PX, PY, Snow: Integer;
  Cv: TCanvas;
begin
  if (X < 0) or (X > 14) or (Y < 0) or (Y > 10) then
    Exit;
  Snow := 20 * B^.Winter;
  PX := X * 32;
  PY := Y * 32;
  Cv := FScreen.Canvas;
  { the cell's background: the pattern brush, no pen (Rectangle 0,0,33,33) }
  if (Code = 0) or ((Code >= 2) and (Code <= 13)) or IsRiver(Code) or
     ((Code >= $5B) and (Code <= $63)) or ((Code >= $6F) and (Code <= $76)) or
     ((Code >= $79) and (Code <= $80)) or ((Code >= $83) and (Code <= $8A)) or
     ((Code >= $8D) and (Code <= $94)) or ((Code >= $97) and (Code <= $9E)) or
     ((Code >= $A1) and (Code <= $A8)) or ((Code >= $AB) and (Code <= $B2)) or
     ((Code >= $B5) and (Code <= $BC)) then
    Cv.CopyRect(Rect(Z(PX), Z(PY), Z(PX + 32), Z(PY + 32)), FGrass.Canvas,
      Rect(Z(PX), Z(PY), Z(PX + 32), Z(PY + 32)))
  else
    { nothing is drawn into the new memory bitmap: black }
    Bar(Cv, PX, PY, PX + 32, PY + 32, clBlack);
  if Code = 0 then
  else if ((Code >= 2) and (Code <= 9)) or ((Code >= $0B) and (Code <= $0D)) then
    Masked(Snow + 1000 + Code, PX, PY)
  else if Code = 10 then
  begin
    Terrain(X, Y);
    Masked(1010, PX, PY);
  end
  else if IsRiver(Code) then
    Masked(Snow + 1000 + Code, PX, PY)
  else if (Code >= $5B) and (Code <= $63) then
    Masked(1000 + B^.Grid[X * 11 + Y], PX, PY)          { (the grid's code) }
  else if (Code >= $6F) and (Code <= $76) then
  begin
    Terrain(X, Y);
    UnitSprite(1, Code - $6E, 1100, True, PX, PY);
  end
  else if (Code >= $79) and (Code <= $80) then
  begin
    Terrain(X, Y);
    UnitSprite(0, Code - $78, 1200, True, PX, PY);
  end
  else if (Code >= $83) and (Code <= $8A) then
  begin
    Terrain(X, Y);
    UnitSprite(1, Code - $82, 1300, False, PX, PY);
  end
  else if (Code >= $8D) and (Code <= $94) then
  begin
    Terrain(X, Y);
    UnitSprite(0, Code - $8C, 1400, False, PX, PY);
  end
  else if (Code >= $97) and (Code <= $9E) then
  begin
    Terrain(X, Y);
    UnitSprite(1, Code - $96, 1200, False, PX, PY);
  end
  else if (Code >= $A1) and (Code <= $A8) then
  begin
    Terrain(X, Y);
    UnitSprite(0, Code - $A0, 1100, False, PX, PY);
  end
  else if (Code >= $AB) and (Code <= $B2) then
  begin
    Terrain(X, Y);
    UnitSprite(1, Code - $AA, 1400, False, PX, PY);
  end
  else if (Code >= $B5) and (Code <= $BC) then
  begin
    Terrain(X, Y);
    UnitSprite(0, Code - $B4, 1300, False, PX, PY);
  end;
  Invalidate;
end;

{ RedrawUnit (1048:6192): the unit's cell; a camouflaged unit outside the
  city shows its terrain }
procedure TBattleForm.RedrawUnit(S, I: Byte);
var
  U: PUnit;
  C: Integer;
begin
  U := UnitOf(B, S, I);
  C := SmallInt(U^.PosX * 11 + U^.PosY);
  if (C < 0) or (C > 164) then
    Exit;
  if (U^.Ability = $1D) and not IsInCity(B^, U^) then
    DrawCell(U^.PosX, U^.PosY, B^.Terrain[C])
  else
    DrawCell(U^.PosX, U^.PosY, B^.Grid[C]);
end;

{ ClearTargetPanel (1048:196c): the right panel's 180 x 64 area grey }
procedure TBattleForm.ClearTargetPanel;
begin
  Bar(FScreen.Canvas, $122, $168, $122 + $B4, $168 + $40, Grey);
  Invalidate;
end;

procedure TBattleForm.EnableButtons(On: Boolean);
var
  K: Integer;
begin
  for K := 0 to 2 do
    FButtons[K].Enabled := On;
  { AiStep / EndAction: the focus to Warten }
  if On and Visible and FButtons[0].CanFocus then
    FButtons[0].SetFocus;
end;

{ DrawUnitStatus (1048:1a60): unit I of side S into the left panel (Panel
  1, the unit to move) or the right one (0, the target). The enemy's
  details only show when the unit to move has a rank (orders, attack,
  defence ...) or is a Haudegen (hit points, morale, ability). The
  motivation is computed first (on a copy here: the logic stores the same
  value right after this call). }
procedure TBattleForm.DrawUnitStatus(S, I, Panel: Byte);
var
  U: TUnit;
  Cur: PUnit;
  P: TBitmap;
  Cv: TCanvas;
  Ord, Bmp: TBitmap;
  N, K, L: Integer;
  A, D: TReal48;
  AV, DV, Pct, Face: Byte;
  Show1, Show2: Boolean;
  IcoName: RawByteString;

  procedure Icon(const BmpName: RawByteString; X, Y: Integer);
  var
    Ic: TBitmap;
  begin
    Ic := ScaledBitmap(BmpName, 0, FF);
    if Ic <> nil then
      Cv.Draw(Z(X), Z(Y), Ic);                { Bmp_Draw (1078:0002): SRCCOPY 12 x 12 }
  end;

  procedure Text(X, Y: Integer; const S: RawByteString; Color: TColor);
  begin
    Cv.Font.Color := Color;
    Cv.TextOut(Z(X), Z(Y), Utf8(S));
  end;

  procedure RightText(X, Y: Integer; const S: RawByteString; Color: TColor);
  begin
    Cv.Font.Color := Color;
    Cv.TextOut(Z(X) - Cv.TextWidth(Utf8(S)), Z(Y), Utf8(S));
  end;

  function Compared(V, Base: Byte): TColor;
  begin
    if V < Base then
      Result := $00007F                       { RGB(0x7f, 0, 0) }
    else if V > Base then
      Result := $007F00                       { RGB(0, 0x7f, 0) }
    else
      Result := clBlack;
  end;

begin
  if I > B^.Side[S].Army1Count then
    Exit;
  U := UnitOf(B, S, I)^;
  ComputeMotivation(B^, U, S);
  Cur := UnitOf(B, B^.SideToMove, B^.UnitToMove);
  Show1 := (S = B^.SideToMove) or (Cur^.Level <> 0);
  Show2 := (S = B^.SideToMove) or (Cur^.Level > 1);
  P := TBitmap.Create;
  try
    P.SetSize(Z($B4), Z($40));
    Cv := P.Canvas;
    Bar(Cv, 0, 0, $B4, $40, Grey);
    { LOGFONT DS:606c (Seg10_InitBattleFont): Comic Sans MS, -12, bold }
    Cv.Font.Name := 'Comic Sans MS';
    Cv.Font.Height := -12 * FF;
    Cv.Font.Style := [fsBold];
    if FF > 1 then
      Cv.Font.Quality := fqAntialiased;
    Cv.Brush.Style := bsClear;
    Text(0, 0, PChar(@U.Name), clBlack);
    if Show1 then
    begin
      { the rank: 1..3 black orders, 1..3 yellow ones, a red one (+ n) }
      L := U.Level;
      if L < 3 then
      begin
        N := L;
        Ord := ScaledBitmap('BLACKORDEN', 0, FF);
      end
      else if L <= 5 then
      begin
        N := L - 3;
        Ord := ScaledBitmap('YELLOWORDEN', 0, FF);
      end
      else
      begin
        N := 0;
        Ord := ScaledBitmap('REDORDEN', 0, FF);
      end;
      if Ord <> nil then
        for K := 0 to N do
          Cv.Draw(Z(K * 12), Z($10), Ord);
      if L > 6 then
        Text(N * 12 + $10, $10, '+' + IntToStr(L - 6), clBlack);
    end;
    Icon('SCHWERT', 0, $22);
    Icon('SCHILD', $24, $22);
    Icon('BOGEN', $48, $22);
    Icon('STIEFEL', $6C, $22);
    if (U.Range > 1) or (U.Ability = $11) then
    begin
      case ShortInt(U.UnitType) of
        $1A: IcoName := 'AXT';
        9: if U.Ability = $11 then IcoName := 'HEAL' else IcoName := 'AXT';
        4, 6: IcoName := 'KUGEL';
        $16: IcoName := 'BOMBE';
        $15: IcoName := 'HEAL';
      else
        IcoName := 'PFEIL';
      end;
      Icon(IcoName, $90, $22);
    end;
    if Show1 then
    begin
      { the effective attack and defence }
      A := R48Mul(R48FromLong(U.Attack), U.Motivation);
      D := R48FromLong(U.Defence);
      if U.BlindRounds > 0 then
      begin
        A := R48Div(A, R48FromLong(U.BlindRounds + 1));
        D := R48Div(D, R48FromLong(U.BlindRounds + 1));
      end;
      if (U.Ability = $0E) and (ShortInt(U.Hp) < ShortInt(U.MaxHp)) then
        A := R48Mul(A, RC($0082, 0, 0));
      if (PByte(@DS.UnitKnight)[ShortInt(U.UnitType)] <> 0) and
         HasAdjacentFriendOfType(B^, S, I, $22) then
        A := R48Add(A, RC($0081, 0, 0));
      if U.UnconsciousRounds > 0 then
      begin
        A := R48Zero;
        D := R48Div(D, RC($0082, 0, 0));
      end;
      if ((B^.City <> 0) and (S = 0) and (B^.SideToMove <> S) and IsInCity(B^, U) and
          not IsInCity(B^, Cur^)) or (U.Stance = 1) then
        D := R48Mul(D, RC($0082, 0, 0));
      if CountAdjacentEnemies(B^, S, I) > 3 then
        D := R48Div(D, RC($0082, 0, 0));
      if U.Stance = 2 then
        D := R48Div(D, RC($0082, 0, 0));
      AV := Byte(R48Round(A));
      DV := Byte(R48Round(D));
      Text($0E, $22, IntToStr(AV), Compared(AV, U.Attack));
      Text($32, $22, IntToStr(DV), Compared(DV, U.Defence));
      Text($56, $22, IntToStr(U.Range), clBlack);
      Text($7A, $22, IntToStr(U.Steps), clBlack);
      if (U.Range > 1) or (U.Ability = $11) then
        Text($9E, $22, IntToStr(U.Ammo), clBlack);
    end;
    Icon('HERZ', 0, $34);
    { the hit point bar: a black frame (14,55)-(115,61) }
    Bar(Cv, $0E, $37, $73, $38, clBlack);
    Bar(Cv, $0E, $3C, $73, $3D, clBlack);
    Bar(Cv, $0E, $37, $0F, $3D, clBlack);
    Bar(Cv, $72, $37, $73, $3D, clBlack);
    if Show2 then
    begin
      if U.MaxHp = 0 then
        Pct := 0
      else
        Pct := Byte(R48Round(R48Div(R48FromLong(ShortInt(U.Hp) * 100),
          R48FromLong(ShortInt(U.MaxHp)))));
      if Pct <= $64 then
      begin
        if Pct <= $20 then
          Cv.Brush.Color := $0000FF
        else if Pct <= $42 then
          Cv.Brush.Color := $00FFFF
        else
          Cv.Brush.Color := $00FF00;
        { Rectangle(15, 56, pct + 15, 61) without a pen }
        if Pct > 1 then
          Bar(Cv, $0F, $38, Pct + $0E, $3C, Cv.Brush.Color);
      end;
      if U.BlindRounds > 0 then
        Icon('BLIND', $78, $34);
      if U.UnconsciousRounds > 0 then
        Icon('HEIA', $84, $34);
      if U.Stance = 1 then
        Icon('SCHILD', $90, $34)
      else if U.Stance = 2 then
        Icon('HEAL', $90, $34);
      { the morale: 50..79 UNHAPPY, 80..99 MODERATE, 100..110 HAPPY }
      Face := Byte(R48Round(R48Mul(RC($0087, 0, $4800), U.Motivation)));
      IcoName := '';
      if (Face >= $32) and (Face <= $4F) then
        IcoName := 'UNHAPPY'
      else if (Face >= $50) and (Face <= $63) then
        IcoName := 'MODERATE'
      else if (Face >= $64) and (Face <= $6E) then
        IcoName := 'HAPPY';
      if IcoName <> '' then
        Icon(IcoName, $A8, $34);
    end;
    { the player, right-aligned: the attacker yellow, the defender blue }
    Cv.Brush.Style := bsClear;
    if S = 1 then
      RightText($B4, 0, PChar(@B^.Side[S].Name), $00FFFF)
    else
      RightText($B4, 0, PChar(@B^.Side[S].Name), $FF0000);
    if (U.Ability <> 0) and Show2 then
      RightText($B4, $10, PChar(@PByte(@DS)[$53D8 + U.Ability * $19]), clBlack);
    if Panel <> 0 then
      FScreen.Canvas.Draw(Z($0A), Z($168), P)
    else
      FScreen.Canvas.Draw(Z($122), Z($168), P);
  finally
    P.Free;
  end;
  Invalidate;
end;

{ -- running it ------------------------------------------------------------- }

function RunBattle(W: PBattleWnd): Byte;
var
  F: TBattleForm;
  Prev: TBattleForm;
begin
  Prev := ActiveBattle;
  BattleEndCode := 0;
  F := TBattleForm.CreateBattle(Application.MainForm, W);
  ActiveBattle := F;
  try
    if F.FAutoAi then
    begin
      W^.Human[0] := 0;
      W^.Human[1] := 0;
    end;
    BattleSetupWindow(W^);
    F.ShowModal;
  finally
    ActiveBattle := Prev;
    F.Free;
  end;
  Result := BattleEndCode;
end;

initialization
  SilhouetteCache := TStringList.Create;
end.
