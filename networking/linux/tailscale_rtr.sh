#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
export WG_INTERFACE="${WG_INTERFACE:-wg0}"
ADVERTISED_ROUTES="${ADVERTISED_ROUTES:-10.0.0.0/23,10.2.0.0/16}"
EXTRA_TS_ARGS="${EXTRA_TS_ARGS:---snat-subnet-routes=false}"
# Leave this off by default for HA subnet routers that advertise the same LANs.
TS_ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-false}"
SYSTEMD_UNIT_NAME="${SYSTEMD_UNIT_NAME:-tailscale-subnet-router.service}"
SYSTEMD_UNIT_PATH="${SYSTEMD_UNIT_PATH:-/etc/systemd/system/$SYSTEMD_UNIT_NAME}"
SYSTEMD_ENV_PATH="${SYSTEMD_ENV_PATH:-/etc/default/tailscale-subnet-router}"

usage() {
  cat <<EOF
Usage: $0 [command]

Commands:
  start-subnet-router       Start Tailscale as a subnet router
  start-exit-node           Start wg0 and Tailscale as subnet router + exit node
  install-systemd-service   Generate and install a systemd service on this host
  print-systemd-unit        Print the generated systemd unit to stdout
  help                      Show this help text

Environment overrides:
  WG_INTERFACE=wg0
  ADVERTISED_ROUTES=10.0.0.0/23,10.2.0.0/16
  EXTRA_TS_ARGS="--snat-subnet-routes=false"
  TS_ACCEPT_ROUTES=false
  SYSTEMD_UNIT_NAME=tailscale-subnet-router.service
EOF
}

reset_pia_wg_interface() {
  ## disable ipv6 temproarily since pia can't get their shit together
  echo "Disabling ipv6 temproarily because pia wireguard vpn does not support and it can cause leaks"
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
  # TODO: better detection for $WG_INTERFACE not existing vs just DOWN
  if ip link show "$WG_INTERFACE" up &>/dev/null; then
    echo "$WG_INTERFACE is UP, resetting wg0 before tailscale"
    sudo wg-quick down "$WG_INTERFACE"
    sleep 5
    sudo wg-quick up "$WG_INTERFACE"
  else
    echo "$WG_INTERFACE s DOWN, attempting to start"
    sudo wg-quick up "$WG_INTERFACE"
    sleep 5
  fi
}

build_tailscale_up_args() {
  TS_UP_ARGS=("--advertise-routes=$ADVERTISED_ROUTES" "--reset")

  if [ -n "$EXTRA_TS_ARGS" ]; then
    # Split EXTRA_TS_ARGS on whitespace so multiple tailscale flags can be supplied.
    read -r -a extra_ts_args_array <<<"$EXTRA_TS_ARGS"
    TS_UP_ARGS+=("${extra_ts_args_array[@]}")
  fi

  if [ "$TS_ACCEPT_ROUTES" = "true" ]; then
    TS_UP_ARGS+=("--accept-routes")
  fi
}

write_systemd_environment_file() {
  {
    printf 'WG_INTERFACE=%s\n' "$WG_INTERFACE"
    printf 'ADVERTISED_ROUTES=%s\n' "$ADVERTISED_ROUTES"
    printf 'EXTRA_TS_ARGS=%s\n' "$EXTRA_TS_ARGS"
    printf 'TS_ACCEPT_ROUTES=%s\n' "$TS_ACCEPT_ROUTES"
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

install_systemd_service() {
  write_systemd_environment_file
  print_systemd_unit | sudo tee "$SYSTEMD_UNIT_PATH" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SYSTEMD_UNIT_NAME"
  echo "Installed and started $SYSTEMD_UNIT_NAME"
}

start_wg0_and_ts_exitnode() {
  reset_pia_wg_interface
  build_tailscale_up_args
  sudo tailscale up "${TS_UP_ARGS[@]}" --advertise-exit-node
}

start_ts_subnet_router() {
  build_tailscale_up_args
  sudo tailscale up "${TS_UP_ARGS[@]}"
}

main() {
  local command="${1:-start-subnet-router}"

  case "$command" in
  start-subnet-router)
    start_ts_subnet_router
    ;;
  start-exit-node)
    start_wg0_and_ts_exitnode
    ;;
  install-systemd-service)
    install_systemd_service
    ;;
  print-systemd-unit)
    print_systemd_unit
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 1
    ;;
  esac
}

main "$@"
