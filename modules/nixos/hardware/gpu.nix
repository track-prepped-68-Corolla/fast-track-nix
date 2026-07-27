{
  config,
  lib,
  ...
}:

################################################################################
# UNIVERSAL GPU MODULE
# ------------------------------------------------------------------------------
# This module provides a consolidated and flexible configuration for various
# GPU setups, including NVIDIA (proprietary/open), AMD, and Intel integrated
# graphics, along with PRIME offloading for hybrid graphics systems.
# The goal is to offer a single, unified interface for GPU configuration.
#
# When ft.gpu.autodetect is true, vendor and Optimus/PRIME settings
# are derived from the facter.json pointed at by ft.facter.reportPath.
################################################################################

let
  cfg = config.ft.gpu;

  facterPath = config.ft.facter.reportPath;

  facter =
    if cfg.autodetect && facterPath != null && builtins.pathExists facterPath then
      builtins.fromJSON (builtins.readFile facterPath)
    else
      { };

  gpuCards = facter.hardware.graphics_card or [ ];

  # Per-card vendor predicates used for both single-GPU and Optimus detection.
  isNvidiaCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "nvidia" || d == "nouveau" || v == "10de";

  isAmdCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "amdgpu" || d == "radeon" || v == "1002";

  isIntelCard =
    c:
    let
      d = lib.toLower (c.driver or "");
      v = lib.toLower ((c.vendor or { }).hex or "");
    in
    d == "i915" || d == "xe" || v == "8086";

  nvidiaCards = builtins.filter isNvidiaCard gpuCards;
  igpuCards = builtins.filter (c: isAmdCard c || isIntelCard c) gpuCards;

  # Optimus: one NVIDIA dGPU alongside at least one AMD/Intel iGPU.
  isOptimus = cfg.autodetect && nvidiaCards != [ ] && igpuCards != [ ];

  optNvidiaCard = if nvidiaCards != [ ] then builtins.head nvidiaCards else { };
  optIgpuCard = if igpuCards != [ ] then builtins.head igpuCards else { };

  primaryGpu = if gpuCards != [ ] then builtins.head gpuCards else { };

  detectedVendor =
    if !cfg.autodetect then
      null
    else if isOptimus then
      "nvidia"
    else if isNvidiaCard primaryGpu then
      "nvidia"
    else if isAmdCard primaryGpu then
      "amd"
    else if isIntelCard primaryGpu then
      "intel"
    else
      null;

  effectiveVendor = if detectedVendor != null then detectedVendor else cfg.vendor;

  isNvidia = effectiveVendor == "nvidia";
  isAmd = effectiveVendor == "amd";
  isIntel = effectiveVendor == "intel";

  # Convert a facter sysfs_bus_id ("0000:c4:00.0") to PRIME format ("PCI:196:0:0").
  hexToInt =
    let
      digits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
    in
    hex: lib.foldl (acc: c: acc * 16 + digits.${c}) 0 (lib.stringToCharacters (lib.toLower hex));

  # Turing (0x1E00+) is the first NVIDIA architecture with open kernel module support.
  nvDeviceId = hexToInt (lib.toLower ((optNvidiaCard.device or { }).hex or "0"));
  nvidiaTuringOrNewer = cfg.autodetect && isNvidia && nvDeviceId >= 7680;
  effectiveOpenKernelModules = if nvidiaTuringOrNewer then true else cfg.nvidia.openKernelModules;

  sysfsIdToPrime =
    id:
    let
      parts = builtins.filter builtins.isString (builtins.split ":" id);
      devFunc = builtins.filter builtins.isString (builtins.split "[.]" (builtins.elemAt parts 2));
    in
    "PCI:${toString (hexToInt (builtins.elemAt parts 1))}:${toString (hexToInt (builtins.elemAt devFunc 0))}:${toString (hexToInt (builtins.elemAt devFunc 1))}";

  # Effective PRIME config: autodetected values fill in when bus IDs are not set manually.
  # Both sysfs_bus_id fields must be present and well-formed before autodetect enables
  # PRIME; an absent, empty, or malformed value would cause sysfsIdToPrime to crash on
  # an out-of-bounds elemAt when splitting the string.
  validSysfsId =
    id:
    builtins.isString id
    && builtins.match "[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-9a-fA-F]" id != null;
  optimusHasBusIds =
    optIgpuCard ? sysfs_bus_id
    && validSysfsId optIgpuCard.sysfs_bus_id
    && optNvidiaCard ? sysfs_bus_id
    && validSysfsId optNvidiaCard.sysfs_bus_id;
  effectivePrimeEnable = (isOptimus && optimusHasBusIds) || cfg.prime.enable;

  effectivePrimePrimaryBusId =
    if isOptimus && optimusHasBusIds && cfg.prime.primaryBusId == "" then
      sysfsIdToPrime optIgpuCard.sysfs_bus_id
    else
      cfg.prime.primaryBusId;

  effectivePrimeSecondaryBusId =
    if isOptimus && optimusHasBusIds && cfg.prime.secondaryBusId == "" then
      sysfsIdToPrime optNvidiaCard.sysfs_bus_id
    else
      cfg.prime.secondaryBusId;

  # In Optimus mode the iGPU type is taken from the detected card; in manual mode
  # it falls back to the main vendor (which the user would set to "amd"/"intel").
  effectivePrimeIsIgpuAmd = if isOptimus then isAmdCard optIgpuCard else isAmd;
  effectivePrimeIsIgpuIntel = if isOptimus then isIntelCard optIgpuCard else isIntel;
