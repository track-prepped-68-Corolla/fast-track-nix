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
# ft.services.hermesVm is three-level (new style) — generic enough for any
# consumer, unlike the grandfathered two-level ft.dockervm.
#
# hermes-agent is installed from inputs.llm-agents (github:numtide/llm-agents.nix)
# via overlays.default. The guest connects to the host's existing Ollama instance
# for inference; no Ollama server runs inside the VM.
#
# VM smoke test exempt: nested KVM is unavailable in CI and hermes-agent requires
# the numtide binary cache. See ft-home CLAUDE.md exclusion table.

let
  cfg = config.ft.services.hermesVm;
  tapId = "tap-${cfg.vmName}";
  bridgeName = "hermes-br";
in
{
  options.ft.services.hermesVm = {
    enable = lib.mkEnableOption "Nous Research Hermes agent microVM" // {
      description = "Boots a Cloud Hypervisor microVM running NixOS with the Nous Research Hermes agent (from github:numtide/llm-agents.nix). The guest runs hermes gateway, pointed at the host's existing Ollama instance. Requires KVM on the host. VM smoke test exempt: nested KVM unavailable in CI; hermes-agent requires the numtide binary cache.";
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
      default = 2048;
      description = "Memory in MiB assigned to the VM.";
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
      description = "Base URL of the Ollama instance on the host. Exposed to the guest as OPENAI_BASE_URL with /v1 appended so hermes-agent uses it as the LLM backend. Requires Ollama to be bound to 0.0.0.0 or the bridge address on the host.";
    };

    openaiApiKey = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = "Value for OPENAI_API_KEY inside the guest. Ollama ignores the key; set this when pointing at a provider that enforces authentication.";
    };

    hermesApiPort = lib.mkOption {
      type = lib.types.port;
      default = 8642;
      description = "Port on which the Hermes gateway API server listens inside the VM. Reachable from the host at http://<vmAddress>:<hermesApiPort>.";
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

    # numtide binary cache — required to substitute hermes-agent without a
    # full Python + Node.js source build. Added to host nix.settings so the
    # host Nix daemon can fetch the guest's hermes-agent closure from cache.
    nix.settings = {
      substituters = lib.mkDefault [ "https://cache.numtide.com" ];
      trusted-public-keys = lib.mkDefault [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    # ── Host bridge (hermes-br) ───────────────────────────────────────────────
    #
    # Uses a dedicated bridge rather than sharing microvm0 with ft.dockervm so
    # the two modules can coexist without conflicting bridge address assignments.
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

    # Auto-attach the TAP interface (created by microvm at VM start) to the bridge.
    systemd.network.networks."10-${tapId}" = lib.mkDefault {
      matchConfig.Name = tapId;
      networkConfig.Bridge = bridgeName;
      linkConfig.RequiredForOnline = "enslaved";
    };

    # NAT is optional — only configured when hostInterface is set.
    networking.nat = lib.mkIf (cfg.hostInterface != "") {
      enable = lib.mkDefault true;
      externalInterface = lib.mkDefault cfg.hostInterface;
      internalInterfaces = [ bridgeName ];
    };

    # ── VM definition ─────────────────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config =
        { pkgs, ... }:
        {
          # Pull hermes-agent from the llm-agents.nix flake overlay.
          # overlays.default builds against the flake's own nixpkgs-unstable pin
          # so packages hit cache.numtide.com without a source rebuild.
          nixpkgs.overlays = [ inputs.llm-agents.overlays.default ];

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

          # ── Guest networking — static IP, gateway to host bridge ────────────
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

          # ── Hermes agent gateway ─────────────────────────────────────────────
          #
          # Runs hermes in gateway mode, which exposes an API server and routes
          # requests to the host's Ollama via the OpenAI-compatible endpoint.
          environment.systemPackages = with pkgs; [ hermes-agent ];

          systemd.services.hermes-gateway = {
            description = "Hermes AI agent gateway";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            environment = {
              OPENAI_BASE_URL = "${cfg.ollamaUrl}/v1";
              OPENAI_API_KEY = cfg.openaiApiKey;
              API_SERVER_ENABLED = "true";
              API_SERVER_PORT = toString cfg.hermesApiPort;
              API_SERVER_HOST = "0.0.0.0";
            };
            serviceConfig = {
              ExecStart = "${pkgs.hermes-agent}/bin/hermes gateway run";
              Restart = "on-failure";
              RestartSec = "5s";
            };
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
