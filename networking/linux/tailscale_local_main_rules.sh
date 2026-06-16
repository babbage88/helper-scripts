#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAILSCALE_RTR_SCRIPT="${TAILSCALE_RTR_SCRIPT:-$SCRIPT_DIR/tailscale_rtr.sh}"

if [ ! -x "$TAILSCALE_RTR_SCRIPT" ]; then
  echo "Error: consolidated script not found or not executable: $TAILSCALE_RTR_SCRIPT" >&2
  exit 1
fi

case "${1:-install-persistence}" in
apply)
  exec "$TAILSCALE_RTR_SCRIPT" apply-local-rules
  ;;
remove)
  exec "$TAILSCALE_RTR_SCRIPT" remove-local-rules
  ;;
detect-backend)
  exec "$TAILSCALE_RTR_SCRIPT" detect-local-rules-backend
  ;;
install-persistence)
  exec "$TAILSCALE_RTR_SCRIPT" install-local-rules
  ;;
remove-persistence)
  exec "$TAILSCALE_RTR_SCRIPT" remove-local-rules-persistence
  ;;
-h|--help|help)
  cat <<EOF
Usage: $0 [apply|remove|detect-backend|install-persistence|remove-persistence]

Compatibility wrapper for tailscale_rtr.sh local-rules commands.
When no action is provided, install-persistence is used by default.
EOF
  ;;
*)
  echo "Error: Unknown action: $1" >&2
  exit 1
  ;;
esac
