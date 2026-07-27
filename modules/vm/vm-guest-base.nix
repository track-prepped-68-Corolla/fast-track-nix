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
{ lib, ... }:
{
  microvm = {
    # Cloud Hypervisor is lightweight like Firecracker but supports virtiofs
    # shares, which the framework's host infra relies on.
    hypervisor = lib.mkDefault "cloud-hypervisor";
    vcpu = lib.mkDefault 2;
    mem = lib.mkDefault 2048;
  };

  # DHCP client — the guest carries no static address; the host bridge's DHCP
  # server hands it one via a MAC-keyed static lease. Keeps the image free of
  # host-specific placement state.
  systemd.network.enable = lib.mkDefault true;
  systemd.network.networks."10-eth" = {
    matchConfig.Name = lib.mkDefault "en* eth*";
    networkConfig.DHCP = lib.mkDefault "yes";
  };

  # Firewall stays at the NixOS default (enabled): guests can share a host
  # bridge, so nothing is trusted implicitly. A VM that needs inbound access
  # opens its own ports (or disables the firewall) in its vms/<name> config.

  system.stateVersion = lib.mkDefault "25.05";
}
