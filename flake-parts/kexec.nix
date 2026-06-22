# =============================================================================
# Kexec installer images — flake-parts module
# =============================================================================
#
# For each machine marked with machines/<name>/var/kexec, emits
# packages.<system>.<name>-kexec: a kexec installer image (via nixos-images)
# with that machine's full system closure baked in and an unattended auto-install
# service (modules/installer/kexec-auto-install.nix).
#
# This is the low-friction "convert a running Linux box, no USB" path: the user
# runs the built script on their existing system, which kexecs into the installer
# image; the image partitions the configured disk, installs the baked system
# offline, and reboots — no surviving orchestrator needed (the self-kexec kills
# the caller, so the install logic lives in the image itself).
#
# The remote nixos-anywhere `deploy` and live-ISO `deploy-local` paths are
# unaffected; this is purely additive. Driven by `ft bootstrap-kexec`.
# =============================================================================
{ inputs, ... }:
let
  inherit (inputs) nixpkgs nixos-images;
  inherit (nixpkgs) lib;

  machinesLib = import ./lib/machines.nix { inherit inputs; };
  inherit (machinesLib) kexecMachines mkNixosModules;

  # The target system that gets baked into the image and installed offline.
  targetSystem =
    machine:
    lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = mkNixosModules machine;
    };

  mkKexecInstaller =
    machine:
    let
      target = targetSystem machine;
      autoInstall = import ../modules/installer/kexec-auto-install.nix {
        inherit (machine) name;
        toplevel = target.config.system.build.toplevel;
        diskoScript = target.config.system.build.diskoScript;
      };
      installer = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          nixos-images.nixosModules.kexec-installer
          autoInstall
          { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
        ];
      };
    in
    # The run script: executed on the existing OS, it kexecs into the installer.
    installer.config.system.build.kexecRun;
in
{
  flake.packages = lib.foldr (
    machine: acc:
    lib.recursiveUpdate acc {
      ${machine.system}."${machine.name}-kexec" = mkKexecInstaller machine;
    }
  ) { } kexecMachines;
}
