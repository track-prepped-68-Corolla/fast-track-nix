{ config, lib, ... }:

################################################################################
# PRINTING SERVICE MODULE
################################################################################

let
  cfg = config.ft.printing;
in
{
  options.ft.printing = {
    enable = lib.mkEnableOption "CUPS printing service" // {
      description = "Starts CUPS along with a virtual PDF printer (CUPS-PDF) and Avahi for finding network printers via mDNS/Bonjour. Turn either piece off with `enableVirtualPdfPrinter` or `enableNetworkDiscovery`, and add hardware drivers via `extraDrivers`.";
    };

    enableVirtualPdfPrinter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Adds a virtual CUPS-PDF printer you can \"print\" to in order to save a PDF.";
    };

    extraDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = "[ pkgs.gutenprint pkgs.hplip ]";
      description = "Additional printer driver packages to install.";
    };

    enableNetworkDiscovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Uses Avahi to automatically discover network printers via mDNS/Bonjour.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      printing = {
        enable = true;
        cups-pdf.enable = cfg.enableVirtualPdfPrinter;
        drivers = cfg.extraDrivers;
      };

      avahi = lib.mkIf cfg.enableNetworkDiscovery {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      udev.extraRules = ''
        TAG=="systemd", ENV{SYSTEMD_ALIAS}+="/dev/lp0"
      '';
    };
  };
}
