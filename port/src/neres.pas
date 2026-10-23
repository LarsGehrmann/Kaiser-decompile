{ The resources of kaiser.exe (16-bit Windows NE executable), read at run
  time: the GUI takes its dialog and menu templates, bitmaps, cursors,
  icons and sounds from the original program, so no original data is part
  of the port. Texts are kept as raw CP1252 bytes.

  Formats: the NE resource table (rscAlignShift, type records, name
  infos), the Windows 3.x DLGTEMPLATE / MENU templates. }
unit NERes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

const
  RT_CURSOR = 1;
  RT_BITMAP = 2;
  RT_ICON = 3;
  RT_MENU = 4;
  RT_DIALOG = 5;
  RT_STRING = 6;
  RT_ACCELERATOR = 9;
  RT_GROUP_CURSOR = 12;
  RT_GROUP_ICON = 14;

type
  TBytes = array of Byte;

  TNEResource = record
    TypeId: Word;              { standard type, 0 for a named type }
    TypeName: RawByteString;   { named type (e.g. 'MAPDATA', 'WAVEDATA') }
    Id: Word;                  { ordinal id, 0 for a named resource }
    Name: RawByteString;       { name (upper case as stored) }
    Data: TBytes;
  end;

  { one control of a dialog template }
  TDlgItem = record
    X, Y, CX, CY: SmallInt;    { dialog units }
    Id: SmallInt;
    Style: LongWord;
    ClassName: RawByteString;  { BUTTON, EDIT, STATIC, LISTBOX, SCROLLBAR, COMBOBOX or a class name }
    Text: RawByteString;       { caption, or a resource name for SS_ICON statics }
    TextOrd: Integer;          { ordinal text (0xFF + word), -1 if none }
  end;

  TDlgTemplate = record
    Name: RawByteString;
    Style: LongWord;
    X, Y, CX, CY: SmallInt;
    Menu, ClassName, Caption: RawByteString;
    FontSize: Word;
    FontFace: RawByteString;
    Items: array of TDlgItem;
  end;

  PMenuTemplate = ^TMenuTemplate;
  TMenuTemplate = record
    Flags: Word;               { MF_* (0x10 popup, 0x800 separator, 0x80 end ...) }
    Id: Word;
    Text: RawByteString;
    Items: array of TMenuTemplate;   { popup contents }
  end;

  TNEFile = class
  private
    FRaw: TBytes;
    FResources: array of TNEResource;
    function U16(Off: LongInt): Word;
    function PStr(Off: LongInt): RawByteString;
    procedure ParseResources(Base: LongInt);
  public
    constructor Create(const FileName: string);
    function Count: Integer;
    function Resource(I: Integer): TNEResource;
    { by standard type and id or name (case-insensitive); nil if missing }
    function Find(TypeId: Word; const Name: RawByteString; Id: Word = 0): TBytes;
    function FindNamedType(const TypeName, Name: RawByteString; Id: Word = 0): TBytes;
    function Dialog(const Name: RawByteString): TDlgTemplate;
    function DialogNames: TStringList;
    function Menu(const Name: RawByteString): TMenuTemplate;
    { a BITMAP resource as a complete .bmp file }
    function BitmapFile(const Name: RawByteString; Id: Word = 0): TBytes;
    { a GROUP_ICON resource and its ICON images as a complete .ico file }
    function IconFile(const Name: RawByteString; Id: Word = 0): TBytes;
  end;

function ParseDialog(const D: TBytes): TDlgTemplate;
function ParseMenu(const D: TBytes): TMenuTemplate;
function CP1252ToUTF8(const S: RawByteString): string;
function UTF8ToCP1252(const S: string): RawByteString;

implementation

function TNEFile.U16(Off: LongInt): Word;
begin
  Result := FRaw[Off] or (FRaw[Off + 1] shl 8);
end;

function TNEFile.PStr(Off: LongInt): RawByteString;
var
  N: Integer;
begin
  N := FRaw[Off];
  SetLength(Result, N);
  if N > 0 then
    Move(FRaw[Off + 1], Result[1], N);
end;

