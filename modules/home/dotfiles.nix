{ config, lib, ... }:

let
  prefixLen = builtins.stringLength config.ft.dotfiles.path + 1;
in
{
  options.ft.dotfiles.enable = lib.mkEnableOption "dotfiles symlinking" // {
    description = "Recursively symlinks every file under `ft.dotfiles.path` into Home Manager's home.file set using out-of-store symlinks, so dotfiles stay live-editable without a rebuild.";
  };

  config = lib.mkIf config.ft.dotfiles.enable {
    home.file = builtins.listToAttrs (
      map (
        file:
        let
          pathStr = toString file;
        in
        {
          name = builtins.substring prefixLen (builtins.stringLength pathStr) pathStr;
          value.source = config.lib.file.mkOutOfStoreSymlink pathStr;
        }
      ) (lib.filesystem.listFilesRecursive (/. + config.ft.dotfiles.path))
    );
  };
}
