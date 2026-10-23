{ Kaiser: the GUI of the port (LCL). Needs the original kaiser.exe for its
  resources (found next to the program, in ../Kaiser or with -exe PATH). }
program KaiserGui;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Graphics, SysUtils, MacAppearance, NERes, KaiserDS, KaiserUI, KaiserLCL, MainForm;

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



var
  LclUI: TLclUI;
begin
  Application.Initialize;
  UseLightAppearance;
  Exe := TNEFile.Create(FindExe);
  ResetDataSegment;
  if ParamStr(1) = '-snapshot' then
  begin
    Snapshot(ParamStr(2), ParamStr(3));
    Halt(0);
  end;
  LclUI := TLclUI.Create;
  UI.Free;
  UI := LclUI;
  Application.CreateForm(TKaiserForm, KaiserForm);
  LclUI.MainForm := KaiserForm;
  Application.Run;
end.