constructor TNEFile.Create(const FileName: string);
var
  F: TFileStream;
  NE: LongInt;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(FRaw, F.Size);
    if F.Size > 0 then
      F.ReadBuffer(FRaw[0], F.Size);
  finally
    F.Free;
  end;
  if (Length(FRaw) < $40) or (FRaw[0] <> Ord('M')) or (FRaw[1] <> Ord('Z')) then
    raise Exception.Create(FileName + ': not an MZ executable');
  NE := U16($3C) or (LongInt(U16($3E)) shl 16);
  if (FRaw[NE] <> Ord('N')) or (FRaw[NE + 1] <> Ord('E')) then
    raise Exception.Create(FileName + ': no NE header');
  if U16(NE + $24) <> U16(NE + $26) then           { resource table present }
    ParseResources(NE + U16(NE + $24));
end;

procedure TNEFile.ParseResources(Base: LongInt);
var
  Shift, TypeId, N, I, Off, Len, Rid: Word;
  P: LongInt;
  R: TNEResource;

  function Ident(V: Word; out Ord: Word): RawByteString;
  begin
    if V and $8000 <> 0 then
    begin
      Ord := V and $7FFF;
      Result := '';
    end
    else
    begin
      Ord := 0;
      Result := UpperCase(PStr(Base + V));
    end;
  end;

begin
  Shift := U16(Base);
  P := Base + 2;
  while True do
  begin
    TypeId := U16(P);
    if TypeId = 0 then
      Break;
    N := U16(P + 2);
    Inc(P, 8);
    for I := 1 to N do
    begin
      Off := U16(P);
      Len := U16(P + 2);
      Rid := U16(P + 6);
      Inc(P, 12);
      R.TypeName := Ident(TypeId, R.TypeId);
      R.Name := Ident(Rid, R.Id);
      R.Data := nil;
      SetLength(R.Data, LongInt(Len) shl Shift);
      if (LongInt(Off) shl Shift) + Length(R.Data) <= Length(FRaw) then
        Move(FRaw[LongInt(Off) shl Shift], R.Data[0], Length(R.Data));
      SetLength(FResources, Length(FResources) + 1);
      FResources[High(FResources)] := R;
    end;
  end;
end;

function TNEFile.Count: Integer;
begin
  Result := Length(FResources);
end;

function TNEFile.Resource(I: Integer): TNEResource;
begin
  Result := FResources[I];
end;

function TNEFile.Find(TypeId: Word; const Name: RawByteString; Id: Word): TBytes;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FResources) do
    if (FResources[I].TypeId = TypeId) and
       (((Name <> '') and (FResources[I].Name = UpperCase(Name))) or
        ((Name = '') and (FResources[I].Id = Id))) then
      Exit(FResources[I].Data);
end;

function TNEFile.FindNamedType(const TypeName, Name: RawByteString; Id: Word): TBytes;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FResources) do
    if (FResources[I].TypeName = UpperCase(TypeName)) and
       (((Name <> '') and (FResources[I].Name = UpperCase(Name))) or
        ((Name = '') and (FResources[I].Id = Id))) then
      Exit(FResources[I].Data);
end;

function TNEFile.Dialog(const Name: RawByteString): TDlgTemplate;
var
  D: TBytes;
begin
  D := Find(RT_DIALOG, Name);
  if D = nil then
    raise Exception.Create('no dialog ' + Name);
  Result := ParseDialog(D);
  Result.Name := UpperCase(Name);
end;

function TNEFile.DialogNames: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(FResources) do
    if FResources[I].TypeId = RT_DIALOG then
      if FResources[I].Name <> '' then
        Result.Add(FResources[I].Name)
      else
        Result.Add(IntToStr(FResources[I].Id));
end;

function TNEFile.Menu(const Name: RawByteString): TMenuTemplate;
var
  D: TBytes;
begin
  D := Find(RT_MENU, Name);
  if D = nil then
    raise Exception.Create('no menu ' + Name);
  Result := ParseMenu(D);
end;

function TNEFile.BitmapFile(const Name: RawByteString; Id: Word): TBytes;
var
  D: TBytes;
  HdrSize, Bits, Colors, Used: LongWord;
  OffBits: LongWord;
