{
  config,
  options,
  lib,
  pkgs,
  ...
}:

################################################################################
# HOST-SIDE KOMODO GITOPS AUTO-APPLY FOR A MICROVM
#
# The VM analogue of running Komodo's ResourceSync from the host: after a
# microVM's Komodo Core comes up, reconcile it with the consumer's containers/
# by driving the bundled `komodo-apply` recipe against Core's API — the same
# justfile invocation the `ft` CLI wrapper uses.
#
# It lives OUTSIDE ft.microvms (which stays a generic host infra module) and is
# keyed by microVM instance name: each entry references ft.microvms.instances.
# <name> to derive the guest Core URL, and needs host ft.cli / ft.sops /
# ft.repoPath plus a sops secret holding the Komodo API credentials. The guest
# runs Komodo headlessly (no repo), so this reconcile has to run on the host.
################################################################################

let
  cfg = config.ft.komodoApply;
  netCfg = config.ft.microvms;
  scriptsDir = ../../../scripts;

  enabled = lib.filterAttrs (_: c: c.enable) cfg;

  subnetPrefix = lib.concatStringsSep "." (lib.take 3 (lib.splitString "." netCfg.hostAddress));
  urlOf =
    name:
    "http://${subnetPrefix}.${toString netCfg.instances.${name}.vmAddressSuffix}:${toString cfg.${name}.port}";

  # Bounded wait for the guest's Komodo Core to answer, then run komodo-apply
  # against the consumer repo. Runs as root (to read the api_env secret), so it
  # forces git safe.directory for the repo.
  mkScript =
    name:
    pkgs.writeShellScript "komodo-apply-${name}" ''
      set -euo pipefail
      export PATH=${
        lib.makeBinPath [
          pkgs.git
          pkgs.jq
          pkgs.curl
          pkgs.just
          pkgs.coreutils
        ]
      }:$PATH
      export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'
      for _ in $(seq 1 60); do
        if curl -sf -o /dev/null "${urlOf name}"; then break; fi
        sleep 5
      done
      exec just --shell ${pkgs.bash}/bin/bash \
        --justfile ${scriptsDir}/ft.just \
        --working-directory ${config.ft.repoPath} \
        komodo-apply
    '';
in
{
  options.ft.komodoApply = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "host-side Komodo GitOps auto-apply for a microVM" // {
            description = "After the named microVM's Komodo Core comes up, runs the bundled `komodo-apply` recipe from the host (in ft.repoPath) against Core's API, reconciling Komodo with containers/ on every rebuild — no UI needed. The attribute name must match an ft.microvms.instances.<name>; the guest Core URL is derived from that instance's address. Requires ft.cli, ft.sops and ft.repoPath, plus the apiEnvSecret below.";
          };

          apiEnvSecret = lib.mkOption {
            type = lib.types.str;
            default = "komodo/api_env";
            description = "sops secret key holding KOMODO_API_KEY and KOMODO_API_SECRET as an env-file (KEY=VALUE lines), used to authenticate the host's komodo-apply call against the guest's Komodo API. Create a Komodo API key once to get these.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 9120;
            description = "Port the guest's Komodo Core listens on, used to build the API URL from the microVM instance's address.";
          };
        };
      }
    );
    default = { };
    description = "Host-side Komodo GitOps auto-apply, keyed by microVM instance name. Each enabled entry reconciles that VM's Komodo with the consumer's containers/ over the API after it boots.";
  };

  config = lib.mkIf (enabled != { }) {
    assertions = lib.mapAttrsToList (name: _: {
      assertion =
        (netCfg.instances ? ${name})
        && config.ft.cli.enable
        && config.ft.sops.enable
        && config.ft.repoPath != options.ft.repoPath.default;
      message = "ft.komodoApply.${name} requires a matching ft.microvms.instances.${name}, plus ft.cli.enable, ft.sops.enable and ft.repoPath set to your consumer repo — it drives `ft komodo-apply` from the host and reads the ${cfg.${name}.apiEnvSecret} sops secret.";
    }) enabled;

    sops.secrets = lib.mapAttrs' (_: c: lib.nameValuePair c.apiEnvSecret { }) enabled;

    systemd.services = lib.mapAttrs' (
      name: c:
      lib.nameValuePair "komodo-apply-${name}" {
        description = "Reconcile ${name}'s Komodo with containers/ over the API (ft komodo-apply)";
        after = [
          "microvm@${name}.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = config.sops.secrets.${c.apiEnvSecret}.path;
          Environment = [ "KOMODO_URL=${urlOf name}" ];
          ExecStart = mkScript name;
        };
      }
    ) enabled;
  };
}
