{
  config,
  lib,
  pkgs,
  ...
}:

let

  crushConfig = "${config.home.homeDirectory}/git/ft-home/home/dotfiles/crush/crush.json";
in
{
  home.packages = [
    pkgs.nur.repos.charmbracelet.crush
  ];

  xdg.configFile."crush/crush.json".source = config.lib.file.mkOutOfStoreSymlink crushConfig;
}
