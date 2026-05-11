{ lib, ... }:
let
  # Drop any .nix file here — no manual wiring needed.
  allFiles = lib.filesystem.listFilesRecursive ./.
  ;
  
  # Filter out anything that isn't a .nix file, and ignore THIS file to prevent infinite loops
  validModules = builtins.filter 
    (path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix) 
    allFiles;
in
{
  # Feed the paths to the module system. It won't evaluate them unless a toggle is flipped.
  imports = validModules;
}
