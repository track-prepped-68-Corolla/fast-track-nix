{ config, lib, ... }:

let
  targetPath = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles";
  prefixLen = builtins.stringLength targetPath + 1;
in
{
  options.ft.dotfiles.enable = lib.mkEnableOption "dotfiles symlinking";

  config = lib.mkIf config.ft.dotfiles.enable {
    home.file = builtins.listToAttrs (map (file:
      let pathStr = toString file; in {
        name = builtins.substring prefixLen (builtins.stringLength pathStr) pathStr;
        value.source = config.lib.file.mkOutOfStoreSymlink pathStr;
      }
    ) (lib.filesystem.listFilesRecursive (/. + targetPath)));
  };
}