begin
  { a BITMAP resource is a DIB without the 14-byte file header }
  Result := nil;
  D := Find(RT_BITMAP, Name, Id);
  if Length(D) < 16 then
    Exit;
  HdrSize := D[0] or (D[1] shl 8) or (D[2] shl 16) or (LongWord(D[3]) shl 24);
  if HdrSize = 12 then
  begin
    Bits := D[10] or (D[11] shl 8);
    if Bits <= 8 then
      Colors := 1 shl Bits
    else
      Colors := 0;
    OffBits := 14 + 12 + Colors * 3;
  end
  else
  begin
    Bits := D[14] or (D[15] shl 8);
    Used := D[32] or (D[33] shl 8) or (D[34] shl 16) or (LongWord(D[35]) shl 24);
    if Used <> 0 then
      Colors := Used
    else if Bits <= 8 then
      Colors := 1 shl Bits
    else
      Colors := 0;
    OffBits := 14 + HdrSize + Colors * 4;
  end;
  SetLength(Result, 14 + Length(D));
  Result[0] := Ord('B');
  Result[1] := Ord('M');
  PLongWord(@Result[2])^ := NtoLE(LongWord(Length(Result)));
  PLongWord(@Result[6])^ := 0;
  PLongWord(@Result[10])^ := NtoLE(OffBits);
  Move(D[0], Result[14], Length(D));
end;

function TNEFile.IconFile(const Name: RawByteString; Id: Word): TBytes;
var
  G, Img: TBytes;
  N, I: Integer;
  Off: LongWord;
  Images: array of TBytes;
begin
  { GRPICONDIR (6 bytes) + N x GRPICONDIRENTRY (14 bytes: .. nID); the .ico
    entries are 16 bytes with the file offset of the image }
  Result := nil;
  G := Find(RT_GROUP_ICON, Name, Id);
  if Length(G) < 6 then
    Exit;
  N := G[4] or (G[5] shl 8);
  SetLength(Images, N);
  Off := 6 + 16 * N;
  for I := 0 to N - 1 do
  begin
    Img := Find(RT_ICON, '', G[6 + 14 * I + 12] or (G[6 + 14 * I + 13] shl 8));
    Images[I] := Img;
    Inc(Off, Length(Img));
  end;
  SetLength(Result, Off);
  Move(G[0], Result[0], 6);
  Off := 6 + 16 * N;
  for I := 0 to N - 1 do
  begin
    Move(G[6 + 14 * I], Result[6 + 16 * I], 8);                 { size, colours, planes, bits }
    PLongWord(@Result[6 + 16 * I + 8])^ := NtoLE(LongWord(Length(Images[I])));
    PLongWord(@Result[6 + 16 * I + 12])^ := NtoLE(Off);
    if Length(Images[I]) > 0 then
      Move(Images[I][0], Result[Off], Length(Images[I]));
    Inc(Off, Length(Images[I]));
  end;
end;

{ -- templates ------------------------------------------------------------ }

function ZStr(const D: TBytes; var P: LongInt): RawByteString;
var
  E: LongInt;
begin
  E := P;
  while (E < Length(D)) and (D[E] <> 0) do
    Inc(E);
  SetLength(Result, E - P);
  if E > P then
    Move(D[P], Result[1], E - P);
  P := E + 1;
end;

function W16(const D: TBytes; P: LongInt): Word; inline;
begin
  Result := D[P] or (D[P + 1] shl 8);
end;

function W32(const D: TBytes; P: LongInt): LongWord; inline;
begin
  Result := W16(D, P) or (LongWord(W16(D, P + 2)) shl 16);
end;

function ParseDialog(const D: TBytes): TDlgTemplate;
const
  Predef: array[$80..$85] of RawByteString = ('BUTTON', 'EDIT', 'STATIC', 'LISTBOX',
    'SCROLLBAR', 'COMBOBOX');
var
  P: LongInt;
  N, I, Extra: Integer;
  It: TDlgItem;
