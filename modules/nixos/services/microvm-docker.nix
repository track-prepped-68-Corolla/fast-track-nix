{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# FIRECRACKER MICROVM WITH ROOTFUL DOCKER COMPOSE
################################################################################

let
  cfg = config.ft.services.microvmDocker;
  tapId = "tap-${cfg.vmName}";
in
{
  options.ft.services.microvmDocker = {
    enable = lib.mkEnableOption "Firecracker microVM with rootful Docker Compose" // {
      description = "Boots a Firecracker microVM attached to a host TAP bridge, installs rootful Docker and docker-compose inside the guest, and routes guest internet traffic via host NAT. Requires KVM (/dev/kvm) on the host and the microvm flake input (bundled with fast-track-nix).";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "docker-vm";
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
      default = "10.0.100.1";
      description = "IP address of the host-side bridge interface (microvm0); becomes the VM's default gateway.";
    };

    vmAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.100.2";
      description = "Static IP address assigned to the VM's primary network interface.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Subnet prefix length shared by the host bridge and VM interface (e.g. 24 for /24).";
    };

    dockerVolumeSize = lib.mkOption {
      type = lib.types.int;
      default = 20480;
      description = "Size of the persistent Docker data volume in MiB (image stored at /var/lib/microvm/<vmName>/docker.img on the host).";
    };

    vmMac = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:00:01";
      description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Provide firecracker and related host binaries from the microvm overlay.
    nixpkgs.overlays = [ inputs.microvm.overlay ];

    # ── Host bridge (microvm0) ───────────────────────────────────────────────
    #
    # systemd-networkd manages the bridge and auto-attaches the TAP interface
    # when microvm creates it at VM start.  Do not combine with networking.bridges
    # on the same interface — pick one manager.
    systemd.network.enable = lib.mkDefault true;

    systemd.network.netdevs."10-microvm0" = lib.mkDefault {
      netdevConfig = {
        Kind = "bridge";
        Name = "microvm0";
      };
    };

    systemd.network.networks."10-microvm0" = lib.mkDefault {
      matchConfig.Name = "microvm0";
      networkConfig = {
        Address = "${cfg.hostAddress}/${toString cfg.prefixLength}";
        ConfigureWithoutCarrier = true;
        IPForward = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # Attach the TAP interface (created by microvm at VM start) to the bridge.
    systemd.network.networks."10-${tapId}" = lib.mkDefault {
      matchConfig.Name = tapId;
      networkConfig.Bridge = "microvm0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # ── NAT — guest internet access ──────────────────────────────────────────
    networking.nat = {
      enable = lib.mkDefault true;
      internalInterfaces = [ "microvm0" ];
    };

    # ── Persistent storage directory on the host ─────────────────────────────
    systemd.tmpfiles.rules = [ "d /var/lib/microvm/${cfg.vmName} 0750 root root -" ];

    # ── Firecracker VM definition ────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config =
        { pkgs, ... }:
        {
          microvm.hypervisor = lib.mkDefault "firecracker";
          microvm.vcpu = lib.mkDefault cfg.vcpus;
          microvm.mem = lib.mkDefault cfg.mem;

          microvm.interfaces = lib.mkDefault [
            {
              type = "tap";
              id = tapId;
              mac = cfg.vmMac;
            }
          ];

          # Persistent Docker data lives on a host-side disk image so container
          # state survives VM restarts without requiring a full overlay2 rootfs.
          microvm.volumes = lib.mkDefault [
            {
              image = "/var/lib/microvm/${cfg.vmName}/docker.img";
              mountPoint = "/var/lib/docker";
              size = cfg.dockerVolumeSize;
            }
          ];

          # ── Guest networking — static IP, gateway to host bridge ─────────
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

          # ── Rootful Docker with docker-compose ───────────────────────────
          virtualisation.docker.enable = lib.mkDefault true;
          virtualisation.docker.daemon.settings.storage-driver = lib.mkDefault "overlay2";

          environment.systemPackages = with pkgs; [ docker-compose ];

          # Working directory for compose projects.
          systemd.tmpfiles.rules = [ "d /opt/compose 0750 root root -" ];

          networking.hostName = lib.mkDefault cfg.vmName;
          networking.firewall.enable = lib.mkDefault false;

          system.stateVersion = lib.mkDefault "25.05";
          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        };
    };
  };
}
