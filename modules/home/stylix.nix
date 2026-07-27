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
        description = "Applies one consistent look across your whole desktop using Stylix — a Catppuccin Mocha color scheme, matching fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, and IBM Plex Serif), a matching cursor theme, window/terminal transparency, and your wallpaper. You can override any of these with `ft.theme.wallpaper`, `ft.theme.schemePath`, and `ft.theme.fonts.*`.";
      };

      wallpaper = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        example = lib.literalExpression "./wallpapers/default.png";
        description = "Path to your desktop wallpaper — required, since there's no sensible default. Set it in your own config, e.g. `ft.theme.wallpaper = ./wallpapers/default.png;`. The framework can't supply a default itself because a path there would point into the framework's own repo rather than yours.";
      };

      schemePath = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        default = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        description = "Path to the color scheme file (in Base16 YAML format) used to theme everything.";
      };

      schemeName = lib.mkOption {
        type = lib.types.str;
        default = "Catppuccin Mocha";
        description = "The scheme's display name, shown wherever the theme's name is referenced.";
      };

      fonts = {
        sans = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Atkinson Hyperlegible";
            description = "Name of the font family used for sans-serif text.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.atkinson-hyperlegible;
            description = "The package that provides the sans-serif font.";
          };
        };
        mono = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "AtkynsonMono Nerd Font Mono";
            description = "Name of the font family used for monospace text, such as in the terminal.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.nerd-fonts.atkynson-mono;
            description = "The package that provides the monospace font.";
          };
        };
        serif = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "IBM Plex Serif";
            description = "Name of the font family used for serif text.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.ibm-plex;
            description = "The package that provides the serif font.";
          };
        };
        emoji = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Noto Color Emoji";
            description = "Name of the font family used to render emoji.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.noto-fonts-color-emoji;
            description = "The package that provides the emoji font.";
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
