{ Kaiser: the GUI of the port (LCL). Needs the original kaiser.exe for its
  resources (found next to the program, in ../Kaiser or with -exe PATH). }
program KaiserGui;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Graphics, SysUtils, LCLType, Types, MacAppearance, KaiserIni, NERes, KaiserDS, KaiserUI, KaiserLCL, KaiserDlgs, LclUI, MainForm, RGraphics;

{ -snapshot DIALOG OUT.png: the dialog built from its template, as an image
  (checks the rendering without a screen capture) }
procedure Snapshot(const Name, OutFile: string);
var
  F: TTemplateForm;
  B: TBitmap;
  P: TPortableNetworkGraphic;
begin
  F := TTemplateForm.CreateFromTemplate(nil, Exe.Dialog(Name));
  F.Left := -4000;
  F.Show;
  Application.ProcessMessages;
  B := F.GetFormImage;
  P := TPortableNetworkGraphic.Create;
  P.Assign(B);
  P.SaveToFile(OutFile);
  P.Free;
  B.Free;
  F.Free;
end;



{ -spritesheet OUT.png N: the unit sprites 1100..1135 and the heroes'
  pictures, each nearest neighbour (left) and by the scaler (right) at
  factor N, on the dialog colour (the remastered branch's look) }
procedure SpriteSheet(const OutFile: string; N: Integer);
var
  B, S: TBitmap;
  P: TPortableNetworkGraphic;
  I, X, Y, Cell: Integer;
begin
  Cell := 32 * N + 8;
  B := TBitmap.Create;
  try
    B.SetSize(8 * 2 * Cell, 6 * Cell);
    B.Canvas.Brush.Color := DialogBackground;
    B.Canvas.FillRect(0, 0, B.Width, B.Height);
    for I := 0 to 47 do
    begin
      X := (I mod 8) * 2 * Cell + 4;
      Y := (I div 8) * Cell + 4;
      if I < 36 then
        S := Sprite(1100 + I)
      else
        S := Sprite(1150 + I - 36);
      if S = nil then
        Continue;
      B.Canvas.StretchDraw(Rect(X, Y, X + 32 * N, Y + 32 * N), S);
      if I < 36 then
        S := ScaledSprite(1100 + I, N)
      else
        S := ScaledSprite(1150 + I - 36, N);
      if S <> nil then
        B.Canvas.Draw(X + Cell, Y, S);
    end;
    P := TPortableNetworkGraphic.Create;
    try
      P.Assign(B);
      P.SaveToFile(OutFile);
    finally
      P.Free;
    end;
  finally
    B.Free;
  end;
end;

var
  TheUI: TLclUI;
begin
  Application.Initialize;
  UseLightAppearance;
  if not FileExists(FindExe) then
  begin
    { the port draws with the original's resources: they are not in the
      repository (README.md, "Building from source") }
    Application.MessageBox(PChar('kaiser.exe (Kaiser 1.23) wurde nicht gefunden.' + LineEnding +
      LineEnding + 'Legt das Originalspiel in einen Ordner "Kaiser" neben das Programm ' +
      'oder startet es mit -exe PFAD/kaiser.exe.' + LineEnding + LineEnding +
      'kaiser.exe (Kaiser 1.23) was not found. Put the original game into a folder ' +
      '"Kaiser" next to the program or start it with -exe PATH/kaiser.exe.'),
      'Kaiser', MB_OK or MB_ICONERROR);
    Halt(1);
  end;
  Exe := TNEFile.Create(FindExe);
  ResetDataSegment;
  InitGlobals;
  ReadSettings(SettingsFile);
  DialogBackground := RGBToColor(DS.OptBackground[0], DS.OptBackground[1], DS.OptBackground[2]);
  if ParamStr(1) = '-spritesheet' then
  begin
    SpriteSheet(ParamStr(2), StrToIntDef(ParamStr(3), 3));
    Halt(0);
  end;
  if ParamStr(1) = '-snapshot' then
  begin
    Snapshot(ParamStr(2), ParamStr(3));
    Halt(0);
  end;
  TheUI := TLclUI.Create;
  UI.Free;
  UI := TheUI;
  Application.CreateForm(TKaiserForm, KaiserForm);
  TheUI.MainForm := KaiserForm;
  TheUI.Players := @KaiserForm.FSave.Players;
  TheUI.Save := @KaiserForm.FSave;
  Application.Run;
end.
