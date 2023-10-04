unit PV_Arj;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04
//ARJ

interface

uses
  Classes, SysUtils, Dialogs, CRC32_ISOHDLC, PV_Pack;

type

  { TArj }

  TArj = class(TPack)
  private
    FStream: TStream;
    FList: TFileList;
    FComment: String;
    procedure Start;
  public
    constructor Create(Str: TStream); override;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; override;
    procedure SetComment(Comment: String); override;
  end;

implementation


{ TArj }

constructor TArj.Create(Str: TStream);
begin
  FStream := Str;
  FList := TFileList.Create;

  Start;
end;

procedure TArj.Start;
type THead = packed record
        Magic: Word; //=$ea60
        HeadSize: Word;
        HeadSize2: Byte;
        Version: Byte; //4
        MinVersion: Byte;  //1
        Host: Byte; //0= dos, 2=unix, 4=mac
        Flags: Byte; //0=no pass
        Security: Byte;
        Typee: Byte; //0=binary
        Reserved: Byte;

        CreateTime: Word;//msdos
        CreateDate: Word; //msdos
        ModifyTime: Word;//msdos
        ModifyDate: Word; //msdos

        ArchiveSize: Cardinal;
        Security2: Cardinal;
        SpecOffset: Word;
        SpecSize: Word;
        Encryption: Byte;
        LastChapter: Byte;
        Protection: Byte;
        ArjFlags: Byte;
        SpareBytes: Word;
     end;

var Head: THead;
    HeadLen: Integer;
    Hasher: TCRC32_ISO;
    CRC: Cardinal;
    ArcName: String;
    ExtHeadSize: Cardinal;
    HeadCRC: Cardinal;
    Null: Byte;
    Mem: TMemoryStream;
    Tmp: Byte;
    i: Integer;
begin
  ArcName := 'ARCHIVE.ARJ';

  HeadLen := SizeOf(Head) + Length(ArcName) + 8;  //8 = 2*null + CRC + extra

  with Head do begin
    Magic     := $ea60;
    HeadSize  := 36+Length(ArcName);
    HeadSize2 := 34; //SizeOf(Head)-4(Magic)
    Version   := 11;
    MinVersion:= 1;
    Host      := 0;
    Flags     := $10;
    Security  := 0;
    Typee     := 2;
    Reserved  := $1a;
    CreateTime  := DosTime;
    CreateDate  := DosDate;
    ModifyTime  := DosTime;
    ModifyDate  := DosDate;
    ArchiveSize := 0;
    Security2   := 0;
    SpecOffset  := 0;
    SpecSize    := 0;
    Encryption  := 0;
    LastChapter := 0;
    Protection  := 0;
    ArjFlags    := 0;
    SpareBytes  := 0;
  end;

  //head crc
  Mem := TMemoryStream.Create;
  Mem.Write(Head, SizeOf(Head));
  Mem.Write(ArcName[1], Length(ArcName));

  Null := 0;
  Mem.Write(Null, 1); //null ending filename
  Mem.Write(Null, 1); //null ending comment

  Mem.Position := 4;
  Hasher := TCRC32_ISO.Create;

  for i:=4 to Mem.Size-1 do begin
    Mem.Read(Tmp, 1);

    Hasher.Update(@Tmp, 1);
  end;
  Mem.Free;
  HeadCRC := Hasher.Final;
  Hasher.Free;


  FStream.Write(Head, SizeOf(Head));
  FStream.Write(ArcName[1], Length(ArcName));
  //archive comment, if any

  Null := 0;
  FStream.Write(Null, 1); //null ending filename
  FStream.Write(Null, 1); //null ending comment

  FStream.Write(HeadCRC, 4);

  ExtHeadSize := 00;
  FStream.Write(ExtHeadSize, 2);
end;

destructor TArj.Destroy;
var EOF: Cardinal;
begin
  EOF := $Ea60;
  FStream.Write(EOF, 4);
end;

