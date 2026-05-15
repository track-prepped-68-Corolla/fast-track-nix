{ lib, pkgs, config, inputs, ... }:

{
  options.ft = {
    repoPath = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Absolute path to the flake repo on disk. Set in hosts/<hostname>/default.nix; written to var/local by bootstrap.";
    };
  };

  config = {
    nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
    system.stateVersion = lib.mkDefault "24.11";
    environment.systemPackages = with pkgs; [
      git
      neovim
      curl
      wget
    ];
  };
}