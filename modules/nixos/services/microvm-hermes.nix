{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# MICROVM — NixOS SANDBOX FOR NOUS RESEARCH HERMES
################################################################################
#
# ft.services.hermesVm — generic enough for any consumer.
#
# The guest is a minimal NixOS environment that points to an existing Ollama
# instance on the host; it does not run its own Ollama server.
#
# VM smoke test exempt: nested KVM is unavailable in CI.

let
  cfg = config.ft.services.hermesVm;
  tapId = "tap-${cfg.vmName}";
  bridgeName = "hermes-br";
in
{
  options.ft.services.hermesVm = {
    enable = lib.mkEnableOption "Nous Research Hermes NixOS microVM" // {
      description = "Boots a Cloud Hypervisor microVM providing an isolated NixOS environment for the Nous Research Hermes agent. The guest reaches the host's existing Ollama instance via the bridge at ollamaUrl — no Ollama server runs inside the VM. Requires KVM on the host and the microvm flake input (bundled with fast-track-nix). VM smoke test exempt: nested KVM is unavailable in CI.";
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
      description = "URL of the Ollama instance on the host. Set as OLLAMA_HOST inside the guest so the ollama CLI and any agent tooling find it automatically. The default points to the host bridge address; adjust if Ollama listens elsewhere.";
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

          # Point the ollama CLI (and any agent tooling) at the host's server.
          environment.variables.OLLAMA_HOST = lib.mkDefault cfg.ollamaUrl;

          # ollama CLI for querying the host-side Ollama from within the guest.
          environment.systemPackages = with pkgs; [ ollama ];

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
