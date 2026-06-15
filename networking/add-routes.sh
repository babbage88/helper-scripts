#!/usr/bin/env bash

set -eu

ROUTE_ENTRIES=(
  "10.0.0.0|255.255.254.0|10.2.12.1"
  "10.2.10.0|255.255.254.0|10.2.12.1"
  "10.2.11.0|255.255.254.0|10.2.12.1"
  "10.2.12.0|255.255.254.0|10.2.12.1"
  "10.2.20.0|255.255.254.0|10.2.12.1"
  "100.64.0.0|255.192.0.0|10.2.12.1"
)

supports_assoc_routes() {
  [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]
}

detect_platform() {
  case "$(uname -s)" in
  Darwin)
    echo "macos"
    ;;
  Linux)
    echo "linux"
    ;;
  *)
    echo "unsupported"
    ;;
  esac
}

maybe_reexec_newer_bash() {
  if supports_assoc_routes || [ "${ADD_ROUTES_BASH_REEXEC:-0}" = "1" ]; then
    return
  fi

  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$candidate" ]; then
      echo "Detected Bash ${BASH_VERSINFO[0]:-0}.${BASH_VERSINFO[1]:-0}; re-running with $candidate for associative-array support."
      exec env ADD_ROUTES_BASH_REEXEC=1 "$candidate" "$0" "$@"
    fi
  done
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r, --reset        Delete existing routes and re-add them
  -d, --remove-all   Delete all managed static routes
  --add-route        Add a single route: --add-route NETWORK NETMASK GATEWAY
  --delete-route     Delete a single route: --delete-route NETWORK NETMASK GATEWAY
  -h, --help         Show this help message

Supported platforms:
  macOS              Uses the built-in route command
  Linux              Uses ip route

Examples:
  $0
  $0 --reset
  $0 --remove-all
  $0 --add-route 10.9.0.0 255.255.255.0 10.2.12.1
  $0 --delete-route 10.9.0.0 255.255.255.0 10.2.12.1
EOF
}

require_platform_tools() {
  case "$PLATFORM" in
  macos)
    command -v route >/dev/null 2>&1 || {
      echo "Error: route command not found." >&2
      exit 1
    }
    ;;
  linux)
    command -v ip >/dev/null 2>&1 || {
      echo "Error: ip command not found. Install iproute2 and try again." >&2
      exit 1
    }
    ;;
  esac
}

netmask_to_prefix() {
  netmask="$1"
  prefix=0

  IFS='.' read -r octet1 octet2 octet3 octet4 <<EOF
$netmask
EOF

  for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
    case "$octet" in
    255)
      prefix=$((prefix + 8))
      ;;
    254)
      prefix=$((prefix + 7))
      ;;
    252)
      prefix=$((prefix + 6))
      ;;
    248)
      prefix=$((prefix + 5))
      ;;
    240)
      prefix=$((prefix + 4))
      ;;
    224)
      prefix=$((prefix + 3))
      ;;
    192)
      prefix=$((prefix + 2))
      ;;
    128)
      prefix=$((prefix + 1))
      ;;
    0)
      ;;
    *)
      echo "Error: Unsupported netmask: $netmask" >&2
      exit 1
      ;;
    esac
  done

  echo "$prefix"
}

add_route() {
  network="$1"
  netmask="$2"
  gateway="$3"
  prefix="$(netmask_to_prefix "$netmask")"

  echo "Adding route: $network/$netmask via $gateway"

  case "$PLATFORM" in
  macos)
    sudo route add -net "$network" -netmask "$netmask" "$gateway" 2>/dev/null ||
      sudo route change -net "$network" -netmask "$netmask" "$gateway"
    ;;
  linux)
    sudo ip route replace "$network/$prefix" via "$gateway"
    ;;
  *)
    echo "Error: Unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
  esac
}

