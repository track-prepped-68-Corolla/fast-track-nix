# Standalone Rust replica of scripts/mullet.just (scripts/mullet-rs) —
# experiment, not wired into the ft CLI or any ft.* module. mullet.just is
# unmodified and remains the canonical implementation; this package exists
# side by side with it for comparison only. Built with stock
# rustPlatform.buildRustPackage — no extra flake input required.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.mullet = pkgs.rustPlatform.buildRustPackage {
        pname = "mullet";
        version = "0.1.0";
        src = ../scripts/mullet-rs;
        cargoLock = {
          lockFile = ../scripts/mullet-rs/Cargo.lock;
        };
      };
    };
}
