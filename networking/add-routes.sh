#!/usr/bin/env bash

set -eu

ROUTE_ENTRIES=(
  "10.0.0.0|255.255.254.0|10.2.12.1"
  "10.2.10.0|255.255.255.0|10.2.12.1"
  "10.2.11.0|255.255.255.0|10.2.12.1"
  "10.2.12.0|255.255.255.0|10.2.12.1"
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
                     or: --add-route CIDR GATEWAY
  --delete-route     Delete a single route: --delete-route NETWORK NETMASK GATEWAY
                     or: --delete-route CIDR GATEWAY
  -h, --help         Show this help message

Supported platforms:
  macOS              Uses the built-in route command
  Linux              Uses ip route

Examples:
  $0
  $0 --reset
  $0 --remove-all
  $0 --add-route 10.9.0.0 255.255.255.0 10.2.12.1
  $0 --add-route 10.9.0.0/24 10.2.12.1
  $0 --delete-route 10.9.0.0 255.255.255.0 10.2.12.1
  $0 --delete-route 10.9.0.0/24 10.2.12.1
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

COLORS_ENABLED=false

init_colors() {
  if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    COLORS_ENABLED=true
  fi
}

warning_prefix() {
  if [ "$COLORS_ENABLED" = true ] || { command -v tput >/dev/null 2>&1 && [ -t 2 ]; }; then
    yellow="$(tput setaf 3)"
    bold="$(tput bold)"
    reset="$(tput sgr0)"
    printf '%s%sWarning:%s' "$bold" "$yellow" "$reset"
    return
  fi

  printf 'Warning:'
}

color_text() {
  color_name="$1"
  text="$2"

  if [ "$COLORS_ENABLED" != true ]; then
    printf '%s' "$text"
    return
  fi

  case "$color_name" in
  label)
    color_code="$(tput bold)$(tput setaf 6)"
    ;;
  route)
    color_code="$(tput setaf 2)"
    ;;
  gateway)
    color_code="$(tput setaf 5)"
    ;;
  *)
    color_code=""
    ;;
  esac

  reset="$(tput sgr0)"
  printf '%s%s%s' "$color_code" "$text" "$reset"
}

print_route_action() {
  action="$1"
  cidr="$2"
  gateway="$3"

  printf '%s %s %s %s\n' \
    "$action" \
    "$(color_text label 'route:')" \
    "$(color_text route "$cidr")" \
    "$(color_text label 'gateway:') $(color_text gateway "$gateway")"
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

ip_to_int() {
  ip_address="$1"

  IFS='.' read -r octet1 octet2 octet3 octet4 <<EOF
$ip_address
EOF

  for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
    case "$octet" in
    ''|*[!0-9]*)
      echo "Error: Invalid IP address: $ip_address" >&2
      exit 1
      ;;
    esac

    if [ "$octet" -gt 255 ]; then
      echo "Error: Invalid IP address: $ip_address" >&2
      exit 1
    fi
  done

  echo $((((octet1 << 24) | (octet2 << 16) | (octet3 << 8) | octet4)))
}

gateway_within_route() {
  network="$1"
  netmask="$2"
  gateway="$3"

  network_int="$(ip_to_int "$network")"
  netmask_int="$(ip_to_int "$netmask")"
  gateway_int="$(ip_to_int "$gateway")"

  [ $((gateway_int & netmask_int)) -eq $((network_int & netmask_int)) ]
}

prefix_to_netmask() {
  prefix="$1"
  remaining_bits="$prefix"
  netmask_octets=""

  case "$prefix" in
  ''|*[!0-9]*)
    echo "Error: Invalid CIDR prefix length: $prefix" >&2
    exit 1
    ;;
  esac

  if [ "$prefix" -lt 0 ] || [ "$prefix" -gt 32 ]; then
    echo "Error: CIDR prefix length must be between 0 and 32: $prefix" >&2
    exit 1
  fi

  for _ in 1 2 3 4; do
    if [ "$remaining_bits" -ge 8 ]; then
      octet=255
      remaining_bits=$((remaining_bits - 8))
    elif [ "$remaining_bits" -le 0 ]; then
      octet=0
    else
      octet=$((256 - 2 ** (8 - remaining_bits)))
      remaining_bits=0
    fi

    if [ -n "$netmask_octets" ]; then
      netmask_octets="$netmask_octets.$octet"
    else
      netmask_octets="$octet"
    fi
  done

  echo "$netmask_octets"
}

