# =============================================================================
# microVM guest baseline — injected into every vms/<name> by flake-parts/vms.nix
# =============================================================================
#
# The generic "this is a microVM guest" scaffolding, analogous to how machines
# get a baseline. It is a NixOS module, so it lives under modules/ (not
# flake-parts/) — in its own modules/vm/ subtree, deliberately NOT inside the
# modules/nixos hub, so listFilesRecursive never applies it to a real host. It
# is imported explicitly by flake-parts/vms.nix, which pulls it into guests only.
#
# A consumer's vms/<name>/default.nix then only sets what makes that VM specific:
# ft.* features (e.g. ft.containers + ft.komodo for a docker VM), resources, and
# its tap interface. Addressing is DHCP from the host bridge (the host assigns a
# static lease keyed on the interface MAC), so nothing host-specific is baked in.
# =============================================================================
{ config, lib, ... }:
let
  vmLib = import ./lib.nix;
  # The VM's name — the generator sets hostName to the vms/<name> dir name, and
  # ft.microvms uses that same instance name, so deriving from it keeps the guest
  # and host in agreement.
  name = config.networking.hostName;
in
{
  microvm = {
    # Cloud Hypervisor is lightweight like Firecracker but supports virtiofs
    # shares, which the framework's host infra relies on.
    hypervisor = lib.mkDefault "cloud-hypervisor";
    vcpu = lib.mkDefault 2;
    mem = lib.mkDefault 2048;

    # Auto tap interface — name and MAC derived from the VM name so they always
    # agree with the host's ft.microvms tap + DHCP static lease, and the
    # interface name never exceeds Linux's 15-char limit (vmLib.tapName
    # truncates). Nothing for the consumer to wire up or keep in sync. mkDefault
    # so a vms/<name> needing custom/multiple interfaces can replace it — but it
    # must then keep the MAC consistent with the host lease, or forgo the lease.
    interfaces = lib.mkDefault [
      {
        type = "tap";
        id = vmLib.tapName name;
        mac = vmLib.mac name;
      }
    ];

    # Auto host share — the companion to ft.microvms' per-instance share dir.
    # The host creates /var/lib/microvm/<name>/share and we mount it here over
    # virtiofs at /srv/host-share, keyed on the VM name (the host uses the same
    # instance name, and the generator sets hostName to it), so every VM gets a
    # host-backed, host-browsable data dir with nothing to wire up. mkDefault so
    # a vms/<name> can opt out (microvm.shares = []) or repoint — but note that
    # any normal-priority microvm.shares definition REPLACES this default
    # wholesale, so a VM that wants extra shares must re-include this entry.
    shares = lib.mkDefault [
      {
        source = "/var/lib/microvm/${name}/share";
        mountPoint = "/srv/host-share";
        tag = "vm-share";
        proto = "virtiofs";
      }
    ];
  };

  # DHCP client — the guest carries no static address; the host bridge's DHCP
  # server hands it one via a MAC-keyed static lease. Keeps the image free of
  # host-specific placement state.
  systemd.network.enable = lib.mkDefault true;
  systemd.network.networks."10-eth" = {
    matchConfig.Name = lib.mkDefault "en*";
    networkConfig.DHCP = lib.mkDefault "yes";
  };

  # The guest is driven entirely by systemd-networkd (above). ft.core is enabled
  # by default and turns on NetworkManager, which would fight networkd for the
  # single virtio NIC — both racing to configure it leaves the guest
  # intermittently unreachable (reachable one boot, ARP-dead the next). A
  # headless microVM has no use for NM (or its wpa_supplicant), so turn it off
  # here. Normal priority deliberately outranks ft.core's `mkDefault true`; a
  # vms/<name> that genuinely needs NM can re-enable it with mkForce.
  networking.networkmanager.enable = false;

  # Firewall stays at the NixOS default (enabled): guests can share a host
  # bridge, so nothing is trusted implicitly. A VM that needs inbound access
  # opens its own ports (or disables the firewall) in its vms/<name> config.

  # ft.cli is on by default, but the `ft` wrapper drives `just` recipes against
  # a consumer repo checkout via ft.repoPath — a headless microVM guest has no
  # such checkout (ft.repoPath stays at the framework default, which the ft.cli
  # assertion rejects). Disable it in the baseline, exactly as the framework's
  # test-only machines do; a specific vms/<name> that genuinely mounts a repo can
  # set ft.cli.enable = true + ft.repoPath at normal priority to override this.
  ft.cli.enable = lib.mkDefault false;

  # ft.core is enabled by default and assigns system.stateVersion = cfg.stateVersion
  # with a plain (non-mkDefault) assignment, and ft.core.stateVersion has no
  # default — every consumer must set it. A guest is analogous to a machine, so
  # the baseline provides it via ft.core.stateVersion (the framework's canonical
  # knob), letting a specific vms/<name> override at normal priority.
  ft.core.stateVersion = lib.mkDefault "25.05";

  # Fallback for a guest that opts out of ft.core (ft.core.enable = false): its
  # config block never runs, so nothing would set system.stateVersion otherwise.
  system.stateVersion = lib.mkDefault "25.05";
}
