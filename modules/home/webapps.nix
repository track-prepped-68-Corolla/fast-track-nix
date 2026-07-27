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
      description = "Creates application-launcher shortcuts that open any website in its own app-like window — no address bar or tabs — using a Chromium-family browser's `--app=` mode, each with its own isolated browser profile. A lightweight alternative to packaging a full Electron wrapper for every site.";
    };

    browser = lib.mkOption {
      type = lib.types.enum browserEnum;
      default = "chromium";
      description = "Which Chromium-family browser to use for launching webapps in `--app=` mode. Only Chromium-family browsers support this; Firefox isn't offered here since it needs the separate PWAsForFirefox setup to do something similar.";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "The name shown for this webapp in your application launcher.";
            };

            url = lib.mkOption {
              type = lib.types.str;
              description = "The URL this webapp's window opens to.";
            };

            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to a local icon image to use. If left unset, the site's favicon is fetched automatically when Home Manager activates; if that fetch fails (e.g. no internet), it just falls back to the browser's default icon.";
            };

            browser = lib.mkOption {
              type = lib.types.nullOr (lib.types.enum browserEnum);
              default = null;
              description = "Overrides which browser launches this particular webapp. Leave unset to use `ft.webapps.browser`.";
            };

            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "Network" ];
              description = "Desktop-entry categories that control where this webapp shows up in application menus.";
            };
          };
        }
      );
      default = { };
      description = "The set of websites to expose as desktop launchers, keyed by a short id used for the app's isolated profile folder and window class.";
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
                "--app=${app.url}"
                "--user-data-dir=${profileDir id}"
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
