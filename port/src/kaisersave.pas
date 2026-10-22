{ Kaiser savegames (*.KSR): read and write the original format byte for byte.

  Layout (see docs/ksr-format.md, original routines SaveGame 1050:058b and
  LoadGame 1050:07ed):
    header  TGameHeader ($295 bytes, the global game record)
    players NumPlayers x TPlayer ($6D5 bytes each)
    extra   $192 bytes, only if EmailGame and GameState = 3 }
unit KaiserSave;

{$mode objfpc}{$H+}

interface

uses
  KaiserTypes;

const
  SaveMagic = $7B;  // the character open-brace, also the version 1.23

type
  TExtraBlock = packed array[0..ExtraSize - 1] of Byte;

  TSaveGame = record
    Header: TGameHeader;
    Players: TPlayers;
    HasExtra: Boolean;
    Extra: TExtraBlock;
  end;

  TLoadResult = (lrOk, lrCannotOpen, lrBadMagic, lrShortRead, lrBadChecksum);

{ The three anti-cheat values the original writes into every player record. }
procedure UpdateChecksums(var P: TPlayer);
function ChecksumsValid(const P: TPlayer): Boolean;

function LoadSaveGame(const FileName: string; out Save: TSaveGame): TLoadResult;
procedure WriteSaveGame(const FileName: string; var Save: TSaveGame);

implementation

procedure UpdateChecksums(var P: TPlayer);
begin
  { SaveGame 1050:058b: check_a = lifetime + (taler - land),
    check_b = lifetime + (land - taler), check_c = (taler + land) div 1000 }
  P.CheckA := P.Lifetime + (P.Taler - P.Land);
  P.CheckB := P.Lifetime + (P.Land - P.Taler);
  P.CheckC := (P.Taler + P.Land) div 1000;
end;

function ChecksumsValid(const P: TPlayer): Boolean;
begin
  Result := (P.CheckA = P.Lifetime + (P.Taler - P.Land)) and
            (P.CheckB = P.Lifetime + (P.Land - P.Taler)) and
            (P.CheckC = (P.Taler + P.Land) div 1000);
end;

function LoadSaveGame(const FileName: string; out Save: TSaveGame): TLoadResult;
var
  F: file;
  I, Got: Integer;
begin
  FillChar(Save, SizeOf(Save), 0);
  Assign(F, FileName);
  FileMode := 0;  { read-only, so write-protected originals can be loaded }
  {$I-} Reset(F, 1); {$I+}
  FileMode := 2;
  if IOResult <> 0 then
    Exit(lrCannotOpen);
  try
    BlockRead(F, Save.Header, HeaderSize, Got);
    if (Got < HeaderSize) or (Save.Header.Magic <> SaveMagic) then
      Exit(lrBadMagic);
    for I := 0 to Save.Header.NumPlayers - 1 do
    begin
      BlockRead(F, Save.Players[I], PlayerSize, Got);
      if Got < PlayerSize then
        Exit(lrShortRead);
      if not ChecksumsValid(Save.Players[I]) then
        Exit(lrBadChecksum);
    end;
    Save.HasExtra := (Save.Header.EmailGameQ <> 0) and (Save.Header.GameState = 3);
    if Save.HasExtra then
    begin
      BlockRead(F, Save.Extra, ExtraSize, Got);
      if Got < ExtraSize then
        Exit(lrShortRead);
    end;
    Result := lrOk;
  finally
    Close(F);
  end;
end;

procedure WriteSaveGame(const FileName: string; var Save: TSaveGame);
var
  F: file;
  I: Integer;
begin
  { the original sets the magic and refreshes the checksums before writing;
    it also stores a new random seed, which a faithful copy must not do }
  Save.Header.Magic := SaveMagic;
  Assign(F, FileName);
  Rewrite(F, 1);
  try
    BlockWrite(F, Save.Header, HeaderSize);
    for I := 0 to Save.Header.NumPlayers - 1 do
    begin
      UpdateChecksums(Save.Players[I]);
      BlockWrite(F, Save.Players[I], PlayerSize);
    end;
    if Save.HasExtra then
      BlockWrite(F, Save.Extra, ExtraSize);
  finally
    Close(F);
  end;
end;

end.
