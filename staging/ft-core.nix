{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.system.maintenance;

  # Dynamically generate the case statement blocks
  commandCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: script: ''
      ${name})
        ${script}
        ;;
    '') cfg.commands
  );

  # Extract just the command names for the help menu
  commandList = lib.concatStringsSep "|" (lib.attrNames cfg.commands);

  ftScript = pkgs.writeShellApplication {
    name = "ft";
    runtimeInputs = with pkgs; [
      git
      lix
      nh
      nixfmt
      delta
      findutils
      nvd
      jq
      TruffleHog
    ];
    text = ''
      set -e
      FLAKE_DIR="${cfg.flakeDir}"

      if [[ ! -d "$FLAKE_DIR" ]]; then
        echo -e "\n\033[1;31m:: Error: Flake directory $FLAKE_DIR not found. ::\033[0m"
        exit 1
      fi

      cd "$FLAKE_DIR"

      BOLD=$(tput bold)
      BLUE=$(tput setaf 4)
      GREEN=$(tput setaf 2)
      RED=$(tput setaf 1)
      RESET=$(tput sgr0)

      header()  { echo -e "\n''${BOLD}''${BLUE}:: $1 ::''${RESET}"; }
      success() { echo -e "\n''${BOLD}''${GREEN} $1''${RESET}"; }
      error()   { echo -e "\n''${BOLD}''${RED} $1''${RESET}"; }

      case "''${1:-}" in
        ${commandCases}
        *)
          echo "Usage: ft {${commandList}}"
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.ft.system.maintenance = {
    enable = lib.mkEnableOption "Pluggable ft maintenance CLI";

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/joe/git/ft-home";
      description = "The absolute path to your NixOS flake directory.";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Registry for ft subcommands. Add keys here to expand the CLI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ftScript ];
    environment.sessionVariables = {
      NH_FLAKE = cfg.flakeDir;
    };
  };
}
