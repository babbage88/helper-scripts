#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

export WG_INTERFACE="${WG_INTERFACE:-wg0}"
ADVERTISED_ROUTES="${ADVERTISED_ROUTES:-10.0.0.0/23,10.2.0.0/16}"
EXTRA_TS_ARGS="${EXTRA_TS_ARGS:---snat-subnet-routes=false}"
TS_ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-true}"
SYSTEMD_UNIT_NAME="${SYSTEMD_UNIT_NAME:-tailscale-subnet-router.service}"
SYSTEMD_UNIT_PATH="${SYSTEMD_UNIT_PATH:-/etc/systemd/system/$SYSTEMD_UNIT_NAME}"
SYSTEMD_ENV_PATH="${SYSTEMD_ENV_PATH:-/etc/default/tailscale-subnet-router}"

RULE_PRIORITY="${RULE_PRIORITY:-2500}"
RULE_TABLE="${RULE_TABLE:-main}"
TAILNET_RULE_PRIORITY="${TAILNET_RULE_PRIORITY:-2600}"
TAILNET_RULE_TABLE="${TAILNET_RULE_TABLE:-52}"
TAILNET_CIDR="${TAILNET_CIDR:-100.64.0.0/10}"
LOCAL_SUBNETS=(
  "${LOCAL_SUBNET_1:-10.2.0.0/16}"
  "${LOCAL_SUBNET_2:-10.0.0.0/23}"
)
LOCAL_RULES_UNIT_NAME="${LOCAL_RULES_UNIT_NAME:-tailscale-local-main-rules.service}"
LOCAL_RULES_UNIT_PATH="${LOCAL_RULES_UNIT_PATH:-/etc/systemd/system/$LOCAL_RULES_UNIT_NAME}"
LOCAL_RULES_ENV_PATH="${LOCAL_RULES_ENV_PATH:-/etc/default/tailscale-local-main-rules}"
NM_CONNECTIONS="${NM_CONNECTIONS:-}"
ENABLE_EXIT_NODE_ADVERTISEMENT="${ENABLE_EXIT_NODE_ADVERTISEMENT:-false}"
ENABLE_WIREGUARD_INTERFACE="${ENABLE_WIREGUARD_INTERFACE:-false}"

COLORS_ENABLED=false

usage() {
  cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  start-subnet-router            Start Tailscale as a subnet router
  install-systemd-service        Install subnet router service and local rule persistence
  remove-systemd-service         Remove subnet router service and local rule persistence
  print-systemd-unit             Print the generated subnet router unit
  apply-local-rules              Apply local policy routing rules now
  remove-local-rules             Remove local policy routing rules now
  install-local-rules            Install persistent local policy routing rules
  remove-local-rules-persistence Remove persistent local policy routing rules
  detect-local-rules-backend     Print networkmanager or systemd
  print-local-rules-unit         Print the generated local-rules systemd unit
  help                           Show this help text

Options:
  -e, --advertise-exit-node      Append --advertise-exit-node to tailscale up
  -w, --enable-wireguard         Bring up the WireGuard interface before tailscale up
  -h, --help                     Show this help text

Default behavior:
  When no command is provided, install-local-rules is used by default.

Environment overrides:
  WG_INTERFACE=wg0
  ADVERTISED_ROUTES=10.0.0.0/23,10.2.0.0/16
  EXTRA_TS_ARGS="--snat-subnet-routes=false"
  TS_ACCEPT_ROUTES=true
  ENABLE_EXIT_NODE_ADVERTISEMENT=false
  ENABLE_WIREGUARD_INTERFACE=false
  SYSTEMD_UNIT_NAME=tailscale-subnet-router.service
  RULE_PRIORITY=2500
  RULE_TABLE=main
  TAILNET_RULE_PRIORITY=2600
  TAILNET_RULE_TABLE=52
  TAILNET_CIDR=100.64.0.0/10
  LOCAL_SUBNET_1=10.2.0.0/16
  LOCAL_SUBNET_2=10.0.0.0/23
  NM_CONNECTIONS=conn1,conn2
EOF
}