in
{
  options.ft.gpu = {
    enable = lib.mkEnableOption "universal GPU configuration" // {
      description = "Sets up graphics drivers for NVIDIA, AMD, or Intel GPUs. It can automatically detect which vendor you have and configure PRIME offloading for hybrid (Optimus) laptops with both an integrated and a discrete GPU.";
    };

    autodetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Detects the GPU vendor and Optimus setup from the hardware report at `ft.facter.reportPath`. When on, it fills in `ft.gpu.vendor` and configures PRIME offloading automatically for Optimus laptops; turn it off to set `vendor` and the `prime` options yourself.";
    };

    vendor = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
      ];
      default = "amd";
      description = "Which GPU vendor to configure for — `nvidia`, `amd`, or `intel`. Ignored when `autodetect` is on and a known GPU is found in the hardware report.";
    };

    enable32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Adds 32-bit graphics support, needed by some older games and applications.";
    };

    nvidia = {
      openKernelModules = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Uses NVIDIA's open-source kernel modules, which only work on Turing-generation GPUs and newer. When `autodetect` is on, this gets set automatically based on the detected GPU; turn `autodetect` off if you need to override it.";
      };
      driverPackage = lib.mkOption {
        type = lib.types.enum [
          "stable"
          "beta"
        ];
        default = "beta";
        description = "Which NVIDIA driver package to use — `stable` or `beta`.";
      };
      enableSettings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Installs the `nvidia-settings` graphical configuration tool.";
      };
      enablePowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Turns on NVIDIA's power management features.";
      };
      finegrainedPowerManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Turns on fine-grained power management (D3cold), which lets a laptop's discrete NVIDIA GPU power down almost completely when it's idle. This only takes effect while PRIME offloading is active, since NVIDIA's own module requires offloading to be on before it will allow fine-grained power management.";
      };
    };

    prime = {
      enable = lib.mkEnableOption "PRIME GPU offloading (for hybrid graphics)";

      primaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:35:0:0";
        description = "The bus ID of the GPU connected to the display — usually the integrated GPU. Filled in automatically from the hardware report when `autodetect` is on and an Optimus setup is detected; set it explicitly to override.";
      };

      secondaryBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:45:0:0";
        description = "The bus ID of the discrete GPU. Filled in automatically from the hardware report when `autodetect` is on and an Optimus setup is detected; set it explicitly to override.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hardware.graphics = {
          enable = lib.mkDefault true;
          enable32Bit = lib.mkDefault cfg.enable32Bit;
        };

        services.xserver.videoDrivers =
          lib.optional isNvidia "nvidia" ++ lib.optional isAmd "amdgpu" ++ lib.optional isIntel "intel";
      }

      # Attach the main user to the render/video groups — only when ft.users is
      # managing users, so we don't materialise the user just for GPU access.
      (lib.mkIf config.ft.users.enable {
        users.users.${config.ft.users.mainUser}.extraGroups = [
          "render"
          "video"
        ];
      })

      # --------------------------------------------------------------------------
      # NVIDIA Configuration
      # --------------------------------------------------------------------------
      (lib.mkIf isNvidia {
        hardware.nvidia = lib.mkMerge [
          {
            modesetting.enable = lib.mkDefault true;
            open = lib.mkDefault effectiveOpenKernelModules;
            nvidiaSettings = lib.mkDefault cfg.nvidia.enableSettings;
            powerManagement.enable = lib.mkDefault cfg.nvidia.enablePowerManagement;
            # Gated on PRIME: nixpkgs' nvidia module asserts that fine-grained
            # power management requires offloading, so applying it on a
            # single-dGPU system would fail evaluation.
            powerManagement.finegrained = lib.mkDefault (
              cfg.nvidia.finegrainedPowerManagement && effectivePrimeEnable
            );
            package = lib.mkDefault (
              if cfg.nvidia.driverPackage == "beta" then
                config.boot.kernelPackages.nvidiaPackages.beta
              else
                config.boot.kernelPackages.nvidiaPackages.stable
            );
          }
          # PRIME Offloading (for hybrid graphics)
          (lib.mkIf effectivePrimeEnable {
            # nixpkgs' nvidia module defines prime.offload.enable itself with
            # mkDefault (mirroring reverseSync), so a plain mkDefault here
            # collides at equal priority. mkOverride 990 sits just above that
            # while remaining overridable by any explicit consumer definition.
            prime.offload.enable = lib.mkOverride 990 true;
            prime.offload.enableOffloadCmd = lib.mkDefault true;
            prime.nvidiaBusId = lib.mkDefault effectivePrimeSecondaryBusId;
            prime.amdgpuBusId = lib.mkIf effectivePrimeIsIgpuAmd (lib.mkDefault effectivePrimePrimaryBusId);
            prime.intelBusId = lib.mkIf effectivePrimeIsIgpuIntel (lib.mkDefault effectivePrimePrimaryBusId);
          })
        ];
      })

      # --------------------------------------------------------------------------
      # AMD Specific Enhancements
      # --------------------------------------------------------------------------
      (lib.mkIf isAmd {
        hardware.amdgpu.opencl.enable = lib.mkDefault true;
      })

      # --------------------------------------------------------------------------
      # Cardwire — eBPF dGPU power control; enabled automatically when PRIME is
      # active so the desktop can block/unblock the discrete GPU device nodes.
      # --------------------------------------------------------------------------
      (lib.mkIf effectivePrimeEnable {
        ft.cardwire.enable = lib.mkDefault true;
      })
    ]
  );
}
