{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # --- Imports ---
  imports = [
    #inputs.sops-nix.homeManagerModules.sops
    ../../home-modules
  ];

  # --- User Information ---
  home.username = "joe";
  
  # 2. Your configuration block
#  sops = {
#    age.keyFile = "/home/joe/.config/sops/age/keys.txt";
#    defaultSopsFile = ../../../secrets.yaml; # Verify this path relative to this .nix file!
#    defaultSopsFormat = "yaml";

#    secrets = {
#    };
#  };

  # --- Configuration Files ---
  # Distrobox configuration
#  xdg.configFile."distrobox/distrobox.conf".text = ''
    # Mount the Nix Store so your host's CLI tools work inside the container
#    container_additional_volumes="/nix/store:/nix/store:ro /etc/profiles/per-user:/etc/profiles/per-user:ro"
#  '';

# --- Module Toggles ---
  # Turn on the LazyVim environment
  ft.lazyvim.enable = true;

  # --- Environment Variables ---
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # --- Packages ---
  home.packages = with pkgs; [

    # SYSTEM / CLI TOOLS
    fastfetch
    htop
    micro
    yazi
    

    # DESKTOP APPS
    brave
    kitty
    signal-desktop
    slack
    localsend

    # DEVELOPMENT
    github-desktop
    vscodium
    direnv
    nixfmt

    # CREATIVE & OFFICE
    krita
    openscad
    freecad
    blender
    libreoffice

    # GAMING
    mangohud
    heroic
    lutris
    discord
  ];
}
