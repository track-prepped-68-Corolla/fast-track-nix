{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.webapps;

  # =========================================================
  # 🚀 THE APP LIST
  # Add your 50+ apps right here. No hashes required.
  # If an icon gets stale, just add "?v=2" to the end of the iconUrl.
  # =========================================================
  myApps = {
    "nix-software" = {
      name = "Nix Software";
      url = "https://nixsoftware.org";
      iconUrl = "https://raw.githubusercontent.com/NixSoftware/nixsoftware.org/main/public/favicon.svg";
    };

    # Template for your next app:
    # "youtube" = {
    #   name = "YouTube";
    #   url = "https://youtube.com";
    #   iconUrl = "https://www.youtube.com/s/desktop/10403b51/img/favicon_144x144.png";
    # };
  };

  # =========================================================
  # ⚙️ THE ENGINE
  # Transforms the list above into native COSMIC desktop items.
  # =========================================================
  mkApp =
    id: info:
    pkgs.makeDesktopItem {
      name = id;
      desktopName = info.name;

      # Launches the native Rust Wayland web wrapper
      exec = "${pkgs.quick-webapps}/bin/quick-webapps --url ${info.url}";

      # The Impure Fetch: Evaluates at build time, let the purists weep.
      icon = builtins.fetchurl info.iconUrl;

      categories = [
        "Network"
        "Utility"
      ];

      # Tells the COSMIC compositor to group these windows properly
      startupWMClass = "quick-webapps";
    };

in
{
  # Defines your custom boolean flag
  options.ft.webapps.enable = lib.mkEnableOption "Declarative COSMIC WebApps (Impure Icons)";

  # Applies the config only if ft.webapps = true
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.quick-webapps
    ]
    ++ (lib.mapAttrsToList mkApp myApps);
  };
}
