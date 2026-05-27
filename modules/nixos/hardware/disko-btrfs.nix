{
  config,
  lib,
  ...
}:

let
  cfg = config.ft.hardware.diskBtrfs;

  btrfsContent = {
    type = "btrfs";
    extraArgs = [ "-f" ];
    subvolumes = {
      "@" = {
        mountpoint = "/";
        mountOptions = [
          "noatime"
          "compress=zstd"
        ];
      };
      "@home" = {
        mountpoint = "/home";
        mountOptions = [
          "noatime"
          "compress=zstd"
        ];
      };
    };
  };
in
{
  # disko is injected by nixosModules.default in flake-parts/exports.nix;
  # no imports needed here.

  options.ft.hardware.diskBtrfs = {
    enable = lib.mkEnableOption "btrfs system disk layout with optional LUKS" // {
      description = "Configures a GPT disk with a 1 GiB ESP and a btrfs root partition containing subvolumes @ (/) and @home (/home) with zstd compression. Optionally wraps the btrfs partition in a LUKS2 container.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/nvme0n1";
      description = "Block device to partition (e.g. /dev/nvme0n1).";
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
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices = lib.mkDefault {
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
    };
  };
}
