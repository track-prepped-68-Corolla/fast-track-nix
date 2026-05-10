{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# PRINTING SERVICE MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the Common Unix Printing System (CUPS),
# providing a robust and network-aware printing solution for NixOS. It includes
# support for a virtual PDF printer, common printer drivers, and Avahi for
# network printer discovery.
################################################################################

let
  cfg = config.ft.services.printing;
in
{
  options.ft.services.printing = {
    enable = lib.mkEnableOption "CUPS printing service";

    enableVirtualPdfPrinter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable CUPS-PDF virtual printer.";
    };

    extraDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = "[ pkgs.gutenprint pkgs.hplip ]";
      description = "List of additional printer driver packages.";
    };

    enableNetworkDiscovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Avahi for network printer discovery (mDNS/Bonjour).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      cups-pdf.enable = cfg.enableVirtualPdfPrinter;
      drivers = cfg.extraDrivers;
    };

    services.avahi = lib.mkIf cfg.enableNetworkDiscovery {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.udev.extraRules = ''
      TAG=="systemd", ENV{SYSTEMD_ALIAS}+="/dev/lp0"
    '';
  };
}
