{
  config,
  options,
  lib,
  inputs,
  ...
}:

################################################################################
# GENERIC MICROVM HOST INFRASTRUCTURE — MULTI-INSTANCE, ATTACH-BY-REFERENCE
#
# Host-side only: bridge (microvm0) + DHCP server + NAT + per-VM TAP, and each
# instance attaches a STANDALONE guest by reference (microvm.vms.<name>.flake =
# self → self.nixosConfigurations.<name>, produced by flake-parts/vms.nix from a
# vms/<name>/ directory). The guest closure is never evaluated inside the host,
# which removes the inline-guest recursion fragility of the old model.
#
# Everything guest-side — vcpus/mem, volumes, shares, sshd, vsock, stateVersion —
# now lives in the guest's own vms/<name>/ config plus the guest baseline
# (modules/vm/vm-guest-base.nix), NOT here. This module only decides where a VM
# sits on the host network, gives it internet access, and provisions its
# host-side directories.
#
# Addressing: guests are DHCP clients (see vm-guest-base.nix); the host bridge
# runs a DHCP server that hands each guest a stable address via a static lease.
# The lease's MAC and the tap interface name are BOTH derived from the instance
# name (modules/vm/lib.nix), identically here and in the guest baseline, so the
# two always agree with nothing hand-set, and the interface name is truncated to
# stay within Linux's 15-char limit regardless of how long the VM name is.
#
# Auto host share: every enabled instance gets /var/lib/microvm/<name>/share
# created here, which the guest baseline mounts over virtiofs at /srv/host-share
# by convention (keyed on the VM name) — so every VM has a host-backed, host-
# browsable data directory with nothing for the consumer to wire up. shareOwner/
# shareGroup set its ownership for guests whose services must write to it.
################################################################################

