# Lazarus_Packer
PV_Packer - simple pure Pascal library to pack files to various archives (ZIP, RAR, TAR...)

See also:
https://github.com/PascalVault/Lazarus_Unpacker

## Supported formats ##
- .ZIP
- .TAR
- .GZ
- .GZA
- .BH
- .RAR (method "store")
- .ARJ (method "store")
- .ACE (method "store")
- .LZH .LHA (method "store")
- .ARC (method "store")
- .ZOO (can be opened with IZarc) (method "store")

## Unsupported, yet ##
- encryption

## Usage ##
    uses PV_Packer;
    ...
    var Zip: TPacker; 
    begin
    Zip := TPacker.Create('out.tar', 'tar');
    Zip.SetComment('Created by PV_Packer'); //not all formats support comments yet

    Zip.AddFile('input file.txt', 'name in the archive.txt'); //or
    Zip.AddFile('input file.txt');

    Zip.Free;      

## Usage - GZIP ##
    uses PV_Packer;
    ...
    var Zip: TPacker; 
    begin
    Zip := TPacker.Create('out.gz', 'gz');
    Zip.SetComment('Created by PV_Packer'); 

    Zip.AddFile('input file.txt', 'name in the archive.txt');
    Zip.AddFile('input file.txt'); //this returns False because there can be only 1 file in .GZIP

    Zip.Free;  
