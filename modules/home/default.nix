{ inputs, lib, ... }:

let
  # 1. Load the directory tree as paths.
  moduleTree = inputs.haumea.lib.load {
    src = ./.;
    loader = inputs.haumea.lib.loaders.path;
  };

  # 2. Flatten the nested attribute set into a 1D list of paths.
  allPaths = lib.collect (x: builtins.isPath x || builtins.isString x) moduleTree;
  
  # 3. Filter out THIS specific file and the root directory to prevent infinite recursion.
  localModules = builtins.filter (path: path != ./default.nix && path != ./.) allPaths;
in
{
  # Boom. Automatically imports every .nix file in this directory and below.
  imports = localModules;
}