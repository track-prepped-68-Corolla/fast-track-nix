# =============================================================================
# microVM guest baseline — injected into every vms/<name> by flake-parts/vms.nix
# =============================================================================
#
# The generic "this is a microVM guest" scaffolding, analogous to how machines
# get a baseline. NOT a flake-parts module and NOT part of the modules/nixos hub
# (so it is never applied to hosts) — imported explicitly by the vms generator.
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

  # The VM is reachable only from the host bridge, so the guest firewall adds
  # friction without a threat model to justify it.
  networking.firewall.enable = lib.mkDefault false;

  system.stateVersion = lib.mkDefault "25.05";
}
