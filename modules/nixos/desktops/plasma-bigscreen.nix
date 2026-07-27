{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# PLASMA BIGSCREEN TV SHELL MODULE
################################################################################

let
  cfg = config.ft.plasmaBigscreen;
  inherit (pkgs.kdePackages.plasma) plasma-bigscreen;
in
{
  options.ft.plasmaBigscreen = {
    enable = lib.mkEnableOption "Plasma Bigscreen TV shell" // {
      description = "Installs Plasma Bigscreen, a TV-friendly interface, and registers its Wayland session so it can be selected as a login option. This module is exempt from the VM smoke test requirement, since it pulls in `qtwebengine` and the full KDE Frameworks stack (which depend on the binary cache) and its main input method, HDMI-CEC, can't be tested inside a VM (it depends on real hardware).";
    };

    cecSupport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Loads the `cec` kernel module and installs `libcec` and `v4l-utils`, so a TV remote can control Plasma Bigscreen over HDMI-CEC.";
    };

    defaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Makes the Plasma Bigscreen session the default one SDDM starts (including for autologin), instead of just offering it as one option alongside whatever other sessions are configured.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager = {
      sddm = {
        enable = lib.mkDefault true;
        wayland.enable = lib.mkDefault true;
      };
      sessionPackages = [ plasma-bigscreen ];
      # Plain value, not mkDefault: nixpkgs' plasma6 module already sets this
      # via mkDefault "plasma", and two mkDefault definitions at equal
      # priority conflict rather than one winning. This only fires when the
      # consumer explicitly opts in via cfg.defaultSession, so it behaves as
      # a consumer-directed override rather than a hardcoded opinion.
      defaultSession = lib.mkIf cfg.defaultSession "plasma-bigscreen-wayland";
    };

    xdg.portal.configPackages = [ plasma-bigscreen ];

    boot.kernelModules = lib.optional cfg.cecSupport "cec";

    environment.systemPackages = [
      plasma-bigscreen
    ]
    ++ lib.optionals cfg.cecSupport [
      pkgs.libcec
      pkgs.v4l-utils
    ];
  };
}
