{ inputs, nixpkgs }:
let
  inherit (import ./lib.nix { inherit inputs nixpkgs; }) baseConfig mkTest;
in
{
  # ft.services.bulkPool (no drives): verifies the module loads and the full
  # tool bundle is installed on PATH. When drivesFile is null (default), the
  # module is a complete no-op for filesystem and snapraid config, but the
  # packages block always runs when enable = true.
  vm-bulk-pool-load = mkTest {
    name = "ft-bulk-pool-load";
    nodes.machine =
      { ... }:
      {
        imports = [ baseConfig ];
        ft.services.bulkPool.enable = true;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("which mergerfs")
      machine.succeed("which snapraid")
      machine.succeed("which snapraid-btrfs")
    '';
  };
}