{
  options.ft.microvms = {
    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.100.1";
      description = "IP address of the shared host-side bridge interface (microvm0), which acts as the default gateway and DHCP server for every microVM on this host. Each VM's guest address is built from this value's /24 network portion plus its own vmAddressSuffix — change the subnet here once, rather than per instance.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Subnet prefix length shared by the host bridge and every guest interface (e.g. 24 for a /24).";
    };

    # instances is an attrsOf submodule — each instance has its own
    # enable option at ft.microvms.instances.<name>.enable, following the
    # standard NixOS pattern for multi-instance modules.
    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "microVM instance" // {
              description = "Runs the standalone guest nixosConfigurations.<name> (built by flake-parts/vms.nix from vms/<name>/) on this host: connects it to the shared bridge (microvm0), gives it a DHCP static lease, sets up NAT so it can reach the internet, attaches a TAP interface, provisions its host-side directories, and manages its microvm@<name> systemd service. Requires KVM (/dev/kvm) and the microvm flake input. The instance name must match the vms/<name>/ directory name.";
            };

            vmAddressSuffix = lib.mkOption {
              type = lib.types.ints.u8;
              description = "The last octet of this VM's IP address on the shared microvm0 subnet — combined with the network portion of ft.microvms.hostAddress to build the full guest address, handed to the guest as a DHCP static lease. Must be unique among all instances on this host. (The lease's MAC and the tap interface name are derived from the instance name automatically — see modules/vm/lib.nix — so they always match the guest and never exceed Linux's 15-char interface limit.)";
            };

            hostInterface = lib.mkOption {
              type = lib.types.str;
              description = "Name of the host's external network interface (e.g. eth0, wlan0, enp3s0), used by networking.nat to add the MASQUERADE rule that gives the VM internet access. Set to the empty string for a VM that should have no internet access. Every VM on the same host that wants internet must agree on this value.";
            };

            shareSecrets = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Share the consumer's sops secret tree (ft.repoPath/var/secrets) into this VM read-only at /var/lib/microvm/<name>/secrets, which its guest mounts at /var/secrets (see the guest's ft.vmSecrets). The files stay sops-encrypted — only a guest holding the matching age recipient can decrypt them. Requires ft.repoPath set to your consumer repo.";
            };

            shareOwner = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Owner of the auto-provisioned host share directory (/var/lib/microvm/<name>/share), which the guest mounts over virtiofs at /srv/host-share. Set this to the user a guest service writes as when it needs write access through the share.";
            };

            shareGroup = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Group of the auto-provisioned host share directory (/var/lib/microvm/<name>/share), created mode 0770. Set this to a group the guest's writing service belongs to (e.g. container for a docker/Komodo guest) so it can write through the virtiofs share.";
            };
          };
        }
      );
      default = { };
      description = "The set of microVM instances to run on this host. Each attribute name must match a vms/<name>/ directory (its standalone nixosConfigurations.<name>), and becomes that VM's systemd service suffix (microvm@<name>), TAP interface suffix (tap-<name>), and host share directory (/var/lib/microvm/<name>/share).";
    };
  };

  # IMPORTANT: config must be a plain attrset — not lib.mkMerge at the top
  # level. lib.mkMerge (lib.mapAttrsToList ... config.ft.microvms.instances)
  # creates infinite recursion because NixOS must evaluate the list to
  # discover which options this module sets, and that evaluation forces
  # config.ft.microvms.instances before it is available. Plain attrset values
  # are thunks — NixOS reads the keys eagerly but forces the values only when
  # the specific options are merged, at which point config.ft.microvms.instances
  # is already resolved.
  config =
    let
      netCfg = config.ft.microvms;
      vms = netCfg.instances;
      anyEnabled = lib.any (vmCfg: vmCfg.enable) (lib.attrValues vms);
      subnetPrefix = lib.concatStringsSep "." (lib.take 3 (lib.splitString "." netCfg.hostAddress));
      vmAddress = vmCfg: "${subnetPrefix}.${toString vmCfg.vmAddressSuffix}";
      # Same derivations the guest baseline uses, so the host's tap match + DHCP
      # lease always agree with the interface the guest declares — nothing is
      # hand-set in two places.
      vmLib = import ../../vm/lib.nix;
    in
    {
      # mkIf (not lib.optional) so the definition disappears entirely when no
      # VM is enabled: the NixOS test framework's read-only.nix declares
      # nixpkgs.overlays as a unique option, and even an empty [] definition
      # here would conflict with it during VM smoke tests.
      nixpkgs.overlays = lib.mkIf anyEnabled [ inputs.microvm.overlay ];

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
        # Bridge network + DHCP server — contributed by each enabled VM; the
        # scalar leaves are mkDefault (identical across VMs, overridable) while
        # the static-lease list is left unwrapped so each VM's lease merges in.
        (lib.mapAttrsToList (
          _vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-microvm0" = {
              matchConfig.Name = lib.mkDefault "microvm0";
              networkConfig = {
                Address = lib.mkDefault "${netCfg.hostAddress}/${toString netCfg.prefixLength}";
                ConfigureWithoutCarrier = lib.mkDefault true;
                IPv4Forwarding = lib.mkDefault true;
                DHCPServer = lib.mkDefault true;
              };
              linkConfig.RequiredForOnline = lib.mkDefault "no";
            };
          }
        ) vms)
        # Per-VM DHCP static lease — concatenated into the bridge's lease list so
        # each guest gets a stable address keyed on its (name-derived) MAC.
        ++ (lib.mapAttrsToList (
          vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-microvm0".dhcpServerStaticLeases = [
              {
                MACAddress = vmLib.mac vmName;
                Address = vmAddress vmCfg;
              }
            ];
          }
        ) vms)
        # Per-VM TAP — unique key per instance, enslaved to the bridge. The
        # matched interface name is the derived (length-safe) tap name.
        ++ (lib.mapAttrsToList (
          vmName: vmCfg:
          lib.mkIf vmCfg.enable {
            "10-tap-${vmName}" = lib.mkDefault {
              matchConfig.Name = vmLib.tapName vmName;
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
          # An instance with hostInterface = "" wants no internet access and
          # must not contribute here — otherwise it conflicts with any other
          # enabled instance that does set a real interface.
          lib.mkIf (vmCfg.enable && vmCfg.hostInterface != "") {
            externalInterface = lib.mkDefault vmCfg.hostInterface;
          }
        ) vms
      );

      # ── Host-side directories ──────────────────────────────────────────────
      # Per instance: the state dir (holds volume images microvm.nix creates) and
      # the auto share dir the guest baseline mounts at /srv/host-share. The
      # state-dir rule sorts before its /share child, so systemd-tmpfiles creates
      # the parent first.
      systemd.tmpfiles.rules = lib.concatLists (
        lib.mapAttrsToList (
          vmName: vmCfg:
          lib.optionals vmCfg.enable (
            [
              "d /var/lib/microvm/${vmName} 0750 microvm - -"
              "d /var/lib/microvm/${vmName}/share 0770 ${vmCfg.shareOwner} ${vmCfg.shareGroup} -"
            ]
            # Mountpoint for the read-only sops-tree bind-mount (below), created
            # only for VMs that opt into shareSecrets.
            ++ lib.optional vmCfg.shareSecrets "d /var/lib/microvm/${vmName}/secrets 0700 root - -"
          )
        ) vms
      );

      # ── Host-shared sops secrets ───────────────────────────────────────────
      # For each VM with shareSecrets, bind-mount the consumer's encrypted sops
      # tree read-only at the path its guest (ft.vmSecrets) reads over virtiofs.
      # Encrypted at rest; only a guest holding the matching age key decrypts it.
      fileSystems = lib.mkMerge (
        lib.mapAttrsToList (
          vmName: vmCfg:
          lib.mkIf (vmCfg.enable && vmCfg.shareSecrets) {
            "/var/lib/microvm/${vmName}/secrets" = {
              device = "${config.ft.repoPath}/var/secrets";
              # fsType "none" is required for a bind mount — fileSystems.<>.fsType
              # has no default, and leaving it unset errors once the mount is
              # forced to evaluate (as an enabled shareSecrets instance does).
              fsType = "none";
              options = [
                "bind"
                "ro"
              ];
            };
          }
        ) vms
      );

      assertions = lib.mapAttrsToList (vmName: vmCfg: {
        assertion =
          !(vmCfg.enable && vmCfg.shareSecrets) || config.ft.repoPath != options.ft.repoPath.default;
        message = "ft.microvms.instances.${vmName}.shareSecrets needs ft.repoPath set to your consumer repo so var/secrets can be shared into the VM — it is still the framework default (\"${options.ft.repoPath.default}\").";
      }) vms;

      # ── VM definitions — ATTACH BY REFERENCE ───────────────────────────────
      # microvm.vms.<name>.flake = self pulls self.nixosConfigurations.<name>
      # (the standalone guest built by flake-parts/vms.nix) rather than building
      # a guest inline here. `self` is the consumer flake: the generator passes
      # the merged input set (consumer self winning) as specialArgs, and that is
      # the flake carrying vms/<name>'s nixosConfigurations entry. Only forced
      # when an instance is enabled, so framework/docs/test evals (no enabled
      # instances) never touch it.
      microvm.vms = lib.mapAttrs (
        _vmName: vmCfg:
        lib.mkIf vmCfg.enable {
          flake = inputs.self;
          autostart = lib.mkDefault true;
        }
      ) vms;
    };
}
