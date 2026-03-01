{
  config,
  lib,
  pkgs,
  ...
}:

let
  # No interpolation, pure string.
  crushConfigPath = "/home/joe/git/ft-home/home/dotfiles/crush";
in
{
  home.packages = [ pkgs.nur.repos.charmbracelet.crush ];

  # Pattern: Link the folder, exactly like your nvim setup
  xdg.configFile."crush".source = config.lib.file.mkOutOfStoreSymlink crushConfigPath;
}
