{ config, lib, pkgs, ... }:

################################################################################
# COMPFYUI CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module provides a robust setup for running ComfyUI, a powerful and modular
# stable diffusion GUI, within a Podman container. It supports both native ROCm
# and a more general Ubuntu-based setup with custom startup scripts for flexibility.
################################################################################

let
  cfg = config.ft.containers.comfyui;

  # Base directory for ComfyUI data on the host. This will persist configurations,
  # models, custom nodes, and outputs across container restarts.
  dataDir = "/var/lib/comfyui";

  # Script for the Ubuntu-based ComfyUI container. This handles dependencies,
  # cloning ComfyUI, and launching the application with specific flags.
  startScript = pkgs.writeScript "comfyui-start.sh" ''
    #!/bin/bash
    set -e

    WORK_DIR="/opt/ComfyUI"
    VENV_DIR="$WORK_DIR/venv"
    BACKUP_DIR="/tmp/comfy_backup"
    MANAGER_DIR="$WORK_DIR/custom_nodes/ComfyUI-Manager"

    echo "--- Starting ComfyUI (Ubuntu Base) ---"

    # 1. Install System Dependencies
    # These are common dependencies required for Python environments and ComfyUI.
    apt-get update
    apt-get install -y git wget python3 python3-pip python3-venv \
                       libgl1 libglib2.0-0 \
                       libzstd1 libbz2-1.0 liblzma5 \
                       libsqlite3-0 libncurses6 libffi8 \
                       libsuitesparse-dev

    cd $WORK_DIR

    # 2. Smart Clone (ComfyUI Core)
    # This section checks if ComfyUI is already cloned and handles updates.
    if [ ! -f "main.py" ]; then
        echo "ComfyUI not found. Cloning..."
        rm -rf ./* .git
        git clone https://github.com/comfyanonymous/ComfyUI .
    fi

    # 2.5 Install/Update ComfyUI Manager (Auto-Install)
    # The ComfyUI Manager is a crucial component for easily adding custom nodes.
    if [ ! -d "$MANAGER_DIR" ]; then
        echo "ComfyUI Manager not found. Installing..."
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
    else
        echo "Updating ComfyUI Manager..."
        cd "$MANAGER_DIR" && git pull && cd "$WORK_DIR"
    fi

    # 3. Python Environment Setup
    # Creates and activates a persistent Python virtual environment.
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating persistent venv..."
        python3 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate

        echo "Installing pip dependencies..."
        pip install --upgrade pip
        pip install -r requirements.txt --no-warn-script-location
    else
        source $VENV_DIR/bin/activate
    fi

    # 4. REPAIR DEPENDENCIES
    # Ensures all required Python packages are installed.
    echo "Checking for missing python packages..."
    pip install sqlalchemy spandrel opencv-python --no-warn-script-location

    # Check Manager requirements too
    if [ -f "$MANAGER_DIR/requirements.txt" ]; then
        echo "Installing ComfyUI Manager requirements..."
        pip install -r "$MANAGER_DIR/requirements.txt" --no-warn-script-location
    fi

    # 5. Launch
    echo "Launching ComfyUI..."
    # Add any specific launch flags here, e.g., for performance or features.
    python3 main.py --listen 0.0.0.0 --use-flash-attention --port ${toString cfg.port}
  '';

  # Script for the ROCm-specific ComfyUI container.
  # This leverages the pre-built ROCm PyTorch image for optimal performance on AMD GPUs.
  startRocmScript = pkgs.writeScript "comfyui-rocm-start.sh" ''
    #!/bin/bash
    set -e

    WORK_DIR="/workspace"
    MANAGER_DIR="$WORK_DIR/custom_nodes/ComfyUI-Manager"

    echo "--- Starting ComfyUI ROCm ---"

    cd $WORK_DIR

    # 1. Source the existing virtual environment in the ROCm image
    # This provides access to pip and the correct torch version
    source /opt/venv/bin/activate

    # 2. Install ComfyUI if missing
    if [ ! -d ".git" ]; then
      echo "--- Bootstrapping ComfyUI ---"
      git clone https://github.com/comfyanonymous/ComfyUI.git .
    fi

    # 2.5 Install/Update ComfyUI Manager
    if [ ! -d "$MANAGER_DIR" ]; then
        echo "ComfyUI Manager not found. Installing..."
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
    else
        echo "Updating ComfyUI Manager..."
        cd "$MANAGER_DIR" && git pull && cd "$WORK_DIR"
    fi

    # 3. Install critical Manager dependencies and ComfyUI requirements
    echo "--- Fixing Dependencies ---"
    pip install --no-cache-dir -r requirements.txt
    pip install --no-cache-dir gitpython

    # 4. Launch ComfyUI using the venv's python
    echo "--- Starting ComfyUI on ROCm ---"
    export PYTORCH_TUNABLEOP_ENABLED=1 
    export MIOPEN_FIND_MODE=FAST 
    export ROCBLAS_USE_HIPBLASLT=0
    python main.py --listen 0.0.0.0 --port ${toString cfg.port} --use-flash-attention
  '';

in
{
  options.ft.containers.comfyui = {
    enable = lib.mkEnableOption "ComfyUI Container";

    # Type of GPU backend to use: "rocm" for AMD GPUs, "ubuntu" for a generic setup.
    gpuBackend = lib.mkOption {
      type = lib.types.enum [ "rocm" "ubuntu" ];
      default = "ubuntu";
      description = "Choose 'rocm' for AMD GPUs (like Strix Halo) or 'ubuntu' for generic/CPU.";
    };

    # Listening port for the ComfyUI web interface.
    port = lib.mkOption {
      type = lib.types.port;
      default = 8188;
      description = "Port for the ComfyUI web interface.";
    };

    # HSA_OVERRIDE_GFX_VERSION for ROCm backend (e.g., "11.5.1" for Strix Halo).
    # Only applicable when `gpuBackend` is "rocm".
    rocmGfxVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HSA_OVERRIDE_GFX_VERSION for ROCm (e.g., 11.5.1). Only for 'rocm' backend.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0775 root users -"
    ];

    virtualisation.oci-containers.containers.comfyui = lib.mkIf (cfg.gpuBackend == "ubuntu") {
      image = "ubuntu:24.04"; # A general-purpose Ubuntu image
      autoStart = true;
      ports = [ "${toString cfg.port}:8188" ];
      volumes = [
        "${dataDir}:/opt/ComfyUI"
        "${startScript}:/start.sh"
      ];
      cmd = [
        "/bin/bash"
        "/start.sh"
      ];
      extraOptions = [
        "--cap-add=SYS_PTRACE"
        "--security-opt=seccomp=unconfined"
        "--ipc=host"
      ];
    } // lib.mkIf (cfg.gpuBackend == "rocm") {
      image = "docker.io/rocm/pytorch:latest"; # ROCm optimized PyTorch image
      autoStart = true;
      ports = [ "${toString cfg.port}:8188" ];
      volumes = [
        "${dataDir}:/workspace"
        "${startRocmScript}:/start.sh"
      ];
      cmd = [
        "/bin/bash"
        "/start.sh"
      ];
      environment = lib.mkIf (cfg.rocmGfxVersion != null) {
        HSA_OVERRIDE_GFX_VERSION = cfg.rocmGfxVersion;
      } // {};
      extraOptions = [
        "--device=/dev/kfd"
        "--device=/dev/dri"
        "--group-add=video"
        "--group-add=render"
        "--ipc=host"
        "--security-opt=seccomp=unconfined"
        "--cap-add=SYS_PTRACE"
      ];
    };
  };
}
