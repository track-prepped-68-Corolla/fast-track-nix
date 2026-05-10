{ config, lib, ... }:

let
  prefixLen = builtins.stringLength config.ft.dotfiles.path + 1;
in
{
  options.ft.dotfiles = {
    enable = lib.mkEnableOption "dotfiles symlinking";

    path = lib.mkOption {
      type = lib.types.str;
      default = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles";
      description = "Absolute path to this user's dotfiles directory.";
    };
  };

  config = lib.mkIf config.ft.dotfiles.enable {
    home.file = builtins.listToAttrs (map (file:
      let pathStr = toString file; in {
        name = builtins.substring prefixLen (builtins.stringLength pathStr) pathStr;
        value.source = config.lib.file.mkOutOfStoreSymlink pathStr;
      }
    ) (lib.filesystem.listFilesRecursive (/. + config.ft.dotfiles.path)));
  };
}
