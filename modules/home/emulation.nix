{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ft.emulation;

  emudeckSrc = pkgs.fetchFromGitHub {
    owner = "dragoonDorise";
    repo = "EmuDeck";
    rev = cfg.emudeckRev;
    hash = cfg.emudeckHash;
  };

  # Rewrite the Steam Deck SD card stem that EmuDeck hard-codes in every config
  # file to the user's actual emulation root. A single sed pass covers all
  # emulators because every hardcoded absolute path in the EmuDeck configs tree
  # shares the same /run/media/mmcblk0p1/Emulation prefix.
  emudeckConfigs = pkgs.runCommand "emudeck-configs" { } ''
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
      description = "Installs the EmuDeck emulator set as Flatpak packages via nix-flatpak, writes their default configurations from a pinned EmuDeck source tree, and provides Steam ROM Manager. Configs are copied on first activation so emulators can write settings back; subsequent activations are a no-op unless you remove a destination manually. Requires services.flatpak.enable = true at the NixOS system level.";
    };

    emulationPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Emulation";
      description = "Root of the emulation library. The subdirectories roms/, bios/, saves/, and storage/ are created here on first activation, and all emulator configs are written with paths under this root.";
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
      description = "SHA-256 hash of the EmuDeck source tree at emudeckRev in SRI format. Compute with: nix-prefetch-github dragoonDorise EmuDeck --rev <rev>. The build error will print the correct value when the placeholder is used.";
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

    # ── Config installation ───────────────────────────────────────────────────
    # Each emulator's config directory is copied from the substituted EmuDeck
    # source tree on first activation. Subsequent activations skip destinations
    # that already exist, preserving any in-app changes the user has made.
    # To reset a single emulator's config, delete its destination and re-run
    # home-manager switch.
    home.activation.installEmudeckConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _emudeck_install() {
        local src="$1" dest="$2"
        [ -e "$src" ] || return 0
        [ -e "$dest" ] && return 0
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
        chmod -R u+w "$dest"
      }

      # ── Flatpak sandbox paths (~/.var/app/<id>/{config,data}/) ──────────────
      _emudeck_install \
        "${emudeckConfigs}/org.libretro.RetroArch/config/retroarch" \
        "$HOME/.var/app/org.libretro.RetroArch/config/retroarch"
      _emudeck_install \
        "${emudeckConfigs}/org.DolphinEmu.dolphin-emu/config/dolphin-emu" \
        "$HOME/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu"
      _emudeck_install \
        "${emudeckConfigs}/io.github.shiiion.primehack/config/dolphin-emu" \
        "$HOME/.var/app/io.github.shiiion.primehack/config/dolphin-emu"
      _emudeck_install \
        "${emudeckConfigs}/org.ryujinx.Ryujinx/config/Ryujinx" \
        "$HOME/.var/app/org.ryujinx.Ryujinx/config/Ryujinx"
      _emudeck_install \
        "${emudeckConfigs}/info.cemu.Cemu/data/cemu" \
        "$HOME/.var/app/info.cemu.Cemu/data/cemu"
      _emudeck_install \
        "${emudeckConfigs}/net.kuribo64.melonDS/config/melonDS" \
        "$HOME/.var/app/net.kuribo64.melonDS/config/melonDS"
      _emudeck_install \
        "${emudeckConfigs}/mgba" \
        "$HOME/.var/app/io.mgba.mGBA/config/mgba"
      _emudeck_install \
        "${emudeckConfigs}/pcsx2qt/.config/PCSX2/inis" \
        "$HOME/.var/app/net.pcsx2.PCSX2/config/PCSX2/inis"
      _emudeck_install \
        "${emudeckConfigs}/net.rpcs3.RPCS3/config/rpcs3" \
        "$HOME/.var/app/net.rpcs3.RPCS3/config/rpcs3"
      _emudeck_install \
        "${emudeckConfigs}/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM" \
        "$HOME/.var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM"
      _emudeck_install \
        "${emudeckConfigs}/duckstation" \
        "$HOME/.local/share/duckstation"
      _emudeck_install \
        "${emudeckConfigs}/app.xemu.xemu/data/xemu" \
        "$HOME/.var/app/app.xemu.xemu/data/xemu"
      _emudeck_install \
        "${emudeckConfigs}/org.flycast.Flycast/config/flycast" \
        "$HOME/.var/app/org.flycast.Flycast/config/flycast"
      _emudeck_install \
        "${emudeckConfigs}/org.scummvm.ScummVM/config/scummvm" \
        "$HOME/.var/app/org.scummvm.ScummVM/config/scummvm"

      # ── XDG config paths (~/.config/) ──────────────────────────────────────
      _emudeck_install \
        "${emudeckConfigs}/Vita3K" \
        "$HOME/.config/Vita3K"
      _emudeck_install \
        "${emudeckConfigs}/emulationstation" \
        "$HOME/.config/ES-DE"
      _emudeck_install \
        "${emudeckConfigs}/steam-rom-manager/userData" \
        "$HOME/.config/steam-rom-manager/userData"

      # ── Emulation library directory structure ───────────────────────────────
      mkdir -p "${cfg.emulationPath}"/{roms,bios,saves,storage}
    '';
  };
}
