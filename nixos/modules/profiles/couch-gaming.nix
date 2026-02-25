{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.couch-gaming;
in
{
  # ============================================================================
  # OPTION DEFINITIONS
  # ============================================================================
  options.ft.couch-gaming = {
    enable = lib.mkEnableOption "Jovian NixOS (Steam Deck UI Experience)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "The username that should automatically log in to Steam.";
    };

    desktop = lib.mkOption {
      type = lib.types.str;
      default = "gnome";
      description = "The desktop environment to launch in Desktop Mode (e.g., 'gnome', 'plasma').";
    };

    gpuVendor = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "intel"
        "nvidia"
      ];
      default = "amd";
      description = "The vendor of the GPU driving the display (affects kernel optimizations).";
    };
  };

  # ============================================================================
  # IMPLEMENTATION
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # --------------------------------------------------------------------------
    # 1. Jovian Core Configuration
    # --------------------------------------------------------------------------
    jovian.steam = {
      enable = true;

      # AUTO START
      # Bypasses the login manager and boots directly into Steam Big Picture.
      autoStart = true;

      # USER CONFIGURATION
      # Dynamically sets the user and desktop environment based on your options.
      user = cfg.user;
      desktopSession = cfg.desktop;
    };

    # --------------------------------------------------------------------------
    # 2. Decky Loader
    # --------------------------------------------------------------------------
    # Enables the homebrew plugin loader for Steam Deck.
    jovian.decky-loader.enable = true;

    # --------------------------------------------------------------------------
    # 3. Hardware Optimization Logic
    # --------------------------------------------------------------------------
    # Jovian provides specific kernel parameters and Mesa optimizations
    # for AMD hardware to match the Steam Deck's performance profile.

    # Enable AMD optimizations ONLY if the vendor is set to 'amd'
    jovian.hardware.has.amd.gpu = (cfg.gpuVendor == "amd");

    # (Future-proofing: If Jovian adds specific flags for Intel/Nvidia,
    # we can add the logic here easily using 'cfg.gpuVendor')
  };
}
