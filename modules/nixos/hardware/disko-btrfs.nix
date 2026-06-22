{
  config,
  lib,
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
      description = "Configures a GPT disk with a 1 GiB ESP and a btrfs root partition containing subvolumes @home (/home), @nix (/nix, nodatacow), @src (/src), and @snapshots (/.snapshots) with zstd compression. Optionally wraps the btrfs partition in a LUKS2 container. When impermanence.enable is set, replaces the @ root subvolume with a tmpfs ramdisk and adds @persist (/persist) for durable state.";
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
