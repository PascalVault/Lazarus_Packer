unit PV_Compressor;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-06

interface

uses
  Classes, SysUtils, DateUtils, ZStream, Dialogs, CRC32_ISOHDLC;

type

  { TCompressor }

  TCompressor = class
  public
    constructor Create(OutStr: TStream);
    destructor Destroy; override;
    function Write(const Buffer; Count: Integer): Integer; virtual; abstract;
  end;

  { TCompressorGzip }

  TCompressorGzip = class(TCompressor)
  private
    FHandle: TCompressionStream;
    FHasher: TCRC32_ISO;
    FSize: Cardinal;
  public
    constructor Create(OutStr: TStream);
    destructor Destroy; override;
    function Write(const Buffer; Count: Integer): Integer;
  end;   

implementation

{ TCompressor }

constructor TCompressor.Create(OutStr: TStream);
begin
  inherited Create;
end;

destructor TCompressor.Destroy;
begin
  inherited Destroy;
end;

{ TCompressorGzip }

constructor TCompressorGzip.Create(OutStr: TStream);
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
begin
  inherited Create(OutStr);
  FHandle := TCompressionStream.Create(cldefault, OutStr, True);

  with Head do begin
    ID1     := 31;
    ID2     := 139;
    Method  := 8; //deflate
    Flag    := 0;
    ModTime := DateTimeToUnix(Now, True);
    XFlag   := 0;
    OS      := 0; //0=DOS+Win
  end;

  OutStr.Write(Head, SizeOf(Head));

  FHasher := TCRC32_ISO.Create;
  FSize   := 0;
end;

destructor TCompressorGzip.Destroy;
var CRC: Cardinal;
    OutStr: TStream;
begin
  FHandle.Free;

  CRC := FHasher.Final;
  FHasher.Free;

  OutStr := FHandle.Source;

  OutStr.Write(CRC, 4);
  OutStr.Write(FSize, 4);

  inherited Destroy;
end;

function TCompressorGzip.Write(const Buffer; Count: Integer): Integer;
begin
  Result := FHandle.Write(Buffer, Count);

  FHasher.Update(@Buffer, Count);

  Inc(FSize, Result);
end;     

end.

