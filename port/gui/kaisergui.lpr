{ Kaiser: the GUI of the port (LCL). Needs the original kaiser.exe for its
  resources (found next to the program, in ../Kaiser or with -exe PATH). }
program KaiserGui;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, NERes, KaiserDS, KaiserUI, KaiserLCL, MainForm;



var
  LclUI: TLclUI;
begin
  Application.Initialize;
  Exe := TNEFile.Create(FindExe);
  ResetDataSegment;
  LclUI := TLclUI.Create;
  UI.Free;
  UI := LclUI;
  Application.CreateForm(TKaiserForm, KaiserForm);
  LclUI.MainForm := KaiserForm;
  Application.Run;
end.