parse_args() {
  COMMAND="install-local-rules"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    start-subnet-router|install-systemd-service|remove-systemd-service|print-systemd-unit|apply-local-rules|remove-local-rules|install-local-rules|remove-local-rules-persistence|detect-local-rules-backend|print-local-rules-unit|help)
      COMMAND="$1"
      ;;
    -e|--advertise-exit-node)
      ENABLE_EXIT_NODE_ADVERTISEMENT=true
      ;;
    -w|--enable-wireguard)
      ENABLE_WIREGUARD_INTERFACE=true
      ;;
    -h|--help)
      COMMAND="help"
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
    esac

    shift
  done
}

require_linux_tools() {
  command -v ip >/dev/null 2>&1 || {
    echo "Error: ip command not found. Install iproute2 and try again." >&2
    exit 1
  }

  command -v tailscale >/dev/null 2>&1 || {
    echo "Error: tailscale command not found." >&2
    exit 1
  }
}

require_wireguard_tools() {
  command -v wg-quick >/dev/null 2>&1 || {
    echo "Error: wg-quick command not found." >&2
    exit 1
  }
}

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
  command)
    color_code="$(tput setaf 4)"
    ;;
  *)
    color_code=""
    ;;
  esac

  reset="$(tput sgr0)"
  printf '%s%s%s' "$color_code" "$text" "$reset"
}

print_rule_action() {
  action="$1"
  cidr="$2"
  table_name="$3"
  priority="$4"

  printf '%s %s %s %s %s %s\n' \
    "$action" \
    "$(color_text label 'rule:')" \
    "$(color_text route "$cidr")" \
    "$(color_text label 'table:')" \
    "$(color_text gateway "$table_name")" \
    "$(color_text label "priority:") $(color_text gateway "$priority")"
}

print_command_action() {
  action="$1"
  description="$2"

  printf '%s %s %s\n' \
    "$action" \
    "$(color_text label 'command:')" \
    "$(color_text command "$description")"
}

rule_table_number() {
  case "$RULE_TABLE" in
  main)
    echo 254
    ;;
  default)
    echo 253
    ;;
  local)
    echo 255
    ;;
  *)
    echo "$RULE_TABLE"
    ;;
  esac
}

rule_exists() {
  local subnet="$1"

  ip rule show | grep -Fq "to $subnet lookup $RULE_TABLE"
}

tailnet_rule_exists() {
  ip rule show | grep -Fq "to $TAILNET_CIDR lookup $TAILNET_RULE_TABLE"
}

apply_rule() {
  local subnet="$1"

  if rule_exists "$subnet"; then
    printf '%s rule already present for %s.\n' "$(warning_prefix)" "$subnet" >&2
    return 0
  fi

  print_rule_action "Adding" "$subnet" "$RULE_TABLE" "$RULE_PRIORITY"
  sudo ip rule add to "$subnet" priority "$RULE_PRIORITY" lookup "$RULE_TABLE"
}

remove_rule() {
  local subnet="$1"

  while rule_exists "$subnet"; do
    print_rule_action "Removing" "$subnet" "$RULE_TABLE" "$RULE_PRIORITY"
    sudo ip rule delete to "$subnet" priority "$RULE_PRIORITY" lookup "$RULE_TABLE"
  done
}

apply_tailnet_rule() {
  if tailnet_rule_exists; then
    printf '%s tailnet forwarding rule already present for %s.\n' "$(warning_prefix)" "$TAILNET_CIDR" >&2
    return 0
  fi

  print_rule_action "Adding" "$TAILNET_CIDR" "$TAILNET_RULE_TABLE" "$TAILNET_RULE_PRIORITY"
  sudo ip rule add to "$TAILNET_CIDR" priority "$TAILNET_RULE_PRIORITY" lookup "$TAILNET_RULE_TABLE"
}

remove_tailnet_rule() {
  while tailnet_rule_exists; do
    print_rule_action "Removing" "$TAILNET_CIDR" "$TAILNET_RULE_TABLE" "$TAILNET_RULE_PRIORITY"
    sudo ip rule delete to "$TAILNET_CIDR" priority "$TAILNET_RULE_PRIORITY" lookup "$TAILNET_RULE_TABLE"
  done
}

apply_local_rules() {
  local subnet

  for subnet in "${LOCAL_SUBNETS[@]}"; do
    apply_rule "$subnet"
  done

  apply_tailnet_rule
}

