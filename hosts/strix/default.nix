# ./hosts/strix.nix
{ inputs, ... }:

inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux"; # Adjust if this is an ARM machine
  
  # Pass flake inputs down to the modules
  specialArgs = { inherit inputs; }; 

  modules = [
    # 1. The hardware scan for this specific machine
    ./hardware-configuration.nix

    # 2. The Haumea Aggregator (Automatically loads core.nix, user.nix, features, etc.)
    ../system/default.nix 

    # 3. Your specific host configuration (Inline module)
    ({ config, lib, pkgs, ... }: {
      
      networking.hostName = "strix";
      
      # Assuming you define these custom options in another file like user.nix
      mainuser = "joe"; 
      superUsers = [ "joe" ];

      # --- FEATURE TOGGLES ---
      ft.profiles.gaming = {
        enable = true;
        user = "joe";
        gpuVendor = "amd";
        enableLeanbackUI = false;
      };

      ft.desktop.cosmic.enable = true;
      ft.containers.enable = true;
      ft.cli.enable = true;
      ft.keepass.enable = true;
      ft.mullet.enable = true;
    })
  ];
}