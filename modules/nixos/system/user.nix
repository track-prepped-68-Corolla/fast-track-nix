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
      description = "Creates sudo users from `superUsers` and regular unprivileged users from `normalUsers`; everyone gets zsh as their shell and membership in the common hardware/service groups. The dedicated admin account is handled separately by the `ft.admin` module.";
    };

    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The main username that other modules, like Home Manager, will apply their configuration to. Defaults to the admin account created by `ft.admin`.";
    };

    superUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra usernames that should get sudo access.";
    };

    normalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Usernames for regular accounts with no admin privileges.";
    };

    initialPasswords = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        admin = "mypassword";
        guest = "guestpass";
      };
      description = "Plain-text passwords to set for individual users the first time the machine boots. Keyed by username, each value overrides the default `changeme` password. Use sops secrets instead for real production credentials.";
    };

    u2f = {
      enable = lib.mkEnableOption "PAM U2F authentication" // {
        description = "Turns on U2F hardware-key authentication for login and sudo. Set up each user's FIDO2 credentials with `ft.users.u2f.mappings`. Users without a key on file always fall back to password login, so nobody gets locked out.";
      };

      mappings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          admin = "publicKey,keyHandle";
          guest = "publicKey2,keyHandle2";
        };
        description = "Each user's U2F key data. The attribute name is the username, and the value is the raw credential string — the part that comes after `username:` in the pam-u2f authfile format.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.groups.container = lib.mkDefault { };

      # The admin account is owned by ft.admin; filter it out of the user lists
      # below so listing it in mainUser/superUsers/normalUsers never produces a
      # duplicate-definition conflict.
      users.users = lib.mkMerge [
        (lib.genAttrs
          (lib.filter (u: u != config.ft.admin.name) (lib.unique ([ cfg.mainUser ] ++ cfg.superUsers)))
          (_user: {
            isNormalUser = true;
            extraGroups = commonGroups ++ [ "wheel" ];
            initialPassword = lib.mkDefault (cfg.initialPasswords.${_user} or null);
            shell = pkgs.zsh;
          })
        )
        (lib.genAttrs (lib.filter (u: u != config.ft.admin.name) cfg.normalUsers) (_user: {
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
