{ lib, config, pkgs, inputs, ... }:
{
  options.ft.kernel.cachyos = {
    enable = lib.mkEnableOption "CachyOS optimized kernel";
    variant = lib.mkOption {
      type = lib.types.enum [ "cachyos" "cachyos-lts" ];
      default = "cachyos";
      description = "CachyOS kernel variant (cachyos = latest, cachyos-lts = LTS).";
    };
  };

  config = lib.mkIf config.ft.kernel.cachyos.enable {
    boot.kernelPackages = pkgs.linuxPackagesFor
      inputs.nix-cachyos.packages.${pkgs.stdenv.hostPlatform.system}."linux-${config.ft.kernel.cachyos.variant}";
  };
}
