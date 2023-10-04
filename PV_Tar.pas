unit PV_Tar;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//TAR

interface

uses
  Classes, SysUtils, StrUtils, Math, Dialogs, CRC32_ISOHDLC, PV_Pack;

type

  { TTar }

  TTar = class(TPack)
  private
    FStream: TStream;
    FList: TFileList;
    FComment: String;
  public
    constructor Create(Str: TStream); override;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; override;
    procedure SetComment(Comment: String); override;
  end;

implementation


{ TTar }

function IntToOct(Val: Integer): String;
var Rest: Integer;
begin
  Result := '';
  while Val <> 0 do begin
    Rest  := Val mod 8;
    Val := Val div 8;
    Result := IntToStr(Rest) + Result;
  end;
end;

constructor TTar.Create(Str: TStream);
begin
  FStream := Str;
  FList := TFileList.Create;
end;

destructor TTar.Destroy;
begin
  //
end;

function TTar.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
       FName       : array[0..99] of Char;
       FileMode    : array[0..7] of Char;
       OwnerID     : array[0..7] of Char;
       GroupID     : array[0..7] of Char;
       UnpackedSize: array[0..11] of Char;
       ModTime     : array[0..11] of Char;
       Checksum    : array[0..7] of Char;
       FileType    : Char;
       LinkName    : array[0..99] of Char;
       UstarMagic  : array[0..5] of Char;
       Version     : array[0..1] of Char;
       UName       : array[0..31] of Char;
       GName       : array[0..31] of Char;
       DevMajor    : array[0..7] of Char;
       DevMinor    : array[0..7] of Char;
       Prefix      : array[0..154] of Char;
    end;

var Head: THead;
    HeadStr: String;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC32_ISO;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CkSum: Cardinal;
    i: Integer;
    Null: Byte;
    Pad: Integer;
begin

  with Head do begin
    FName        := Name;
    FileMode     := '0000777' + chr(0);
    OwnerID      := '0000000' + chr(0);
    GroupID      := '0000000' + chr(0);
    UnpackedSize := AddChar('0', IntToOct(Str.Size), 11) + chr(0);
    ModTime      := AddChar('0', IntToOct(UnixStamp), 11) + chr(0);
    Checksum     := '        ';
    FileType     := '0';
    LinkName     := AddChar(chr(0), '', 100);

    UstarMagic  := 'ustar ';
    Version     := ' ' + chr(0);
    UName       := AddChar(chr(0), '', 32);
    GName       := AddChar(chr(0), '', 32);
    DevMajor    := AddChar(chr(0), '', 8);
    DevMinor    := AddChar(chr(0), '', 8);
    Prefix      := AddChar(chr(0), '', 155);
  end;

  HeadStr := Head.FName + Head.FileMode + Head.OwnerID + Head.GroupID + Head.UnpackedSize + Head.ModTime + Head.Checksum +
             Head.FileType + Head.LinkName + Head.UstarMagic + Head.Version + Head.UName + Head.Gname + Head.DevMajor +
             Head.DevMinor + Head.Prefix;

  CkSum := 0;

  for i:=1 to Length(HeadStr) do
    CkSum := CkSum + ord(HeadStr[i]);

  Head.Checksum := AddChar('0', IntToOct(CkSum), 6) + chr(0) + ' ';

  FStream.Write(Head, SizeOf(Head));

  Pad := Ceil(FStream.Position / 512) * 512 - FStream.Position;

  Null := 0;
  for i:=0 to Pad-1 do
    FStream.Write(Null, 1);


  SetLength(Buf, BufLen);
  while Str.Position < Str.Size do begin
    ReadLen := Str.Read(Buf[0], BufLen);

    FStream.Write(Buf[0], ReadLen);
  end;

  Pad := Ceil(FStream.Position / 512) * 512 - FStream.Position;

  Null := 0;
  for i:=0 to Pad-1 do
    FStream.Write(Null, 1);

  for i:=0 to 511 do
    FStream.Write(Null, 1);
  for i:=0 to 511 do
    FStream.Write(Null, 1);
end;

procedure TTar.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

