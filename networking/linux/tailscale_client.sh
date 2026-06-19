#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

RULE_PRIORITY="${RULE_PRIORITY:-2500}"
RULE_TABLE="${RULE_TABLE:-main}"
TAILNET_RULE_PRIORITY="${TAILNET_RULE_PRIORITY:-2600}"
TAILNET_RULE_TABLE="${TAILNET_RULE_TABLE:-52}"
TAILNET_CIDR="${TAILNET_CIDR:-100.64.0.0/10}"
LOCAL_SUBNETS=(
  "${LOCAL_SUBNET_1:-10.2.0.0/16}"
  "${LOCAL_SUBNET_2:-10.0.0.0/23}"
)

RP_FILTER_VALUE="${RP_FILTER_VALUE:-0}"
RP_FILTER_INTERFACES=(
  "${RP_FILTER_INTERFACE_1:-all}"
  "${RP_FILTER_INTERFACE_2:-default}"
  "${RP_FILTER_INTERFACE_3:-tailscale0}"
)

SYSTEMD_UNIT_NAME="${SYSTEMD_UNIT_NAME:-tailscale-client-routes.service}"
SYSTEMD_UNIT_PATH="${SYSTEMD_UNIT_PATH:-/etc/systemd/system/$SYSTEMD_UNIT_NAME}"
SYSTEMD_ENV_PATH="${SYSTEMD_ENV_PATH:-/etc/default/tailscale-client-routes}"
SYSCTL_DROPIN_DIR="${SYSCTL_DROPIN_DIR:-/etc/sysctl.d}"
SYSCTL_DROPIN_PATH="${SYSCTL_DROPIN_PATH:-$SYSCTL_DROPIN_DIR/99-tailscale-client-rpf.conf}"

COLORS_ENABLED=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [COMMAND]

Commands:
  apply                   Apply rp_filter and policy-routing rules now
  remove                  Remove rp_filter and policy-routing rules now
  install-persistence     Install persistent client routing and rp_filter settings
  remove-persistence      Remove persistent client routing and rp_filter settings
  print-systemd-unit      Print the generated systemd unit
  print-sysctl-dropin     Print the generated rp_filter sysctl drop-in
  help                    Show this help text

Default behavior:
  When no command is provided, install-persistence is used by default.

Environment overrides:
  RULE_PRIORITY=2500
  RULE_TABLE=main
  TAILNET_RULE_PRIORITY=2600
  TAILNET_RULE_TABLE=52
  TAILNET_CIDR=100.64.0.0/10
  LOCAL_SUBNET_1=10.2.0.0/16
  LOCAL_SUBNET_2=10.0.0.0/23
  RP_FILTER_VALUE=0
  RP_FILTER_INTERFACE_1=all
  RP_FILTER_INTERFACE_2=default
  RP_FILTER_INTERFACE_3=tailscale0
  SYSTEMD_UNIT_NAME=tailscale-client-routes.service

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME apply
  $SCRIPT_NAME install-persistence
  $SCRIPT_NAME remove-persistence
EOF
}

init_colors() {
  if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    COLORS_ENABLED=true
  fi
}

color_text() {
  color_name="$1"
  text="$2"

  if [ "$COLORS_ENABLED" != true ]; then
    printf '%s' "$text"
    return
  fi

  case "$color_name" in
  info)
    color_code="$(tput bold)$(tput setaf 6)"
    ;;
  success)
    color_code="$(tput bold)$(tput setaf 2)"
    ;;
  warning)
    color_code="$(tput bold)$(tput setaf 3)"
    ;;
  error)
    color_code="$(tput bold)$(tput setaf 1)"
    ;;
  value)
    color_code="$(tput setaf 5)"
    ;;
  *)
    color_code=""
    ;;
  esac

  reset="$(tput sgr0)"
  printf '%s%s%s' "$color_code" "$text" "$reset"
}

log_info() {
  printf '%s %s\n' "$(color_text info 'Info:')" "$1"
}

log_success() {
  printf '%s %s\n' "$(color_text success 'Success:')" "$1"
}

log_warning() {
  printf '%s %s\n' "$(color_text warning 'Warning:')" "$1"
}

log_error() {
  printf '%s %s\n' "$(color_text error 'Error:')" "$1" >&2
}

print_rule_action() {
  action="$1"
  cidr="$2"
  table_name="$3"
  priority="$4"

  printf '%s %s %s %s %s %s\n' \
    "$action" \
    "$(color_text info 'rule:')" \
    "$(color_text value "$cidr")" \
    "$(color_text info 'table:')" \
    "$(color_text value "$table_name")" \
    "$(color_text info "priority:") $(color_text value "$priority")"
}

print_setting_action() {
  action="$1"
  key="$2"
  value="$3"

  printf '%s %s %s %s %s\n' \
    "$action" \
    "$(color_text info 'setting:')" \
    "$(color_text value "$key")" \
    "$(color_text info 'value:')" \
    "$(color_text value "$value")"
}

