{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ft.emulation;

  # On-disk directory that holds the live-editable EmuDeck config trees.
  # Activation seeds it from the Nix store (once, non-destructively); all
  # emulator config symlinks point here so users can edit without rebuilding.
  configsDir = "${cfg.emulationPath}/.configs";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${configsDir}/${sub}";

  emudeckSrc = pkgs.fetchFromGitHub {
    owner = "dragoonDorise";
    repo = "EmuDeck";
    rev = cfg.emudeckRev;
    hash = cfg.emudeckHash;
  };

  # Substitute the Steam Deck SD card stem that EmuDeck hard-codes across its
  # entire configs tree. Every absolute path uses /run/media/mmcblk0p1/Emulation
  # as a prefix, so a single sed pass covers all emulators.
  emudeckConfigsSrc = pkgs.runCommand "emudeck-configs" { } ''
    cp -r ${emudeckSrc}/configs $out
    chmod -R u+w $out
    find $out -type f -exec sed -i \
      's|/run/media/mmcblk0p1/Emulation|${cfg.emulationPath}|g' {} \;
  '';
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  options.ft.emulation = {
    enable = lib.mkEnableOption "EmuDeck-compatible emulation suite" // {
      description = "Installs the EmuDeck emulator set as Flatpak packages via nix-flatpak, seeds live-editable emulator configurations from a pinned EmuDeck source tree into emulationPath/.configs/, and symlinks each emulator's config directory there using out-of-store symlinks. Configs are copied once on first activation and never overwritten, so in-app edits persist across rebuilds. Requires services.flatpak.enable = true at the NixOS system level.";
    };

    emulationPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Emulation";
      description = "Root of the emulation library. Subdirectories roms/, bios/, saves/, storage/, and .configs/ are created here on first activation. All emulator configs are written under .configs/ and referenced via out-of-store symlinks.";
      example = "/home/alice/Emulation";
    };

    emudeckRev = lib.mkOption {
      type = lib.types.str;
      default = "125a09a37f49c013338a9bb2811505b18844c988";
      description = "EmuDeck git revision to source default configurations from. Bump together with emudeckHash to pull in newer upstream configs.";
    };

    emudeckHash = lib.mkOption {
      type = lib.types.str;
      default = lib.fakeHash;
      description = "SHA-256 hash of the EmuDeck source tree at emudeckRev in SRI format. Compute with: nix-prefetch-github dragoonDorise EmuDeck --rev <rev>. The build error will show the correct value when the placeholder is used.";
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Flatpak emulators ─────────────────────────────────────────────────────
    # Mirrors the default EmuDeck install set. Remove entries you do not need.
    # org.ryujinx.Ryujinx may be absent from Flathub — remove it if activation
    # fails with an unknown application error.
    services.flatpak.packages = lib.mkDefault [
      # Multi-system
      { appId = "org.libretro.RetroArch"; origin = "flathub"; }
      # Nintendo GC / Wii
      { appId = "org.DolphinEmu.dolphin-emu"; origin = "flathub"; }
      # Metroid Prime trilogy via Dolphin fork
      { appId = "io.github.shiiion.primehack"; origin = "flathub"; }
      # Nintendo Switch (community Ryujinx fork)
      { appId = "org.ryujinx.Ryujinx"; origin = "flathub"; }
      # Nintendo Wii U
      { appId = "info.cemu.Cemu"; origin = "flathub"; }
      # Nintendo DS / DSi
      { appId = "net.kuribo64.melonDS"; origin = "flathub"; }
      # Nintendo GBA
      { appId = "io.mgba.mGBA"; origin = "flathub"; }
      # Sony PS1
      { appId = "org.duckstation.DuckStation"; origin = "flathub"; }
      # Sony PS2
      { appId = "net.pcsx2.PCSX2"; origin = "flathub"; }
      # Sony PS3
      { appId = "net.rpcs3.RPCS3"; origin = "flathub"; }
      # Sony PSP
      { appId = "org.ppsspp.PPSSPP"; origin = "flathub"; }
      # Sony PS Vita
      { appId = "org.vita3k.Vita3K"; origin = "flathub"; }
      # Xbox (original)
      { appId = "app.xemu.xemu"; origin = "flathub"; }
      # Sega Dreamcast
      { appId = "org.flycast.Flycast"; origin = "flathub"; }
      # Classic point-and-click adventures
      { appId = "org.scummvm.ScummVM"; origin = "flathub"; }
      # Frontend
      { appId = "org.es_de.frontend"; origin = "flathub"; }
    ];

    # ── Steam ROM Manager ─────────────────────────────────────────────────────
    home.packages = [ pkgs.steam-rom-manager ];

    # ── Emulator config symlinks ──────────────────────────────────────────────
    # Each entry links the emulator's expected config location to the matching
    # subdirectory inside configsDir. Because configsDir is outside the Nix
    # store, users can edit files there without triggering a rebuild.
    # Note: Flatpak apps require home filesystem access (--filesystem=home or
    # equivalent) to follow symlinks that resolve outside ~/.var/app/<id>/.
    # Most emulator Flatpaks already request this for ROM loading.
    home.file = {
      # RetroArch
      ".var/app/org.libretro.RetroArch/config/retroarch".source =
        link "org.libretro.RetroArch/config/retroarch";
      # Dolphin (GC / Wii)
      ".var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu".source =
        link "org.DolphinEmu.dolphin-emu/config/dolphin-emu";
      # Primehack (Dolphin Metroid fork — same config layout as Dolphin)
      ".var/app/io.github.shiiion.primehack/config/dolphin-emu".source =
        link "io.github.shiiion.primehack/config/dolphin-emu";
      # Ryujinx (Switch)
      ".var/app/org.ryujinx.Ryujinx/config/Ryujinx".source =
        link "org.ryujinx.Ryujinx/config/Ryujinx";
      # Cemu (Wii U) — config lives under data/, not config/
      ".var/app/info.cemu.Cemu/data/cemu".source =
        link "info.cemu.Cemu/data/cemu";
      # melonDS (DS / DSi)
      ".var/app/net.kuribo64.melonDS/config/melonDS".source =
        link "net.kuribo64.melonDS/config/melonDS";
      # mGBA (GBA)
      ".var/app/io.mgba.mGBA/config/mgba".source =
        link "mgba";
      # DuckStation (PS1) — exposes ~/.local/share/duckstation via home override
      ".local/share/duckstation".source =
        link "duckstation";
      # PCSX2 (PS2) — Flatpak maps XDG_CONFIG_HOME/PCSX2 to the inis directory
      ".var/app/net.pcsx2.PCSX2/config/PCSX2/inis".source =
        link "pcsx2qt/.config/PCSX2/inis";
      # RPCS3 (PS3)
      ".var/app/net.rpcs3.RPCS3/config/rpcs3".source =
        link "net.rpcs3.RPCS3/config/rpcs3";
      # PPSSPP (PSP) — only the SYSTEM dir; saves and states live elsewhere
      ".var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM".source =
        link "org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM";
      # xemu (Xbox OG) — config lives under data/, not config/
      ".var/app/app.xemu.xemu/data/xemu".source =
        link "app.xemu.xemu/data/xemu";
      # Flycast (Dreamcast)
      ".var/app/org.flycast.Flycast/config/flycast".source =
        link "org.flycast.Flycast/config/flycast";
      # ScummVM
      ".var/app/org.scummvm.ScummVM/config/scummvm".source =
        link "org.scummvm.ScummVM/config/scummvm";
    };

    xdg.configFile = {
      # Vita3K — accesses ~/.config/Vita3K via home filesystem override
      "Vita3K".source = link "Vita3K";
      # ES-DE frontend — accesses ~/.config/ES-DE via home filesystem override
      "ES-DE".source = link "emulationstation";
      # Steam ROM Manager parsers and settings
      "steam-rom-manager/userData".source = link "steam-rom-manager/userData";
    };

    # ── Config seeding and directory setup ────────────────────────────────────
    # Copies EmuDeck config templates into configsDir on first activation.
    # Existing entries are never overwritten, so in-app edits survive rebuilds.
    # To reset a specific emulator to EmuDeck defaults, delete its subdirectory
    # under emulationPath/.configs/ and re-run home-manager switch.
    home.activation.seedEmudeckConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _emudeck_seed() {
        local src="$1" dest="$2"
        [ -e "$src" ] || return 0
        [ -e "$dest" ] && return 0
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
        chmod -R u+w "$dest"
      }

      # Flatpak sandbox paths → configsDir
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.libretro.RetroArch/config/retroarch" \
        "${configsDir}/org.libretro.RetroArch/config/retroarch"
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.DolphinEmu.dolphin-emu/config/dolphin-emu" \
        "${configsDir}/org.DolphinEmu.dolphin-emu/config/dolphin-emu"
      _emudeck_seed \
        "${emudeckConfigsSrc}/io.github.shiiion.primehack/config/dolphin-emu" \
        "${configsDir}/io.github.shiiion.primehack/config/dolphin-emu"
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.ryujinx.Ryujinx/config/Ryujinx" \
        "${configsDir}/org.ryujinx.Ryujinx/config/Ryujinx"
      _emudeck_seed \
        "${emudeckConfigsSrc}/info.cemu.Cemu/data/cemu" \
        "${configsDir}/info.cemu.Cemu/data/cemu"
      _emudeck_seed \
        "${emudeckConfigsSrc}/net.kuribo64.melonDS/config/melonDS" \
        "${configsDir}/net.kuribo64.melonDS/config/melonDS"
      _emudeck_seed \
        "${emudeckConfigsSrc}/mgba" \
        "${configsDir}/mgba"
      _emudeck_seed \
        "${emudeckConfigsSrc}/duckstation" \
        "${configsDir}/duckstation"
      _emudeck_seed \
        "${emudeckConfigsSrc}/pcsx2qt/.config/PCSX2/inis" \
        "${configsDir}/pcsx2qt/.config/PCSX2/inis"
      _emudeck_seed \
        "${emudeckConfigsSrc}/net.rpcs3.RPCS3/config/rpcs3" \
        "${configsDir}/net.rpcs3.RPCS3/config/rpcs3"
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM" \
        "${configsDir}/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM"
      _emudeck_seed \
        "${emudeckConfigsSrc}/app.xemu.xemu/data/xemu" \
        "${configsDir}/app.xemu.xemu/data/xemu"
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.flycast.Flycast/config/flycast" \
        "${configsDir}/org.flycast.Flycast/config/flycast"
      _emudeck_seed \
        "${emudeckConfigsSrc}/org.scummvm.ScummVM/config/scummvm" \
        "${configsDir}/org.scummvm.ScummVM/config/scummvm"

      # XDG config paths
      _emudeck_seed \
        "${emudeckConfigsSrc}/Vita3K" \
        "${configsDir}/Vita3K"
      _emudeck_seed \
        "${emudeckConfigsSrc}/emulationstation" \
        "${configsDir}/emulationstation"
      _emudeck_seed \
        "${emudeckConfigsSrc}/steam-rom-manager/userData" \
        "${configsDir}/steam-rom-manager/userData"

      # Emulation library directory structure
      mkdir -p "${cfg.emulationPath}"/{roms,bios,saves,storage}
    '';
  };
}