remove_local_rules() {
  local subnet

  for subnet in "${LOCAL_SUBNETS[@]}"; do
    remove_rule "$subnet"
  done

  remove_tailnet_rule
}

networkmanager_is_active() {
  command -v nmcli >/dev/null 2>&1 &&
    command -v systemctl >/dev/null 2>&1 &&
    systemctl is-active --quiet NetworkManager
}

resolve_nm_connections() {
  if [ -n "$NM_CONNECTIONS" ]; then
    tr ',' '\n' <<<"$NM_CONNECTIONS" | sed '/^[[:space:]]*$/d'
    return 0
  fi

  nmcli -t -f NAME,DEVICE connection show --active |
    awk -F: '$2 != "" && $2 != "lo" && $2 != "tailscale0" { print $1 }' |
    sort -u
}

require_single_nm_connection_if_autodetected() {
  local -a connections=()

  mapfile -t connections < <(resolve_nm_connections)

  if [ "${#connections[@]}" -eq 0 ]; then
    echo "Error: No active NetworkManager connections were found." >&2
    exit 1
  fi

  if [ -z "$NM_CONNECTIONS" ] && [ "${#connections[@]}" -gt 1 ]; then
    echo "Error: Multiple active NetworkManager connections were detected: ${connections[*]}" >&2
    echo "Set NM_CONNECTIONS=conn1,conn2 to choose which profiles should persist the routing rules." >&2
    exit 1
  fi

  printf '%s\n' "${connections[@]}"
}

nm_rule_spec() {
  local subnet="$1"
  local table_number

  table_number="$(rule_table_number)"
  printf 'priority %s to %s table %s' "$RULE_PRIORITY" "$subnet" "$table_number"
}

nm_tailnet_rule_spec() {
  printf 'priority %s to %s table %s' "$TAILNET_RULE_PRIORITY" "$TAILNET_CIDR" "$TAILNET_RULE_TABLE"
}

nm_rule_exists() {
  local connection="$1"
  local subnet="$2"
  local spec

  spec="$(nm_rule_spec "$subnet")"
  nmcli -g ipv4.routing-rules connection show "$connection" | tr ',' '\n' | grep -Fqx "$spec"
}

nm_tailnet_rule_exists() {
  local connection="$1"
  local spec

  spec="$(nm_tailnet_rule_spec)"
  nmcli -g ipv4.routing-rules connection show "$connection" | tr ',' '\n' | grep -Fqx "$spec"
}

install_nm_local_rules_persistence() {
  local -a connections=()
  local connection
  local subnet
  local spec
  local tailnet_spec

  mapfile -t connections < <(require_single_nm_connection_if_autodetected)
  tailnet_spec="$(nm_tailnet_rule_spec)"

  for connection in "${connections[@]}"; do
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      spec="$(nm_rule_spec "$subnet")"
      if nm_rule_exists "$connection" "$subnet"; then
        printf '%s NetworkManager profile %s already has rule: %s\n' \
          "$(warning_prefix)" "$connection" "$spec" >&2
        continue
      fi

      print_command_action "Adding" "nmcli connection modify $connection +ipv4.routing-rules $spec"
      sudo nmcli connection modify "$connection" +ipv4.routing-rules "$spec"
    done

    if nm_tailnet_rule_exists "$connection"; then
      printf '%s NetworkManager profile %s already has rule: %s\n' \
        "$(warning_prefix)" "$connection" "$tailnet_spec" >&2
      continue
    fi

    print_command_action "Adding" "nmcli connection modify $connection +ipv4.routing-rules $tailnet_spec"
    sudo nmcli connection modify "$connection" +ipv4.routing-rules "$tailnet_spec"
  done

  cat <<EOF
NetworkManager persistence installed.
Reactivate the modified connection profile(s) or reboot for NetworkManager to
fully re-apply the saved routing rules.
EOF
}

