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

  # Runs at boot. Fails the unit (visible in systemctl --failed) and writes a
  # login banner to /run/motd.d/ when any expected drive is absent. Cleans up
  # the banner and exits 0 when all drives are present.
  driveCheckScript = pkgs.writeShellScript "bulk-pool-check" (
    ''
      MOTD=/run/motd.d/bulk-pool-warning
      missing=()
    ''
    + lib.concatMapStrings (label: ''
      if [[ ! -e /dev/disk/by-label/${label} ]]; then
        missing+=("${label}")
      fi
    '') allDrives
    + ''
      if [[ ''${#missing[@]} -gt 0 ]]; then
        mkdir -p /run/motd.d
        {
          echo ""
          echo "  !! BULK POOL WARNING !!"
          echo "  Missing drives: ''${missing[*]}"
          echo "  Snapraid sync is suspended until all drives are present."
          echo "  Run: systemctl status bulk-pool-check"
          echo "  Run: ft drives-sync"
          echo ""
        } > "$MOTD"
        echo "ERROR: bulk pool — missing drives: ''${missing[*]}" >&2
        exit 1
      fi
      rm -f "$MOTD"
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
      description = "Sets up a pooled bulk storage array: reads machines/<host>/var/bulk-drives.nix for the drives you've registered (labelled bulk-*), mounts each one, combines the data and cache drives into a single pool with mergerfs, and protects the data drives with nightly SnapRAID parity syncs. Does nothing when drivesFile is unset or every drive list is empty.";
    };

    drivesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the bulk-drives.nix file that lists your registered drives by role (parity, data, cache). Managed by ft drives-format and ft drives-sync in the consumer repo. When this is null or the file doesn't exist, the whole module is a no-op.";
    };

    driveBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk";
      description = "Directory prefix each drive is mounted under (e.g. a drive labelled bulk-data-1 mounts at /mnt/bulk/bulk-data-1).";
    };

    poolMount = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/bulk-pool";
      description = "Where the combined mergerfs pool of data and cache drives (the @data subvolume of each) is mounted.";
    };

    snapraid = {
      contentFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/snapraid/content";
        description = "Path to SnapRAID's main content file, kept on the system drive rather than on any data disk.";
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
          RemainAfterExit = true;
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
