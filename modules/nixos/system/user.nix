{ pkgs, lib, config, inputs, ...}:

let
  # --- CONSTANTS ---
  commonGroups = [ "video" "render" "lp" "scanner" ]
    ++ lib.optional config.networking.networkmanager.enable "networkmanager"
    ++ lib.optional config.virtualisation.podman.enable "podman";
in
{
  # --- THE API (Options) ---
  # These are the "knobs" you turn in your host files (e.g., machines/spec/default.nix).
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

  # --- THE IMPLEMENTATION (Config) ---
  config = {

    # 1. ENABLE YUBIKEY / U2F AUTHENTICATION
    security.pam.u2f = {
      enable = true;
      settings = {
        cue = true; # Tells you to tap the key
        interactive = true;
        control = "sufficient"; 
        # Use a path that can be managed by sops-nix later
        authFile = let
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

      # 1. THE PERMANENT ADMIN (Safety Net)
      # This user is hardcoded. It is always present on every system you build.
      {
        admin = {
          isNormalUser = true;
          extraGroups = commonGroups ++ [ "wheel" ]; # 'wheel' = sudo access
          initialPassword = lib.mkDefault "snp";
          #openssh.authorizedKeys.keys = [
          # "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINTWBO+wJvD/8Dili8rdo9fNvNLxYnzTZxv90Y2AK0WfAAAADXNzaDpmYXN0dHJhY2s= ssh:fasttrack"
          #];
          shell = pkgs.zsh;
        };
      }

      # 2. EXTRA SUPER USERS
      # Combines 'mainuser' and 'superUsers', filtering out the safety 'admin'.
      (lib.genAttrs (lib.filter (u: u != "admin") (
        lib.unique ([ config.mainuser ] ++ config.superUsers)
      )) (user: {
        isNormalUser = true;
        extraGroups = commonGroups ++ [ "wheel" ];
        initialPassword = lib.mkDefault "changeme";
        shell = pkgs.zsh;
      }))

      # 3. NORMAL USERS
      # This loop creates restricted accounts with no sudo access.
      (lib.genAttrs (lib.filter (u: u != "admin") config.normalUsers) (user: {
        isNormalUser = true;
        extraGroups = commonGroups;
        initialPassword = lib.mkDefault "changeme";
        shell = pkgs.zsh;
      }))
    ];
  };
}
