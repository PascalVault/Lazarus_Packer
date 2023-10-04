unit PV_Zip;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//PK ZIP

interface

uses
  Classes, SysUtils, Dialogs, CRC32_ISOHDLC, PV_Pack;

type

  { TZip }

  TZip = class(TPack)
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


{ TZip }

constructor TZip.Create(Str: TStream);
begin
  FStream := Str;
  FList := TFileList.Create;
end;

destructor TZip.Destroy;
type TCentral = packed record
       Magic: Cardinal;
       Version: Word;
       MinimumVersion: Word;
       GeneralFlag: Word;
       Compression: Word;
       ModTime: Word;
       ModDate: Word;
       CRC32: Cardinal;
       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       FNameLen: Word;
       ExtraLen: Word;
       CommentLen: Word;
       DiskNumber: Word;
       Attributes: Word;
       ExternalAttributes: Cardinal;
       HeaderOffset: Cardinal;
    end;
    TFoot = packed record
       Magic: Cardinal;
       NumberOfDisks: Word;
       StartDisk: Word;
       NumRecordsOnDisk: Word;
       NumRecords: Word;
       SizeOfCentral: Cardinal;
       CentralOffset: Cardinal;
       CommentLen: Word;
    end;

var Central: TCentral;
    Foot: TFoot;
    i: Integer;
    CentralOffset1: Cardinal;
    CentralSize: Cardinal;
begin
  CentralOffset1 := FStream.Position;
  CentralSize := SizeOf(Central) + Length(FList[0].Name);

  for i:=0 to FList.Count-1 do begin

    with Central do begin
      Magic              := $02014b50;
      Version            := $3f;
      MinimumVersion     := 10;
      GeneralFlag        := 0;
      Compression        := 0;
      ModTime            := DosTime;
      ModDate            := DosDate;
      CRC32              := FList[i].Hash;
      PackedSize         := FList[i].PackedSize;
      UnpackedSize       := FList[i].Size;
      FNameLen           := Length(FList[i].Name);
      ExtraLen           := 0;
      CommentLen         := 0;
      DiskNumber         := i;
      Attributes         := 0;
      ExternalAttributes := 0;
      HeaderOffset       := 0;
    end;
    FStream.Write(Central, SizeOf(Central));

    FStream.Write(FList[i].Name[1], Length(FList[i].Name));
  end;

  with Foot do begin
    Magic            := $06054b50;
    NumberOfDisks    := 0;
    StartDisk        := 0;
    NumRecordsOnDisk := FList.Count;
    NumRecords       := FList.Count;
    SizeOfCentral    := CentralSize;
    CentralOffset    := CentralOffset1;
    CommentLen       := Length(FComment);
  end;

  FStream.Write(Foot, SizeOf(Foot));

  if FComment <> '' then
    FStream.Write(FComment[1], Length(FComment));
end;

function TZip.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
       Magic: Cardinal;
       MinimumVersion: Word;
       GeneralFlag: Word;
       Compression: Word;
       ModTime: Word;
       ModDate: Word;
       CRC32: Cardinal;
       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       FNameLen: Word;
       ExtraLen: Word;
    end;

var Head: THead;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC32_ISO;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CRC: Cardinal;
begin
  HeadLen := SizeOf(Head) + Length(Name);

  //skip head for now
  HeadOffset := FStream.Position;
  DataOffset := HeadOffset + HeadLen;
  FStream.Position := DataOffset;

  //copy data and calculate checksum
  Hasher := TCRC32_ISO.Create;

  SetLength(Buf, BufLen);
  while Str.Position < Str.Size do begin
    ReadLen := Str.Read(Buf[0], BufLen);

    Hasher.Update(@Buf[0], ReadLen);

    FStream.Write(Buf[0], ReadLen);
  end;

  PackSize := FStream.Position - DataOffset;
  FinalOffset := FStream.Position;

  //rewind to write head
  FStream.Position := HeadOffset;

  CRC := Hasher.Final;
  Hasher.Free;

  with Head do begin
    Magic          := $04034b50;
    MinimumVersion := 10;
    GeneralFlag    := 0;
    Compression    := 0;
    ModTime        := DosTime;
    ModDate        := DosDate;
    CRC32          := CRC;
    PackedSize     := PackSize;
    UnpackedSize   := Str.Size;
    FNameLen       := Length(Name);
    ExtraLen       := 0;
  end;

  FList.Add(Name, FinalOffset, Str.Size, PackSize, CRC);

  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));

  FStream.Position := FinalOffset;
end;

procedure TZip.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

