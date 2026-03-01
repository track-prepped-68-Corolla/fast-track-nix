{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The nvim-style pattern, but using the home variable to break Flake shadowing
  crushConfigPath = "${config.home.homeDirectory}/git/ft-home/home/dotfiles/crush";
in
{
  home.packages = [
    pkgs.nur.repos.charmbracelet.crush
  ];

  # Force the directory symlink
  xdg.configFile."crush".source = config.lib.file.mkOutOfStoreSymlink crushConfigPath;
}
