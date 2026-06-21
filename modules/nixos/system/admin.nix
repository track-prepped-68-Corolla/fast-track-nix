{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ft.admin;
  # Hardware/service groups a management account needs day to day. Kept in sync
  # with ft.users' commonGroups — the two modules own different users now.
  commonGroups = [
    "video"
    "render"
    "lp"
    "scanner"
    "container"
    "dialout"
  ]
  ++ lib.optional config.networking.networkmanager.enable "networkmanager";
in
{
  options.ft.admin = {
    enable = lib.mkEnableOption "the privileged admin user" // {
      default = true;
      description = "Creates a wheel (sudo) management account — present on every machine by default, but toggleable. Authenticates via `authorizedKeys` (key-based) and/or `initialPassword`, so it is never a locked-out account. Pulled out of `ft.users` so the administrator is owned by one dedicated, predictable place.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username of the admin/management account.";
    };

    initialPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "changeme";
      description = "Plaintext password set at first boot so the account is never locked out. Override per machine; set to null to rely solely on key-based auth; or supply a real credential via `hashedPasswordFile` for production. Ignored when `hashedPasswordFile` is set.";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the admin's hashed password (e.g. a sops secret). Takes precedence over `initialPassword` when set.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for key-based login as the admin user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional groups for the admin user, on top of wheel and the common hardware/service groups.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ] ++ commonGroups ++ cfg.extraGroups;
      # Normal priority (not mkDefault): the base sets shell via mkDefault, so
      # two mkDefaults would conflict — match how ft.users assigns user shells.
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    }
    // lib.optionalAttrs (cfg.hashedPasswordFile != null) {
      inherit (cfg) hashedPasswordFile;
    }
    // lib.optionalAttrs (cfg.hashedPasswordFile == null) {
      initialPassword = lib.mkDefault cfg.initialPassword;
    };
  };
}
