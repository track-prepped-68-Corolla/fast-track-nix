{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.ft.cachyos;
in
{
  options.ft.cachyos = {
    enable = lib.mkEnableOption "CachyOS optimized kernel" // {
      description = "Swaps the default kernel for a CachyOS build tuned for performance, pulled from the nix-cachyos flake input. Pick which build with `ft.cachyos.variant` (default: latest) — variants ending in `-x86_64-v3`, `-x86_64-v4`, or `-zen4` are tuned for specific CPU generations, and variants ending in `-lto` are compiled with link-time optimisation.";
    };
    variant = lib.mkOption {
      type = lib.types.enum [
        "latest"
        "latest-lto"
        "latest-x86_64-v3"
        "latest-lto-x86_64-v3"
        "latest-x86_64-v4"
        "latest-lto-x86_64-v4"
        "latest-zen4"
        "latest-lto-zen4"
        "bore"
        "bore-lto"
        "bore-x86_64-v3"
        "bore-lto-x86_64-v3"
        "bore-x86_64-v4"
        "bore-lto-x86_64-v4"
        "bore-zen4"
        "bore-lto-zen4"
        "eevdf"
        "eevdf-lto"
        "bmq"
        "bmq-lto"
        "lts"
        "lts-lto"
        "lts-x86_64-v3"
        "lts-lto-x86_64-v3"
        "lts-x86_64-v4"
        "lts-lto-x86_64-v4"
        "lts-zen4"
        "lts-lto-zen4"
        "rt-bore"
        "rt-bore-lto"
        "hardened"
        "hardened-lto"
        "server"
        "server-lto"
        "rc"
        "rc-lto"
        "deckify"
        "deckify-lto"
      ];
      default = "latest";
      description = "Which CachyOS kernel build to use, corresponding to `linux-cachyos-<variant>` from nix-cachyos.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = lib.mkDefault (
      pkgs.linuxPackagesFor
        inputs.nix-cachyos.packages.${pkgs.stdenv.hostPlatform.system}."linux-cachyos-${cfg.variant}"
    );

    nix.settings = {
      extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
      extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    };
  };
}
