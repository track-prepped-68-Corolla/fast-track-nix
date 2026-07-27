{ config, lib, ... }:

let
  prefixLen = builtins.stringLength config.ft.dotfiles.path + 1;
in
{
  options.ft.dotfiles.enable = lib.mkEnableOption "dotfiles symlinking" // {
    description = "Symlinks every file under `ft.dotfiles.path` into place, recursively. It uses out-of-store symlinks, so you can edit your dotfiles directly and see the changes immediately, without rebuilding.";
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
