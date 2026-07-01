_rsync_media_complete() {
  local cur prev positional_count arg skip_next
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"

  COMPREPLY=()

  case "$prev" in
  -d|--dest-subdir)
    return 0
    ;;
  --)
    return 0
    ;;
  esac

  positional_count=0
  skip_next=0
  for arg in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi

    case "$arg" in
    -m|--movies|-t|--tv|-s|--sane-dir|-h|--help)
      ;;
    -d|--dest-subdir)
      skip_next=1
      ;;
    --)
      return 0
      ;;
    -*)
      ;;
    *)
      positional_count=$((positional_count + 1))
      ;;
    esac
  done

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "-m --movies -t --tv -d --dest-subdir -s --sane-dir -h --help --" -- "$cur"))
    return 0
  fi

  if [ "$positional_count" -eq 0 ]; then
    compopt -o filenames 2>/dev/null || true
    COMPREPLY=($(compgen -f -- "$cur"))
    return 0
  fi
}

complete -F _rsync_media_complete \
  rsync_media.sh \
  rsync_media \
  rsync-media \
  rsync_media/rsync_media.sh \
  ./rsync_media/rsync_media.sh
