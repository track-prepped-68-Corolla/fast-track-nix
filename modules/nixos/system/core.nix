{ lib, pkgs, config, ... }:

{
  # --- 1. DECLARE THE OPTION HERE ---
  options.ft = {
    flakeDir = lib.mkOption {
      type = lib.types.str;
      description = "The absolute path to the root of the dotfiles flake.";
    };
  };

  # --- 2. SET THE VALUES HERE ---
  config = {
    ft.flakeDir = "/home/joe/git/nixos-config";

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSPs4="
    ];

    system.stateVersion = "24.11";

    environment.systemPackages = with pkgs; [
      git
      neovim
      curl
      wget
    ];
  };
}
