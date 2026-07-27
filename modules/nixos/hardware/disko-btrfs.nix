{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ft.diskBtrfs;

  defaultDevice = "/dev/nvme0n1";

  commonSubvolumes = {
    "@home" = {
      mountpoint = "/home";
      mountOptions = [
        "noatime"
        "compress=zstd"
      ];
    };
    "@nix" = {
      mountpoint = "/nix";
      # nodatacow and compression are mutually exclusive in btrfs.
      mountOptions = [
        "noatime"
        "nodatacow"
      ];
    };
    "@snapshots" = {
      mountpoint = "/.snapshots";
      mountOptions = [
        "noatime"
        "compress=zstd"
      ];
    };
    "@src" = {
      mountpoint = "/src";
      mountOptions = [
        "noatime"
        "compress=zstd"
      ];
    };
  };

  btrfsContent = {
    type = "btrfs";
    extraArgs = [ "-f" ];
    subvolumes =
      commonSubvolumes
      // lib.optionalAttrs (!cfg.impermanence.enable) {
        "@" = {
          mountpoint = "/";
          mountOptions = [
            "noatime"
            "compress=zstd"
          ];
        };
      }
      // lib.optionalAttrs cfg.impermanence.enable {
        "@persist" = {
          mountpoint = "/persist";
          mountOptions = [
            "noatime"
            "compress=zstd"
          ];
        };
      };
  };
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  # disko is injected by nixosModules.default in flake-parts/exports.nix;
  # no imports needed here.

  options.ft.diskBtrfs = {
    enable = lib.mkEnableOption "btrfs system disk layout with optional LUKS" // {
      description = "Sets up disk partitioning for a machine: a small 1 GiB boot partition (ESP) and a btrfs root split into subvolumes for `/home`, `/nix` (with copy-on-write turned off), `/src`, and `/.snapshots`, all using zstd compression. You can optionally wrap the btrfs partition in LUKS2 encryption. When `impermanence.enable` is on, the root subvolume becomes a tmpfs ramdisk that's wiped on every boot, with a separate `@persist` subvolume added at `/persist` to hold the state that should survive. `/src` is set up so members of the `wheel` group can write to it without `sudo` — it's owned `root:wheel` with permissions `2775` and a default ACL that grants group-write on everything created inside it, plus a repair pass at boot that fixes older files created before the ACL existed. Git's global `safe.directory` protection is also turned off system-wide, because every repository under `/src` gets placed there as root by `nixos-anywhere` during provisioning.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = defaultDevice;
      description = "The block device to partition, for example `/dev/nvme0n1`.";
    };

    confirmDevice = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "A safety check: if you change `device` away from the framework default (${defaultDevice}), you must also set this to the exact same value. It's a typed double-entry confirmation — if a deploy script or a person picks the wrong disk, the mismatch causes evaluation to fail before disko or nixos-anywhere ever touches the storage.";
    };

    excludeDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "A list of device paths that should never be used as the install target — for example, the live installer's own boot media. If `device` matches any of these, evaluation fails.";
    };

    luks = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Encrypts the btrfs partition inside a LUKS2 container.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        default = "cryptroot";
        description = "The name given to the LUKS device, which shows up under `/dev/mapper/`.";
      };

      tpm.enable = lib.mkEnableOption "TPM2+PIN unlock for the LUKS volume" // {
        description = "Lets you unlock the LUKS volume at boot with a short PIN instead of typing the full passphrase, using a key sealed inside the TPM2 chip. Turning this on switches the initrd to systemd and adds `tpm2-device=auto` to the device's crypttab options, so boot prompts for the PIN (the TPM rate-limits guesses) while the original passphrase keyslot stays available as a fallback. It doesn't bind to any boot-chain measurements (PCRs) — the PIN itself is the secret. This option only wires up the configuration; you still need to run `systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes <luks-partition>` once after installing to actually add the TPM+PIN keyslot, since the PIN can't be declared in config. Requires `luks.enable` to also be on.";
      };
    };

    impermanence = {
      enable = lib.mkEnableOption "impermanence (tmpfs root at / with @persist for durable state)" // {
        description = "Makes the root filesystem ephemeral: replaces the btrfs root subvolume with a tmpfs ramdisk at `/`, so anything not explicitly kept is wiped on reboot, and adds a `@persist` subvolume at `/persist` for the state you do want to keep. This turns on the impermanence NixOS module, which persists `/etc/machine-id`, `/etc/ssh`, `/var/lib`, and `/var/log` by default.";
      };

      rootSize = lib.mkOption {
        type = lib.types.str;
        default = "2G";
        description = "How large the tmpfs ramdisk at `/` is, when `impermanence.enable` is turned on.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.device == defaultDevice || cfg.device == cfg.confirmDevice;
        message = ''
          ft.diskBtrfs.device is set to "${cfg.device}", which differs from the framework
          default ("${defaultDevice}"), but ft.diskBtrfs.confirmDevice ("${cfg.confirmDevice}")
          does not match it. Set confirmDevice to the same value as device to confirm this is
          the disk you intend to wipe.
        '';
      }
      {
        assertion = !(builtins.elem cfg.device cfg.excludeDevices);
        message = ''
          ft.diskBtrfs.device ("${cfg.device}") is listed in ft.diskBtrfs.excludeDevices and
          cannot be used as the install target.
        '';
      }
      {
        assertion = !cfg.luks.tpm.enable || cfg.luks.enable;
        message = "ft.diskBtrfs.luks.tpm.enable requires ft.diskBtrfs.luks.enable = true.";
      }
    ];

    disko.devices = lib.mkDefault (
      {
        disk.main = {
          type = "disk";
          inherit (cfg) device;
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "fmask=0077"
                    "dmask=0077"
                  ];
                };
              };
              root = {
                size = "100%";
                content =
                  if cfg.luks.enable then
                    {
                      type = "luks";
                      name = cfg.luks.label;
                      content = btrfsContent;
                    }
                  else
                    btrfsContent;
              };
            };
          };
        };
      }
      // lib.optionalAttrs cfg.impermanence.enable {
        nodev."/" = {
          fsType = "tmpfs";
          mountOptions = [
            "defaults"
            "size=${cfg.impermanence.rootSize}"
            "mode=755"
          ];
        };
      }
    );

    # All users can read /src; wheel group members can write without sudo.
    # setgid ensures new files/dirs inherit the wheel group.
    systemd.tmpfiles.rules = [ "d /src 2775 root wheel - -" ];

    # setgid only inherits group *ownership*, not the write bit. This bites on
    # every fresh install via the documented bootstrap flow, not just unusual
    # setups: bootstrap.just's deploy/deploy-local recipes stage this repo with
    # `cp -a` (preserving the operator's own clone's permission bits verbatim,
    # which have no group-write since a plain `git clone` has no reason to
    # anticipate landing in a group-writable directory) and hand it to
    # nixos-anywhere's --extra-files, so the very first /src/<repo> on a new
    # machine is already group-owned by wheel but not group-writable.
    #
    # This unit does two things on every boot, both idempotent:
    #   1. A default ACL (setfacl -d) so everything created under /src from
    #      here on is group-writable regardless of the creating process's
    #      umask — propagates to new subdirectories automatically, since they
    #      inherit their parent's default ACL as their own.
    #   2. A recursive chown/chmod repair pass, so files that already existed
    #      before this unit ever ran (e.g. the very first nixos-anywhere
    #      bundle, which predates the default ACL) get fixed automatically on
    #      the next boot instead of requiring a one-time manual chmod. Safe to
    #      re-run indefinitely: chown/chmod are no-ops once permissions are
    #      already correct.
    systemd.services.ftSrcDefaultAcl = {
      description = "Apply and repair /src group-write permissions so they survive any umask or pre-existing state";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathIsMountPoint = "/src";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # A plain string (bash -c + a quoted script), not writeShellScript:
        # keeps ExecStart eval-inspectable as a literal string (see
        # checks.srcDefaultAcl) without needing to build a wrapper derivation.
        ExecStart = "${lib.getExe' pkgs.bash "bash"} -c ${lib.escapeShellArg ''
          ${lib.getExe' pkgs.acl "setfacl"} -d -m g:wheel:rwx /src
          ${lib.getExe' pkgs.coreutils "chown"} -R root:wheel /src
          ${lib.getExe' pkgs.coreutils "chmod"} -R g+rwX /src
          ${lib.getExe' pkgs.findutils "find"} /src -type d -exec ${lib.getExe' pkgs.coreutils "chmod"} g+s {} +
        ''}";
      };
    };

    # git refuses to operate on a repository whose files are owned by a
    # different UID than the process running git (a guard against local
    # privilege escalation via untrusted repos placed by another user). Every
    # repo under /src is bundled by nixos-anywhere's --extra-files as root
    # during provisioning, so any non-root user hitting this is guaranteed,
    # not an edge case — matches the golden-path framing above. /src is
    # wholly owned by this module's own group-based trust model (root:wheel,
    # setgid, default ACL), not a general-purpose location where an untrusted
    # party could plant a repo, so disabling git's ownership check entirely
    # (the `*` sentinel is git's own documented way to do this) is a
    # deliberate, scoped trade-off rather than a blanket security regression.
    environment.etc."gitconfig".text = lib.mkDefault ''
      [safe]
        directory = *
    '';

    # TPM2+PIN unlock: the systemd-based initrd plus tpm2-device=auto on the
    # crypttab entry disko generates for the LUKS device. The TPM+PIN keyslot is
    # enrolled once post-install (systemd-cryptenroll --tpm2-device=auto
    # --tpm2-with-pin=yes; see ft.diskBtrfs.luks.tpm.enable); until then boot
    # falls back to the passphrase keyslot.
    boot.initrd = lib.mkIf (cfg.luks.enable && cfg.luks.tpm.enable) {
      systemd.enable = lib.mkDefault true;
      luks.devices.${cfg.luks.label}.crypttabExtraOpts = [ "tpm2-device=auto" ];
    };

    environment.persistence."/persist" = lib.mkIf cfg.impermanence.enable {
      hideMounts = lib.mkDefault true;
      directories = [
        "/var/lib"
        "/var/log"
        "/etc/ssh"
      ];
      files = [ "/etc/machine-id" ];
    };
  };
}
