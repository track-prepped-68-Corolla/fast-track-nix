{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# AI CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module provides a flexible setup for running AI models and their frontends
# using Podman containers. It supports a backend (e.g., llama.cpp) and an
# optional frontend (e.g., OpenWebUI) with customizable models and settings.
################################################################################

let
  cfg = config.ft.containers.ai;
in
{
  options.ft.containers.ai = {
    enable = lib.mkEnableOption "AI Stack (llama.cpp and OpenWebUI)";

    # Path to the directory where AI models are stored on the host.
    # This directory will be mounted into the backend container.
    modelPath = lib.mkOption {
      type = lib.types.path;
      default = "/home/joe/models";
      description = "Host path to AI model directory.";
    };

    # Name of the primary model to be used by the backend. This is passed
    # as an argument to the llama.cpp server.
    modelName = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5-coder-32b-instruct-q8_0.gguf";
      description = "Filename of the AI model to load (e.g., model.gguf).";
    };

    # Port on which the llama.cpp server will listen. The frontend will
    # connect to this port.
    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the llama.cpp backend server.";
    };

    # Port on which the OpenWebUI frontend will listen.
    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the OpenWebUI frontend.";
    };

    # Enable or disable the OpenWebUI frontend.
    enableFrontend = lib.mkEnableOption "OpenWebUI frontend for AI interaction";

    # Enable or disable an additional ComfyUI image generator (for AIZ module).
    enableComfyUI = lib.mkEnableOption "ComfyUI image generator";

    # ComfyUI specific options if enabled
    comfyui = {
      # Image to use for the ComfyUI container
      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/rocm/pytorch:latest";
        description = "Docker image for ComfyUI.";
      };
      # ROCm GFX version override for ComfyUI (e.g., "11.5.1" for Strix Halo)
      gfxVersion = lib.mkOption {
        type = lib.types.str;
        default = "11.5.1";
        description = "HSA_OVERRIDE_GFX_VERSION for ComfyUI (e.g. 11.5.1).";
      };
      # ComfyUI listening port
      port = lib.mkOption {
        type = lib.types.port;
        default = 8188;
        description = "Port for the ComfyUI server.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";

    # Ensure Podman is enabled at the system level
    virtualisation.podman.enable = true;

    # Allow access to necessary ports through the firewall
    networking.firewall.allowedTCPPorts = [
      cfg.backendPort
    ]
    ++ lib.optionals cfg.enableFrontend [ cfg.frontendPort ]
    ++ lib.optionals cfg.enableComfyUI [ cfg.comfyui.port ];

    virtualisation.oci-containers.containers = {
      llama-cpp = {
        image = "kyuz0/amd-strix-halo-toolboxes:rocm-6.4.4";
        autoStart = true;

        environment = {
          "HSA_ENABLE_SDMA" = "0";
          "GGML_CUDA_NO_PINNED" = "1";
        };

        entrypoint = "llama-server";

        cmd = [
          "-m"
          "/models/${cfg.modelName}"
          "--host"
          "0.0.0.0"
          "--port"
          "${toString cfg.backendPort}"
          "-c"
          "131072"
          "-ngl"
          "99"
          "--no-mmap"
        ];

        extraOptions = [
          "--network=host"
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=label=disable"
          "--no-healthcheck"
        ];

        volumes = [
          "${cfg.modelPath}:/models"
          "/home/joe/containers/rocm:/root/.cache"
        ];
      };
    }
    // lib.mkIf cfg.enableFrontend {
      open-webui = {
        image = "ghcr.io/open-webui/open-webui:main";
        autoStart = true;

        environment = {
          "PORT" = "${toString cfg.frontendPort}";
          "ENABLE_OLLAMA_API" = "False";
          "OPENAI_API_BASE_URL" = "http://127.0.0.1:${toString cfg.backendPort}/v1";
          "OPENAI_API_KEY" = "sk-no-key-required";
        };

        volumes = [ "open-webui-data:/app/backend/data" ];
        extraOptions = [ "--network=host" ];
      };
    }
    // lib.mkIf cfg.enableComfyUI {
      comfyui-generator = {
        image = cfg.comfyui.image;
        autoStart = true;
        environment = {
          "HSA_OVERRIDE_GFX_VERSION" = cfg.comfyui.gfxVersion;
          "HSA_ENABLE_SDMA" = "0";
          "PYTHONPATH" = "/root/ComfyUI";
        };

        workdir = "/root/ComfyUI";

        entrypoint = "/bin/sh";
        cmd = [
          "-c"
          ''
            python3 -m pip install --no-cache-dir pyyaml
            python3 -m pip install --no-cache-dir -r requirements.txt
            python3 main.py --listen 0.0.0.0 --port ${toString cfg.comfyui.port} --highvram --preview-method auto
          ''
        ];

        extraOptions = [
          "--network=host"
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--security-opt=label=disable"
          "--shm-size=16g"
          "--group-add=video"
          "--group-add=render"
        ];

        volumes = [
          "/home/joe/containers/comfyui/app:/root/ComfyUI"
          "${cfg.modelPath}:/root/ComfyUI/models"
          "/home/joe/containers/comfyui/custom_nodes:/root/ComfyUI/custom_nodes"
          "/home/joe/containers/comfyui/user:/root/ComfyUI/user"
          "/home/joe/containers/comfyui/input:/root/ComfyUI/input"
          "/home/joe/containers/comfyui/output:/root/ComfyUI/output"
          "/home/joe/containers/comfyui/pip_cache:/root/.cache/pip"
        ];
      };
    };
  };
}
