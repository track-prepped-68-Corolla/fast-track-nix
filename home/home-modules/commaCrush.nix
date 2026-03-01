{
  config,
  lib,
  pkgs,
  ...
}:

let

  dotfilePath = "/home/joe/git/ft-home/home/dotfiles/crush/crush.json";
in
{
  home.packages = [
    pkgs.nur.repos.charmbracelet.crush
  ];

  xdg.configFile."crush/crush.json".source = config.lib.file.mkOutOfStoreSymlink dotfilePath;
}
