_install_dev_utils_complete() {
  local cur prev actions options

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [ "$COMP_CWORD" -gt 0 ]; then
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  actions="updates apt-reqs rust-cargo uv nvm-node dotnet-sdk update-golang install-golang setup-golang-envars nvim-from-source nerd-fonts lazyvim reinstall-lazyvim add-dev-user clone-projects all"
  options="-a --action -u --username -g --go-version -n --nvm-version -s --dotnet-sdk -F --font-version -N --font-name -h --help"

  COMPREPLY=()

  case "$prev" in
  -a|--action)
    COMPREPLY=($(compgen -W "$actions" -- "$cur"))
    return 0
    ;;
  -u|--username|-g|--go-version|-n|--nvm-version|-F|--font-version|-N|--font-name)
    return 0
    ;;
  -s|--dotnet-sdk)
    COMPREPLY=($(compgen -W "8.0 9.0 10.0" -- "$cur"))
    return 0
    ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "$options" -- "$cur"))
    return 0
  fi

  COMPREPLY=($(compgen -W "$actions" -- "$cur"))
}

complete -F _install_dev_utils_complete \
  install_dev_utils.sh \
  install_dev_utils \
  ./install_dev_utils.sh
