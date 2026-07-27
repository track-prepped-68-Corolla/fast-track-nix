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
      description = "Uses a hardware report to detect and configure kernel modules automatically, instead of a hand-written `hardware-configuration.nix`. Generate the report on the target machine by running `nixos-facter`, commit it to `machines/<name>/var/facter.json`, and point `ft.facter.reportPath` at it (e.g. `./var/facter.json`) from the machine's `default.nix`.";
    };

    reportPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The path to the committed `facter.json` report, relative to the flake, e.g. `reportPath = ./var/facter.json;` in the machine's `default.nix`. Leave it as `null` to skip this wiring entirely.";
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
