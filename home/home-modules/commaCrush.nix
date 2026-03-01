{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The path you confirmed exists in your git repo
  crushConfigPath = "/home/joe/git/ft-home/home/dotfiles/crush";
in
{
  home.packages = [
    pkgs.nur.repos.charmbracelet.crush
  ];

  # This is the exact pattern that works for your nvim
  xdg.configFile."crush".source = config.lib.file.mkOutOfStoreSymlink crushConfigPath;

  # Force the parent directory to exist just in case
  home.activation.checkCrush = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    mkdir -p ${config.home.homeDirectory}/.config
  '';
}
