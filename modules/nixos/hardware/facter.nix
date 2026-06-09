{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# FACTER MODULE — nixos-facter hardware detection
# ------------------------------------------------------------------------------
# Points the nixos-facter NixOS module at a facter.json report committed to the
# machine directory. Replaces hardware-configuration.nix for kernel-module
# detection. Imports the upstream nixos-facter module directly so consumers do
# not need to wire it manually.
################################################################################

let
  cfg = config.ft.facter;
in
{
  imports = [ inputs.nixos-facter-modules.nixosModules.facter ];

  options.ft.facter = {
    enable = lib.mkEnableOption "nixos-facter hardware detection" // {
      description = "Points the nixos-facter NixOS module at a facter.json report committed to the machine directory. Replaces hardware-configuration.nix for kernel-module detection. Generate the report on the target with `nixos-facter`, commit it to machines/<name>/var/facter.json, and set ft.facter.reportPath = ./var/facter.json in the machine's default.nix.";
    };

    reportPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Flake-relative path to the facter.json report committed in the consumer repo, e.g. reportPath = ./var/facter.json; from the machine's default.nix. Null disables the report wiring.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # not-detected.nix used to set this implicitly; make it explicit when
        # facter takes over as the hardware detection source.
        hardware.enableRedistributableFirmware = lib.mkDefault true;
      }
      (lib.mkIf (cfg.reportPath != null && builtins.pathExists cfg.reportPath) {
        hardware.facter.reportPath = lib.mkDefault cfg.reportPath;
      })
    ]
  );
}
