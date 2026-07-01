{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# WEBAPPS (Home Manager) — site-specific browser shortcuts
################################################################################

let
  cfg = config.ft.webapps;

  browserEnum = [
    "chromium"
    "google-chrome"
    "brave"
    "vivaldi"
    "ungoogled-chromium"
  ];

  # The enum values already match the nixpkgs attribute names; only the binary
  # name inside the package differs from the package name in some cases.
  browserBins = {
    chromium = "chromium";
    google-chrome = "google-chrome-stable";
    brave = "brave";
    vivaldi = "vivaldi";
    ungoogled-chromium = "chromium";
  };

  browserFor = app: if app.browser != null then app.browser else cfg.browser;
  usedBrowsers = lib.unique (lib.mapAttrsToList (_id: browserFor) cfg.apps ++ [ cfg.browser ]);

  iconDir = "${config.xdg.dataHome}/ft-webapps/icons";
  profileDir = id: "${config.xdg.dataHome}/ft-webapps/${id}";
  faviconPath = id: "${iconDir}/${id}.png";

  hostOf = url: lib.head (lib.splitString "/" (lib.last (lib.splitString "://" url)));
in
{
  options.ft.webapps = {
    enable = lib.mkEnableOption "site-specific webapp launchers" // {
      description = "Generates application-launcher entries that open arbitrary websites as standalone, app-style windows (no address bar or tabs) using a Chromium-family browser's --app= mode, each in its own isolated profile directory. A lightweight alternative to bundling a full Electron/nativefier wrapper per site.";
    };

    browser = lib.mkOption {
      type = lib.types.enum browserEnum;
      default = "chromium";
      description = "Default Chromium-family browser used to launch webapps in --app= mode. Only Chromium-family browsers support --app=; Firefox has no equivalent without the separate PWAsForFirefox stack, so it is not offered here.";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name shown in the application launcher.";
            };

            url = lib.mkOption {
              type = lib.types.str;
              description = "URL the webapp window opens to.";
            };

            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to a local icon image. When null, the site's favicon is fetched automatically at Home Manager activation time (best-effort; silently keeps the browser's default icon if the fetch is unavailable, e.g. offline).";
            };

            browser = lib.mkOption {
              type = lib.types.nullOr (lib.types.enum browserEnum);
              default = null;
              description = "Per-app override of the Chromium-family browser used to launch this webapp. Falls back to ft.webapps.browser when null.";
            };

            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "Network" ];
              description = "Freedesktop desktop-entry categories used to place this webapp in application menus.";
            };
          };
        }
      );
      default = { };
      description = "Set of website-backed apps to expose as desktop launchers, keyed by a short app id used for the isolated profile directory and window class.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkDefault (map (b: pkgs.${b}) usedBrowsers);

    xdg.dataFile = lib.mapAttrs' (
      id: app:
      lib.nameValuePair "applications/${id}.desktop" {
        source =
          let
            item = pkgs.makeDesktopItem {
              name = id;
              desktopName = app.name;
              inherit (app) categories;
              icon = if app.icon != null then toString app.icon else faviconPath id;
              exec = lib.concatStringsSep " " [
                (lib.getExe' pkgs.${browserFor app} browserBins.${browserFor app})
                "--app=${lib.escapeShellArg app.url}"
                "--user-data-dir=${lib.escapeShellArg (profileDir id)}"
                "--class=ft-webapp-${id}"
              ];
            };
          in
          "${item}/share/applications/${id}.desktop";
      }
    ) cfg.apps;

    home.activation.ftWebappFavicons =
      let
        curl = lib.getExe pkgs.curl;
        mkdir = lib.getExe' pkgs.coreutils "mkdir";
        autoIconApps = lib.filterAttrs (_id: app: app.icon == null) cfg.apps;
        fetchOne = id: app: ''
          $DRY_RUN_CMD ${curl} -fsSL --max-time 5 ${lib.escapeShellArg "https://www.google.com/s2/favicons?domain=${hostOf app.url}&sz=128"} -o ${lib.escapeShellArg (faviconPath id)} || true
        '';
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          $DRY_RUN_CMD ${mkdir} -p ${lib.escapeShellArg iconDir}
        ''
        + lib.concatStrings (lib.mapAttrsToList fetchOne autoIconApps)
      );
  };
}
