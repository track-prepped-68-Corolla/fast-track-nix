# =============================================================================
# Shared microVM naming helpers
# =============================================================================
#
# Used by BOTH the host module (ft.microvms, modules/nixos/services/microvm.nix)
# and the guest baseline (vm-guest-base.nix) so a VM's tap interface name and MAC
# are derived identically on both sides from its name — the guest declares the
# interface, the host declares the matching DHCP static lease + bridge port, and
# neither can drift from a hand-written value. Plain attrset of pure helpers
# (needs no lib — only builtins), not a NixOS module, so it is never picked up
# by the module hub.
# =============================================================================
rec {
  # Deterministic tap interface name for a VM, ALWAYS <= 15 chars (Linux
  # IFNAMSIZ caps interface names at 15). "tap-<name>" when it fits; otherwise a
  # 7-char name prefix plus 4 hex chars of the name's sha256, which keeps it
  # within the limit and unique across VMs. Removes the footgun where a VM name
  # longer than 11 chars produced a rejected 16+-char interface name.
  tapName =
    name:
    let
      full = "tap-${name}";
    in
    if builtins.stringLength full <= 15 then
      full
    else
      "tap-${builtins.substring 0 7 name}${builtins.substring 0 4 (builtins.hashString "sha256" name)}";

  # Deterministic locally-administered unicast MAC (first octet 02) derived from
  # the VM name, so the guest's interface MAC and the host's DHCP static lease
  # agree without the consumer setting the same MAC in two decoupled places.
  mac =
    name:
    let
      h = builtins.hashString "sha256" name;
      byte = i: builtins.substring (i * 2) 2 h;
    in
    "02:${byte 0}:${byte 1}:${byte 2}:${byte 3}:${byte 4}";
}
