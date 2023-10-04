unit PV_Lzh;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//LZH

interface

uses
  Classes, SysUtils, Dialogs, CRC16_ARC, PV_Pack;

type

  { TLzh }

  TLzh = class(TPack)
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


{ TLzh }

constructor TLzh.Create(Str: TStream);
begin
  FStream := Str;
  FList := TFileList.Create;
end;

destructor TLzh.Destroy;
var EOF: Byte;
begin
  EOF := 0;
  FStream.Write(EOF, 1);
end;

function TLzh.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
      HeadLen: Byte;   // 0=end of file
      HeadCRC: Byte;   //CRC-16 ARC
      SignBegin: Char; // '-'
      l: Char;         // 'l'
      H: Char;         // 'h'
      Compression: Char;
      SignEnd: Char;  // '-'
      PackedSize: Cardinal;
      UnpackedSize: Cardinal;
      FileTime: Word;
      FileDate: Word;
      ExternalAttr: Byte;
      Level: Byte;
      FNameLen: Byte;
    end;

var Head: THead;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC16_ARC;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CRC: Cardinal;
    Mem: TMemoryStream;
    HeadCRC: Byte;
    Tmp: Byte;
    i: Integer;
begin
  HeadLen := SizeOf(Head) + Length(Name)+2;

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

  with Head do begin
      HeadLen      := SizeOf(Head) + Length(Name);   // 0=end of file
      HeadCRC      := 0;
      SignBegin    := '-';
      l            := 'l';
      H            := 'h';
      Compression  := '0';
      SignEnd      := '-';
      PackedSize   := PackSize;
      UnpackedSize := Str.Size;
      FileTime     := DosTime;
      FileDate     := DosDate;
      ExternalAttr := $20;
      Level        := 0;
      FNameLen     := Length(Name);
  end;

  Mem := TMemoryStream.Create;
  Mem.Write(Head, SizeOf(Head));
  Mem.Write(Name[1], Length(Name));
  Mem.Write(CRC, 2);
  Mem.Position := 2;

  HeadCRC := 0;
  for i:=2 to Mem.Size-1 do begin
    Mem.Read(Tmp, 1);
    HeadCRC := HeadCRC + Tmp;
  end;
  Mem.Free;
  Head.HeadCRC := HeadCRC;


  FStream.Write(Head, SizeOf(Head));
  FStream.Write(Name[1], Length(Name));
  FStream.Write(CRC, 2);

  FStream.Position := FinalOffset;
end;

procedure TLzh.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

