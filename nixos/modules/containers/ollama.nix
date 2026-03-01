{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.ft.containers.ollama;
in
{
  options.ft.containers.ollama = {
    enable = mkEnableOption "Ollama OCI Max-VRAM (Strix Halo Optimized)";
  };

  config = mkIf cfg.enable {
    # 1. Kernel Overrides - Massive GTT for Strix Halo
    boot.kernelParams = [
      "amdgpu.gttsize=120000"
      "ttm.pages_limit=31457280"
      "amd_iommu=off"
    ];

    # 2. Graphics Stack - Cleaned of deprecated 'amdvlk' and 'mesa.drivers'
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        mesa # Replaces mesa.drivers
        vulkan-loader
        # amdvlk is gone; RADV is built into mesa/vulkan-loader
      ];
    };

    systemd.tmpfiles.rules = [ "d /opt/ollama 0775 root root -" ];

    # 3. The OCI Container
    virtualisation.oci-containers.containers."ollama" = {
      image = "docker.io/ollama/ollama:latest";
      ports = [ "11434:11434" ];
      volumes = [
        "/opt/ollama:/root/.ollama"
        "/dev/dri:/dev/dri"
      ];

      environment = {
        "OLLAMA_LLM_LIBRARY" = "vulkan";
        "OLLAMA_VRAM_OVERRIDE" = "120000";
        "OLLAMA_HOST" = "0.0.0.0:11434";
      };

      extraOptions = [
        "--device=/dev/dri:/dev/dri"
        "--security-opt=label=disable"
        "--shm-size=16gb"
      ];
    };

    networking.firewall.allowedTCPPorts = [ 11434 ];
  };
}
