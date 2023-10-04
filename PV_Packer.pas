unit PV_Packer;

{$mode objfpc}{$H+}
//PV Pack
//https://github.com/PascalVault
//Licence: MIT
//Last update: 2023-10-04

interface

uses
  Classes, SysUtils, Dialogs, PV_Pack;

type

  { TPacker }

  TPacker = class
  private
   FObj: TPack;
   FFile: TFileStream;
  public
    constructor Create(Str: TStream; Format: String = ''); overload;
    constructor Create(Filename: String; Format: String = ''); overload;
    destructor Destroy; override;
    function AddFile(Str: TStream; Name: String): Boolean; overload;
    function AddFile(Filename: String; Name: String = ''): Boolean; overload;
    procedure SetComment(Comment: String);
  end;


implementation

uses PV_Zip, PV_BH, PV_Bga, PV_Tar, PV_Lzh, PV_Arj, PV_Rar;

{ TPacker }

constructor TPacker.Create(Str: TStream; Format: String = '');
begin
  Format := LowerCase(Format);

  case Format of
   'zip': FObj := TZip.Create(Str);
   'bh' : FObj := TBH.Create(Str);
   'bga': FObj := TBga.Create(Str);
   'lzh': FObj := TLzh.Create(Str);
   'arj': FObj := TArj.Create(Str);
   'tar': FObj := TTar.Create(Str);
   'rar': FObj := TRar.Create(Str);
   //'zoo' : FObj := TZoo.Create(Str);
  end;
end;

constructor TPacker.Create(Filename: String; Format: String);
begin
  FFile := TFileStream.Create(Filename, fmCreate or fmShareDenyWrite);

  Create(FFile, Format);
end;

destructor TPacker.Destroy;
begin
  FObj.Destroy;
end;

function TPacker.AddFile(Str: TStream; Name: String): Boolean;
begin
  FObj.AddFile(Str, Name);
end;

function TPacker.AddFile(Filename: String; Name: String): Boolean;
var F: TFileStream;
begin
  if Name = '' then Name := ExtractFileName(Filename);

  F := TFileStream.Create(Filename, fmOpenRead or fmShareDenyNone);
  FObj.AddFile(F, Name);
  F.Free;
end;

procedure TPacker.SetComment(Comment: String);
begin
  FOBj.SetComment(Comment);
end;



end.

