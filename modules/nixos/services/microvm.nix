{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# GENERIC MICROVM HOST INFRASTRUCTURE — MULTI-INSTANCE
################################################################################

{
  # ft.services.microvms is an attrsOf submodule — each instance has its own
  # enable option at ft.services.microvms.<name>.enable (four levels), which is
  # the standard NixOS pattern for multi-instance modules and takes precedence
  # over the three-level convention for single-instance modules.
  options.ft.services.microvms = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "microVM instance" // {
            description = "Provisions a Cloud Hypervisor microVM on the host: creates a bridge interface (microvm0), configures NAT for guest internet access, attaches a TAP interface, and manages the microvm@<name> systemd service. Requires KVM (/dev/kvm) and the microvm flake input.";
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
            description = "IP address of the host-side bridge interface (microvm0); becomes the VM's default gateway. All VMs on the same host share this bridge and must agree on this value.";
          };

          vmAddress = lib.mkOption {
            type = lib.types.str;
            description = "Static IP address assigned to the VM's primary network interface. Must be unique within the host bridge subnet.";
          };

          prefixLength = lib.mkOption {
            type = lib.types.int;
            default = 24;
            description = "Subnet prefix length shared by the host bridge and VM interface (e.g. 24 for /24).";
          };

          vmMac = lib.mkOption {
            type = lib.types.str;
            description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02) and unique per host.";
          };

          vsockCid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "vsock context ID (CID) for the VM. When set, enables systemd-notify support and the host service will wait for the VM to signal readiness — do not set this if any service blocks multi-user.target for a long time (e.g. first-boot image pulls). Must be unique per host (valid range: 3–4294967293).";
          };

          hostInterface = lib.mkOption {
            type = lib.types.str;
            description = "Name of the host's external network interface (e.g. eth0, wlan0, enp3s0). Used by networking.nat to add the MASQUERADE rule that gives the VM internet access. All VMs on the same host must agree on this value.";
          };

          sshAuthorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "SSH public keys authorized to log in as root inside the VM. When non-empty, enables OpenSSH server in the guest on port 22 (the VM is only reachable from the host bridge).";
          };

          volumes = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
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
              }
            );
            default = [ ];
            description = "Persistent disk images attached to the guest. Each entry creates a host-side image file and mounts it at the given path inside the VM.";
          };

          shares = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
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
              }
            );
            default = [ ];
            description = "Host directories shared into the guest via virtiofs. Requires cloud-hypervisor (Firecracker does not support virtiofs).";
          };

          extraGuestConfig = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
            description = "Additional NixOS module merged into the guest configuration. Use this to inject application-level services (e.g. ft.services.ociStack) without modifying this generic infrastructure module.";
          };
        };
      }
    );
    default = { };
    description = "Set of microVM instances to provision on this host. Each attribute key becomes the VM name, systemd service suffix, guest hostname, and TAP interface suffix (tap-<name>).";
  };

  # IMPORTANT: config must be a plain attrset — not lib.mkMerge at the top
  # level. lib.mkMerge (lib.mapAttrsToList ... config.ft.services.microvms)
  # creates infinite recursion because NixOS must evaluate the list to discover
  # which options this module sets, and that evaluation forces
  # config.ft.services.microvms before it is available. Plain attrset values
  # are thunks — NixOS reads the keys eagerly but forces the values only when
  # the specific options are merged, at which point config.ft.services.microvms
  # is already resolved.
  config =
    let
      vms = config.ft.services.microvms;
      anyEnabled = lib.any (vmCfg: vmCfg.enable) (lib.attrValues vms);
    in
    {
      nixpkgs.overlays = lib.optional anyEnabled inputs.microvm.overlay;

      # ── Host bridge (microvm0) — shared by all VMs ─────────────────────────
      systemd.network.enable = lib.mkIf anyEnabled (lib.mkDefault true);

      systemd.network.netdevs = lib.mkMerge (
        lib.mapAttrsToList (
          _vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-microvm0" = lib.mkDefault {
              netdevConfig = {
                Kind = "bridge";
                Name = "microvm0";
              };
            };
          }
        ) vms
      );

      systemd.network.networks = lib.mkMerge (
        # Bridge network — contributed by each enabled VM, values must be identical
        (lib.mapAttrsToList (
          _vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-microvm0" = lib.mkDefault {
              matchConfig.Name = "microvm0";
              networkConfig = {
                Address = "${vmCfg.hostAddress}/${toString vmCfg.prefixLength}";
                ConfigureWithoutCarrier = true;
                IPv4Forwarding = true;
              };
              linkConfig.RequiredForOnline = "no";
            };
          }
        ) vms)
        # Per-VM TAP — unique key per instance
        ++ (lib.mapAttrsToList (
          vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-tap-${vmName}" = lib.mkDefault {
              matchConfig.Name = "tap-${vmName}";
              networkConfig.Bridge = "microvm0";
              linkConfig.RequiredForOnline = "enslaved";
            };
          }
        ) vms)
      );

      # ── NAT — guest internet access ────────────────────────────────────────
      networking.nat = lib.mkMerge (
        [
          (lib.mkIf anyEnabled {
            enable = lib.mkDefault true;
            internalInterfaces = [ "microvm0" ];
          })
        ]
        ++ lib.mapAttrsToList (
          _vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            externalInterface = lib.mkDefault vmCfg.hostInterface;
          }
        ) vms
      );

      systemd.tmpfiles.rules = lib.concatLists (
        lib.mapAttrsToList (
          vmName: vmCfg: lib.optional vmCfg.enable "d /var/lib/microvm/${vmName} 0750 microvm - -"
        ) vms
      );

      # ── VM definitions ─────────────────────────────────────────────────────
      microvm.vms = lib.mapAttrs (
        vmName: vmCfg:
        lib.mkIf vmCfg.enable {
          autostart = lib.mkDefault true;

          config =
            { ... }:
            {
              imports = [ vmCfg.extraGuestConfig ];

              microvm.hypervisor = lib.mkDefault "cloud-hypervisor";
              microvm.vcpu = lib.mkDefault vmCfg.vcpus;
              microvm.mem = lib.mkDefault vmCfg.mem;
              microvm.vsock.cid = lib.mkIf (vmCfg.vsockCid != null) (lib.mkDefault vmCfg.vsockCid);

              microvm.interfaces = lib.mkDefault [
                {
                  type = "tap";
                  id = "tap-${vmName}";
                  mac = vmCfg.vmMac;
                }
              ];

              microvm.volumes = lib.mkDefault vmCfg.volumes;
              microvm.shares = lib.mkDefault vmCfg.shares;

              systemd.network.enable = lib.mkDefault true;
              systemd.network.networks."10-eth" = lib.mkDefault {
                matchConfig.Name = "en* eth*";
                networkConfig = {
                  Address = "${vmCfg.vmAddress}/${toString vmCfg.prefixLength}";
                  Gateway = vmCfg.hostAddress;
                  DNS = [
                    "1.1.1.1"
                    "8.8.8.8"
                  ];
                };
              };

              services.openssh = lib.mkIf (vmCfg.sshAuthorizedKeys != [ ]) {
                enable = lib.mkDefault true;
                settings = {
                  PermitRootLogin = lib.mkDefault "yes";
                  PasswordAuthentication = lib.mkDefault false;
                };
              };

              users.users.root = lib.mkIf (vmCfg.sshAuthorizedKeys != [ ]) {
                openssh.authorizedKeys.keys = lib.mkDefault vmCfg.sshAuthorizedKeys;
              };

              networking.hostName = lib.mkDefault vmName;
              networking.firewall.enable = lib.mkDefault false;
              system.stateVersion = lib.mkDefault "25.05";
              nixpkgs.hostPlatform = lib.mkDefault config.nixpkgs.hostPlatform;
            };
        }
      ) vms;
    };
}
