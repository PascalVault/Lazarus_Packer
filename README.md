# Lazarus_Packer
PV_Packer - simple pure Pascal library to pack files to various archives (ZIP, RAR, TAR...)

See also:
https://github.com/PascalVault/Lazarus_Unpacker

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
