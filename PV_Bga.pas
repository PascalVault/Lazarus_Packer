unit PV_Bga;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//BGA format .GZA, .BZA

interface

uses
  Classes, SysUtils, Dialogs, PV_Pack, PV_Compressor;

type

  { TBga }

  TBga = class(TPack)
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

{ TBga }

constructor TBga.Create(Str: TStream);
begin
  FStream := Str;
end;

destructor TBga.Destroy;
begin
  //
end;

function Sign(C: Byte): LongInt;
begin
  Result := C;
  if Result >= $80 then Result := Result or $ffffff00;
end;

function TBga.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
      Checksum: Cardinal;
      Magic: array[0..3] of Char;
      PackedSize: Cardinal;
      UnpackedSize: Cardinal;
      Date: Word;
      Time: Word;
      Attrib: Byte;
      HeadType: Byte;
      ArcType: Word;
      DirLen: Word;
      FNameLen: Word;
    end;

var Head: THead;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CheckSum1: LongInt;
    Mem: TMemoryStream;
    Data: Byte;
    i: Integer;
    Gzip: TCompressorGzip;
begin
  HeadLen := SizeOf(Head) + Length(Name);

  //skip head for now
  HeadOffset := FStream.Position;
  DataOffset := HeadOffset + HeadLen;
  FStream.Position := DataOffset;

  Gzip := TCompressorGzip.Create(FStream);

  SetLength(Buf, BufLen);
  while Str.Position < Str.Size do begin
    ReadLen := Str.Read(Buf[0], BufLen);

    Gzip.Write(Buf[0], ReadLen);
  end;

  Gzip.Free;

  PackSize := FStream.Position - DataOffset;
  FinalOffset := FStream.Position;

  //rewind to write head
  FStream.Position := HeadOffset;

  with Head do begin
     Checksum     := 0;
     Magic        := 'GZIP';
     PackedSize   := PackSize;
     UnpackedSize := Str.Size;
     Date         := DosDate;
     Time         := DosTime;
     Attrib       := 0; //DIR=16
     HeadType     := 0;
     ArcType      := 1; //2=store, 1=packed
     DirLen       := 0;
     FNameLen     := Length(Name);
  end;

  Mem := TMemoryStream.Create;
  Mem.Write(Head, SizeOf(Head));
  Mem.Write(Name[1], Length(Name));
  Mem.Position := 4;

  Checksum1 := 0;
  for i:=4 to Mem.Size-1 do begin
     Mem.Read(Data, 1);
    Checksum1 := Checksum1 + Sign(Data);
  end;
  Mem.Free;

  Head.Checksum := Checksum1;

  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));

  FStream.Position := FinalOffset;
end;

procedure TBga.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

