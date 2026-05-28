{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ft.user;
  commonGroups = [
    "video"
    "render"
    "lp"
    "scanner"
  ]
  ++ lib.optional config.networking.networkmanager.enable "networkmanager"
  ++ lib.optional config.virtualisation.podman.enable "podman";
in
{
  meta.description = "Creates and manages all system users: always creates an admin wheel user; additional wheel users from superUsers; unprivileged users from normalUsers. All users get zsh and common group membership.";

  options.ft.user = {
    mainUser = lib.mkOption {
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

    initialPasswords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { admin = "mypassword"; guest = "guestpass"; };
      description = "Per-user initial plaintext passwords set at first boot.";
    };

    u2f = {
      enable = lib.mkEnableOption "PAM U2F authentication" // {
        description = "Enables PAM U2F for login and sudo. Configure per-user FIDO2 credentials via ft.user.u2f.mappings.";
      };

      mappings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = { admin = "publicKey,keyHandle"; };
        description = "Per-user U2F key data. Attribute name is the username; value is the raw credential string.";
      };
    };
  };

  config = lib.mkMerge [
    { ft.user.enable = lib.mkDefault true; }
    (lib.mkIf cfg.enable {
      users.users = lib.mkMerge [
        {
          admin = {
            isNormalUser = true;
            extraGroups = commonGroups ++ [ "wheel" ];
            initialPassword = lib.mkDefault (cfg.initialPasswords.admin or null);
            shell = pkgs.zsh;
          };
        }
        (lib.genAttrs (lib.filter (u: u != "admin") (lib.unique ([ cfg.mainUser ] ++ cfg.superUsers)))
          (_user: {
            isNormalUser = true;
            extraGroups = commonGroups ++ [ "wheel" ];
            initialPassword = lib.mkDefault (cfg.initialPasswords.${_user} or null);
            shell = pkgs.zsh;
          })
        )
        (lib.genAttrs (lib.filter (u: u != "admin") cfg.normalUsers) (_user: {
          isNormalUser = true;
          extraGroups = commonGroups;
          initialPassword = lib.mkDefault (cfg.initialPasswords.${_user} or null);
          shell = pkgs.zsh;
        }))
      ];
    })

    (lib.mkIf (cfg.enable && cfg.u2f.enable) {
      security.pam = {
        u2f = {
          enable = lib.mkDefault true;
          settings = {
            cue = lib.mkDefault true;
            control = lib.mkDefault "sufficient";
            nouserok = lib.mkDefault true;
            authfile = lib.mkDefault (
              pkgs.writeText "u2f_keys" (
                lib.concatStringsSep "\n" (lib.mapAttrsToList (user: key: "${user}:${key}") cfg.u2f.mappings)
              )
            );
          };
        };

        services = {
          login.u2fAuth = lib.mkDefault true;
          sudo.u2fAuth = lib.mkDefault true;
        };
      };
    })
  ];
}
