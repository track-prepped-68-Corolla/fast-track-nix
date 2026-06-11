{ pkgs, lib, config, ... }:

################################################################################
# VENDOR HARDWARE MODULE
# ------------------------------------------------------------------------------
# Reads facter.json (via ft.facter.reportPath) and installs vendor-specific
# drivers, daemons, and tooling for detected hardware brands. Each brand can
# also be forced on or off via a nullable-bool override option.
#
# Detection sources:
#   Laptops (Lenovo Legion, MSI, ASUS) — SMBIOS/DMI manufacturer + product strings
#   Handhelds (Legion Go, GPD, Ayaneo)  — SMBIOS chassis type 11 or DMI strings
#   USB peripherals (Razer, Logitech, Corsair) — USB vendor ID in hardware.usb[]
#   OpenRGB — no autodetect; enable explicitly (universal, brand-agnostic)
################################################################################

let
  cfg = config.ft.vendorHw;

  facterPath = config.ft.facter.reportPath;

  facter =
    if cfg.autodetect && facterPath != null && builtins.pathExists facterPath then
      builtins.fromJSON (builtins.readFile facterPath)
    else
      { };

  # nixos-facter v2 puts DMI at the top level; v1 nests it under hardware.
  dmiRaw = facter.dmi or (facter.hardware or { }).dmi or { };
  dmiSystem = dmiRaw.system or { };
  dmiChassis = dmiRaw.chassis or { };

  dmiMfr = lib.toLower (dmiSystem.manufacturer or "");
  dmiFamily = lib.toLower (dmiSystem.family or "");
  dmiProduct = lib.toLower (dmiSystem.product_name or "");
  dmiVersion = lib.toLower (dmiSystem.version or "");

  # SMBIOS chassis type 11 = "Hand Held" per DMTF spec.
  chassisType = toString (dmiChassis.type or "");

  # USB device list for peripheral vendor detection.
  usbDevices = facter.hardware.usb or [ ];
  hasUsbVendor =
    vid: builtins.any (d: lib.toLower ((d.vendor or { }).hex or "") == vid) usbDevices;

  # Brand detection predicates ---------------------------------------------------

  detectLenovo =
    dmiMfr == "lenovo"
    && (
      lib.hasInfix "legion" dmiFamily
      || lib.hasInfix "legion" dmiProduct
      || lib.hasInfix "legion" dmiVersion
    );

  # Chassis type 11 catches any vendor's handheld; named DMI strings cover
  # devices that report a desktop chassis type despite being handhelds.
  detectHandheld =
    chassisType == "11"
    || lib.hasInfix "legion go" dmiFamily
    || lib.hasInfix "legion go" dmiProduct
    || lib.hasInfix "gpd" dmiMfr
    || lib.hasInfix "ayaneo" dmiMfr
    || lib.hasInfix "ayn" dmiMfr;

  detectRazer = hasUsbVendor "1532";
  detectLogitech = hasUsbVendor "046d";
  detectCorsair = hasUsbVendor "1b1c";

  detectMsi = lib.hasInfix "micro-star" dmiMfr || dmiMfr == "msi";

  detectAsus = lib.hasInfix "asus" dmiMfr;

  # Resolve effective bool: explicit override wins; null falls through to autodetect.
  resolve =
    override: detected:
    if override != null then override else (cfg.autodetect && detected);

  effLenovo = resolve cfg.lenovo detectLenovo;
  effRazer = resolve cfg.razer detectRazer;
  effMsi = resolve cfg.msi detectMsi;
  effLogitech = resolve cfg.logitech detectLogitech;
  effCorsair = resolve cfg.corsair detectCorsair;
  effOpenrgb = resolve cfg.openrgb false;
  effAsus = resolve cfg.asus detectAsus;
  effHandheld = resolve cfg.handheld detectHandheld;

