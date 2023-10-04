unit PV_Rar;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//WinRAR .RAR 4

interface

uses
  Classes, SysUtils, CRC32_ISOHDLC, PV_Pack, Dialogs;

type

  { TRar }

  TRar = class(TPack)
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


{ TRar }

constructor TRar.Create(Str: TStream);
begin
  FStream := Str;
end;

destructor TRar.Destroy;
begin
  //
end;

function TRar.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type TVolHead = packed record
       CRC: Word;
       Typee: Byte;
       Flags: Word;
       Size: Word;
       //size 5 (without CRC)
     end;

     TMainHead = packed record
       Reserved1: Word;
       Reserved2: Cardinal;
     end;

     THead = packed record
       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       HostOS: Byte;
       CRC32: Cardinal;
       FileTime: Word;
       FileDate: Word;
       Version: Byte;
       Method: Byte;
       FNameLen: Word;
       FileAttr: Cardinal;
       //size = 25
     end;

var Head: THead;
    VolHead: TVolHead;
    MainHead: TMainHead;

    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC32_ISO;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CRC: Cardinal;
    Mem: TMemoryStream;
    i: Integer;
    NullByte: Byte;
    Tmp: Byte;
begin
  HeadLen := SizeOf(Head) + Length(Name) + 3*SizeOf(VolHead) + SizeOf(MainHead)+1;

  Mem := TMemoryStream.Create;

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

  //MARK_HEAD = signature
  with VolHead do begin
    CRC   := $6152;
    Typee := $72;
    Flags := $1a21;
    Size  := $0007;
  end;
  FStream.Write(VolHead, SizeOf(VolHead));

  //MAIN_HEAD
  with VolHead do begin
    CRC   := 0;
    Typee := $73;
    Flags := 0;
    Size  := 13;  //SizeOf(VolHead) + SizeOf(MainHead) - SizeOf(CRC)
  end;
  with MainHead do begin
    Reserved1 := 0;
    Reserved2 := 0;
  end;

  Mem.Write(VolHead, SizeOf(VolHead));
  Mem.Write(MainHead, SizeOf(MainHead));

  Hasher := TCRC32_ISO.Create;
  Mem.Position := 2;
  for i:=2 to Mem.Size-1 do begin
    Mem.Read(Tmp, 1);
    Hasher.Update(@Tmp, 1);
  end;
  VolHead.CRC := Hasher.Final and $FFFF;
  Hasher.Free;

  FStream.Write(VolHead, SizeOf(VolHead));
  FStream.Write(MainHead, SizeOf(MainHead));

  //FILE_HEAD
  with VolHead do begin
    CRC   := 0;
    Typee := $74;
    Flags := $8020;;
    Size  := SizeOf(VolHead) + SizeOf(Head) + Length(Name) + 1;
  end;
  with Head do begin
    PackedSize   := PackSize;
    UnpackedSize := Str.Size;
    HostOS       := 2; //2=Windows
    CRC32        := CRC;
    FileTime     := DosTime;
    FileDate     := DosDate;
    Version      := 20;
    Method       := 48;
    FNameLen     := Length(Name);
    FileAttr     := $20;
  end;

  Mem.Clear;
  Mem.Write(VolHead, SizeOf(VolHead));
  Mem.Write(Head, SizeOf(Head));
  Mem.Write(Name[1], Length(Name));
  NullByte := 0;
  Mem.Write(NullByte, 1);

  Hasher := TCRC32_ISO.Create;
  Mem.Position := 2;
  for i:=2 to Mem.Size-1 do begin
    Mem.Read(Tmp, 1);
    Hasher.Update(@Tmp, 1);
  end;
  VolHead.CRC := Hasher.Final and $FFFF;
  Hasher.Free;

  FStream.Write(VolHead, SizeOf(VolHead));
  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));
  NullByte := 0;
  FStream.Write(NullByte, 1);

  FStream.Position := FinalOffset;


  //EOF
  with VolHead do begin
    CRC   := $3dc4;
    Typee := $7b;
    Flags := $4000;
    Size  := $0007;
  end;

  FStream.Write(VolHead, SizeOf(VolHead));

  Mem.Free;
end;

procedure TRar.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

