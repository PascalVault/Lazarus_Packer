unit PV_Pack;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04

interface

uses
  Classes, SysUtils, DateUtils, Dialogs;

type

  { TPack }

  TPack = class
  private
    FStream: TStream;
  public
    constructor Create(Str: TStream); virtual; abstract;
    destructor Destroy; virtual; abstract;
    function AddFile(Str: TStream; Name: String): Boolean; virtual; abstract;
    procedure SetComment(Comment: String); virtual; abstract;
  end;

  TFileRec = record
    Name: String;
    Offset: Cardinal;
    Size: Cardinal;
    PackedSize: Cardinal;
    Hash: Cardinal;
  end;

  { TFileList }

  TFileList = class
  private
    FSize: Integer;
    FCount: Integer;
    FArray: array of TFileRec;
  public
    constructor Create;
    procedure Add(Name: String; Offset, Size, PackedSize, Hash: Cardinal);
    function GetFile(Index: Integer): TFileRec;
    property Count: Integer read FCount;
    property Files[Index: Integer]: TFileRec read GetFile; default;
  end;

  function DosTime(Time: TDateTime = -1): Word;
  function DosDate(Time: TDateTime = -1): Word;
  function UnixStamp(Time: TDateTime = -1): Int64;

implementation

function DosTime(Time: TDateTime): Word;
var Temp: Cardinal;
begin
  if Time = -1 then Time := Now();
  Temp := DateTimeToDosDateTime(Time);
  Result := Temp and $FFFF;
end;

function DosDate(Time: TDateTime): Word;
var Temp: Cardinal;
begin
  if Time = -1 then Time := Now();
  Temp := DateTimeToDosDateTime(Time);
  Result := Temp shr 16;
end;

function UnixStamp(Time: TDateTime): Int64;
begin
  if Time = -1 then Time := Now();
  Result := DateTimeToUnix(Time, True);
end;

{ TFileList }

constructor TFileList.Create;
begin
  FSize := 1000;
  FCount := 0;
  SetLength(FArray, FSize);
end;

procedure TFileList.Add(Name: String; Offset, Size, PackedSize, Hash: Cardinal);
begin
  if FCount > FSize-1 then begin
    Inc(FSize, 1000);
    SetLength(FArray, FSize);
  end;

  FArray[FCount].Name := Name;
  FArray[FCount].Offset := Offset;
  FArray[FCount].Size := Size;
  FArray[FCount].PackedSize := PackedSize;
  FArray[FCount].Hash := Hash;

  Inc(FCount);
end;

function TFileList.GetFile(Index: Integer): TFileRec;
begin
  Result := FArray[Index];
end;

end.

