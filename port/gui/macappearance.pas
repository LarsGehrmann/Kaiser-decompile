{ The light look of Windows 3.1 also when macOS runs in dark mode (nothing
  to do on Windows). }
unit MacAppearance;

{$mode objfpc}{$H+}
{$ifdef darwin}
{$modeswitch objectivec1}
{$endif}

interface

procedure UseLightAppearance;
{ device pixels per point of the main screen (2 on Retina; 1 elsewhere) }
function BackingScale: Double;

implementation

{$ifdef darwin}
uses
  CocoaAll, Cocoa_Extra;
{$endif}

function BackingScale: Double;
begin
  Result := 1;
  {$ifdef darwin}
  if NSScreen.mainScreen <> nil then
    Result := NSScreen.mainScreen.backingScaleFactor;
  {$endif}
end;

procedure UseLightAppearance;
begin
  {$ifdef darwin}
  NSApp.setAppearance(NSAppearance.appearanceNamed(NSSTR('NSAppearanceNameAqua')));
  {$endif}
end;

end.
