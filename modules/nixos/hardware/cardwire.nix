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
      description = "Enables the cardwired D-Bus service, which uses eBPF LSM hooks to block and unblock GPU device nodes for integrated/hybrid/manual GPU power control. Requires a kernel with CONFIG_BPF_LSM=y and lsm=...,bpf in boot parameters.";
    };

    autoApplyGpuState = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically restore the last saved GPU state when the cardwired service starts.";
    };

    experimentalNvidiaBlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable experimental blocking of NVIDIA-specific device files. Enabled automatically when ft.gpu is active with the NVIDIA driver.";
    };

    batteryAutoSwitch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically switch to integrated GPU mode when running on battery power.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cardwire = {
      enable = lib.mkDefault true;
      settings = {
        auto_apply_gpu_state = lib.mkDefault cfg.autoApplyGpuState;
        experimental_nvidia_block = lib.mkDefault (
          cfg.experimentalNvidiaBlock
          || builtins.elem "nvidia" config.services.xserver.videoDrivers
        );
        battery_auto_switch = lib.mkDefault cfg.batteryAutoSwitch;
      };
    };
  };
}
