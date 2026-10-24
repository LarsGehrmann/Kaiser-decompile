{ The light look of Windows 3.1 also when macOS runs in dark mode (nothing
  to do on Windows). }
unit MacAppearance;

{$mode objfpc}{$H+}
{$ifdef darwin}
{$modeswitch objectivec1}
{$endif}

interface

uses
  StdCtrls;

procedure UseLightAppearance;
{ device pixels per point of the main screen (2 on Retina; 1 elsewhere) }
function BackingScale: Double;
{ remastered: a push button of any height when Flexible (Cocoa's rounded one
  keeps its height, a scaled caption ran out of it): the square bezel, set
  whenever LCL makes the native button (again) }
type
  TFlexButton = class(TButton)
  protected
    procedure CreateWnd; override;
  public
    Flexible: Boolean;
  end;

implementation

{$ifdef darwin}
uses
  CocoaAll, Cocoa_Extra;
{$endif}

procedure TFlexButton.CreateWnd;
begin
  inherited CreateWnd;
  {$ifdef darwin}
  if Flexible then
  begin
    NSButton(Handle).setBezelStyle(NSSmallSquareBezelStyle);
    { the frame again, without the rounded bezel's margins }
    DoSendBoundsToInterface;
  end;
  {$endif}
end;

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
