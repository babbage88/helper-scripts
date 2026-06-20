_tailscale_rtr_command_words() {
  local command_name

  command_name="$(basename -- "${1:-}")"

  case "$command_name" in
  tailscale_local_main_rules.sh|tailscale-local-main-rules)
    printf '%s\n' \
      "apply" \
      "remove" \
      "detect-backend" \
      "install-persistence" \
      "remove-persistence" \
      "help"
    ;;
  *)
    printf '%s\n' \
      "start-subnet-router" \
      "install-systemd-service" \
      "remove-systemd-service" \
      "print-systemd-unit" \
      "apply-local-rules" \
      "remove-local-rules" \
      "install-local-rules" \
      "remove-local-rules-persistence" \
      "detect-local-rules-backend" \
      "print-local-rules-unit" \
      "help"
    ;;
  esac
}

_tailscale_rtr_option_words() {
  printf '%s\n' \
    "--advertise-exit-node" \
    "--enable-wireguard" \
    "--help" \
    "-e" \
    "-w" \
    "-h"
}

_tailscale_rtr_complete() {
  local cur
  local prev
  local -a commands
  local -a options

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"
  COMPREPLY=()

  mapfile -t commands < <(_tailscale_rtr_command_words "${COMP_WORDS[0]}")
  mapfile -t options < <(_tailscale_rtr_option_words)

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "${options[*]}" -- "$cur"))
    return 0
  fi

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "${commands[*]} ${options[*]}" -- "$cur"))
    return 0
  fi

  COMPREPLY=($(compgen -W "${commands[*]}" -- "$cur"))
}

complete -F _tailscale_rtr_complete \
  tailscale_rtr.sh \
  tailscale-rtr \
  networking/linux/tailscale_rtr.sh \
  ./networking/linux/tailscale_rtr.sh \
  tailscale_local_main_rules.sh \
  tailscale-local-main-rules \
  networking/linux/tailscale_local_main_rules.sh \
  ./networking/linux/tailscale_local_main_rules.sh
