#compdef tailscale_rtr.sh tailscale-rtr networking/linux/tailscale_rtr.sh ./networking/linux/tailscale_rtr.sh tailscale_local_main_rules.sh tailscale-local-main-rules networking/linux/tailscale_local_main_rules.sh ./networking/linux/tailscale_local_main_rules.sh

_tailscale_rtr_commands() {
  local command_word

  command_word="${words[1]:-}"
  command_word="${command_word:t}"

  case "$command_word" in
    tailscale_local_main_rules.sh|tailscale-local-main-rules)
      print -r -- \
        'apply:Apply local policy routing rules now' \
        'remove:Remove local policy routing rules now' \
        'detect-backend:Print the persistence backend' \
        'install-persistence:Install persistent local policy routing rules' \
        'remove-persistence:Remove persistent local policy routing rules' \
        'help:Show help text'
      ;;
    *)
      print -r -- \
        'start-subnet-router:Start Tailscale as a subnet router' \
        'install-systemd-service:Install subnet router service and local rule persistence' \
        'remove-systemd-service:Remove subnet router service and local rule persistence' \
        'print-systemd-unit:Print the generated subnet router unit' \
        'apply-local-rules:Apply local policy routing rules now' \
        'remove-local-rules:Remove local policy routing rules now' \
        'install-local-rules:Install persistent local policy routing rules' \
        'remove-local-rules-persistence:Remove persistent local policy routing rules' \
        'detect-local-rules-backend:Print the local rule persistence backend' \
        'print-local-rules-unit:Print the generated local rules unit' \
        'help:Show help text'
      ;;
  esac
}

_tailscale_rtr_options() {
  print -r -- \
    '(-e --advertise-exit-node)'{-e,--advertise-exit-node}'[Append --advertise-exit-node to tailscale up]' \
    '(-w --enable-wireguard)'{-w,--enable-wireguard}'[Bring up the WireGuard interface before tailscale up]' \
    '(-h --help)'{-h,--help}'[Show help text]'
}

_tailscale_rtr() {
  local -a commands
  local -a options

  options=(${(@f)$(_tailscale_rtr_options)})
  _arguments -s -S \
    "${options[@]}" \
    '1:command:->command'

  case "$state" in
    command)
      commands=(${(@f)$(_tailscale_rtr_commands)})
      (( ${#commands[@]} )) && _describe -t commands 'tailscale command' commands
      ;;
  esac
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _tailscale_rtr \
  tailscale_rtr.sh \
  tailscale-rtr \
  networking/linux/tailscale_rtr.sh \
  ./networking/linux/tailscale_rtr.sh \
  tailscale_local_main_rules.sh \
  tailscale-local-main-rules \
  networking/linux/tailscale_local_main_rules.sh \
  ./networking/linux/tailscale_local_main_rules.sh
compdef -p _tailscale_rtr '*/tailscale_rtr.sh'
compdef -p _tailscale_rtr '*/tailscale_local_main_rules.sh'
