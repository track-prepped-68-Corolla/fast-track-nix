{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.containers.ai;
in
{
  options.ft.containers.ai = {
    enable = lib.mkEnableOption "AI Stack (llama.cpp and OpenWebUI)";

    modelPath = lib.mkOption {
      type = lib.types.path;
      default = "/opt/ai-models";
      description = "Host path to AI model directory.";
    };

    modelName = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5-coder-32b-instruct-q8_0.gguf";
      description = "Filename of the AI model to load.";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    enableFrontend = lib.mkEnableOption "OpenWebUI frontend";
    enableComfyUI = lib.mkEnableOption "ComfyUI image generator";

    comfyui = {
      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/rocm/pytorch:latest";
      };
      gfxVersion = lib.mkOption {
        type = lib.types.str;
        default = "11.5.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8188;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    networking.firewall.allowedTCPPorts = [
      cfg.backendPort
    ]
    ++ lib.optionals cfg.enableFrontend [ cfg.frontendPort ]
    ++ lib.optionals cfg.enableComfyUI [ cfg.comfyui.port ];

    virtualisation.oci-containers.containers = lib.mkMerge [
      # 1. LLAMA.CPP BACKEND
      {
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
            "32768"
            "-ngl"
            "99"
            "--flash-attn"
            "on"
            "--no-mmap"
          ];
          extraOptions = [
            "--network=host"
            "--device=/dev/kfd"
            "--device=/dev/dri"
            "--security-opt=label=disable"
          ];
          volumes = [
            "${cfg.modelPath}:/models"
            "/opt/llama-cpp/cache:/root/.cache"
          ];
        };
      }

      # 2. OPEN WEBUI FRONTEND
      (lib.mkIf cfg.enableFrontend {
        open-webui = {
          image = "ghcr.io/open-webui/open-webui:main";
          autoStart = true;
          environment = {
            "PORT" = "${toString cfg.frontendPort}";
            "ENABLE_OLLAMA_API" = "False";
            "OPENAI_API_BASE_URL" = "http://127.0.0.1:${toString cfg.backendPort}/v1";
            "OPENAI_API_KEY" = "sk-no-key-required";
          };
          volumes = [ "/opt/open-webui:/app/backend/data" ];
          extraOptions = [ "--network=host" ];
        };
      })

      # 3. COMFYUI GENERATOR
      (lib.mkIf cfg.enableComfyUI {
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
            "/opt/comfyui/app:/root/ComfyUI"
            "${cfg.modelPath}:/root/ComfyUI/models"
            "/opt/comfyui/custom_nodes:/root/ComfyUI/custom_nodes"
            "/opt/comfyui/user:/root/ComfyUI/user"
            "/opt/comfyui/input:/root/ComfyUI/input"
            "/opt/comfyui/output:/root/ComfyUI/output"
          ];
        };
      })
    ];
  };
}
