{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ft.emulation;
  # Produces an out-of-store symlink into the user's EmuDeck configs directory.
  link = sub: config.lib.file.mkOutOfStoreSymlink "${cfg.emudeckPath}/${sub}";
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  options.ft.emulation = {
    enable = lib.mkEnableOption "EmuDeck-compatible emulation suite" // {
      description = "Installs the EmuDeck emulator set as Flatpak packages via nix-flatpak, symlinks their configurations from a local EmuDeck configs directory into each emulator's expected location, and provides Steam ROM Manager. Requires services.flatpak.enable = true at the NixOS system level.";
    };

    emudeckPath = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the EmuDeck configs directory on disk — the configs/ subdirectory of an EmuDeck checkout (github.com/dragoonDorise/EmuDeck), or any directory following the same layout. Subdirectories here are symlinked into each emulator's Flatpak config location.";
      example = "/home/alice/emudeck/configs";
    };

    romsPath = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the ROMs library root. Passed to ES-DE and Steam ROM Manager as the content root; created during home-manager activation if absent.";
      example = "/home/alice/Emulation/roms";
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Flatpak emulators ─────────────────────────────────────────────────────
    # Mirrors the default EmuDeck install set.  Remove entries you do not need;
    # the org.ryujinx.Ryujinx entry may be unavailable if it is no longer on
    # Flathub — comment it out if the activation fails.
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
    # Each entry links the emulator's runtime config directory to the matching
    # subdirectory under cfg.emudeckPath, following EmuDeck's configs/ layout.
    # Flatpak apps sandbox config under ~/.var/app/<id>/{config,data}/; a few
    # (DuckStation, Vita3K, ES-DE) access ~/.local/share or ~/.config directly
    # via filesystem overrides.
    home.file = {
      # RetroArch — cores, playlists, remaps, overlays
      ".var/app/org.libretro.RetroArch/config/retroarch".source =
        link "org.libretro.RetroArch/config/retroarch";
      # Dolphin (GC / Wii)
      ".var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu".source =
        link "org.DolphinEmu.dolphin-emu/config/dolphin-emu";
      # Primehack (Dolphin Metroid fork — same config structure as Dolphin)
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
      # mGBA (GBA) — EmuDeck supplies the mgba/ native config; Flatpak reads it
      # from the same XDG_CONFIG_HOME path inside the sandbox
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
      # Vita3K (PS Vita) — accesses ~/.config/Vita3K via home filesystem override
      "Vita3K".source = link "Vita3K";
      # ES-DE frontend — accesses ~/.config/ES-DE via home filesystem override
      "ES-DE".source = link "emulationstation";
      # Steam ROM Manager parsers and settings
      "steam-rom-manager/userData".source = link "steam-rom-manager/userData";
    };

    # Create the ROMs root so ES-DE and SRM can find it on first launch.
    home.activation.createEmulationDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${lib.escapeShellArg cfg.romsPath}
    '';
  };
}
