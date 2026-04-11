{ lib, pkgs, ... }:

{
  # Global settings that apply to ALL hosts
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.11"; 

  # Core packages needed on every machine
  environment.systemPackages = with pkgs; [ 
    git 
    vim 
    curl 
    wget ];
}