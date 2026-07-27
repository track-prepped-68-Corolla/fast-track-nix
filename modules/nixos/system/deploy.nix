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
      description = "Adds this machine to the fleet that can be deployed remotely with `colmena apply`. It's off by default, so you opt each machine in individually — that way local-only machines or disk images never accidentally become a remote deploy target.";
    };

    targetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The hostname or IP address colmena connects to over SSH. Leave it null to use the machine's own name instead, resolved through DNS or Tailscale MagicDNS.";
    };

    targetUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "The SSH user colmena connects as. It needs to be able to activate system changes, so this must be root or a user with passwordless sudo.";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Tags for this machine, so you can target a subset of the fleet with `colmena apply --on @<tag>`.";
    };

    buildOnTarget = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Build the system on the target machine itself instead of on your control machine. Handy when targeting a different CPU architecture, or to avoid pushing a large build over the network.";
    };
  };
}
