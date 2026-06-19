#compdef install_dev_utils.sh install_dev_utils ./install_dev_utils.sh

_install_dev_utils() {
  _arguments -s -S \
    '(-a --action)'{-a,--action}'[Action to run]:action:(updates apt-reqs rust-cargo uv nvm-node dotnet-sdk update-golang install-golang setup-golang-envars nvim-from-source nerd-fonts lazyvim reinstall-lazyvim add-dev-user clone-projects all)' \
    '(-u --username)'{-u,--username}'[Username used by add-dev-user]:username:' \
    '(-g --go-version)'{-g,--go-version}'[Go version to install]:go version:' \
    '(-n --nvm-version)'{-n,--nvm-version}'[nvm installer version tag]:nvm version:' \
    '(-s --dotnet-sdk)'{-s,--dotnet-sdk}'[.NET SDK version to install]:dotnet sdk version:(8.0 9.0 10.0)' \
    '(-F --font-version)'{-F,--font-version}'[Nerd Font release version]:font version:' \
    '(-N --font-name)'{-N,--font-name}'[Nerd Font archive name]:font name:' \
    '(-h --help)'{-h,--help}'[Show help message]'
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _install_dev_utils install_dev_utils.sh install_dev_utils ./install_dev_utils.sh
compdef -p _install_dev_utils '*/install_dev_utils.sh'
