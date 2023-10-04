unit PV_BH;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//BlakHole .BH

interface

uses
  Classes, SysUtils, Dialogs, CRC32_ISOHDLC, PV_Pack;

type

  { TBH }

  TBH = class(TPack)
  private
    FStream: TStream;
    FComment: String;
  public
    constructor Create(Str: TStream); override;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; override;
    procedure SetComment(Comment: String); override;
  end;

implementation


{ TBH }

constructor TBH.Create(Str: TStream);
begin
  FStream := Str;
end;

destructor TBH.Destroy;
begin
  //
end;

function TBH.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
       SignAtr: array[0..3] of Char;
       HdrSize: Word;
       HeadSize: Byte;
       VerNum: Byte;
       MinVerNum: Byte;
       BitFlag: Byte;
       Compression: Byte;       //0= store, 8=deflate
       FileTime: Word;
       FileDate: Word;
       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       CRC32: Cardinal;
       ExternalAttr: Word;
       HeadCrc32: Cardinal;
       FNameLen: Word;
       CommentLen: Word;
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
    SignAtr     := 'BH' + chr(5)+chr(7);
    HdrSize     := 37 + Length(Name);
    HeadSize    := 37;
    VerNum      := 218;
    MinVerNum   := 4;
    BitFlag     := 0;
    Compression := 0;       //0= store, 8=deflate
    FileTime    := DosTime;
    FileDate    := DosDate;
    PackedSize  := Str.Size;
    UnpackedSize:= Str.Size;
    CRC32        := CRC;
    ExternalAttr := 8224; //?
    HeadCrc32    := 0;
    FNameLen     := Length(Name);
    CommentLen   := 0;
  end;

  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));

  FStream.Position := FinalOffset;
end;

procedure TBH.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

