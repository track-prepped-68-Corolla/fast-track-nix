{
  config,
  lib,
  pkgs,
  ...
}:

let
  flakeDir = config.ft.system.maintenance.flakeDir;
  cfg = config.ft.system.mullet;

  startMarker = "# MULLET_START_9f8b7c6d5e4a3b2c1";
  endMarker = "# MULLET_END_9f8b7c6d5e4a3b2c1";

in
{
  options.ft.system.mullet = {
    enable = lib.mkEnableOption "Imperative package management (The Mullet)";

    sourcePath = lib.mkOption {
      type = lib.types.str;
      default = "${flakeDir}/mullet.nix";
      description = "The absolute path to this file.";
    };
  };

  config = lib.mkIf cfg.enable {

    # 1. 🏁 THE LANDING PAD
    environment.systemPackages = with pkgs; [
      # =====================================================================
      # ⚠️ DIRE WARNING: DO NOT TOUCH THE MARKERS BELOW ⚠️
      # The 'ft' CLI uses these exact strings to surgically inject packages.
      # If you delete, modify, or move these markers, 'ft add' and 'ft rm'
      # will permanently break and you will have to fix this file manually.
      # =====================================================================
      # MULLET_START_9f8b7c6d5e4a3b2c1
        cowsay
      # MULLET_END_9f8b7c6d5e4a3b2c1
    ];

    # 2. Inject commands into the ft core
    ft.system.maintenance.commands = {

      search = ''
        QUERY="''${2:-}"
        if [ -z "$QUERY" ]; then error "Usage: ft search <query>"; exit 1; fi
        header "Searching Nixpkgs for: $QUERY"
        nix search nixpkgs "$QUERY"
        echo ""
        success "To install a package, copy its name and run: ft add <name>"
      '';

      add = ''
        PKG="''${2:-}"
        if [ -z "$PKG" ]; then error "Usage: ft add <pkg>"; exit 1; fi
        FILE="${cfg.sourcePath}"
        if [ ! -f "$FILE" ]; then error "Mullet source file not found at: $FILE"; exit 1; fi

        if grep -q "^[[:space:]]*$PKG[[:space:]]*$" "$FILE"; then
          success "$PKG is already in the Landing Pad."
          exit 0
        fi

        # Backup and inject
        cp "$FILE" "$FILE.bak"
        sed -i "/${endMarker}/i \      $PKG" "$FILE"

        # Validation Gate
        if ! nix-instantiate --parse "$FILE" > /dev/null 2>&1; then
          mv "$FILE.bak" "$FILE"
          error "Syntax validation failed. Reverting to prevent broken builds."
          exit 1
        fi

        rm -f "$FILE.bak"
        success "Added $PKG to the Mullet. Run 'ft gen' to apply."
      '';

      rm = ''
        PKG="''${2:-}"
        if [ -z "$PKG" ]; then error "Usage: ft rm <pkg>"; exit 1; fi
        FILE="${cfg.sourcePath}"
        if [ ! -f "$FILE" ]; then error "Mullet source file not found at: $FILE"; exit 1; fi

        if grep -q "^[[:space:]]*$PKG[[:space:]]*$" "$FILE"; then
          # Backup and extract
          cp "$FILE" "$FILE.bak"
          sed -i "/${startMarker}/,/${endMarker}/ { /^[[:space:]]*$PKG[[:space:]]*$/d }" "$FILE"
          
          # Validation Gate
          if ! nix-instantiate --parse "$FILE" > /dev/null 2>&1; then
            mv "$FILE.bak" "$FILE"
            error "Syntax validation failed. Reverting to prevent broken builds."
            exit 1
          fi

          rm -f "$FILE.bak"
          success "Removed $PKG from the Mullet. Run 'ft gen' to apply."
        else
          error "$PKG not found in the Landing Pad."
        fi
      '';

      lst = ''
        FILE="${cfg.sourcePath}"
        if [ ! -f "$FILE" ]; then error "Mullet source file not found at: $FILE"; exit 1; fi

        header "Imperative Packages (The Mullet)"
        sed -n "/${startMarker}/,/${endMarker}/p" "$FILE" \
          | sed '1d;$d' \
          | tr -d ' ' \
          | grep -v '^$' || echo "  (Empty)"
        echo ""
      '';

      haircut = ''
        FILE="${cfg.sourcePath}"
        if [ ! -f "$FILE" ]; then error "Mullet source file not found at: $FILE"; exit 1; fi

        read -p "This will remove all imperative packages. Continue? [y/N]: " choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
          cp "$FILE" "$FILE.bak"
          
          # Delete everything between markers, but keep the markers themselves
          sed -i "/${startMarker}/,/${endMarker}/ { /${startMarker}/b; /${endMarker}/b; d }" "$FILE"
          
          if ! nix-instantiate --parse "$FILE" > /dev/null 2>&1; then
            mv "$FILE.bak" "$FILE"
            error "Syntax validation failed during haircut. Reverting."
            exit 1
          fi

          rm -f "$FILE.bak"
          success "Haircut complete. Run 'ft gen' to apply the clean slate."
        else
          echo "Cancelled."
        fi
      '';
    };
  };
}