delete_route() {
  network="$1"
  netmask="$2"
  gateway="$3"
  prefix="$(netmask_to_prefix "$netmask")"

  echo "Deleting route: $network/$netmask via $gateway"

  case "$PLATFORM" in
  macos)
    sudo route delete -net "$network" -netmask "$netmask" "$gateway" >/dev/null 2>&1 || true
    ;;
  linux)
    sudo ip route del "$network/$prefix" via "$gateway" >/dev/null 2>&1 ||
      sudo ip route del "$network/$prefix" >/dev/null 2>&1 ||
      true
    ;;
  *)
    echo "Error: Unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
  esac
}

iterate_routes() {
  callback="$1"

  if supports_assoc_routes; then
    for route in "${!ROUTES[@]}"; do
      IFS='|' read -r network netmask <<EOF
$route
EOF
      gateway="${ROUTES[$route]}"
      "$callback" "$network" "$netmask" "$gateway"
    done
    return
  fi

  for entry in "${ROUTE_ENTRIES[@]}"; do
    IFS='|' read -r network netmask gateway <<EOF
$entry
EOF
    "$callback" "$network" "$netmask" "$gateway"
  done
}

add_routes() {
  iterate_routes add_route
}

delete_routes() {
  iterate_routes delete_route
}

reset_routes() {
  delete_routes
  add_routes
}

RESET=false
REMOVE_ALL=false
ADD_SINGLE_ROUTE=false
DELETE_SINGLE_ROUTE=false
SINGLE_NETWORK=""
SINGLE_NETMASK=""
SINGLE_GATEWAY=""

maybe_reexec_newer_bash "$@"
PLATFORM="$(detect_platform)"

if [ "$PLATFORM" = "unsupported" ]; then
  echo "Error: Unsupported platform: $(uname -s)" >&2
  exit 1
fi

require_platform_tools

if supports_assoc_routes; then
  declare -A ROUTES=()

  for entry in "${ROUTE_ENTRIES[@]}"; do
    IFS='|' read -r network netmask gateway <<EOF
$entry
EOF
    ROUTES["$network|$netmask"]="$gateway"
  done
fi

require_route_args() {
  option_name="$1"

  if [ "$#" -lt 4 ]; then
    echo "Error: $option_name requires NETWORK, NETMASK, and GATEWAY."
    usage
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  -r|--reset)
    RESET=true
    ;;
  -d|--remove-all)
    REMOVE_ALL=true
    ;;
  --add-route)
    require_route_args "$1" "$@"
    ADD_SINGLE_ROUTE=true
    SINGLE_NETWORK="$2"
    SINGLE_NETMASK="$3"
    SINGLE_GATEWAY="$4"
    shift 3
    ;;
  --delete-route)
    require_route_args "$1" "$@"
    DELETE_SINGLE_ROUTE=true
    SINGLE_NETWORK="$2"
    SINGLE_NETMASK="$3"
    SINGLE_GATEWAY="$4"
    shift 3
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Error: Unknown option: $1"
    usage
    exit 1
    ;;
  esac
  shift
done

ACTION_COUNT=0

if [ "$RESET" = true ]; then
  ACTION_COUNT=$((ACTION_COUNT + 1))
fi

if [ "$REMOVE_ALL" = true ]; then
  ACTION_COUNT=$((ACTION_COUNT + 1))
fi

if [ "$ADD_SINGLE_ROUTE" = true ]; then
  ACTION_COUNT=$((ACTION_COUNT + 1))
fi

if [ "$DELETE_SINGLE_ROUTE" = true ]; then
  ACTION_COUNT=$((ACTION_COUNT + 1))
fi

if [ "$ACTION_COUNT" -gt 1 ]; then
  echo "Error: choose only one of --reset, --remove-all, --add-route, or --delete-route."
  exit 1
fi

if [ "$REMOVE_ALL" = true ]; then
  delete_routes
  exit 0
fi

if [ "$ADD_SINGLE_ROUTE" = true ]; then
  add_route "$SINGLE_NETWORK" "$SINGLE_NETMASK" "$SINGLE_GATEWAY"
  exit 0
fi

if [ "$DELETE_SINGLE_ROUTE" = true ]; then
  delete_route "$SINGLE_NETWORK" "$SINGLE_NETMASK" "$SINGLE_GATEWAY"
  exit 0
fi

if [ "$RESET" = true ]; then
  reset_routes
else
  add_routes
fi
