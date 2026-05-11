{ pkgs, lib, config, inputs, ...}:

let
  commonGroups = [ "video" "render" "lp" "scanner" ]
    ++ lib.optional config.networking.networkmanager.enable "networkmanager"
    ++ lib.optional config.virtualisation.podman.enable "podman";
in
{
  options = {
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

  config = {
    security.pam.u2f = {
      enable = true;
      settings = {
        cue = true;
        interactive = true;
        control = "sufficient";
        authFile =
          let
            defaultAdmin = "admin:umYt1X/qG0dA0eXySg2gujsVMu8hrZpifCf1rynFdb47NZzWGPLJ1db8R5Jgg8C4PxgjsVtYZoNxeUKD4YbKcA==,1XgVi7a4BpLBwWW6x17CU9VguEwoqAEJCg7LvnlgAQpcsFOBuiAl40jAiO//dvaDN";
          in
            pkgs.writeText "u2f_keys" (defaultAdmin + "\n" + config.u2fMappings);
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
      (lib.genAttrs (lib.filter (u: u != "admin") (
        lib.unique ([ config.mainuser ] ++ config.superUsers)
      )) (user: {
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
