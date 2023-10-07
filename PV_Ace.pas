unit PV_Ace;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-07
//Marcel Lemke .ACE 1.2

interface

uses
  Classes, SysUtils, StrUtils, Dialogs, CRC32_JAMCRC, PV_Pack;

type

  { TAce }

  TAce = class(TPack)
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


{ TAce }

constructor TAce.Create(Str: TStream);
begin
  FStream := Str;
end;

destructor TAce.Destroy;
begin
  //
end;

function TAce.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type THead = packed record
       CRC: Word;
       Size: Word;
       Typee: Byte;
       Flags: Word;

       Magic: array[0..6] of Char; //**ACE**
       VersionExtract: Byte;
       VersionCreate: Byte;
       Host: Byte;
       VolumeNum: Byte;
       FileTime: Word;
       FileDate: Word;
       Reserved1: Cardinal;
       Reserved2: Cardinal;
     end;

     TEntry = packed record
       CRC: Word;
       Size: Word;
       Typee: Byte;
       Flags: Word;

       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       FileTime: Word;
       FileDate: Word;
       Attrib: Cardinal;
       CRC32: Cardinal;
       Method: Byte;
       Speed: Byte;
       Decompression: Word;
       Reserved: Word;
       FNameLen: Word;
       //FName
    end;

var Entry: TEntry;
    Head: THead;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC32_JAM;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    Mem: TMemoryStream;
    ResCRC: Cardinal;
    ResCRC16: Cardinal;
    Null: Byte;
    Tmp: Byte;
    AvLen: Byte;
    AV: String;
begin
  AV := '*UNREGISTERED VERSION*';
  AvLen := Length(AV);

  Name := UpperCase(Name);

  HeadLen := SizeOf(Entry) + SizeOf(Head) + Length(Name) + AvLen+1;

  //skip head for now
  HeadOffset := FStream.Position;
  DataOffset := HeadOffset + HeadLen;
  FStream.Position := DataOffset;

  //copy data and calculate checksum
  Hasher := TCRC32_JAM.Create;

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

  ResCRC := Hasher.Final;
  Hasher.Free;



  with Head do begin
      CRC   := 0;
      Size  := SizeOf(Head)-4 + AvLen+1;
      Typee := 0; //0=head
      Flags := $1000;    //=main header contains AV-string

      Magic          := '**ACE**';
      VersionExtract := $0a;
      VersionCreate  := $0c;
      Host           := 0;// 0=dos
      VolumeNum      := 0;
      FileTime       := DosTime;
      FileDate       := DosDate;
      Reserved1      := 0;
      Reserved2      := 0;
  end;

  //calc CRC16
  Mem := TMemoryStream.Create;
  Hasher := TCRC32_JAM.Create;

  Mem.Write(Head, SizeOf(Head));
  Mem.Write(AvLen, 1);
  Mem.Write(AV[1], Length(AV));

  Mem.Position := 4;
  while Mem.Position < Mem.Size do begin
     Mem.Read(Tmp, 1);

     Hasher.Update(@Tmp, 1);
  end;
  ResCRC16 := Hasher.Final and $FFFF;
  Hasher.Free;
  Mem.Free;
  //===

  Head.CRC := ResCRC16;
  FStream.Write(Head, SizeOf(Head));
  FStream.Write(AvLen, 1);
  FStream.Write(AV[1], 22);

  with Entry do begin
      CRC   := 0;
      Size  := SizeOf(Entry)-4 + Length(Name);
      Typee := 1; //1=file
      Flags := 1;


      PackedSize   := PackSize;
      UnpackedSize := Str.Size;
      FileTime     := DosTime;
      FileDate     := DosDate;
      Attrib       := 0;
      CRC32        := ResCRC;
      Method       := 0; //0=store
      Speed        := 0; //0=fastest
      Decompression:= 0;
      Reserved     := 0;
      FNameLen     := Length(Name);
  end;

  //calc CRC16
  Mem := TMemoryStream.Create;
  Hasher := TCRC32_JAM.Create;

  Mem.Write(Entry, SizeOf(Entry));
  Mem.Write(Name[1], Length(Name));

  Mem.Position := 4;
  while Mem.Position < Mem.Size do begin
     Mem.Read(Tmp, 1);

     Hasher.Update(@Tmp, 1);
  end;
  ResCRC16 := Hasher.Final and $FFFF;
  Hasher.Free;
  Mem.Free;

  Entry.CRC := ResCRC16;

  FStream.Write(Entry, SizeOf(Entry));
  FStream.Write(Name[1], Length(Name));

  FStream.Position := FinalOffset;
end;

procedure TAce.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.

