{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The path to your actual config file inside your monorepo.
  # Using an absolute string is required for flakes to avoid read-only store copies.
  dotfilePath = "${config.home.homeDirectory}/ft-home/home/dotfiles/config/crush/crush.json";
in
{
  home.packages = [
    # Most up-to-date source for Crush on Nix is currently via NUR
    # or the numtide/nix-ai-tools flake.
    pkgs.nur.repos.charmbracelet.crush
  ];

  # The 'magic' part: symlinking your mutable config file
  xdg.configFile."crush/crush.json".source = config.lib.file.mkOutOfStoreSymlink dotfilePath;

  # Optional: Symlink your custom 'skills' directory if you have one
  # xdg.configFile."crush/skills".source =
  #   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/ft-home/home/dotfiles/config/crush/skills";
}
