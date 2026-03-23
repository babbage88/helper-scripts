_rename_spaces_in_filenames_bash_completion() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    -p|--path)
      COMPREPLY=($(compgen -d -- "$cur"))
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "-p --path -h --help" -- "$cur"))
  else
    COMPREPLY=($(compgen -d -- "$cur"))
  fi
}

complete -F _rename_spaces_in_filenames_bash_completion rename_spaces_in_filenames
