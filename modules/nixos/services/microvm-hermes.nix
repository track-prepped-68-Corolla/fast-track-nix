{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# MICROVM WITH NOUS RESEARCH HERMES (via Ollama)
################################################################################
#
# ft.services.hermesVm is three-level (new style) — generic enough for any
# consumer, unlike the grandfathered two-level ft.dockervm.
#
# VM smoke test exempt: nested KVM is unavailable in CI, and first-boot model
# pulls require outbound internet access. See ft-home CLAUDE.md exclusion table.

let
  cfg = config.ft.services.hermesVm;
  tapId = "tap-${cfg.vmName}";
  bridgeName = "hermes-br";
in
{
  options.ft.services.hermesVm = {
    enable = lib.mkEnableOption "Nous Research Hermes microVM" // {
      description = "Boots a Cloud Hypervisor microVM running NixOS with Ollama serving a Nous Research Hermes language model on an OpenAI-compatible API. The guest is a full NixOS environment reachable from the host bridge. Requires KVM on the host and the microvm flake input (bundled with fast-track-nix). VM smoke test exempt: nested KVM and network-dependent model pulls are unavailable in CI.";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-vm";
      description = "Name for the microvm instance. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-<vmName>).";
    };

    vcpus = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of vCPUs assigned to the VM. Nous Hermes 7B benefits from at least 2; larger models need more.";
    };

    mem = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = "Memory in MiB assigned to the VM. The default targets nous-hermes2 (7B); larger models such as hermes3 on Llama 3.1 70B require significantly more.";
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
      description = "Name of the host's external network interface (e.g. eth0, enp3s0). Required for NAT so the VM can reach the internet to pull Ollama models on first boot. Must be set when enable = true.";
    };

    ollamaPort = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port on which Ollama listens inside the VM for OpenAI-compatible API requests. The API is reachable from the host at http://<vmAddress>:<ollamaPort>.";
    };

    hermesModel = lib.mkOption {
      type = lib.types.str;
      default = "nous-hermes2";
      description = "Ollama model tag for the Nous Research Hermes model to pull and serve on first boot. Common choices: nous-hermes2 (7B, Mistral-based), nous-hermes2-mixtral (47B), hermes3 (8B, Llama 3.1-based).";
    };

    modelDataSize = lib.mkOption {
      type = lib.types.int;
      default = 10240;
      description = "Size in MiB of the persistent Ollama data volume stored at /var/lib/microvm/<vmName>/ollama.img on the host. The nous-hermes2 7B Q4 model requires approximately 4 GiB; increase for larger models.";
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized to log in as root inside the VM. When non-empty, enables OpenSSH in the guest on port 22. The VM is only reachable from the host bridge, so exposure is limited to the host.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hostInterface != "";
        message = "ft.services.hermesVm.hostInterface must be set to the host's external network interface (e.g. enp3s0, wlp3s0). Check `ip link` on the host.";
      }
    ];

    # Provide cloud-hypervisor and related host binaries from the microvm overlay.
    nixpkgs.overlays = [ inputs.microvm.overlay ];

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

    # ── NAT — guest internet access (required for first-boot model pull) ──────
    networking.nat = {
      enable = lib.mkDefault true;
      externalInterface = lib.mkDefault cfg.hostInterface;
      internalInterfaces = [ bridgeName ];
    };

    # ── Persistent storage directory on the host ──────────────────────────────
    # microvm@.service runs as the microvm user created by the host module.
    systemd.tmpfiles.rules = [
      "d /var/lib/microvm/${cfg.vmName} 0750 microvm - -"
    ];

    # ── VM definition ─────────────────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config = _: {
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

        # Persistent disk image so downloaded model weights survive VM restarts.
        microvm.volumes = lib.mkDefault [
          {
            image = "/var/lib/microvm/${cfg.vmName}/ollama.img";
            mountPoint = "/var/lib/ollama";
            size = cfg.modelDataSize;
          }
        ];

        # ── Guest networking — static IP, gateway to host bridge ──────────────
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

        # ── Ollama serving Nous Hermes ────────────────────────────────────────
        #
        # Bound to 0.0.0.0 so the host can reach the OpenAI-compatible API at
        # http://<vmAddress>:<ollamaPort>. loadModels pulls the model on first
        # boot; subsequent starts are idempotent (ollama skips cached models).
        services.ollama = {
          enable = lib.mkDefault true;
          host = lib.mkDefault "0.0.0.0";
          port = lib.mkDefault cfg.ollamaPort;
          loadModels = lib.mkDefault [ cfg.hermesModel ];
        };

        # ── Optional SSH access from the host ─────────────────────────────────
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