require_linux_tools() {
  command -v ip >/dev/null 2>&1 || {
    log_error "Required command not found: ip"
    exit 1
  }

  command -v sysctl >/dev/null 2>&1 || {
    log_error "Required command not found: sysctl"
    exit 1
  }
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
    log_warning "Rule already present for $(color_text value "$subnet")"
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
    log_warning "Tailnet forwarding rule already present for $(color_text value "$TAILNET_CIDR")"
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

apply_rp_filter_settings() {
  local interface_name

  for interface_name in "${RP_FILTER_INTERFACES[@]}"; do
    print_setting_action "Applying" "net.ipv4.conf.${interface_name}.rp_filter" "$RP_FILTER_VALUE"
    sudo sysctl -w "net.ipv4.conf.${interface_name}.rp_filter=$RP_FILTER_VALUE" >/dev/null
  done
}

remove_rp_filter_settings() {
  local interface_name

  for interface_name in "${RP_FILTER_INTERFACES[@]}"; do
    print_setting_action "Applying" "net.ipv4.conf.${interface_name}.rp_filter" "1"
    sudo sysctl -w "net.ipv4.conf.${interface_name}.rp_filter=1" >/dev/null
  done
}

apply_client_rules() {
  local subnet

  apply_rp_filter_settings

  for subnet in "${LOCAL_SUBNETS[@]}"; do
    apply_rule "$subnet"
  done

  apply_tailnet_rule
}

remove_client_rules() {
  local subnet

  for subnet in "${LOCAL_SUBNETS[@]}"; do
    remove_rule "$subnet"
  done

  remove_tailnet_rule
  remove_rp_filter_settings
}

write_environment_file() {
  {
    printf 'RULE_PRIORITY=%s\n' "$RULE_PRIORITY"
    printf 'RULE_TABLE=%s\n' "$RULE_TABLE"
    printf 'TAILNET_RULE_PRIORITY=%s\n' "$TAILNET_RULE_PRIORITY"
    printf 'TAILNET_RULE_TABLE=%s\n' "$TAILNET_RULE_TABLE"
    printf 'TAILNET_CIDR=%s\n' "$TAILNET_CIDR"
    printf 'RP_FILTER_VALUE=%s\n' "$RP_FILTER_VALUE"
    local index=1
    local subnet
    local interface_name

    for subnet in "${LOCAL_SUBNETS[@]}"; do
      printf 'LOCAL_SUBNET_%s=%s\n' "$index" "$subnet"
      index=$((index + 1))
    done

    index=1
    for interface_name in "${RP_FILTER_INTERFACES[@]}"; do
      printf 'RP_FILTER_INTERFACE_%s=%s\n' "$index" "$interface_name"
      index=$((index + 1))
    done
  } | sudo tee "$SYSTEMD_ENV_PATH" >/dev/null
}

print_systemd_unit() {
  cat <<EOF
[Unit]
Description=Persist Tailscale client routing and rp_filter settings
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

print_sysctl_dropin() {
  local interface_name

  for interface_name in "${RP_FILTER_INTERFACES[@]}"; do
    printf 'net.ipv4.conf.%s.rp_filter=%s\n' "$interface_name" "$RP_FILTER_VALUE"
  done
}

install_persistence() {
  write_environment_file
  print_systemd_unit | sudo tee "$SYSTEMD_UNIT_PATH" >/dev/null
  sudo mkdir -p "$SYSCTL_DROPIN_DIR"
  print_sysctl_dropin | sudo tee "$SYSCTL_DROPIN_PATH" >/dev/null
  apply_client_rules
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SYSTEMD_UNIT_NAME"
  sudo sysctl --system >/dev/null
  log_success "Installed client persistence via $(color_text value "$SYSTEMD_UNIT_NAME")"
  log_success "Installed rp_filter sysctl drop-in at $(color_text value "$SYSCTL_DROPIN_PATH")"
}

remove_persistence() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl disable --now "$SYSTEMD_UNIT_NAME" >/dev/null 2>&1 || true
    sudo systemctl daemon-reload
  fi

  sudo rm -f "$SYSTEMD_UNIT_PATH" "$SYSTEMD_ENV_PATH" "$SYSCTL_DROPIN_PATH"
  remove_client_rules
  sudo sysctl --system >/dev/null
  log_success "Removed client persistence for $(color_text value "$SYSTEMD_UNIT_NAME")"
}

main() {
  action="${1:-install-persistence}"

  case "$action" in
  apply)
    apply_client_rules
    ;;
  remove)
    remove_client_rules
    ;;
  install-persistence)
    install_persistence
    ;;
  remove-persistence)
    remove_persistence
    ;;
  print-systemd-unit)
    print_systemd_unit
    ;;
  print-sysctl-dropin)
    print_sysctl_dropin
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown command: $action"
    usage
    exit 1
    ;;
  esac
}

init_colors
require_linux_tools
main "$@"
