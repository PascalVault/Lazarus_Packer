unit PV_Zoo;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-05
//Rahul Dhesi .ZOO version 1.20

interface

uses
  Classes, SysUtils, StrUtils, Dialogs, CRC16_ARC, PV_Pack;

type

  { TZoo }

  TZoo = class(TPack)
  private
    FStream: TStream;
    FComment: String;
    procedure Start;
  public
    constructor Create(Str: TStream); override;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; override;
    procedure SetComment(Comment: String); override;
  end;

implementation


{ TZoo }

procedure TZoo.Start;
type THead = packed record
       HeadText: array[0..19] of Char; //^Z terminated, null padded
       Magic: Cardinal; //FDC4A7DC
       OffsetFile: Cardinal;
       OffsetMinus: Cardinal;
       MajorVersion: Byte;
       MinorVersion: Byte;
    end;
var Head: THead;
begin
    with Head do begin
     HeadText    := AddCharR(chr(0), 'ZOO 1.20 Archive.'+chr(26), 20);
     Magic       := $FDC4A7DC;
     OffsetFile  := $22;
     OffsetMinus := $FFFFFFDE;
     MajorVersion := 1;
     MinorVersion := 1;
  end;
  //34 bytes

  FStream.Write(Head, SizeOf(Head));
end;

constructor TZoo.Create(Str: TStream);
begin
  FStream := Str;

  Start;
end;

destructor TZoo.Destroy;
var FootMagic: Cardinal;
    FootSpace: array[0..13] of Cardinal;
begin
  FootMagic := $FDC4A7DC;
  FillChar(FootSpace, 48, 0);

  FStream.Write(FootMagic, 4);
  FStream.Write(FootSpace, 48);
end;

function TZoo.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type TFoot= packed record
       Magic: Cardinal;
    end;
    TEntry = packed record
      Magic: Cardinal;
      FileType: Byte;
      Compression: Byte; //0=store
      NextEntryOffset: Cardinal;
      NextHeadOffset: Cardinal;
      Date: Word;
      Time: Word;
      CRC16: Word;            //CRC-16 ARC
      UnpackedSize: Cardinal;
      PackedSize: Cardinal;
      MajorVersion: Byte;
      MinorVersion: Byte;
      Deleted: Byte; //1=deleted, 0=normal
      Struc: Byte;
      CommentOffset: Cardinal; //0 for none
      CommentLen: Word;
      FName: array[0..12] of Char; //ASCIIZ

      VarDirSize: Byte;
      TimeZone: Byte;
      DirCRC: Cardinal;
    end;

var Foot: TFoot;
    Entry: TEntry;
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
      Magic           := $FDC4A7DC;
      FileType        := 1;
      Compression     := 0; //store
      NextEntryOffset := FinalOffset; //offset to next entry
      NextHeadOffset  := DataOffset;  //offset to this file
      Date            := DosDate;
      Time            := DosTime;
      CRC16           := CRC;         //CRC-16 ARC
      UnpackedSize    := Str.Size;
      PackedSize      := PackSize;
      MajorVersion    := 1;
      MinorVersion    := 0;
      Deleted         := 0;
      Struc           := 0;
      CommentOffset   := 0; //0 for none
      CommentLen      := 0;
      FName           := Name;

      VarDirSize      := $4f;
      TimeZone        := $40;
      DirCRC          := $00282329; //why?
  end;

  FStream.Write(Entry, SizeOf(Entry));

  FStream.Position := FinalOffset;
end;

procedure TZoo.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

