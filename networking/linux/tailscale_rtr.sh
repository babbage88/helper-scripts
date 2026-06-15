#!/usr/bin/env bash
export WG_INTERFACE=wg0
ADVERTISED_ROUTES="10.0.0.0/23,10.2.0.0/16"
EXTRA_TS_ARGS="--snat-subnet-routes=false"

reset_pia_wg_interface() {
    ## disable ipv6 temproarily since pia can't get their shit together
    echo "Disabling ipv6 temproarily because pia wireguard vpn does not support and it can cause leaks"
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
    # TODO: better detection for $WG_INTERFACE not existing vs just DOWN
    if ip link show wg0 up &>/dev/null; then
        echo "$WG_INTERFACE is UP, resetting wg0 before tailscale"
        sudo wg-quick down $WG_INTERFACE
        sleep 5
        sudo wg-quick up $WG_INTERFACE
    else
        echo "$WG_INTERFACE s DOWN, attempting to start"
        sudo wg-quick up $WG_INTERFACE
        sleep 5
    fi
}

start_wg0_and_ts_exitnode() {
    reset_pia_wg_interface
    #sudo tailscale up --advertise-exit-node --accept-routes --reset
    sudo tailscale up --advertise-routes=$ADVERTISED_ROUTES --advertise-exit-node --accept-routes $EXTRA_TS_ARGS --reset
}

start_ts_subnet_router() {
    sudo tailscale up --advertise-routes=$ADVERTISED_ROUTES --accept-routes $EXTRA_TS_ARGS --reset
}

start_ts_subnet_router