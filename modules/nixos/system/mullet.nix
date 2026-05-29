{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.mullet;

  content =
    if cfg.sourcePath != null && builtins.pathExists cfg.sourcePath then
      builtins.readFile cfg.sourcePath
    else
      "";

  rawLines = lib.splitString "\n" content;
  pkgNames = builtins.filter (n: n != "") rawLines;

  # Resolves dotted attribute paths like "vimPlugins.LazyVim" against pkgs.
  resolvePkg =
    name:
    let
      pathList = lib.splitString "." name;
    in
    lib.attrsets.attrByPath pathList null pkgs;

  mulletPackages = builtins.filter (p: p != null) (builtins.map resolvePkg pkgNames);

in
{
  options.ft.mullet = {
    enable = lib.mkEnableOption "Imperative package management (The Mullet)";
    sourcePath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the flat text file listing imperative packages, one nixpkgs attribute per line. Set this to the mullet.txt in your user's var/ directory, e.g. sourcePath = ../users/joe/var/mullet.txt;";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = mulletPackages;
  };
}
