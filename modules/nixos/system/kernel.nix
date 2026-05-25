{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  options.ft.kernel.cachyos = {
    enable = lib.mkEnableOption "CachyOS optimized kernel" // {
      description = "Replaces the default kernel with a CachyOS-optimised build sourced from the nix-cachyos flake input. Select a variant with `ft.kernel.cachyos.variant` (default: latest). Append -x86_64-v3, -x86_64-v4, or -zen4 for microarchitecture-optimised builds. Append -lto for LTO-compiled editions.";
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
      description = "CachyOS kernel variant. Maps to linux-cachyos-<variant> from nix-cachyos.";
    };
  };

  config = lib.mkIf config.ft.kernel.cachyos.enable {
    boot.kernelPackages =
      pkgs.linuxPackagesFor
        inputs.nix-cachyos.packages.${pkgs.stdenv.hostPlatform.system}."linux-cachyos-${config.ft.kernel.cachyos.variant}";

    nix.settings = {
      extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
      extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    };
  };
}
