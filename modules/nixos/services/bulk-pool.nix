{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# BULK STORAGE POOL — mergerfs + snapraid-btrfs
#
# Drives are prepared by `ft drives-format` (creates btrfs label bulk-*, @data
# and @snapshots subvolumes) and registered in machines/<host>/var/bulk-drives.nix.
# Use `ft drives-sync` to reconcile the file when the array changes.
# This module reads that file, mounts btrfs roots, builds a mergerfs pool over
# data+cache drives, and runs snapraid-btrfs nightly against parity drives.
#
# Label convention (enforced by ft drives-format):
#   bulk-parity-N  →  snapraid parity drive (not in pool)
#   bulk-cache-N   →  mergerfs cache (in pool, not in snapraid)
#   bulk-*         →  data drive (in pool and in snapraid)
################################################################################

let
  cfg = config.ft.bulkPool;

  # snapraid-btrfs is not in nixpkgs; package it inline from the maintained fork.
  snapraidBtrfs = pkgs.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      makeWrapper,
      coreutils,
      gnugrep,
      gawk,
      gnused,
      snapraid,
      snapper,
      lib,
    }:
    stdenv.mkDerivation {
      pname = "snapraid-btrfs";
      version = "0-unstable-2024-01-01";
      src = fetchFromGitHub {
        owner = "D34DC3N73R";
        repo = "snapraid-btrfs";
        rev = "a43e9a40773772b881b1450edfef28c9937f5f27";
        hash = "sha256-zOFc1/H2hgcZMeGUnLvuWL+SFvE5kvekm0F/dvhakWI=";
      };
      dontBuild = true;
      nativeBuildInputs = [ makeWrapper ];
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp snapraid-btrfs $out/bin/
        chmod +x $out/bin/snapraid-btrfs
        patchShebangs $out/bin/snapraid-btrfs
        wrapProgram $out/bin/snapraid-btrfs \
          --prefix PATH : ${
            lib.makeBinPath [
              coreutils
              gnugrep
              gawk
              gnused
              snapraid
              snapper
            ]
          }
        runHook postInstall
      '';
      meta = {
        description = "Wrapper script to ease using snapraid with btrfs snapshots";
        homepage = "https://github.com/D34DC3N73R/snapraid-btrfs";
        license = lib.licenses.gpl3Plus;
        platforms = lib.platforms.linux;
        mainProgram = "snapraid-btrfs";
      };
    }
  ) { };

  drives =
    if cfg.drivesFile == null then
      {
        parity = [ ];
        data = [ ];
        cache = [ ];
      }
    else if builtins.pathExists cfg.drivesFile then
      import cfg.drivesFile
    else
      {
        parity = [ ];
        data = [ ];
        cache = [ ];
      };

  allDrives = drives.parity ++ drives.data ++ drives.cache;
  poolDrives = drives.data ++ drives.cache;
  hasAny = allDrives != [ ];
  hasPool = poolDrives != [ ];
  hasSnapraid = drives.parity != [ ] && drives.data != [ ];

  # Runs at boot; warns about missing drives but exits 0 so boot is not blocked.
  driveCheckScript = pkgs.writeShellScript "bulk-pool-check" (
    ''
      missing=0
    ''
    + lib.concatMapStrings (label: ''
      if [[ ! -e /dev/disk/by-label/${label} ]]; then
        echo "WARNING: bulk drive ${label} is not present" >&2
        missing=1
      fi
    '') allDrives
    + ''
      if [[ $missing -eq 1 ]]; then
        echo "WARNING: one or more bulk drives are missing — pool may be degraded" >&2
      fi
      exit 0
    ''
  );

  # Wraps snapraid-btrfs sync; blocks if any expected drive is absent.
  snapraidSyncScript = pkgs.writeShellScript "bulk-pool-snapraid-sync" (
    ''
      missing=()
    ''
    + lib.concatMapStrings (label: ''
      if [[ ! -e /dev/disk/by-label/${label} ]]; then
        missing+=("${label}")
      fi
    '') allDrives
    + ''
      if [[ ''${#missing[@]} -gt 0 ]]; then
        echo "ERROR: snapraid sync blocked — missing bulk drives: ''${missing[*]}" >&2
        exit 1
      fi
      exec ${snapraidBtrfs}/bin/snapraid-btrfs sync
    ''
  );

in
{
  options.ft.bulkPool = {
    enable = lib.mkEnableOption "mergerfs + snapraid-btrfs bulk storage pool" // {
      description = "Reads machines/<host>/var/bulk-drives.nix to discover registered bulk drives (labelled bulk-*), mounts each btrfs root, pools data and cache drives via mergerfs, protects data drives with snapraid parity, and runs a nightly snapraid-btrfs sync. A no-op when drivesFile is unset or all drive lists are empty.";
    };

    drivesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the bulk-drives.nix file listing registered drive labels by role (parity, data, cache). Managed by ft drives-format and ft drives-sync in the consumer repo. When null or the file is absent, the module is a complete no-op.";
    };

    driveBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk";
      description = "Directory prefix for individual drive mount points (e.g. /mnt/bulk/bulk-data-1 mounts the btrfs root of that drive).";
    };

    poolMount = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk-pool";
      description = "Mount point for the mergerfs union pool of data and cache drives (@data subvolume of each).";
    };

    snapraid = {
      contentFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/snapraid/content";
        description = "Primary snapraid content file path on the system drive (not on a data disk).";
      };
    };
  };

  config = lib.mkMerge [

    # ── Always install tools when enabled (needed before any drives are registered) ──
    (lib.mkIf cfg.enable {
      environment.systemPackages =
        (with pkgs; [
          mergerfs
          snapraid
          btrfs-progs
          util-linux
          parted
          jq
        ])
        ++ [ snapraidBtrfs ];
    })

    # ── Drive presence check — warns on missing drives, never blocks boot ───────
    (lib.mkIf (cfg.enable && hasAny) {
      systemd.services.bulk-pool-check = {
        description = "Bulk storage pool drive presence check";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${driveCheckScript}";
        };
      };
    })

    # ── Individual drive mounts (btrfs root, no subvol restriction) ────────────
    (lib.mkIf (cfg.enable && hasAny) {

      fileSystems = lib.listToAttrs (
        map (
          label:
          lib.nameValuePair "${cfg.driveBase}/${label}" {
            device = "/dev/disk/by-label/${label}";
            fsType = "btrfs";
            options = [
              "noatime"
              "nofail"
              "x-systemd.device-timeout=5"
            ];
          }
        ) allDrives
      );
    })

    # ── MergerFS pool over @data subvolumes of data + cache drives ─────────────
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

    # ── SnapRAID parity + nightly snapraid-btrfs sync ──────────────────────────
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
        after = [
          "local-fs.target"
          "multi-user.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${snapraidSyncScript}";
        };
      };

      systemd.timers.snapraid-btrfs-sync = {
        description = "Nightly SnapRAID-btrfs parity sync";
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };
    })

  ];
}