remove_nm_local_rules_persistence() {
  local -a connections=()
  local connection
  local subnet
  local spec
  local tailnet_spec

  mapfile -t connections < <(require_single_nm_connection_if_autodetected)
  tailnet_spec="$(nm_tailnet_rule_spec)"

  for connection in "${connections[@]}"; do
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      spec="$(nm_rule_spec "$subnet")"
      if ! nm_rule_exists "$connection" "$subnet"; then
        printf '%s NetworkManager profile %s does not contain rule: %s\n' \
          "$(warning_prefix)" "$connection" "$spec" >&2
        continue
      fi

      print_command_action "Removing" "nmcli connection modify $connection -ipv4.routing-rules $spec"
      sudo nmcli connection modify "$connection" -ipv4.routing-rules "$spec"
    done

    if ! nm_tailnet_rule_exists "$connection"; then
      printf '%s NetworkManager profile %s does not contain rule: %s\n' \
        "$(warning_prefix)" "$connection" "$tailnet_spec" >&2
      continue
    fi

    print_command_action "Removing" "nmcli connection modify $connection -ipv4.routing-rules $tailnet_spec"
    sudo nmcli connection modify "$connection" -ipv4.routing-rules "$tailnet_spec"
  done
}

write_local_rules_environment_file() {
  {
    printf 'RULE_PRIORITY=%s\n' "$RULE_PRIORITY"
    printf 'RULE_TABLE=%s\n' "$RULE_TABLE"
    printf 'TAILNET_RULE_PRIORITY=%s\n' "$TAILNET_RULE_PRIORITY"
    printf 'TAILNET_RULE_TABLE=%s\n' "$TAILNET_RULE_TABLE"
    printf 'TAILNET_CIDR=%s\n' "$TAILNET_CIDR"
    local index=1
    local subnet

    for subnet in "${LOCAL_SUBNETS[@]}"; do
      printf 'LOCAL_SUBNET_%s=%s\n' "$index" "$subnet"
      index=$((index + 1))
    done
  } | sudo tee "$LOCAL_RULES_ENV_PATH" >/dev/null
}

print_local_rules_systemd_unit() {
  cat <<EOF
[Unit]
Description=Prefer main table for local LAN destinations on Tailscale nodes
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=oneshot
EnvironmentFile=-$LOCAL_RULES_ENV_PATH
ExecStart=/bin/bash $SCRIPT_PATH apply-local-rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

install_systemd_local_rules_persistence() {
  write_local_rules_environment_file
  print_local_rules_systemd_unit | sudo tee "$LOCAL_RULES_UNIT_PATH" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$LOCAL_RULES_UNIT_NAME"
  echo "Systemd persistence installed with unit $LOCAL_RULES_UNIT_NAME"
}

remove_systemd_local_rules_persistence() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl disable --now "$LOCAL_RULES_UNIT_NAME" >/dev/null 2>&1 || true
  fi

  sudo rm -f "$LOCAL_RULES_UNIT_PATH" "$LOCAL_RULES_ENV_PATH"

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload
  fi
}

detect_local_rules_backend() {
  if networkmanager_is_active; then
    echo "networkmanager"
    return
  fi

  echo "systemd"
}

install_local_rules_persistence() {
  if networkmanager_is_active; then
    install_nm_local_rules_persistence
  else
    install_systemd_local_rules_persistence
  fi
}

remove_local_rules_persistence() {
  if networkmanager_is_active; then
    remove_nm_local_rules_persistence
  else
    remove_systemd_local_rules_persistence
  fi
}

write_subnet_router_environment_file() {
  {
    printf 'WG_INTERFACE=%s\n' "$WG_INTERFACE"
    printf 'ADVERTISED_ROUTES=%s\n' "$ADVERTISED_ROUTES"
    printf 'EXTRA_TS_ARGS=%s\n' "$EXTRA_TS_ARGS"
    printf 'TS_ACCEPT_ROUTES=%s\n' "$TS_ACCEPT_ROUTES"
    printf 'ENABLE_EXIT_NODE_ADVERTISEMENT=%s\n' "$ENABLE_EXIT_NODE_ADVERTISEMENT"
    printf 'ENABLE_WIREGUARD_INTERFACE=%s\n' "$ENABLE_WIREGUARD_INTERFACE"
    printf 'RULE_PRIORITY=%s\n' "$RULE_PRIORITY"
    printf 'RULE_TABLE=%s\n' "$RULE_TABLE"
    printf 'TAILNET_RULE_PRIORITY=%s\n' "$TAILNET_RULE_PRIORITY"
    printf 'TAILNET_RULE_TABLE=%s\n' "$TAILNET_RULE_TABLE"
    printf 'TAILNET_CIDR=%s\n' "$TAILNET_CIDR"
    local index=1
    local subnet

    for subnet in "${LOCAL_SUBNETS[@]}"; do
      printf 'LOCAL_SUBNET_%s=%s\n' "$index" "$subnet"
      index=$((index + 1))
    done
  } | sudo tee "$SYSTEMD_ENV_PATH" >/dev/null
}

