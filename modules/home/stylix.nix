{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ft.stylix;
in
{
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  meta.description = "Applies a Catppuccin Mocha theme system-wide via Stylix: configures fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, IBM Plex Serif), catppuccin-mocha-dark cursor, window and terminal opacity, and wallpaper. Override defaults with ft.stylix.wallpaper, ft.stylix.schemePath, and ft.stylix.fonts.*.";

  options = {
    ft.stylix = {
      wallpaper = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        default = ../../homes/guest/wallpapers/default.png;
        description = "Path to the primary desktop wallpaper.";
      };

      schemePath = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        default = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        description = "Path to the Base16 YAML scheme.";
      };

      schemeName = lib.mkOption {
        type = lib.types.str;
        default = "Catppuccin Mocha";
        description = "Human-readable name of the scheme (used by COSMIC).";
      };

      fonts = {
        sans = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Atkinson Hyperlegible";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.atkinson-hyperlegible;
          };
        };
        mono = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "AtkynsonMono Nerd Font Mono";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.nerd-fonts.atkynson-mono;
          };
        };
        serif = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "IBM Plex Serif";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.ibm-plex;
          };
        };
        emoji = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Noto Color Emoji";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.noto-fonts-color-emoji;
          };
        };
      };
    };

    ft.cosmic.enable = lib.mkEnableOption "COSMIC desktop environment theming logic" // {
      description = "Applies COSMIC-specific theming overrides on top of ft.stylix. Enable this alongside ft.cosmic.enable when running the COSMIC desktop environment.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.fonts.sans.package
      cfg.fonts.mono.package
      cfg.fonts.serif.package
      cfg.fonts.emoji.package
    ];

    stylix = {
      enable = true;
      image = cfg.wallpaper;
      base16Scheme = cfg.schemePath;

      fonts = {
        sansSerif = {
          inherit (cfg.fonts.sans) package name;
        };
        monospace = {
          inherit (cfg.fonts.mono) package name;
        };
        serif = {
          inherit (cfg.fonts.serif) package name;
        };
        emoji = {
          inherit (cfg.fonts.emoji) package name;
        };
        sizes = {
          applications = 12;
          terminal = 13;
          desktop = 11;
          popups = 11;
        };
      };

      cursor = {
        package = pkgs.catppuccin-cursors.mochaDark;
        name = "catppuccin-mocha-dark-cursors";
        size = 24;
      };

      opacity = {
        terminal = 0.85;
        applications = 0.95;
        desktop = 0.90;
      };

      targets.starship.enable = false;
    };
  };
}
