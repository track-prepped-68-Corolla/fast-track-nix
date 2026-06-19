MULLET_FILE := "users/" + env_var("USER") + "/var/mullet.txt"

@search query:
    #!/usr/bin/env bash
    echo ":: Searching Nix-Index for binary '{{query}}' ::"
    RESULTS=$(nix-locate --top-level --minimal --at-root "/bin/{{query}}")
    
    if [ -n "$RESULTS" ]; then
      echo "$RESULTS"
    else
      echo ":: No exact binary match in Nix-Index. ::"
      echo ":: Searching Nixpkgs descriptions... ::"
      nix search nixpkgs "{{query}}" | head -n 15
    fi

@add pkg:
    #!/usr/bin/env bash
    set -e
    # shellcheck source=lib/mullet.sh
    source "{{justfile_directory()}}/lib/mullet.sh"

    # 1. Check if it's already in the file
    if mullet_contains "{{MULLET_FILE}}" "{{pkg}}"; then
      echo ":: '{{pkg}}' is already in The Mullet. ::"
      exit 0
    fi

    echo ":: Verifying '{{pkg}}' exists... ::"
    
    # 2. Fast validation that natively supports nested attributes
    if ! nix eval "nixpkgs#{{pkg}}" --apply "p: p.outPath or p.pname or p.name" &>/dev/null; then
      echo ":: Error: '{{pkg}}' is not a valid package path. ::"
      echo ":: Did you mean one of these? (Searching Nix-Index for '{{pkg}}') ::"
      echo ""
      nix-locate --top-level --minimal --at-root "/bin/{{pkg}}"
      
      echo ""
      echo ":: (Fallback) Searching Nixpkgs descriptions... ::"
      nix search nixpkgs "{{pkg}}" | head -n 10
      exit 1
    fi

    # 3. Append to the flat file
    mullet_add_line "{{MULLET_FILE}}" "{{pkg}}"
    echo ":: Added {{pkg}}. Run 'ft switch' to apply. ::"

@rm pkg:
    #!/usr/bin/env bash
    set -e
    # shellcheck source=lib/mullet.sh
    source "{{justfile_directory()}}/lib/mullet.sh"
    if mullet_contains "{{MULLET_FILE}}" "{{pkg}}"; then
      mullet_rm_line "{{MULLET_FILE}}" "{{pkg}}"
      echo ":: Removed {{pkg}}. Run 'ft switch' to apply. ::"
    else
      echo ":: Error: '{{pkg}}' not found in The Mullet. ::"
      exit 1
    fi

@lst:
    echo ":: Imperative Packages (The Mullet) ::"
    cat "{{MULLET_FILE}}" || echo "  (Empty)"

@haircut:
    #!/usr/bin/env bash
    read -p "This removes all imperative packages. Continue? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      > "{{MULLET_FILE}}"
      echo ":: Haircut complete. Run 'ft switch' to apply the clean slate. ::"
    else
      echo "Cancelled."
    fi