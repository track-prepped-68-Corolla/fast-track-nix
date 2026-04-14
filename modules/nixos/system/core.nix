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
    # Set the value for the option we just declared above
    ft.flakeDir = "/home/joe/git/HM-refactor";

    # Global settings that apply to ALL hosts
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    
    system.stateVersion = "24.11"; 

    # Core packages needed on every machine
    environment.systemPackages = with pkgs; [ 
      git 
      neovim 
      curl 
      wget 
    ];
  };
}