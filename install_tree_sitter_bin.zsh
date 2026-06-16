#compdef install_tree_sitter_bin.sh install_tree_sitter_bin ./install_tree_sitter_bin.sh

_install_tree_sitter_bin() {
  _arguments -s -S \
    '(-v --version)'{-v,--version}'[Tree-sitter version tag to install]:version tag:' \
    '(-a --arch)'{-a,--arch}'[Release architecture]:architecture:(x64 arm64)' \
    '(-o --os)'{-o,--os}'[Release OS name]:operating system:(linux macos)' \
    '(-d --download-dir)'{-d,--download-dir}'[Directory used for the downloaded binary]:directory:_files -/' \
    '(-i --install-dir)'{-i,--install-dir}'[Directory where the binary is installed]:directory:_files -/' \
    '(-u --user-install)'{-u,--user-install}'[Install to $HOME/.local/bin for the current user]' \
    '(-b --bin-name)'{-b,--bin-name}'[Installed binary name]:binary name:' \
    '(-f --force)'{-f,--force}'[Re-download even if the archive already exists]' \
    '(-h --help)'{-h,--help}'[Show help message]'
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _install_tree_sitter_bin install_tree_sitter_bin.sh install_tree_sitter_bin ./install_tree_sitter_bin.sh
compdef -p _install_tree_sitter_bin '*/install_tree_sitter_bin.sh'
