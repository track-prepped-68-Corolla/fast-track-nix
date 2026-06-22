# =============================================================================
# Kexec unattended auto-install module
# =============================================================================
#
# Added to the kexec INSTALLER system (flake-parts/kexec.nix), NOT to any real
# machine — it lives under modules/installer/ rather than modules/nixos/ so the
# framework module hub never picks it up.
#
# When the kexec image boots, this oneshot:
#   1. runs the target machine's disko script (partition + mount the configured
#      device at /mnt),
#   2. installs the baked-in target system closure offline (no network), and
#   3. reboots into the freshly installed system.
#
# No secrets or repo are baked in (host-key option B): the SSH host key is
# generated fresh on first boot, and sops + the consumer repo are wired
# afterward (see the post-install steps printed by `ft bootstrap-kexec`).
#
# This is parameterised by the target machine via a small function so
# flake-parts/kexec.nix can build one installer per machine.
{
  name,
  toplevel,
  diskoScript,
}:
{ pkgs, ... }:
{
  systemd.services.ft-kexec-install = {
    description = "Fast Track unattended kexec install (${name})";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    path = [
      pkgs.nixos-install-tools
      pkgs.util-linux
      pkgs.coreutils
    ];
    script = ''
      set -euo pipefail
      echo ":: Fast Track kexec install for ${name} starting ::"

      echo ":: Partitioning and mounting the target disk (disko) ::"
      ${diskoScript}

      echo ":: Installing the baked system closure offline ::"
      nixos-install --system ${toplevel} --root /mnt --no-root-passwd

      echo ":: Install complete — rebooting into the installed system ::"
      systemctl reboot
    '';
  };
}
