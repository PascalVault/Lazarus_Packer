unit PV_Arc;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-06
//SEA .ARC, spec 6.02

interface

uses
  Classes, SysUtils, StrUtils, Dialogs, CRC16_ARC, PV_Pack;

type

  { TArc }

  TArc = class(TPack)
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


{ TArc }

constructor TArc.Create(Str: TStream);
begin
  FStream := Str;
end;

destructor TArc.Destroy;
var FootMagic: Word;
begin
  FootMagic := $001A;

  FStream.Write(FootMagic, 2);
end;

function TArc.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type TEntry = packed record
       Magic: Byte; //1A
       Method: Byte;
       FName: array[0..12] of Char;    //max 12 bytes+null
       PackedSize: Cardinal;
       FileTime: Word;
       FileDate: Word;
       CRC16: Word;
       UnpackedSize: Cardinal;
    end;

var Entry: TEntry;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC16_ARC;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CRC: Cardinal;
    Null: Byte;
begin
  HeadLen := SizeOf(Entry);

  //skip head for now
  HeadOffset := FStream.Position;
  DataOffset := HeadOffset + HeadLen;
  FStream.Position := DataOffset;

  //copy data and calculate checksum
  Hasher := TCRC16_ARC.Create;

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

  with Entry do begin
      Magic        := $1A;
      Method       := 2; //2=store (ARC 3.1+)
      FName        := Name;
      PackedSize   := PackSize;
      FileTime     := DosTime;
      FileDate     := DosDate;
      CRC16        := CRC;
      UnpackedSize := Str.Size;
  end;

  FStream.Write(Entry, SizeOf(Entry));

  FStream.Position := FinalOffset;
end;

procedure TArc.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

