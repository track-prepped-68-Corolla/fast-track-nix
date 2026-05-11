{ config, lib, ... }:

let
  prefixLen = builtins.stringLength config.ft.dotfiles.path + 1;
in
{
  options.ft.dotfiles.enable = lib.mkEnableOption "dotfiles symlinking";

  config = lib.mkIf config.ft.dotfiles.enable {
    home.file = builtins.listToAttrs (map (file:
      let pathStr = toString file; in {
        name = builtins.substring prefixLen (builtins.stringLength pathStr) pathStr;
        value.source = config.lib.file.mkOutOfStoreSymlink pathStr;
      }
    ) (lib.filesystem.listFilesRecursive (/. + config.ft.dotfiles.path)));
  };
}
