_install_tree_sitter_bin_complete() {
  local cur prev

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [ "$COMP_CWORD" -gt 0 ]; then
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  COMPREPLY=()

  case "$prev" in
  -o|--os)
    COMPREPLY=($(compgen -W "linux macos" -- "$cur"))
    return 0
    ;;
  -a|--arch)
    COMPREPLY=($(compgen -W "x64 arm64" -- "$cur"))
    return 0
    ;;
  -d|--download-dir|-i|--install-dir)
    COMPREPLY=($(compgen -d -- "$cur"))
    return 0
    ;;
  -v|--version|-b|--bin-name)
    return 0
    ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "-v --version -a --arch -o --os -d --download-dir -i --install-dir -u --user-install -b --bin-name -f --force -h --help" -- "$cur"))
    return 0
  fi

  COMPREPLY=($(compgen -d -- "$cur"))
}

complete -F _install_tree_sitter_bin_complete \
  install_tree_sitter_bin.sh \
  install_tree_sitter_bin \
  ./install_tree_sitter_bin.sh
