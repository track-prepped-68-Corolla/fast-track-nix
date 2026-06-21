{ lib, ... }:

# -----------------------------------------------------------------------------
#  ft.deploy — colmena deployment metadata
# -----------------------------------------------------------------------------
# Options only: there is no `config` block. These values are consumed at deploy
# time by the flake-parts colmena layer (flake-parts/colmena.nix), which maps
# them onto colmena's deployment.* options and builds the `colmenaHive` flake
# output. Nothing on the machine itself reads them, so there is nothing to
# assert or activate here. The options are intentionally generic (ft.deploy, not
# ft.colmena) so a future pull-based GitOps layer can reuse enable/tags to
# enumerate and group the fleet.
#
# VM-test exempt: deployment infrastructure (needs real inter-host SSH); covered
# instead by an eval check that the hive builds in ft-testing.
{
  options.ft.deploy = {
    enable = lib.mkEnableOption "colmena deployment target" // {
      description = "Includes this machine as a node in the `colmenaHive` flake output so it can be built and activated remotely with `colmena apply`. Off by default; opt machines in individually so local-only or image machines never become remote-push targets.";
    };

    targetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname or IP colmena connects to over SSH. Null uses the machine's attribute name, resolved via DNS or Tailscale MagicDNS.";
    };

    targetUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "SSH user colmena connects as. Must be able to activate system closures — root, or a user with passwordless sudo.";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Colmena tags for this node, used to target subsets with `colmena apply --on @<tag>`.";
    };

    buildOnTarget = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Build the system closure on the target host instead of the control machine. Useful for cross-architecture targets or to avoid pushing large closures over the network.";
    };
  };
}
