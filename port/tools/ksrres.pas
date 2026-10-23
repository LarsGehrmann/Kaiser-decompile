{ Dump the dialog and menu templates of kaiser.exe in the format of
  extracted/res/dialogs.txt and menus.txt (tools/ne_resources.py), to check
  the NERes reader: ksrres EXE dialogs|menus }
program KsrRes;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, NERes;

const
  ButtonStyles: array[0..11] of string = ('PUSHBUTTON', 'DEFPUSHBUTTON', 'CHECKBOX',
    'AUTOCHECKBOX', 'RADIOBUTTON', '3STATE', 'AUTO3STATE', 'GROUPBOX', 'BUTTON',
    'AUTORADIOBUTTON', 'BUTTON', 'OWNERDRAW');

function Pad(const S: string; N: Integer): string;
begin
  Result := S;
  while Length(Result) < N do
    Result := Result + ' ';
end;

procedure DumpMenu(const M: TMenuTemplate; Depth: Integer);
var
  I: Integer;
  Ind, L: string;
begin
  Ind := StringOfChar(' ', 4 * Depth);
  for I := 0 to High(M.Items) do
    with M.Items[I] do
      if Flags and $10 <> 0 then
      begin
        WriteLn(Ind, 'POPUP "', CP1252ToUTF8(Text), '"');
        DumpMenu(M.Items[I], Depth + 1);
      end
      else if (Text = '') and (Id = 0) then
        WriteLn(Ind, 'SEPARATOR')
      else
      begin
        L := Ind + 'MENUITEM id=' + Pad(IntToStr(Id), 5) + ' "' + CP1252ToUTF8(Text) + '"';
        if Flags and not $80 <> 0 then
          L := L + ' flags=0x' + LowerCase(IntToHex(Flags, 1));
        WriteLn(L);
      end;
end;

var
  E: TNEFile;
  I, K: Integer;
  R: TNEResource;
  T: TDlgTemplate;
  L, Ctl: string;
begin
  E := TNEFile.Create(ParamStr(1));
  for I := 0 to E.Count - 1 do
  begin
    R := E.Resource(I);
    if (ParamStr(2) = 'dialogs') and (R.TypeId = RT_DIALOG) then
    begin
      T := ParseDialog(R.Data);
      if R.Name <> '' then L := R.Name else L := IntToStr(R.Id);
      L := Format('DIALOG %s  (%d,%d,%d,%d)  style=0x%.8x  caption="%s"',
        [L, T.X, T.Y, T.CX, T.CY, T.Style, CP1252ToUTF8(T.Caption)]);
      L := LowerCase(Copy(L, 1, 0)) + L;
      if T.ClassName <> '' then L := L + ' class="' + T.ClassName + '"';
      if T.Menu <> '' then L := L + ' menu=' + T.Menu;
      if T.Style and $40 <> 0 then
        L := L + Format(' FONT %d "%s"', [T.FontSize, CP1252ToUTF8(T.FontFace)]);
      WriteLn(StringReplace(L, 'style=0x' + IntToHex(T.Style, 8), 'style=0x' + LowerCase(IntToHex(T.Style, 8)), []));
      for K := 0 to High(T.Items) do
        with T.Items[K] do
        begin
          Ctl := ClassName;
          if Ctl = 'BUTTON' then
            Ctl := ButtonStyles[Style and $F mod 12];
          WriteLn(Format('    %s id=%s (%d,%d,%d,%d)  "%s"  style=0x%s',
            [Pad(Ctl, 16), Pad(IntToStr(Id), 6), X, Y, CX, CY, CP1252ToUTF8(Text),
             LowerCase(IntToHex(Style, 8))]));
        end;
      WriteLn;
    end
    else if (ParamStr(2) = 'menus') and (R.TypeId = RT_MENU) then
    begin
      WriteLn('MENU ', R.Name);
      DumpMenu(E.Menu(R.Name), 1);
      WriteLn;
    end;
  end;
  E.Free;
end.
