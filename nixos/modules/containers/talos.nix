{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.ft.containers.talos;
in
{
  options.ft.containers.talos = {
    enable = mkEnableOption "Open WebUI OCI container on /opt/talos";
  };

  config = mkIf cfg.enable {
    # 1. Create the persistent directory for databases/uploads
    systemd.tmpfiles.rules = [
      "d /opt/talos 0775 root root -"
    ];

    # 2. The OCI Container
    virtualisation.oci-containers.containers."open-webui" = {
      image = "ghcr.io/open-webui/open-webui:main";

      # Mapping host 3000 -> container 8080
      ports = [ "3000:8080" ];

      volumes = [
        "/opt/talos:/app/backend/data"
      ];

      environment = {
        # Point to the Ollama container on the same host
        # Using 127.0.0.1 here works because of the --network=host or host-gateway tweak
        "OLLAMA_BASE_URL" = "http://host.containers.internal:11434";
        # Essential for security/session persistence
        "WEBUI_AUTH" = "True";
      };

      extraOptions = [
        "--add-host=host.containers.internal:host-gateway"
        "--security-opt=label=disable"
      ];
    };

    # 3. Open port 3000 in the firewall
    networking.firewall.allowedTCPPorts = [ 3000 ];
  };
}
