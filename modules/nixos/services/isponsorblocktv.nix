{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# ISPONSORBLOCKTV — SponsorBlock (and ad skip/mute) for YouTube TV clients
################################################################################
#
# iSponsorBlockTV pairs with YouTube TV clients the way a phone does ("Link
# with TV code") and, over YouTube's Lounge API, skips SponsorBlock segments
# and optionally skips/mutes ads on whatever they play. It does not block ads
# itself: unskippable ads are only muted.
#
# config.json is assembled at service start from the declarative `settings`
# plus the paired devices in `devicesFile`, kept separate because each
# device's screen_id can control that YouTube session.

let
  cfg = config.ft.isponsorblocktv;
  stateDir = "/var/lib/isponsorblocktv";
  jsonFormat = pkgs.formats.json { };
  settingsFile = jsonFormat.generate "isponsorblocktv-settings.json" cfg.settings;
  jq = lib.getExe pkgs.jq;

  # Runs as root (ExecStartPre=+) so devicesFile may be a root-only sops secret.
  assembleConfig = pkgs.writeShellScript "isponsorblocktv-assemble-config" ''
    set -euo pipefail
    ${jq} -s '.[0] + { devices: .[1] }' ${settingsFile} ${lib.escapeShellArg cfg.devicesFile} \
      > ${stateDir}/config.json.tmp
    chown isponsorblocktv:isponsorblocktv ${stateDir}/config.json.tmp
    chmod 0600 ${stateDir}/config.json.tmp
    mv ${stateDir}/config.json.tmp ${stateDir}/config.json
  '';

  pairHelper = pkgs.writeShellScriptBin "ft-isponsorblocktv-pair" ''
    set -euo pipefail
    if [ "$(id -u)" -ne 0 ]; then
      echo "Run this as root (sudo ft-isponsorblocktv-pair)." >&2
      exit 1
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    echo "First, on the TV: YouTube -> Settings -> Link with TV code."
    echo "Then add the device below using that code (other prompts can be skipped)."
    ${lib.getExe pkgs.isponsorblocktv} --data "$tmp" setup-cli

    if [ ! -s "$tmp/config.json" ] || [ "$(${jq} '.devices | length' "$tmp/config.json")" -eq 0 ]; then
      echo "No device was paired; nothing changed." >&2
      exit 1
    fi

    target=${lib.escapeShellArg cfg.devicesFile}
    if [ "$target" != ${lib.escapeShellArg "${stateDir}/devices.json"} ]; then
      echo "ft.isponsorblocktv.devicesFile points at $target, which this helper does not manage."
      echo "Add these devices to it (e.g. in your sops secret):"
      ${jq} '.devices' "$tmp/config.json"
      exit 0
    fi

    mkdir -p ${stateDir}
    existing='[]'
    if [ -s "$target" ]; then existing=$(cat "$target"); fi
    ${jq} -s '(.[0] + .[1]) | unique_by(.screen_id)' <(echo "$existing") <(${jq} '.devices' "$tmp/config.json") \
      > "$target.tmp"
    chmod 0600 "$target.tmp"
    mv "$target.tmp" "$target"
    echo "Saved paired devices to $target; restarting isponsorblocktv."
    systemctl restart isponsorblocktv.service
  '';
in
{
  options.ft.isponsorblocktv = {
    enable = lib.mkEnableOption "iSponsorBlockTV" // {
      description = "Runs iSponsorBlockTV as a system service that skips SponsorBlock segments, and optionally skips or mutes ads, on YouTube TV clients paired with it (including YouTube's TV web interface at youtube.com/tv). It does not block ads: unskippable ads are muted at most. Pair a device with `sudo ft-isponsorblocktv-pair`. Exempt from VM smoke tests (needs network access to YouTube and SponsorBlock).";
    };

    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      description = "Non-secret iSponsorBlockTV configuration (its config.json keys, e.g. `skip_categories`, `skip_ads`, `mute_ads`, `auto_play`, `join_name`), merged with the paired devices from `devicesFile`. The framework defaults each of `skip_categories`, `skip_ads`, `mute_ads` and `auto_play` individually, so setting one key keeps the others.";
    };

    devicesFile = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/devices.json";
      description = "Path to a JSON list of paired devices (iSponsorBlockTV's `devices` config entries). Each device's `screen_id` can control that YouTube session, so treat it as a secret: point this at a sops secret's path, or keep the default and fill it with `sudo ft-isponsorblocktv-pair`. The service waits until this file exists.";
    };
  };

  config = lib.mkIf cfg.enable {
    ft.isponsorblocktv.settings = {
      skip_categories = lib.mkDefault [ "sponsor" ];
      skip_ads = lib.mkDefault true;
      mute_ads = lib.mkDefault true;
      auto_play = lib.mkDefault true;
    };

    environment.systemPackages = [ pairHelper ];

    users.users.isponsorblocktv = {
      isSystemUser = true;
      group = "isponsorblocktv";
      home = stateDir;
    };
    users.groups.isponsorblocktv = { };

    systemd.services.isponsorblocktv = {
      description = "iSponsorBlockTV: SponsorBlock for YouTube TV clients (ft.isponsorblocktv)";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      # Not paired yet: skip cleanly instead of crash-looping. The path unit
      # below starts the service once the file appears.
      unitConfig.ConditionPathExists = cfg.devicesFile;
      serviceConfig = {
        User = "isponsorblocktv";
        Group = "isponsorblocktv";
        StateDirectory = "isponsorblocktv";
        StateDirectoryMode = "0700";
        ExecStartPre = "+${assembleConfig}";
        ExecStart = "${lib.getExe pkgs.isponsorblocktv} --data ${stateDir} start";
        Restart = "on-failure";
        RestartSec = "30s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    systemd.paths.isponsorblocktv = {
      description = "Start iSponsorBlockTV once a device is paired (ft.isponsorblocktv)";
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathExists = cfg.devicesFile;
    };
  };
}
