{ pkgs, lib, config, ... }:

let
  # --- CONSTANTS ---
  # Groups that every user should belong to, regardless of sudo status.
  commonGroups = [
    "networkmanager" # So they can onnect to Wifi
    "podman" # to use containers
    "lp" "scanner" "printadmin" # for printing
    "video" "render" # for hardware accelerated rendering and video playback
  ];
in
{
  # --- OPTIONS (The API) ---
  # These are the variables we set in flake.nix.
  # By defining them here, we create a strict "contract" for what data this module needs.
  options = {
    
    mainuser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The primary user (automatically gets sudo/wheel access)";
    };

    superUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of EXTRA users to be added to wheel (sudo) group";
    };

    normalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of standard users (no sudo access)";
    };
  };

  # --- CONFIGURATION (The Implementation) ---
  # This is where the code actually runs.
  config = {
    
    # lib.mkMerge allows us to generate multiple lists of users 
    # and combine them into one final result.
    users.users = lib.mkMerge [

      # 1. THE SUPER USERS
      # We combine 'mainuser' with the 'superUsers' list using a loop (genAttrs).
      (lib.genAttrs (lib.unique ([ config.mainuser ] ++ config.superUsers)) (user: {
        isNormalUser = true;
        description = "Super User"; 
        
        # 'wheel' is the magic group that grants sudo access on Linux
        extraGroups = commonGroups ++ [ "wheel" ];
        
        # REQUIRED: Set a placeholder password so you can login immediately.
        # Change this with the 'passwd' command!
        initialPassword = "changeme"; 
        
        # Set the default shell
        shell = pkgs.bash; 
      }))

      # 2. THE NORMAL USERS
      # Loop over the normalUsers list and create restricted accounts.
      (lib.genAttrs config.normalUsers (user: {
        isNormalUser = true;
        description = "Standard User";
        
        # Notice: No 'wheel' group here!
        extraGroups = commonGroups;
        
        initialPassword = "changeme";
        shell = pkgs.bash;
      }))
    ];
  };
}