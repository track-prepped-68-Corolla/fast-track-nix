# --- Fleet deployment (colmena) ---
#
# Thin passthrough to colmena, run against the consumer flake's `colmenaHive`
# output (colmena auto-detects the flake in the working directory). Only
# machines with `ft.deploy.enable = true` are nodes in the hive.
#
#   ft fleet apply               # build + activate every opted-in node
#   ft fleet apply --on @web     # only nodes tagged "web"
#   ft fleet build               # build all node closures, don't deploy
#   ft fleet apply-local         # deploy to the local host
#   ft fleet --help              # full colmena usage
fleet *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v colmena &> /dev/null; then
      echo ":: Error: colmena is not installed. Enable ft.cli on this machine. ::" >&2
      exit 1
    fi
    colmena {{ARGS}}
