{ config, lib, ... }:

################################################################################
# PRINTING SERVICE MODULE
################################################################################

let
  cfg = config.ft.services.printing;
in
{
  options.ft.services.printing = {
    enable = lib.mkEnableOption "CUPS printing service" // {
      description = "Starts CUPS with a virtual PDF printer (CUPS-PDF) and Avahi for mDNS/Bonjour network printer discovery. Disable either sub-feature with `enableVirtualPdfPrinter` or `enableNetworkDiscovery`. Add hardware drivers via `extraDrivers`.";
    };

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
