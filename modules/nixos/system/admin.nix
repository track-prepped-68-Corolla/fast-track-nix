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
      description = "Sets up a dedicated admin account with sudo access, present on every machine by default (you can turn it off). It can log in with an SSH key via `authorizedKeys`, a password via `initialPassword`, or both, so you're never locked out. This account is kept separate from `ft.users` so there's always one predictable place that owns the admin user.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The username for the admin account.";
    };

    initialPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "changeme";
      description = "A plain-text password set the first time the machine boots, so the account is never locked out. Override it per machine, set it to null to rely only on SSH-key login, or use `hashedPasswordFile` for a real production credential. This option is ignored whenever `hashedPasswordFile` is set.";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file holding the admin's already-hashed password, such as a sops secret. When set, it takes priority over `initialPassword`.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "The SSH public keys allowed to log in as the admin user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Any extra groups to add the admin user to, beyond wheel and the standard hardware/service groups it already gets.";
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
