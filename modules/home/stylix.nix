{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfgTheme = config.ft.theme;
in
{
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  options = {
    ft.theme = {
      enable = lib.mkEnableOption "unified system theming via Stylix" // {
        description = "Applies a Catppuccin Mocha theme system-wide via Stylix: configures fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, IBM Plex Serif), catppuccin-mocha-dark cursor, window and terminal opacity, and wallpaper. Override defaults with `ft.theme.wallpaper`, `ft.theme.schemePath`, and `ft.theme.fonts.*`.";
      };

      wallpaper = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        example = lib.literalExpression "./wallpapers/default.png";
        description = "Required: path to the primary desktop wallpaper. Set this in your user config, e.g. ft.theme.wallpaper = ./wallpapers/default.png;. No framework default is provided because a framework-relative path would resolve into the framework repo, not the consumer's.";
      };

      schemePath = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        default = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        description = "Path to the Base16 YAML scheme.";
      };

      schemeName = lib.mkOption {
        type = lib.types.str;
        default = "Catppuccin Mocha";
        description = "Human-readable name of the scheme.";
      };

      fonts = {
        sans = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Atkinson Hyperlegible";
            description = "Font family name for the sans-serif role.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.atkinson-hyperlegible;
            description = "Package providing the sans-serif font.";
          };
        };
        mono = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "AtkynsonMono Nerd Font Mono";
            description = "Font family name for the monospace role.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.nerd-fonts.atkynson-mono;
            description = "Package providing the monospace font.";
          };
        };
        serif = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "IBM Plex Serif";
            description = "Font family name for the serif role.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.ibm-plex;
            description = "Package providing the serif font.";
          };
        };
        emoji = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Noto Color Emoji";
            description = "Font family name for the emoji role.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.noto-fonts-color-emoji;
            description = "Package providing the emoji font.";
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfgTheme.enable {
      home.packages = [
        cfgTheme.fonts.sans.package
        cfgTheme.fonts.mono.package
        cfgTheme.fonts.serif.package
        cfgTheme.fonts.emoji.package
      ];

      stylix = {
        enable = true;
        image = cfgTheme.wallpaper;
        base16Scheme = cfgTheme.schemePath;

        fonts = {
          sansSerif = {
            inherit (cfgTheme.fonts.sans) package name;
          };
          monospace = {
            inherit (cfgTheme.fonts.mono) package name;
          };
          serif = {
            inherit (cfgTheme.fonts.serif) package name;
          };
          emoji = {
            inherit (cfgTheme.fonts.emoji) package name;
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
    })
  ];
}
