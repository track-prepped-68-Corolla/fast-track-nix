{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# MICROVM — NixOS SANDBOX FOR NOUS RESEARCH HERMES AGENT
################################################################################
#
# Thin wrapper that composes ft.microvms (host infrastructure) with the
# official hermes-agent NixOS module (github:NousResearch/hermes-agent),
# following the same pattern as ft.dockervm. Delegating to ft.microvms means
# this VM shares the host's microvm0 bridge and NAT setup instead of
# maintaining its own — no bespoke bridge/NAT plumbing belongs here.
#
# The guest runs hermes in container mode so npm/pip installs inside the
# agent have a writable Ubuntu layer.
#
# The guest connects to the host's existing Ollama instance for inference via
# settings.model.base_url — no Ollama server runs inside the VM.
#
# VM smoke test exempt: nested KVM is unavailable in CI.

let
  cfg = config.ft.hermesVm;
in
{
  options.ft.hermesVm = {
    enable = lib.mkEnableOption "Nous Research Hermes NixOS microVM" // {
      description = "Boots a Cloud Hypervisor microVM providing an isolated NixOS environment for the Nous Research Hermes agent. Uses the official hermes-agent NixOS module with container mode enabled so the agent can install runtime dependencies. The guest reaches the host's existing Ollama instance via ollamaUrl. Requires KVM on the host. VM smoke test exempt: nested KVM is unavailable in CI.";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-vm";
      description = "Name for the microvm instance. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-<vmName>).";
    };

    vcpus = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of vCPUs assigned to the VM.";
    };

    mem = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Memory in MiB assigned to the VM. Container mode needs more headroom than native mode; 4096 is a safe default.";
    };

    vmAddressSuffix = lib.mkOption {
      type = lib.types.ints.u8;
      default = 3;
      description = "Last octet of the VM's IP address on the shared microvm0 subnet (ft.microvms.hostAddress). Must be unique among all microvm instances on this host — distinct from ft.dockervm's vmAddressSuffix.";
    };

    vmMac = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:01:01";
      description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02) and unique per host — distinct from ft.dockervm's vmMac.";
    };

    hostInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Host external network interface (e.g. eth0, enp3s0) for NAT. When set, the guest gets outbound internet access. Leave empty if only host–guest communication is needed.";
    };

    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${config.ft.microvms.hostAddress}:11434";
      description = "Base URL of the Ollama instance on the host. Set as services.hermes-agent.settings.model.base_url (with /v1 appended) inside the guest. Requires Ollama to be bound to 0.0.0.0 or the bridge address on the host.";
    };

    openaiApiKey = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = "API key for the custom OpenAI-compatible provider (services.hermes-agent.settings.model.api_key and OPENAI_API_KEY inside the guest). Ollama ignores the key; set this when pointing at a real provider that enforces authentication. For real secrets, use environmentFiles instead.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths to env files containing secrets (e.g. real API keys). Passed directly to services.hermes-agent.environmentFiles inside the guest. Paths must be accessible inside the VM — use microvm volumes to mount host files if needed.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Arbitrary hermes-agent settings merged into services.hermes-agent.settings inside the guest. See the hermes-agent NixOS module options reference for available keys.";
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized to log in as root inside the VM. When non-empty, enables OpenSSH in the guest on port 22. The VM is only reachable from the host bridge, so exposure is limited to the host.";
    };
  };

  config = lib.mkIf cfg.enable {
    ft.microvms.instances.${cfg.vmName} = {
      enable = lib.mkDefault true;
      inherit (cfg)
        vcpus
        mem
        vmAddressSuffix
        vmMac
        hostInterface
        sshAuthorizedKeys
        ;

      extraGuestConfig = {
        imports = [ inputs.hermes-agent.nixosModules.default ];

        # ── Hermes agent service (official NixOS module) ─────────────────────
        #
        # container.enable gives hermes a persistent Ubuntu writable layer so
        # npm/pip/apt installs work — the same isolation the microvm provides
        # for the host, the container provides for the NixOS guest filesystem.
        services.hermes-agent = {
          enable = lib.mkDefault true;
          addToSystemPackages = lib.mkDefault true;
          container.enable = lib.mkDefault true;
          environment = lib.mkDefault {
            OPENAI_API_KEY = cfg.openaiApiKey;
          };
          environmentFiles = lib.mkDefault cfg.environmentFiles;
          settings = lib.mkDefault (
            {
              model = {
                provider = "custom";
                base_url = "${cfg.ollamaUrl}/v1";
                api_key = cfg.openaiApiKey;
              };
            }
            // cfg.settings
          );
        };
      };
    };
  };
}
