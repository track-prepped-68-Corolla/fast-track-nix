{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# GENERIC MICROVM HOST INFRASTRUCTURE
################################################################################

let
  cfg = config.ft.services.microvm;
  tapId = "tap-${cfg.vmName}";
in
{
  options.ft.services.microvm = {
    enable = lib.mkEnableOption "generic microVM host infrastructure" // {
      description = "Provisions a Cloud Hypervisor microVM on the host: creates a bridge interface (microvm0), configures NAT for guest internet access, attaches a TAP interface, and manages the microvm@<vmName> systemd service. Requires KVM (/dev/kvm) and the microvm flake input.";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "vm";
      description = "Name of the microvm instance. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-<vmName>).";
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

    vmMac = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:00:01";
      description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02).";
    };

    vsockCid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "vsock context ID (CID) for the VM. When set, enables systemd-notify support and the host service will wait for the VM to signal readiness — do not set this if any service blocks multi-user.target for a long time (e.g. first-boot image pulls). Must be unique per host (valid range: 3–4294967293).";
    };

    hostInterface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the host's external network interface (e.g. eth0, wlan0, enp3s0). Used by networking.nat to add the MASQUERADE rule that gives the VM internet access.";
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized to log in as root inside the VM. When non-empty, enables OpenSSH server in the guest on port 22 (the VM is only reachable from the host bridge).";
    };

    volumes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          image = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path to the host-side disk image file.";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Mount point inside the guest.";
          };
          size = lib.mkOption {
            type = lib.types.int;
            description = "Size of the disk image in MiB.";
          };
        };
      });
      default = [ ];
      description = "Persistent disk images attached to the guest. Each entry creates a host-side image file and mounts it at the given path inside the VM.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path on the host to share into the guest.";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Mount point inside the guest.";
          };
          tag = lib.mkOption {
            type = lib.types.str;
            description = "Unique virtiofs tag for this share.";
          };
          proto = lib.mkOption {
            type = lib.types.str;
            default = "virtiofs";
            description = "Filesystem sharing protocol (virtiofs or 9p).";
          };
        };
      });
      default = [ ];
      description = "Host directories shared into the guest via virtiofs. Requires cloud-hypervisor (Firecracker does not support virtiofs).";
    };

    extraGuestConfig = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Additional NixOS module merged into the guest configuration. Use this to inject application-level services (e.g. ft.services.ociStack) without modifying this generic infrastructure module.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.microvm.overlay ];

    # ── Host bridge (microvm0) ───────────────────────────────────────────────
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
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    systemd.network.networks."10-${tapId}" = lib.mkDefault {
      matchConfig.Name = tapId;
      networkConfig.Bridge = "microvm0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # ── NAT — guest internet access ──────────────────────────────────────────
    networking.nat = {
      enable = lib.mkDefault true;
      externalInterface = lib.mkDefault cfg.hostInterface;
      internalInterfaces = [ "microvm0" ];
    };

    systemd.tmpfiles.rules = [ "d /var/lib/microvm/${cfg.vmName} 0750 microvm - -" ];

    # ── VM definition ────────────────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config =
        { ... }:
        {
          imports = [ cfg.extraGuestConfig ];

          microvm.hypervisor = lib.mkDefault "cloud-hypervisor";
          microvm.vcpu = lib.mkDefault cfg.vcpus;
          microvm.mem = lib.mkDefault cfg.mem;
          microvm.vsock.cid = lib.mkIf (cfg.vsockCid != null) (lib.mkDefault cfg.vsockCid);

          microvm.interfaces = lib.mkDefault [
            {
              type = "tap";
              id = tapId;
              mac = cfg.vmMac;
            }
          ];

          microvm.volumes = lib.mkDefault cfg.volumes;
          microvm.shares = lib.mkDefault cfg.shares;

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
