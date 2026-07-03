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
      description = "Configures a GPT disk with a 1 GiB ESP and a btrfs root partition containing subvolumes @home (/home), @nix (/nix, nodatacow), @src (/src), and @snapshots (/.snapshots) with zstd compression. Optionally wraps the btrfs partition in a LUKS2 container. When impermanence.enable is set, replaces the @ root subvolume with a tmpfs ramdisk and adds @persist (/persist) for durable state. /src is root:wheel 2775 with a default ACL granting wheel group-write on everything created under it (plus a boot-time repair pass for files that predate the ACL), so wheel members can write without sudo regardless of the creating process's umask or when the file was created. System-wide git safe.directory is also disabled, since every repo under /src is bundled by nixos-anywhere as root during provisioning.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = defaultDevice;
      description = "Block device to partition (e.g. /dev/nvme0n1).";
    };

    confirmDevice = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Must equal `device` whenever `device` is overridden away from the framework default (${defaultDevice}). A typed double-entry confirmation: a deploy script or a human that selects the wrong disk produces a mismatch here, which fails evaluation before disko or nixos-anywhere ever touches storage.";
    };

    excludeDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device paths that must never be used as the install target, e.g. a live installer's own boot media. Evaluation fails if `device` matches one of these.";
    };

    luks = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Wrap the btrfs partition in a LUKS2 container.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        default = "cryptroot";
        description = "Name of the LUKS dm-crypt device (appears under /dev/mapper/).";
      };

      tpm.enable = lib.mkEnableOption "TPM2+PIN unlock for the LUKS volume" // {
        description = "Unlock the LUKS volume at boot with a TPM2-sealed key gated by a PIN instead of the full passphrase: switches the initrd to systemd and adds `tpm2-device=auto` to the device's crypttab options, so early boot prompts for a short PIN (rate-limited by the TPM) and the passphrase keyslot remains as recovery. No PCR binding is configured (the PIN is the secret, not the boot-chain state). Declarative wiring only — you must run `systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes <luks-partition>` once after install to add the TPM+PIN keyslot, since the PIN is a secret and cannot be declared. Requires luks.enable.";
      };
    };

    impermanence = {
      enable = lib.mkEnableOption "impermanence (tmpfs root at / with @persist for durable state)" // {
        description = "Replace the btrfs @ root subvolume with a tmpfs ramdisk at / and add @persist (/persist) for durable state. Enables the impermanence NixOS module with /etc/machine-id, /etc/ssh, /var/lib, and /var/log persisted by default.";
      };

      rootSize = lib.mkOption {
        type = lib.types.str;
        default = "2G";
        description = "Size of the tmpfs ramdisk mounted at / when impermanence.enable is true.";
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
