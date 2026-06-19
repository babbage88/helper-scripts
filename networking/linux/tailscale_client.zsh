#compdef tailscale_client.sh tailscale_client ./tailscale_client.sh networking/linux/tailscale_client.sh ./networking/linux/tailscale_client.sh

_tailscale_client() {
  _arguments -s -S \
    '1:command:(apply remove install-persistence remove-persistence print-systemd-unit print-sysctl-dropin help)'
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _tailscale_client tailscale_client.sh tailscale_client ./tailscale_client.sh networking/linux/tailscale_client.sh ./networking/linux/tailscale_client.sh
compdef -p _tailscale_client '*/tailscale_client.sh'