normalize_route_spec() {
  route_spec="$1"
  route_netmask="${2:-}"

  NORMALIZED_NETWORK=""
  NORMALIZED_NETMASK=""
  NORMALIZED_PREFIX=""

  case "$route_spec" in
  */*)
    NORMALIZED_NETWORK="${route_spec%%/*}"
    NORMALIZED_PREFIX="${route_spec#*/}"
    NORMALIZED_NETMASK="$(prefix_to_netmask "$NORMALIZED_PREFIX")"
    ;;
  *)
    NORMALIZED_NETWORK="$route_spec"
    NORMALIZED_NETMASK="$route_netmask"
    NORMALIZED_PREFIX="$(netmask_to_prefix "$route_netmask")"
    ;;
  esac
}

add_route() {
  network="$1"
  netmask="$2"
  gateway="$3"
  route_source="${4:-explicit}"
  prefix="$(netmask_to_prefix "$netmask")"

  if gateway_within_route "$network" "$netmask" "$gateway"; then
    if [ "$route_source" = "route_entries" ]; then
      printf '%s skipping %s/%s via %s because the gateway is inside the destination subnet.\n' \
        "$(warning_prefix)" "$network" "$netmask" "$gateway" >&2
      return 0
    fi

    echo "Error: refusing to add $network/$netmask via $gateway because the gateway is inside the destination subnet." >&2
    return 1
  fi

  print_route_action "Adding" "$network/$prefix" "$gateway"

  case "$PLATFORM" in
  macos)
    sudo route add -net "$network" -netmask "$netmask" "$gateway" >/dev/null 2>&1 ||
      sudo route change -net "$network" -netmask "$netmask" "$gateway" >/dev/null 2>&1
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

  print_route_action "Deleting" "$network/$prefix" "$gateway"

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
      "$callback" "$network" "$netmask" "$gateway" "route_entries"
    done
    return
  fi

  for entry in "${ROUTE_ENTRIES[@]}"; do
    IFS='|' read -r network netmask gateway <<EOF
$entry
EOF
    "$callback" "$network" "$netmask" "$gateway" "route_entries"
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
init_colors

if supports_assoc_routes; then
  declare -A ROUTES=()

  for entry in "${ROUTE_ENTRIES[@]}"; do
    IFS='|' read -r network netmask gateway <<EOF
$entry
EOF
    ROUTES["$network|$netmask"]="$gateway"
  done
fi

parse_single_route_args() {
  option_name="$1"
  route_spec="${2:-}"

  SINGLE_ROUTE_ARGC=0

  if [ -z "$route_spec" ]; then
    echo "Error: $option_name requires either NETWORK NETMASK GATEWAY or CIDR GATEWAY."
    usage
    exit 1
  fi

  case "$route_spec" in
  */*)
    if [ "$#" -lt 3 ]; then
      echo "Error: $option_name requires CIDR and GATEWAY when using CIDR notation."
      usage
      exit 1
    fi

    normalize_route_spec "$route_spec"
    SINGLE_NETWORK="$NORMALIZED_NETWORK"
    SINGLE_NETMASK="$NORMALIZED_NETMASK"
    SINGLE_GATEWAY="$3"
    SINGLE_ROUTE_ARGC=2
    ;;
  *)
    if [ "$#" -lt 4 ]; then
      echo "Error: $option_name requires NETWORK, NETMASK, and GATEWAY."
      usage
      exit 1
    fi

    normalize_route_spec "$route_spec" "$3"
    SINGLE_NETWORK="$NORMALIZED_NETWORK"
    SINGLE_NETMASK="$NORMALIZED_NETMASK"
    SINGLE_GATEWAY="$4"
    SINGLE_ROUTE_ARGC=3
    ;;
  esac
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
    parse_single_route_args "$@"
    ADD_SINGLE_ROUTE=true
    shift "$SINGLE_ROUTE_ARGC"
    ;;
  --delete-route)
    parse_single_route_args "$@"
    DELETE_SINGLE_ROUTE=true
    shift "$SINGLE_ROUTE_ARGC"
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
