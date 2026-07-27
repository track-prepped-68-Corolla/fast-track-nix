{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# VENDOR HARDWARE MODULE
# ------------------------------------------------------------------------------
# Reads facter.json (via ft.facter.reportPath) and installs vendor-specific
# drivers, daemons, and tooling for detected hardware brands. Each brand can
# also be forced on or off via a nullable-bool override option.
#
# Detection sources:
#   Laptops (Lenovo Legion, MSI, ASUS) — SMBIOS manufacturer + product strings
#   Handhelds (Legion Go, GPD, Ayaneo)  — SMBIOS chassis type 11 or product strings
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

  # nixos-facter serialises SMBIOS data under the top-level "smbios" key.
  # smbios.system is a single object; smbios.chassis is an array — take the
  # first entry, or an empty attrset if the array is absent.
  smbiosSystem = (facter.smbios or { }).system or { };
  smbiosChassisList = (facter.smbios or { }).chassis or [ ];
  smbiosChassis = if smbiosChassisList != [ ] then builtins.head smbiosChassisList else { };

  dmiMfr = lib.toLower (smbiosSystem.manufacturer or "");
  dmiProduct = lib.toLower (smbiosSystem.product or "");
  dmiVersion = lib.toLower (smbiosSystem.version or "");

  # SMBIOS chassis type 11 = "Hand Held" per DMTF spec.
  # chassis_type.value is the integer from the SMBIOS record.
  chassisType = toString ((smbiosChassis.chassis_type or { }).value or "");

  # USB device list for peripheral vendor detection.
  usbDevices = facter.hardware.usb or [ ];
  hasUsbVendor = vid: builtins.any (d: lib.toLower ((d.vendor or { }).hex or "") == vid) usbDevices;

  # Brand detection predicates ---------------------------------------------------

  detectLenovo =
    dmiMfr == "lenovo" && (lib.hasInfix "legion" dmiProduct || lib.hasInfix "legion" dmiVersion);

  # Chassis type 11 catches any vendor's handheld; named product strings cover
  # devices that report a non-handheld chassis type despite being handhelds.
  detectHandheld =
    chassisType == "11"
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
  resolve = override: detected: if override != null then override else (cfg.autodetect && detected);

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
      description = "Installs and configures the right drivers, background services, and tools for whichever hardware brand is detected in the hardware report. Covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices.";
    };

    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reads the hardware report at `ft.facter.reportPath` and turns on matching vendor tooling automatically. Turn this off to rely only on the per-brand override options below.";
    };

    lenovo = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for Lenovo Legion Linux support (an out-of-tree kernel driver plus the `legiond` daemon). Leave as `null` to detect this automatically from the machine's manufacturer and family information.";
    };

    razer = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for OpenRazer support (kernel driver, daemon, and the Polychromatic GUI). Leave as `null` to detect this automatically from USB vendor ID `1532`.";
    };

    msi = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for the `msi-ec` kernel module (part of the mainline kernel since Linux 5.16) and the MControlCenter GUI. Leave as `null` to detect this automatically from the machine's manufacturer information.";
    };

    logitech = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for Solaar (for Unifying/Bolt receivers) and Piper/ratbagd (for gaming mice and keyboards). Leave as `null` to detect this automatically from USB vendor ID `046d`.";
    };

    corsair = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for ckb-next, the driver and GUI for Corsair keyboards and mice. Leave as `null` to detect this automatically from USB vendor ID `1b1c`.";
    };

    openrgb = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Turns on OpenRGB, a vendor-agnostic RGB lighting daemon, along with the `i2c-dev` kernel module it needs. There's no autodetection for this one — set it to `true` explicitly to enable it.";
    };

    asus = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for asusctl (the `asusd` daemon, fan curve control, and AuraSync) on ASUS ROG/TUF laptops. Leave as `null` to detect this automatically from the machine's manufacturer information.";
    };

    handheld = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Overrides autodetection for InputPlumber (which remaps controls into standard gamepad input) and PowerStation (which controls TDP and power profiles), for handheld gaming devices like the Legion Go, GPD, Ayaneo, and AYN. Leave as `null` to detect this automatically from the chassis type or known manufacturer information reported by the hardware.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      # -------------------------------------------------------------------------
      # Lenovo Legion Linux — out-of-tree kernel driver + userspace daemon/GUI.
      # -------------------------------------------------------------------------
      (lib.mkIf effLenovo {
        boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
        environment.systemPackages = [ pkgs.lenovo-legion ];
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
