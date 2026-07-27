{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.ft.cardwire;
in
{
  imports = [ inputs.cardwire.nixosModules.default ];

  options.ft.cardwire = {
    enable = lib.mkEnableOption "Cardwire GPU manager" // {
      description = "Turns on the cardwired service, which can block or unblock GPU device nodes so you can switch between integrated, hybrid, or manual GPU power modes. It works by hooking into the kernel with eBPF, so it needs a kernel built with `CONFIG_BPF_LSM=y` and `lsm=...,bpf` added to the boot parameters.";
    };

    autoApplyGpuState = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When the cardwired service starts, automatically restore whichever GPU state was last saved.";
    };

    experimentalNvidiaBlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Turns on experimental support for blocking NVIDIA-specific device files. This switches on automatically whenever `ft.gpu` is active with the NVIDIA driver.";
    };

    batteryAutoSwitch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Switch to the integrated GPU automatically whenever the machine is running on battery.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cardwire = {
      enable = lib.mkDefault true;
      settings = {
        auto_apply_gpu_state = lib.mkDefault cfg.autoApplyGpuState;
        experimental_nvidia_block = lib.mkDefault (
          cfg.experimentalNvidiaBlock || builtins.elem "nvidia" config.services.xserver.videoDrivers
        );
        battery_auto_switch = lib.mkDefault cfg.batteryAutoSwitch;
      };
    };
  };
}