print_systemd_unit() {
  cat <<EOF
[Unit]
Description=Tailscale subnet router
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=oneshot
EnvironmentFile=-$SYSTEMD_ENV_PATH
ExecStart=/bin/bash $SCRIPT_PATH start-subnet-router
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

reset_pia_wg_interface() {
  print_command_action "Applying" "disable IPv6 temporarily for $WG_INTERFACE"
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

  if ip link show "$WG_INTERFACE" up &>/dev/null; then
    print_command_action "Resetting" "wg-quick down $WG_INTERFACE"
    sudo wg-quick down "$WG_INTERFACE"
    sleep 5
    print_command_action "Starting" "wg-quick up $WG_INTERFACE"
    sudo wg-quick up "$WG_INTERFACE"
  else
    print_command_action "Starting" "wg-quick up $WG_INTERFACE"
    sudo wg-quick up "$WG_INTERFACE"
    sleep 5
  fi
}

build_tailscale_up_args() {
  TS_UP_ARGS=("--advertise-routes=$ADVERTISED_ROUTES" "--reset")

  if [ -n "$EXTRA_TS_ARGS" ]; then
    read -r -a extra_ts_args_array <<<"$EXTRA_TS_ARGS"
    TS_UP_ARGS+=("${extra_ts_args_array[@]}")
  fi

  if [ "$TS_ACCEPT_ROUTES" = "true" ]; then
    TS_UP_ARGS+=("--accept-routes")
  fi

  if [ "$ENABLE_EXIT_NODE_ADVERTISEMENT" = "true" ]; then
    TS_UP_ARGS+=("--advertise-exit-node")
  fi
}

maybe_apply_local_rules() {
  if [ "$TS_ACCEPT_ROUTES" != "true" ]; then
    return 0
  fi

  apply_local_rules
}

install_systemd_service() {
  write_subnet_router_environment_file
  print_systemd_unit | sudo tee "$SYSTEMD_UNIT_PATH" >/dev/null
  maybe_apply_local_rules
  install_local_rules_persistence
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SYSTEMD_UNIT_NAME"
  echo "Installed and started $SYSTEMD_UNIT_NAME"
}

remove_systemd_service() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl disable --now "$SYSTEMD_UNIT_NAME" >/dev/null 2>&1 || true
  fi

  sudo rm -f "$SYSTEMD_UNIT_PATH" "$SYSTEMD_ENV_PATH"

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload
  fi
}

start_ts_subnet_router() {
  if [ "$ENABLE_WIREGUARD_INTERFACE" = "true" ]; then
    require_wireguard_tools
    reset_pia_wg_interface
  fi

  maybe_apply_local_rules
  build_tailscale_up_args
  print_command_action "Starting" "tailscale up ${TS_UP_ARGS[*]}"
  sudo tailscale up "${TS_UP_ARGS[@]}"
}

main() {
  parse_args "$@"

  case "$COMMAND" in
  start-subnet-router)
    start_ts_subnet_router
    ;;
  install-systemd-service)
    install_systemd_service
    ;;
  remove-systemd-service)
    remove_systemd_service
    ;;
  print-systemd-unit)
    print_systemd_unit
    ;;
  apply-local-rules)
    apply_local_rules
    ;;
  remove-local-rules)
    remove_local_rules
    ;;
  install-local-rules)
    install_local_rules_persistence
    ;;
  remove-local-rules-persistence)
    remove_local_rules_persistence
    ;;
  detect-local-rules-backend)
    detect_local_rules_backend
    ;;
  print-local-rules-unit)
    print_local_rules_systemd_unit
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Error: Unknown command: $command" >&2
    usage >&2
    exit 1
    ;;
  esac
}

require_linux_tools
init_colors
main "$@"
