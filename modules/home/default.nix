{ lib, ... }:
let
  # Drop any .nix file here — no manual wiring needed.
  allFiles = lib.filesystem.listFilesRecursive ./.
  ;
  
  validModules = builtins.filter 
    (path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix) 
    allFiles;
in
{
  imports = validModules;
}
