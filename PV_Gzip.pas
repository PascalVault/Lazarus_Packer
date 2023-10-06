unit PV_Gzip;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-06
//Gzip

interface

uses
  Classes, SysUtils, StrUtils, Dialogs, CRC32_ISOHDLC, PV_Pack, PV_Compressor;

type

  { TGzip }

  TGzip = class(TPack)
  private
    FStream: TStream;
    FComment: String;
    FIsFull: Boolean;
  public
    constructor Create(Str: TStream); override;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; override;
    procedure SetComment(Comment: String); override;
  end;

implementation


{ TGzip }

constructor TGzip.Create(Str: TStream);
begin
  FStream := Str;
  FIsFull := False;
end;

destructor TGzip.Destroy;
begin
  //
end;

function TGzip.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
        ID1: Byte;
        ID2: Byte;
        Method: Byte;
        Flag: Byte;
        ModTime: Cardinal; //unix
        XFlag: Byte;
        OS: Byte;
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
    Null: Byte;
    Deflate: TCompressorDeflate;
begin
  if FIsFull then Exit(False);

  FIsFull := True;
  HeadLen := SizeOf(Head) + Length(Name)+1;
  if FComment <> '' then HeadLen := HeadLen + Length(FComment)+1;

  //skip head for now
  HeadOffset := FStream.Position;
  DataOffset := HeadOffset + HeadLen;
  FStream.Position := DataOffset;

  //copy data and calculate checksum
  Hasher := TCRC32_ISO.Create;

  Deflate := TCompressorDeflate.Create(FStream);

  SetLength(Buf, BufLen);
  while Str.Position < Str.Size do begin
    ReadLen := Str.Read(Buf[0], BufLen);

    Hasher.Update(@Buf[0], ReadLen);

    //FStream.Write(Buf[0], ReadLen);
    Deflate.Write(Buf[0], ReadLen);
  end;
  Deflate.Free;

  PackSize := FStream.Position - DataOffset;
  FinalOffset := FStream.Position;

  //rewind to write head
  FStream.Position := HeadOffset;

  CRC := Hasher.Final;
  Hasher.Free;

  with Head do begin
    ID1     := 31;
    ID2     := 139;
    Method  := 8; //deflate
    Flag    := 8;
    ModTime := UnixStamp;
    XFlag   := 0;
    OS      := 0; //0=DOS+Win
  end;
  if FComment <> '' then Head.Flag := Head.Flag + 16;

  Null := 0;

  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));
  FStream.Write(Null, 1);

  if FComment <> '' then begin
    FStream.Write(FComment[1], Length(FComment));
    FStream.Write(Null, 1);
  end;

  FStream.Position := FinalOffset;

  FStream.Write(CRC, 4);
  FStream.Write(Str.Size, 4);
end;

procedure TGzip.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

