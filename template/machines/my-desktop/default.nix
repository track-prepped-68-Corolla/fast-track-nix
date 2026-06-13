# Replace "my-desktop" with your machine's hostname throughout this repo.
# Run `sudo nixos-facter -o var/facter.json` on the target to populate
# var/facter.json; the generator reads it for the system architecture.
_: {
  networking.hostName = "my-desktop";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ft = {
    core.stateVersion = "25.05"; # set once at install time, never change
    users.mainUser = "myuser"; # must match a directory under users/
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
