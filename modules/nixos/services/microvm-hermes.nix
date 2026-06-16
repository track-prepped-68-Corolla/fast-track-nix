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
# ft.hermesVm is three-level (new style) — generic enough for any consumer.
#
# Uses the official hermes-agent NixOS module (github:NousResearch/hermes-agent)
# rather than a hand-rolled systemd service. The guest runs hermes in container
# mode so npm/pip installs inside the agent have a writable Ubuntu layer.
#
# The guest connects to the host's existing Ollama instance for inference via
# settings.model.base_url — no Ollama server runs inside the VM.
#
# VM smoke test exempt: nested KVM is unavailable in CI.

let
  cfg = config.ft.hermesVm;
  tapId = "tap-${cfg.vmName}";
  bridgeName = "hermes-br";
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

    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.102.1";
      description = "IP address of the host-side bridge interface (hermes-br); becomes the VM's default gateway.";
    };

    vmAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.102.2";
      description = "Static IP address assigned to the VM's primary network interface.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Subnet prefix length shared by the host bridge and VM interface (e.g. 24 for /24).";
    };

    vmMac = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:01:01";
      description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02). Change this if running alongside ft.dockervm to avoid collisions.";
    };

    hostInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Host external network interface (e.g. eth0, enp3s0) for NAT. When set, the guest gets outbound internet access. Leave empty if only host–guest communication is needed.";
    };

    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${cfg.hostAddress}:11434";
      description = "Base URL of the Ollama instance on the host. Set as services.hermes-agent.settings.model.base_url (with /v1 appended) inside the guest. Requires Ollama to be bound to 0.0.0.0 or the bridge address on the host.";
    };

    openaiApiKey = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = "Value for OPENROUTER_API_KEY inside the guest. Ollama ignores the key; set this when pointing at a real provider that enforces authentication. For real secrets, use environmentFiles instead.";
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
    # Provide cloud-hypervisor and related host binaries from the microvm overlay.
    nixpkgs.overlays = [ inputs.microvm.overlay ];

    # ── Host bridge (hermes-br) ───────────────────────────────────────────────
    systemd.network.enable = lib.mkDefault true;

    systemd.network.netdevs."10-${bridgeName}" = lib.mkDefault {
      netdevConfig = {
        Kind = "bridge";
        Name = bridgeName;
      };
    };

    systemd.network.networks."10-${bridgeName}" = lib.mkDefault {
      matchConfig.Name = bridgeName;
      networkConfig = {
        Address = "${cfg.hostAddress}/${toString cfg.prefixLength}";
        ConfigureWithoutCarrier = true;
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    systemd.network.networks."10-${tapId}" = lib.mkDefault {
      matchConfig.Name = tapId;
      networkConfig.Bridge = bridgeName;
      linkConfig.RequiredForOnline = "enslaved";
    };

    networking.nat.enable = lib.mkIf (cfg.hostInterface != "") (lib.mkDefault true);
    networking.nat.externalInterface = lib.mkIf (cfg.hostInterface != "") (
      lib.mkDefault cfg.hostInterface
    );
    networking.nat.internalInterfaces = lib.optionals (cfg.hostInterface != "") [ bridgeName ];

    # ── VM definition ─────────────────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config =
        { ... }:
        {
          imports = [ inputs.hermes-agent.nixosModules.default ];

          microvm.hypervisor = lib.mkDefault "cloud-hypervisor";
          microvm.vcpu = lib.mkDefault cfg.vcpus;
          microvm.mem = lib.mkDefault cfg.mem;

          microvm.interfaces = lib.mkDefault [
            {
              type = "tap";
              id = tapId;
              mac = cfg.vmMac;
            }
          ];

          # ── Guest networking ─────────────────────────────────────────────────
          systemd.network.enable = lib.mkDefault true;
          systemd.network.networks."10-eth" = lib.mkDefault {
            matchConfig.Name = "en* eth*";
            networkConfig = {
              Address = "${cfg.vmAddress}/${toString cfg.prefixLength}";
              Gateway = cfg.hostAddress;
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
            };
          };

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
              OPENROUTER_API_KEY = cfg.openaiApiKey;
            };
            environmentFiles = lib.mkDefault cfg.environmentFiles;
            settings = lib.mkDefault (
              {
                model.base_url = "${cfg.ollamaUrl}/v1";
              }
              // cfg.settings
            );
          };

          # ── Optional SSH access from the host ───────────────────────────────
          services.openssh = lib.mkIf (cfg.sshAuthorizedKeys != [ ]) {
            enable = lib.mkDefault true;
            settings = {
              PermitRootLogin = lib.mkDefault "yes";
              PasswordAuthentication = lib.mkDefault false;
            };
          };

          users.users.root = lib.mkIf (cfg.sshAuthorizedKeys != [ ]) {
            openssh.authorizedKeys.keys = lib.mkDefault cfg.sshAuthorizedKeys;
          };

          networking.hostName = lib.mkDefault cfg.vmName;
          networking.firewall.enable = lib.mkDefault false;

          system.stateVersion = lib.mkDefault "25.05";
          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        };
    };
  };
}
