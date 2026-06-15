{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ft.users;
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
  options.ft.users = {
    enable = lib.mkEnableOption "user management" // {
      default = true;
      description = "Creates and manages all system users: always creates an `admin` wheel user; additional wheel users from `superUsers`; unprivileged users from `normalUsers`. All users get zsh and common group membership.";
    };

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
      example = {
        admin = "mypassword";
        guest = "guestpass";
      };
      description = "Per-user initial plaintext passwords set at first boot. Key is username; value overrides the 'changeme' default. Use sops secrets for production credentials.";
    };

    u2f = {
      enable = lib.mkEnableOption "PAM U2F authentication" // {
        description = "Enables PAM U2F for login and sudo. Configure per-user FIDO2 credentials via `ft.users.u2f.mappings`. `nouserok` is always set so users without a key entry fall through to password authentication.";
      };

      mappings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          admin = "publicKey,keyHandle";
          guest = "publicKey2,keyHandle2";
        };
        description = "Per-user U2F key data. Attribute name is the username; value is the raw credential string (the part after 'username:' in the pam-u2f authfile format).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.groups.container = lib.mkDefault { };

      users.users = lib.mkMerge [
        # Hardcoded safety net — always present regardless of mainUser to prevent
        # complete lockout if the primary account becomes inaccessible.
        {
          admin = {
            isNormalUser = true;
            extraGroups = commonGroups ++ [ "wheel" ];
            initialPassword = lib.mkDefault (cfg.initialPasswords.admin or null);
            shell = pkgs.zsh;
          };
        }
        # admin is filtered out here to avoid a duplicate-definition conflict
        # when mainUser or superUsers also lists "admin".
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
            # nouserok: if the user has no entry in the authfile (or the device
            # is unreachable), skip the challenge and fall through to password.
            # Prevents lockout when the key is absent or a new user is created.
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
