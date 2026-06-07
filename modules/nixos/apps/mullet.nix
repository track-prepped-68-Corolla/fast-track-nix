{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# MULLET MODULE — imperative package escape hatch
# ------------------------------------------------------------------------------
# Reads a flat newline-delimited text file of package attribute names and
# installs each into environment.systemPackages. Lets a consumer add or drop
# packages by editing a plain text file rather than rebuilding module options.
# Names may be nested (e.g. "vimPlugins.LazyVim"); unresolved names are dropped.
################################################################################

let
  cfg = config.ft.mullet;

  # Safely read the file, providing an empty string if it doesn't exist yet.
  content = if builtins.pathExists cfg.sourcePath then builtins.readFile cfg.sourcePath else "";

  # Clean up the raw text into a list of strings.
  rawLines = lib.splitString "\n" content;
  pkgNames = builtins.filter (n: n != "") rawLines;

  # Resolver for nested attributes (e.g. "vimPlugins.LazyVim" -> ["vimPlugins" "LazyVim"]).
  resolvePkg =
    name:
    let
      pathList = lib.splitString "." name;
    in
    lib.attrsets.attrByPath pathList null pkgs;

  # Map the names to actual packages, filtering out nulls from typos/absent attrs.
  mulletPackages = builtins.filter (p: p != null) (builtins.map resolvePkg pkgNames);
in
{
  options.ft.mullet = {
    enable = lib.mkEnableOption "imperative package management (the Mullet)" // {
      description = "Installs every package named in the newline-delimited file at `ft.mullet.sourcePath` into the system closure. Lets a consumer add or remove packages by editing a plain text file instead of editing Nix. Unresolved names are silently skipped.";
    };

    sourcePath = lib.mkOption {
      type = lib.types.path;
      default = ./mullet.txt;
      description = "Path to the flat newline-delimited text file tracking imperatively-managed package attribute names.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = mulletPackages;
  };
}