begin
  Result := Default(TDlgTemplate);
  Result.Style := W32(D, 0);
  N := D[4];
  Result.X := SmallInt(W16(D, 5));
  Result.Y := SmallInt(W16(D, 7));
  Result.CX := SmallInt(W16(D, 9));
  Result.CY := SmallInt(W16(D, 11));
  P := 13;
  if D[P] = $FF then
  begin
    Result.Menu := '#' + IntToStr(W16(D, P + 1));
    Inc(P, 3);
  end
  else
    Result.Menu := ZStr(D, P);
  Result.ClassName := ZStr(D, P);
  Result.Caption := ZStr(D, P);
  if Result.Style and $40 <> 0 then                     { DS_SETFONT }
  begin
    Result.FontSize := W16(D, P);
    Inc(P, 2);
    Result.FontFace := ZStr(D, P);
  end;
  SetLength(Result.Items, N);
  for I := 0 to N - 1 do
  begin
    It := Default(TDlgItem);
    It.X := SmallInt(W16(D, P));
    It.Y := SmallInt(W16(D, P + 2));
    It.CX := SmallInt(W16(D, P + 4));
    It.CY := SmallInt(W16(D, P + 6));
    It.Id := SmallInt(W16(D, P + 8));
    It.Style := W32(D, P + 10);
    Inc(P, 14);
    if D[P] and $80 <> 0 then
    begin
      if (D[P] >= $80) and (D[P] <= $85) then
        It.ClassName := Predef[D[P]]
      else
        It.ClassName := '0x' + LowerCase(IntToHex(D[P], 2));
      Inc(P);
    end
    else
      It.ClassName := ZStr(D, P);
    It.TextOrd := -1;
    if D[P] = $FF then
    begin
      It.TextOrd := W16(D, P + 1);
      It.Text := '#' + IntToStr(It.TextOrd);
      Inc(P, 3);
    end
    else
      It.Text := ZStr(D, P);
    Extra := D[P];
    Inc(P, 1 + Extra);
    Result.Items[I] := It;
  end;
end;

function ParseMenu(const D: TBytes): TMenuTemplate;
var
  P: LongInt;

  procedure Walk(var M: TMenuTemplate);
  var
    It: TMenuTemplate;
  begin
    repeat
      It := Default(TMenuTemplate);
      It.Flags := W16(D, P);
      Inc(P, 2);
      if It.Flags and $10 <> 0 then                    { MF_POPUP }
      begin
        It.Text := ZStr(D, P);
        Walk(It);
      end
      else
      begin
        It.Id := W16(D, P);
        Inc(P, 2);
        It.Text := ZStr(D, P);
      end;
      SetLength(M.Items, Length(M.Items) + 1);
      M.Items[High(M.Items)] := It;
    until (It.Flags and $80 <> 0) or (P >= Length(D));  { MF_END }
  end;

begin
  Result := Default(TMenuTemplate);
  P := 4 + W16(D, 2);
  Walk(Result);
end;

const
  { 0x80..0x9F in CP1252 }
  CP1252Hi: array[$80..$9F] of Word = ($20AC, $FFFD, $201A, $0192, $201E, $2026, $2020, $2021,
    $02C6, $2030, $0160, $2039, $0152, $FFFD, $017D, $FFFD, $FFFD, $2018, $2019, $201C,
    $201D, $2022, $2013, $2014, $02DC, $2122, $0161, $203A, $0153, $FFFD, $017E, $0178);

function CP1252ToUTF8(const S: RawByteString): string;
var
  I: Integer;
  C: Word;
  U: UnicodeString;
begin
  SetLength(U, Length(S));
  for I := 1 to Length(S) do
  begin
    C := Ord(S[I]);
    if (C >= $80) and (C <= $9F) then
      C := CP1252Hi[C];
    U[I] := WideChar(C);
  end;
  Result := UTF8Encode(U);
end;

function UTF8ToCP1252(const S: string): RawByteString;
var
  U: UnicodeString;
  I, K: Integer;
  C: Word;
begin
  U := UTF8Decode(S);
  SetLength(Result, Length(U));
  for I := 1 to Length(U) do
  begin
    C := Ord(U[I]);
    if C > $FF then
    begin
      for K := $80 to $9F do
        if CP1252Hi[K] = C then
          C := K;
      if C > $FF then
        C := Ord('?');
    end;
    Result[I] := Chr(C);
  end;
end;

end.
