{ lib, pkgs, config, ... }:

{
  options.ft = {
    flakeDir = lib.mkOption {
      type = lib.types.str;
      description = "The absolute path to the root of the dotfiles flake.";
    };
  };

  config = {
    ft.flakeDir = "/home/joe/git/nixos-config";

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "24.11";

    environment.systemPackages = with pkgs; [
      git
      neovim
      curl
      wget
    ];
  };
}
