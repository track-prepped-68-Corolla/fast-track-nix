{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# BULK STORAGE POOL — mergerfs + snapraid-btrfs
################################################################################

let
  cfg = config.ft."bulk-pool";

  drives =
    if cfg.drivesFile == null then
      { parity = [ ]; data = [ ]; cache = [ ]; }
    else if builtins.pathExists cfg.drivesFile then
      import cfg.drivesFile
    else
      { parity = [ ]; data = [ ]; cache = [ ]; };

  allDrives = drives.parity ++ drives.data ++ drives.cache;
  poolDrives = drives.data ++ drives.cache;
  hasAny = allDrives != [ ];
  hasPool = poolDrives != [ ];
  hasSnapraid = drives.parity != [ ] && drives.data != [ ];
in
{
  meta.description = "Reads machines/<host>/var/bulk-drives.nix to discover registered bulk drives (labelled bulk-*), mounts each btrfs root, pools data and cache drives via mergerfs, protects data drives with snapraid parity, and runs a nightly snapraid-btrfs sync. A no-op when drivesFile is unset or all drive lists are empty.";

  options.ft."bulk-pool" = {
    drivesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the bulk-drives.nix file listing registered drive labels by role (parity, data, cache).";
    };

    driveBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk";
      description = "Directory prefix for individual drive mount points.";
    };

    poolMount = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk-pool";
      description = "Mount point for the mergerfs union pool.";
    };

    snapraid = {
      contentFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/snapraid/content";
        description = "Primary snapraid content file path on the system drive.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        mergerfs
        snapraid
        snapraid-btrfs
        btrfs-progs
        util-linux
        parted
        jq
      ];
    })

    (lib.mkIf (cfg.enable && hasAny) {
      fileSystems = lib.listToAttrs (
        map (
          label:
          lib.nameValuePair "${cfg.driveBase}/${label}" {
            device = "/dev/disk/by-label/${label}";
            fsType = "btrfs";
            options = [ "noatime" "nofail" "x-systemd.device-timeout=5" ];
          }
        ) allDrives
      );
    })

    (lib.mkIf (cfg.enable && hasPool) {
      fileSystems."${cfg.poolMount}" = {
        device = lib.concatStringsSep ":" (map (l: "${cfg.driveBase}/${l}/@data") poolDrives);
        fsType = "fuse.mergerfs";
        depends = map (l: "${cfg.driveBase}/${l}") poolDrives;
        options = [
          "defaults"
          "allow_other"
          "use_ino"
          "cache.files=partial"
          "dropcacheonclose=true"
          "category.create=mfs"
          "moveonenospc=true"
          "minfreespace=4G"
          "nofail"
        ];
      };
    })

    (lib.mkIf (cfg.enable && hasSnapraid) {
      services.snapraid = {
        enable = lib.mkDefault true;
        parityFiles = lib.mkDefault (map (l: "${cfg.driveBase}/${l}/snapraid.parity") drives.parity);
        dataDisks = lib.mkDefault (
          lib.listToAttrs (
            lib.imap1 (i: l: lib.nameValuePair "d${toString i}" "${cfg.driveBase}/${l}/@data") drives.data
          )
        );
        contentFiles = lib.mkDefault (
          [ cfg.snapraid.contentFile ] ++ map (l: "${cfg.driveBase}/${l}/@data/snapraid.content") drives.data
        );
      };

      systemd.services.snapraid-btrfs-sync = {
        description = "SnapRAID-btrfs nightly parity sync";
        after = [ "local-fs.target" "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.snapraid-btrfs}/bin/snapraid-btrfs sync";
        };
      };

      systemd.timers.snapraid-btrfs-sync = {
        description = "Nightly SnapRAID-btrfs parity sync";
        timerConfig = { OnCalendar = "daily"; Persistent = true; };
        wantedBy = [ "timers.target" ];
      };
    })
  ];
}
