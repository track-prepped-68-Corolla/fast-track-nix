{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Using your confirmed working pattern
  crushConfigPath = "/home/joe/git/ft-home/home/dotfiles/crush";
in
{
  home.packages = [
    pkgs.nur.repos.charmbracelet.crush
  ];

  # Symlink the entire directory
  xdg.configFile."crush".source = config.lib.file.mkOutOfStoreSymlink crushConfigPath;
}
