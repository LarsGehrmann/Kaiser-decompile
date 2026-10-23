{ The light look of Windows 3.1 also when macOS runs in dark mode. }
unit MacAppearance;

{$mode objfpc}{$H+}
{$modeswitch objectivec1}

interface

procedure UseLightAppearance;

implementation

uses
  CocoaAll, Cocoa_Extra;

procedure UseLightAppearance;
begin
  NSApp.setAppearance(NSAppearance.appearanceNamed(NSSTR('NSAppearanceNameAqua')));
end;

end.
