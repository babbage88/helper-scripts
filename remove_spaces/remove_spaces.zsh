#compdef rename_spaces_in_filenames

_rename_spaces_in_filenames() {
  _arguments -s -S \
    '(-p --path)'{-p,--path}'[Directory to search]:directory:_files -/' \
    '(-h --help)'{-h,--help}'[Show help]'
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _rename_spaces_in_filenames rename_spaces_in_filenames
