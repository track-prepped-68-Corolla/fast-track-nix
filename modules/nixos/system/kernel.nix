{ lib, config, pkgs, inputs, ... }:
{
  options.ft.kernel.cachyos = {
    enable = lib.mkEnableOption "CachyOS optimized kernel" // {
      description = "Replaces the default kernel with a CachyOS-optimised build sourced from the nix-cachyos flake input. Select a variant with `ft.kernel.cachyos.variant` (default: latest). Available variants: bore, eevdf, bmq, lts, rt-bore, hardened, server, deckify, rc, and LTO editions of each.";
    };
    variant = lib.mkOption {
      type = lib.types.enum [
        "latest"     "latest-lto"
        "bore"       "bore-lto"
        "eevdf"      "eevdf-lto"
        "bmq"        "bmq-lto"
        "lts"        "lts-lto"
        "rt-bore"    "rt-bore-lto"
        "hardened"   "hardened-lto"
        "server"     "server-lto"
        "rc"         "rc-lto"
        "deckify"    "deckify-lto"
      ];
      default = "latest";
      description = "CachyOS kernel variant. Maps to linux-cachyos-<variant> from nix-cachyos.";
    };
  };

  config = lib.mkIf config.ft.kernel.cachyos.enable {
    boot.kernelPackages = pkgs.linuxPackagesFor
      inputs.nix-cachyos.packages.${pkgs.stdenv.hostPlatform.system}."linux-cachyos-${config.ft.kernel.cachyos.variant}";
  };
}
