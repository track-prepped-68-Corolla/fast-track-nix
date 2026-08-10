{ lib, config, ... }:

################################################################################
# NIRI — user config.kdl generation, paired with ft.niri (NixOS)
################################################################################

let
  cfg = config.ft.niri;
in
{
  options.ft.niri = {
    enable = lib.mkEnableOption "niri user config" // {
      description = "Generates ~/.config/niri/config.kdl declaratively. Pairs with ft.niri (NixOS) for the compositor session itself.";
    };

    launcherCommand = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = if config.ft.vicinae.enable then [
        "vicinae"
        "toggle"
      ] else null;
      description = "Command, as an argv list, that ft.niri.launcherBind runs to open the app launcher. Defaults to [\"vicinae\" \"toggle\"] when ft.vicinae.enable is also on; set to null to omit the launcher bind entirely.";
    };

    launcherBind = lib.mkOption {
      type = lib.types.str;
      default = "Mod+Space";
      description = "niri KDL bind key combination (e.g. \"Mod+Space\", \"Mod\") that triggers ft.niri.launcherCommand. niri's own binds syntax determines which combinations are valid — check niri's config.kdl documentation before setting this to a bare modifier like \"Mod\".";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw KDL text appended after the generated launcher bind in config.kdl, for binds and settings ft.niri doesn't expose its own option for.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri/config.kdl".text = lib.mkDefault ''
      ${lib.optionalString (cfg.launcherCommand != null) ''
        binds {
            ${cfg.launcherBind} { spawn ${lib.concatMapStringsSep " " builtins.toJSON cfg.launcherCommand}; }
        }
      ''}
      ${cfg.extraConfig}
    '';
  };
}
