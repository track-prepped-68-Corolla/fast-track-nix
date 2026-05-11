{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.nvidia;
in
{
  options.ft.nvidia = {
    enable = lib.mkEnableOption "Nvidia proprietary drivers (Open Beta)";

    prime = {
      enable = lib.mkEnableOption "Prime Offloading (Hybrid Graphics)";

      primaryGpuVendor = lib.mkOption {
        type = lib.types.enum [
          "amd"
          "intel"
        ];
        default = "amd";
        description = "The vendor of the GPU connected to your display (usually the iGPU).";
      };

      primaryBusId = lib.mkOption {
        type = lib.types.str;
        example = "PCI:35:0:0";
        description = "Bus ID of the GPU connected to the display (Run 'lspci' to find this).";
      };

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        example = "PCI:45:0:0";
        description = "Bus ID of the discrete Nvidia GPU.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      nvidiaSettings = true;

      powerManagement = {
        enable = false;
        finegrained = true;
      };
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia.prime = lib.mkIf cfg.prime.enable {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      nvidiaBusId = cfg.prime.nvidiaBusId;
      amdgpuBusId = lib.mkIf (cfg.prime.primaryGpuVendor == "amd") cfg.prime.primaryBusId;
      intelBusId  = lib.mkIf (cfg.prime.primaryGpuVendor == "intel") cfg.prime.primaryBusId;
    };
  };
}
