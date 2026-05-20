{ pkgs, lib, config, ... }:

let
  cfg = config.ft.users;
  commonGroups =
    [ "video" "render" "lp" "scanner" ]
    ++ lib.optional config.networking.networkmanager.enable "networkmanager"
    ++ lib.optional config.virtualisation.podman.enable "podman";
in
{
  options = {
    ft.users.enable = lib.mkEnableOption "user management" // {
      default = true;
      description = "Creates and manages all system users: always creates an `admin` wheel user; additional wheel users from `superUsers`; unprivileged users from `normalUsers`. All users get zsh and common group membership. Also configures PAM U2F for login and sudo; append additional key mappings via `u2fMappings`.";
    };

    mainuser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The primary username other modules (like Home Manager) will target.";
    };

    superUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra users who get sudo (wheel) access.";
    };

    normalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Standard users with no administrative privileges.";
    };

    u2fMappings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Raw U2F auth mappings (user:key1,key2...).";
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.u2f = {
      enable = true;
      settings = {
        cue = true;
        control = "sufficient";
        # nouserok: if the user has no entry in the authfile (or the device
        # is unreachable), skip the challenge and fall through to password.
        # Prevents lockout when the key is absent or a new user is created.
        nouserok = true;
        authfile =
          let
            defaultAdmin = "admin:umYt1X/qG0dA0eXySg2gujsVMu8hrZpifCf1rynFdb47NZzWGPLJ1db8R5Jgg8C4PxgjsVtYZoNxeUKD4YbKcA==,1XgVi7a4BpLBwWW6x17CU9VguEwoqAEJCg7LvnlgAQpcsFOBuiAl40jAiO//dvaDN";
          in
          pkgs.writeText "u2f_keys" (
            defaultAdmin + lib.optionalString (config.u2fMappings != "") ("\n" + config.u2fMappings)
          );
      };
    };

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
    };

    users.users = lib.mkMerge [
      {
        admin = {
          isNormalUser = true;
          extraGroups = commonGroups ++ [ "wheel" ];
          initialPassword = lib.mkDefault "snp";
          shell = pkgs.zsh;
        };
      }
      (lib.genAttrs
        (lib.filter (u: u != "admin") (lib.unique ([ config.mainuser ] ++ config.superUsers)))
        (user: {
          isNormalUser = true;
          extraGroups = commonGroups ++ [ "wheel" ];
          initialPassword = lib.mkDefault "changeme";
          shell = pkgs.zsh;
        }))
      (lib.genAttrs (lib.filter (u: u != "admin") config.normalUsers) (user: {
        isNormalUser = true;
        extraGroups = commonGroups;
        initialPassword = lib.mkDefault "changeme";
        shell = pkgs.zsh;
      }))
    ];
  };
}
