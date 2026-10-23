{ The light look of Windows 3.1 also when macOS runs in dark mode (nothing
  to do on Windows). }
unit MacAppearance;

{$mode objfpc}{$H+}
{$ifdef darwin}
{$modeswitch objectivec1}
{$endif}

interface

procedure UseLightAppearance;

implementation

{$ifdef darwin}
uses
  CocoaAll, Cocoa_Extra;
{$endif}

procedure UseLightAppearance;
begin
  {$ifdef darwin}
  NSApp.setAppearance(NSAppearance.appearanceNamed(NSSTR('NSAppearanceNameAqua')));
  {$endif}
end;

end.
