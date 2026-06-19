_tailscale_client_complete() {
  local cur prev

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [ "$COMP_CWORD" -gt 0 ]; then
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  COMPREPLY=()

  case "$prev" in
  apply|remove|install-persistence|remove-persistence|print-systemd-unit|print-sysctl-dropin|help)
    return 0
    ;;
  esac

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "apply remove install-persistence remove-persistence print-systemd-unit print-sysctl-dropin help" -- "$cur"))
    return 0
  fi
}

complete -F _tailscale_client_complete \
  tailscale_client.sh \
  tailscale_client \
  ./tailscale_client.sh \
  networking/linux/tailscale_client.sh \
  ./networking/linux/tailscale_client.sh
