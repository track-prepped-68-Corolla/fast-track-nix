# =============================================================================
# ISO `findiso=` support for the systemd initrd (Ventoy / GRUB loopback boot)
# =============================================================================
#
# Added to ISO image machines by flake-parts/generator.nix, NOT to any real
# machine — it lives under modules/installer/ rather than modules/nixos/ so the
# framework module hub never picks it up.
#
# When an ISO is booted from a file on another disk (Ventoy's GRUB2 mode, or a
# GRUB `loopback` entry), the ISO's own grub.cfg appends `findiso=<path>` to the
# kernel command line. The scripted initrd used to resolve that by mounting the
# disk holding the file and loop-mounting the ISO. nixpkgs removed the scripted
# initrd, and the systemd initrd has no equivalent, so `/iso` (mounted by
# label) never appears and boot drops to emergency mode.
#
# This unit restores the behaviour: when `findiso=` is present it scans block
# devices for the named file, keeps the holding filesystem mounted at
# /run/findiso (moved into the real root at switch-root, so the loop device's
# backing file stays reachable), and attaches the ISO read-only as a loop
# device. udev then publishes the ISO's volume label, and nixpkgs' own
# sysroot-iso.mount proceeds as it does for a USB stick. Without `findiso=` the
# unit is skipped entirely.
{ pkgs, ... }:
{
  # Ventoy's data partition is exFAT by default; NTFS and FAT are also common
  # for a disk carrying ISO files.
  boot.initrd.supportedFilesystems = [
    "exfat"
    "ntfs3"
    "vfat"
  ];

  boot.initrd.systemd = {
    initrdBin = [ pkgs.util-linux ];

    services.ft-findiso = {
      description = "Attach the ISO named by findiso= as a loop device";
      unitConfig = {
        DefaultDependencies = false;
        ConditionKernelCommandLine = "findiso";
      };
      requiredBy = [ "sysroot-iso.mount" ];
      before = [ "sysroot-iso.mount" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        read -r cmdline < /proc/cmdline
        iso=""
        for arg in $cmdline; do
          case "$arg" in
            findiso=*) iso="''${arg#findiso=}" ;;
          esac
        done
        [ -n "$iso" ] || exit 0

        mnt=/run/findiso
        mkdir -p "$mnt"
        # Block devices can still be appearing; retry for up to a minute.
        for _ in $(seq 60); do
          for dev in $(lsblk -lnpo NAME); do
            mount -o ro "$dev" "$mnt" 2>/dev/null || continue
            if [ -f "$mnt$iso" ]; then
              losetup --find --read-only --show "$mnt$iso"
              exit 0
            fi
            umount "$mnt"
          done
          sleep 1
        done
        echo "findiso: $iso not found on any block device" >&2
        exit 1
      '';
    };
  };
}
