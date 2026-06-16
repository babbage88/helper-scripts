#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
RULE_PRIORITY="${RULE_PRIORITY:-2500}"
RULE_TABLE="${RULE_TABLE:-main}"
LOCAL_SUBNETS=(
  "${LOCAL_SUBNET_1:-10.2.0.0/16}"
  "${LOCAL_SUBNET_2:-10.0.0.0/23}"
)
SYSTEMD_UNIT_NAME="${SYSTEMD_UNIT_NAME:-tailscale-local-main-rules.service}"
SYSTEMD_UNIT_PATH="${SYSTEMD_UNIT_PATH:-/etc/systemd/system/$SYSTEMD_UNIT_NAME}"
SYSTEMD_ENV_PATH="${SYSTEMD_ENV_PATH:-/etc/default/tailscale-local-main-rules}"
NM_CONNECTIONS="${NM_CONNECTIONS:-}"

usage() {
  cat <<EOF
Usage: $0 [apply|remove|detect-backend|install-persistence|remove-persistence]

Applies or removes ip rules that force traffic destined for directly-connected
LAN prefixes to use the main routing table instead of Tailscale's policy table.

Environment overrides:
  RULE_PRIORITY=2500
  RULE_TABLE=main
  LOCAL_SUBNET_1=10.2.0.0/16
  LOCAL_SUBNET_2=10.0.0.0/23
  NM_CONNECTIONS=conn1,conn2

Persistence behavior:
  - Uses NetworkManager connection profiles when nmcli is present and
    NetworkManager is active.
  - Falls back to a systemd oneshot service otherwise.
EOF
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

apply_rule() {
  local subnet="$1"

  if rule_exists "$subnet"; then
    echo "Rule already present for $subnet"
    return 0
  fi

  echo "Adding rule for $subnet via table $RULE_TABLE with priority $RULE_PRIORITY"
  sudo ip rule add to "$subnet" priority "$RULE_PRIORITY" lookup "$RULE_TABLE"
}

remove_rule() {
  local subnet="$1"

  while rule_exists "$subnet"; do
    echo "Removing rule for $subnet via table $RULE_TABLE with priority $RULE_PRIORITY"
    sudo ip rule delete to "$subnet" priority "$RULE_PRIORITY" lookup "$RULE_TABLE"
  done
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
    echo "No active NetworkManager connections were found." >&2
    exit 1
  fi

  if [ -z "$NM_CONNECTIONS" ] && [ "${#connections[@]}" -gt 1 ]; then
    echo "Multiple active NetworkManager connections were detected: ${connections[*]}" >&2
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

nm_rule_exists() {
  local connection="$1"
  local subnet="$2"
  local spec

  spec="$(nm_rule_spec "$subnet")"
  nmcli -g ipv4.routing-rules connection show "$connection" | tr ',' '\n' | grep -Fqx "$spec"
}

install_nm_persistence() {
  local -a connections=()
  local connection
  local subnet
  local spec

  mapfile -t connections < <(require_single_nm_connection_if_autodetected)

  for connection in "${connections[@]}"; do
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      spec="$(nm_rule_spec "$subnet")"
      if nm_rule_exists "$connection" "$subnet"; then
        echo "NetworkManager profile $connection already has rule: $spec"
        continue
      fi

      echo "Adding NetworkManager rule to $connection: $spec"
      sudo nmcli connection modify "$connection" +ipv4.routing-rules "$spec"
    done
  done

  cat <<EOF
NetworkManager persistence installed.
Reactivate the modified connection profile(s) or reboot for NetworkManager to
fully re-apply the saved routing rules.
EOF
}

remove_nm_persistence() {
  local -a connections=()
  local connection
  local subnet
  local spec

  mapfile -t connections < <(require_single_nm_connection_if_autodetected)

  for connection in "${connections[@]}"; do
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      spec="$(nm_rule_spec "$subnet")"
      if ! nm_rule_exists "$connection" "$subnet"; then
        echo "NetworkManager profile $connection does not contain rule: $spec"
        continue
      fi

      echo "Removing NetworkManager rule from $connection: $spec"
      sudo nmcli connection modify "$connection" -ipv4.routing-rules "$spec"
    done
  done
}

write_systemd_environment_file() {
  {
    printf 'RULE_PRIORITY=%s\n' "$RULE_PRIORITY"
    printf 'RULE_TABLE=%s\n' "$RULE_TABLE"
    local index=1
    local subnet

    for subnet in "${LOCAL_SUBNETS[@]}"; do
      printf 'LOCAL_SUBNET_%s=%s\n' "$index" "$subnet"
      index=$((index + 1))
    done
  } | sudo tee "$SYSTEMD_ENV_PATH" >/dev/null
}

write_systemd_unit_file() {
  sudo tee "$SYSTEMD_UNIT_PATH" >/dev/null <<EOF
[Unit]
Description=Prefer main table for local LAN destinations on Tailscale nodes
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=oneshot
EnvironmentFile=-$SYSTEMD_ENV_PATH
ExecStart=/bin/bash $SCRIPT_PATH apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

install_systemd_persistence() {
  write_systemd_environment_file
  write_systemd_unit_file
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SYSTEMD_UNIT_NAME"
  echo "Systemd persistence installed with unit $SYSTEMD_UNIT_NAME"
}

remove_systemd_persistence() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl disable --now "$SYSTEMD_UNIT_NAME" >/dev/null 2>&1 || true
  fi

  sudo rm -f "$SYSTEMD_UNIT_PATH" "$SYSTEMD_ENV_PATH"

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload
  fi
}

detect_backend() {
  if networkmanager_is_active; then
    echo "networkmanager"
    return
  fi

  echo "systemd"
}

main() {
  local action="${1:-apply}"

  case "$action" in
  apply)
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      apply_rule "$subnet"
    done
    ;;
  remove)
    for subnet in "${LOCAL_SUBNETS[@]}"; do
      remove_rule "$subnet"
    done
    ;;
  detect-backend)
    detect_backend
    ;;
  install-persistence)
    if networkmanager_is_active; then
      install_nm_persistence
    else
      install_systemd_persistence
    fi
    ;;
  remove-persistence)
    if networkmanager_is_active; then
      remove_nm_persistence
    else
      remove_systemd_persistence
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown action: $action" >&2
    usage
    exit 1
    ;;
  esac
}

main "$@"