in
{
  options.ft.vendorHw = {
    enable = lib.mkEnableOption "vendor-specific hardware software" // {
      description = "Installs and configures vendor-specific drivers, daemons, and tooling based on hardware detected in facter.json; covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices.";
    };

    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Read ft.facter.reportPath and enable matching vendor tooling automatically. Set to false to use only the per-brand override options below.";
    };

    lenovo = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for Lenovo Legion Linux (out-of-tree kernel driver and legiond daemon). Null uses autodetect via DMI manufacturer/family strings.";
    };

    razer = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for OpenRazer kernel driver/daemon and Polychromatic GUI. Null uses autodetect via USB vendor ID 1532.";
    };

    msi = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for the msi-ec kernel module (mainlined since Linux 5.16) and MControlCenter GUI. Null uses autodetect via DMI manufacturer string.";
    };

    logitech = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for Solaar (Unifying/Bolt receivers) and Piper/ratbagd (gaming mice/keyboards). Null uses autodetect via USB vendor ID 046d.";
    };

    corsair = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for ckb-next Corsair keyboard/mouse driver and GUI. Null uses autodetect via USB vendor ID 1b1c.";
    };

    openrgb = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable OpenRGB universal RGB lighting daemon and the i2c-dev kernel module it requires. No facter autodetect — set true to enable explicitly.";
    };

    asus = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for asusctl (asusd daemon, fan curves, AuraSync) for ASUS ROG/TUF laptops. Null uses autodetect via DMI manufacturer string.";
    };

    handheld = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override autodetect for InputPlumber (OGC input remapping framework) and PowerStation (TDP and power-profile control) for handheld gaming devices (Legion Go, GPD, Ayaneo, AYN). Null uses autodetect via SMBIOS chassis type 11 or known DMI manufacturer strings.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      # -------------------------------------------------------------------------
      # Lenovo Legion Linux — out-of-tree kernel driver + userspace daemon/GUI.
      # -------------------------------------------------------------------------
      (lib.mkIf effLenovo {
        boot.extraModulePackages = [ config.boot.kernelPackages.lenovoLegionLinux ];
        environment.systemPackages = [ pkgs.lenovoLegionLinux ];
        services.udev.packages = [ pkgs.lenovoLegionLinux ];
      })

      # -------------------------------------------------------------------------
      # Razer — OpenRazer kernel driver/daemon + Polychromatic GUI.
      # -------------------------------------------------------------------------
      (lib.mkIf effRazer {
        hardware.openrazer.enable = lib.mkDefault true;
        hardware.openrazer.users = lib.optional config.ft.users.enable config.ft.users.mainUser;
        environment.systemPackages = [ pkgs.polychromatic ];
      })

      # -------------------------------------------------------------------------
      # MSI — msi-ec is mainlined (Linux ≥ 5.16); MControlCenter wraps EC access.
      # -------------------------------------------------------------------------
      (lib.mkIf effMsi {
        boot.kernelModules = [ "msi-ec" ];
        environment.systemPackages = [ pkgs.mcontrolcenter ];
      })

      # -------------------------------------------------------------------------
      # Logitech — Solaar manages Unifying/Bolt receivers; Piper/ratbagd covers
      # gaming-grade mice and keyboards via the libratbag protocol.
      # -------------------------------------------------------------------------
      (lib.mkIf effLogitech {
        services.ratbagd.enable = lib.mkDefault true;
        environment.systemPackages = with pkgs; [
          solaar
          piper
        ];
      })

      # -------------------------------------------------------------------------
      # Corsair — ckb-next provides a daemon and GUI for keyboards/mice.
      # -------------------------------------------------------------------------
      (lib.mkIf effCorsair {
        hardware.ckb-next.enable = lib.mkDefault true;
      })

      # -------------------------------------------------------------------------
      # OpenRGB — universal RGB lighting daemon; i2c-dev exposes SMBus devices.
      # -------------------------------------------------------------------------
      (lib.mkIf effOpenrgb {
        services.hardware.openrgb.enable = lib.mkDefault true;
        boot.kernelModules = [ "i2c-dev" ];
      })

      # -------------------------------------------------------------------------
      # ASUS ROG/TUF — asusctl handles fan curves, AuraSync RGB, and platform
      # profiles. dGPU switching is handled by ft.cardwire, which gpu.nix
      # enables automatically when PRIME offloading is active.
      # -------------------------------------------------------------------------
      (lib.mkIf effAsus {
        services.asusd.enable = lib.mkDefault true;
        environment.systemPackages = [ pkgs.asusctl ];
      })

      # -------------------------------------------------------------------------
      # Handheld gaming devices — InputPlumber remaps physical inputs to standard
      # gamepad events; PowerStation controls TDP and power profiles.
      # -------------------------------------------------------------------------
      (lib.mkIf effHandheld {
        services.inputplumber.enable = lib.mkDefault true;
        services.powerstation.enable = lib.mkDefault true;
      })

    ]
  );
}
