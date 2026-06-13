{
  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/fast-track-nix/testing";
    nixpkgs.follows = "ft-home/nixpkgs";
  };

  outputs =
    inputs @ { ft-home, ... }:
    ft-home.lib.mkFlake inputs;
}