function TArj.AddFile(Str: TStream; Name: String): Boolean;
const BufLen = 4096;
type TEntryHead = packed record
       Magic: Word; //=$ea60
       HeadSize: Word;
     end;

     TEntry = packed record
       HeadSize2: Byte;
       Version: Byte; //4
       MinVersion: Byte;  //1
       Host: Byte; //0= dos, 2=unix, 4=mac
       Flags: Byte; //0=no pass
       Compression: Byte;//0=stored
       Typee: Byte; //0=binary
       Reserved: Byte;
       Time: Word;//msdos
       Date: Word; //msdos
       PackedSize: Cardinal;
       UnpackedSize: Cardinal;
       CRC32: Cardinal;                //CRC32_ISOHDLC
       Offset: Word;                 //11
       Attributes: Word;             //868
       HostData: Word;
       //34 bytes all the above

      //file name null terminated
      //comment null terminated
      //crc32 of basic header

      //packed file here

    end;

var Entry: TEntry;
    EntryHead: TEntryHead;
    HeadLen: Integer;
    HeadOffset: Integer;
    DataOffset: Integer;
    PackSize: Cardinal;
    Hasher: TCRC32_ISO;
    Buf: array of Byte;
    ReadLen: Integer;
    FinalOffset: Cardinal;
    CRC: Cardinal;
    ArcName: String;
    What: Cardinal;
    ExtHeadSize: Cardinal;
    HeadCRC: Cardinal;
    Null: Byte;
    Mem: TMemoryStream;
    Tmp: Byte;
    i: Integer;
begin
  Name := Uppercase(Name);

  HeadLen := SizeOf(EntryHead) + SizeOf(Entry) + Length(Name) + 8;  //8 = 2*null + CRC + extra

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

  CRC := Hasher.Final;
  Hasher.Free;

  PackSize := FStream.Position - DataOffset;
  FinalOffset := FStream.Position;

  //rewind to write head
  FStream.Position := HeadOffset;

  with EntryHead do begin
    Magic    := $ea60;
    HeadSize := 30 + 2 + Length(Name);    //2 = 2*null
  end;

  FStream.Write(EntryHead, SizeOf(EntryHead));

  with Entry do begin
      HeadSize2  := 30;
      Version    := $0b;
      MinVersion := 1;
      Host       := 0;
      Flags      := $10;  //(0x10 = PATHSYM_FLAG) indicates filename translated ("\" changed to "/")
      Compression:= 0; //store
      Typee      := 0; //binary
      Reserved   := $1a;
      Time       := DosTime;
      Date       := DosDate;
      PackedSize := PackSize;
      UnpackedSize:= Str.Size;
      CRC32       := CRC;
      Offset      := 0;
      Attributes  := $20;
      Hostdata    := 0;
  end;


  //head crc
  Mem := TMemoryStream.Create;
  Mem.Write(Entry, SizeOf(Entry));
  Mem.Write(Name[1], Length(Name));

  Null := 0;
  Mem.Write(Null, 1); //null ending filename
  Mem.Write(Null, 1); //null ending comment

  Mem.Position := 0;
  Hasher := TCRC32_ISO.Create;

  for i:=0 to Mem.Size-1 do begin
    Mem.Read(Tmp, 1);

    Hasher.Update(@Tmp, 1);
  end;
  Mem.Free;

  HeadCRC := Hasher.Final;  //CRC32 ISO HDLC of 38 bytes, that is from HeadSize2 to the last null above
  Hasher.Free;



  FStream.Write(Entry, SizeOf(Entry));
  FStream.Write(Name[1], Length(Name));

  Null := 0;
  FStream.Write(Null, 1); //null ending filename
  FStream.Write(Null, 1); //null ending comment

  FStream.Write(HeadCRC, 4);

  ExtHeadSize := 0;
  FStream.Write(ExtHeadSize, 2);



  FStream.Position := FinalOffset;
end;

procedure TArj.SetComment(Comment: String);
begin
  FComment := Comment;
end;

end.


