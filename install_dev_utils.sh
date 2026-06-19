#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"

COLORS_ENABLED=false
ACTION=""
USERNAME=""
GO_VERSION="1.26.4"
NVM_VERSION="v0.40.2"
DOTNET_SDK_VERSION="10.0"
NERD_FONT_VERSION="v3.0.2"
NERD_FONT_NAME="JetBrainsMono"
PACKAGE_MANAGER=""

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Install helper utilities and workstation dependencies across common Linux distros.

Options:
  -a, --action NAME       Action to run
  -u, --username NAME     Username used by the add-dev-user action
  -g, --go-version VER    Go version to install (default: $GO_VERSION)
  -n, --nvm-version VER   nvm installer version/tag (default: $NVM_VERSION)
  -s, --dotnet-sdk VER    .NET SDK version to install (default: $DOTNET_SDK_VERSION)
  -F, --font-version VER  Nerd Font release version (default: $NERD_FONT_VERSION)
  -N, --font-name NAME    Nerd Font archive name (default: $NERD_FONT_NAME)
  -h, --help              Show this help message

Actions:
  updates                 Refresh package metadata and upgrade installed packages
  apt-reqs                Install base package requirements using apt/dnf/yum
  rust-cargo              Install Rust via rustup
  uv                      Install uv
  nvm-node                Install nvm and the latest LTS Node.js
  dotnet-sdk              Install the requested .NET SDK version
  update-golang           Replace /usr/local/go with the requested Go version
  install-golang          Install the requested Go version and append shell env vars
  setup-golang-envars     Append Go env vars to ~/.bashrc
  nvim-from-source        Build and install Neovim from source
  nerd-fonts              Install the requested Nerd Font archive/version
  lazyvim                 Install the LazyVim starter config
  reinstall-lazyvim       Reinstall LazyVim and back up related state
  add-dev-user            Create a sudo-enabled dev user (requires --username)
  clone-projects          Clone the standard project set into ~/projects
  all                     Run the common workstation bootstrap steps

Examples:
  $SCRIPT_NAME --action apt-reqs
  $SCRIPT_NAME --action add-dev-user --username jtrahan
  $SCRIPT_NAME -a install-golang --go-version 1.24.3
  $SCRIPT_NAME -a dotnet-sdk --dotnet-sdk 8.0
  $SCRIPT_NAME apt-reqs
EOF
}

init_colors() {
  if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    COLORS_ENABLED=true
  fi
}

color_text() {
  color_name="$1"
  text="$2"

  if [ "$COLORS_ENABLED" != true ]; then
    printf '%s' "$text"
    return
  fi

  case "$color_name" in
  info)
    color_code="$(tput bold)$(tput setaf 6)"
    ;;
  success)
    color_code="$(tput bold)$(tput setaf 2)"
    ;;
  warning)
    color_code="$(tput bold)$(tput setaf 3)"
    ;;
  error)
    color_code="$(tput bold)$(tput setaf 1)"
    ;;
  value)
    color_code="$(tput setaf 5)"
    ;;
  *)
    color_code=""
    ;;
  esac

  reset="$(tput sgr0)"
  printf '%s%s%s' "$color_code" "$text" "$reset"
}

log_info() {
  printf '%s %s\n' "$(color_text info 'Info:')" "$1"
}

log_success() {
  printf '%s %s\n' "$(color_text success 'Success:')" "$1"
}

log_warning() {
  printf '%s %s\n' "$(color_text warning 'Warning:')" "$1"
}

log_error() {
  printf '%s %s\n' "$(color_text error 'Error:')" "$1" >&2
}

require_command() {
  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    log_error "Required command not found: $command_name"
    exit 1
  }
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER="yum"
  else
    log_error "Unsupported package manager. Expected apt-get, dnf, or yum."
    exit 1
  fi
}

ensure_package_manager() {
  if [ -z "$PACKAGE_MANAGER" ]; then
    detect_package_manager
  fi
}

try_enable_rhel_builder_repos() {
  ensure_package_manager

  if [ "$PACKAGE_MANAGER" != "dnf" ] && [ "$PACKAGE_MANAGER" != "yum" ]; then
    return
  fi

  if command -v crb >/dev/null 2>&1; then
    log_info "Attempting to enable $(color_text value 'CRB') repository with $(color_text value 'crb enable')"
    if sudo crb enable >/dev/null 2>&1; then
      log_success "CRB repository is enabled"
    else
      log_warning "Unable to enable CRB with $(color_text value 'crb enable'); continuing"
    fi
  elif command -v dnf >/dev/null 2>&1; then
    log_info "Attempting to enable $(color_text value 'crb') repository with dnf config-manager"
    if sudo dnf config-manager --set-enabled crb >/dev/null 2>&1; then
      log_success "CRB repository is enabled"
    else
      log_warning "Unable to enable CRB with dnf config-manager; continuing"
    fi
  elif command -v yum-config-manager >/dev/null 2>&1; then
    log_info "Attempting to enable $(color_text value 'crb') repository with yum-config-manager"
    if sudo yum-config-manager --enable crb >/dev/null 2>&1; then
      log_success "CRB repository is enabled"
    else
      log_warning "Unable to enable CRB with yum-config-manager; continuing"
    fi
  else
    log_warning "Could not find a CRB enable command; you may need to enable CRB manually"
  fi

  if rpm -q epel-release >/dev/null 2>&1; then
    log_info "$(color_text value 'epel-release') is already installed"
    return
  fi

  log_info "Attempting to install $(color_text value 'epel-release') for extra build dependencies"
  if sudo "$PACKAGE_MANAGER" install -y epel-release >/dev/null 2>&1; then
    log_success "Installed epel-release"
  else
    log_warning "Unable to install epel-release automatically; continuing"
  fi
}

append_line_if_missing() {
  file_path="$1"
  line="$2"

  touch "$file_path"

  if grep -F "$line" "$file_path" >/dev/null 2>&1; then
    log_info "$(color_text value "$line") already exists in $(color_text value "$file_path")"
    return
  fi

  printf '%s\n' "$line" >> "$file_path"
  log_success "Appended $(color_text value "$line") to $(color_text value "$file_path")"
}

install_updates() {
  ensure_package_manager

  case "$PACKAGE_MANAGER" in
  apt)
    log_info "Running $(color_text value 'sudo apt-get update -y')"
    sudo apt-get update -y
    log_info "Running $(color_text value 'sudo apt-get upgrade -y')"
    sudo apt-get upgrade -y
    ;;
  dnf)
    log_info "Running $(color_text value 'sudo dnf makecache --refresh')"
    sudo dnf makecache --refresh
    log_info "Running $(color_text value 'sudo dnf upgrade -y')"
    sudo dnf upgrade -y
    ;;
  yum)
    log_info "Running $(color_text value 'sudo yum makecache')"
    sudo yum makecache
    log_info "Running $(color_text value 'sudo yum update -y')"
    sudo yum update -y
    ;;
  esac

  log_success "System package metadata and upgrades completed"
}

install_apt_reqs() {
  ensure_package_manager

  case "$PACKAGE_MANAGER" in
  apt)
    log_info "Installing base packages with $(color_text value 'apt-get')"
    sudo apt-get install -y wget tar curl python3-venv git ninja-build gettext libtool libtool-bin autoconf automake cmake g++ gcc make pkg-config unzip patch doxygen fontconfig
    ;;
  dnf)
    try_enable_rhel_builder_repos
    log_info "Installing base packages with $(color_text value 'dnf')"
    sudo dnf install -y dnf-plugins-core wget tar curl python3 python3-pip git ninja-build gettext libtool autoconf automake cmake gcc gcc-c++ make pkgconf-pkg-config unzip patch doxygen fontconfig
    ;;
  yum)
    try_enable_rhel_builder_repos
    log_info "Installing base packages with $(color_text value 'yum')"
    sudo yum install -y yum-utils wget tar curl python3 python3-pip git ninja-build gettext libtool autoconf automake cmake gcc gcc-c++ make pkgconfig unzip patch doxygen fontconfig
    ;;
  esac

  log_success "Base package requirements installed"
}

install_rust_cargo() {
  require_command curl
  log_info "Installing Rust via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  log_success "Rust install completed"
}

install_uv() {
  require_command curl
  log_info "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  log_success "uv install completed"
}

install_nvm_node() {
  require_command curl
  log_info "Installing nvm"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

  export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf '%s' "${HOME}/.nvm" || printf '%s' "${XDG_CONFIG_HOME}/nvm")"
  # shellcheck disable=SC1090
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  log_info "Installing latest LTS Node.js"
  nvm install --lts
  log_success "nvm and Node.js LTS installed"
}

install_dotnet_sdk() {
  ensure_package_manager

  case "$PACKAGE_MANAGER" in
  apt)
    if ! command -v add-apt-repository >/dev/null 2>&1; then
      log_info "Installing software-properties-common for add-apt-repository"
      sudo apt-get install -y software-properties-common
    fi

    log_info "Installing .NET SDK $(color_text value "$DOTNET_SDK_VERSION") via apt"
    sudo add-apt-repository ppa:dotnet/backports -y
    sudo apt-get update
    sudo apt-get install -y "dotnet-sdk-${DOTNET_SDK_VERSION}"
    ;;
  dnf|yum)
    log_info "Installing .NET SDK $(color_text value "$DOTNET_SDK_VERSION") via ${PACKAGE_MANAGER}"
    sudo "$PACKAGE_MANAGER" install -y "dotnet-sdk-${DOTNET_SDK_VERSION}"
    ;;
  esac

  log_success ".NET SDK ${DOTNET_SDK_VERSION} installed"
}

install_go_archive() {
  archive_name="go${GO_VERSION}.linux-amd64.tar.gz"

  require_command wget
  log_info "Downloading $(color_text value "$archive_name")"
  wget "https://go.dev/dl/${archive_name}"

  log_info "Installing Go into $(color_text value '/usr/local/go')"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$archive_name"
  rm -f "$archive_name"
  log_success "Go archive installed"
}

update_golang() {
  install_go_archive
}

install_golang() {
  install_go_archive

  append_line_if_missing "$HOME/.bashrc" 'export PATH=$PATH:/usr/local/go/bin'
  append_line_if_missing "$HOME/.bashrc" 'export GOPATH=$HOME/go'
  append_line_if_missing "$HOME/.bashrc" 'export GOBIN=$GOPATH/bin'

  append_line_if_missing "$HOME/.zshrc" 'export PATH=$PATH:/usr/local/go/bin'
  append_line_if_missing "$HOME/.zshrc" 'export GOPATH=$HOME/go'
  append_line_if_missing "$HOME/.zshrc" 'export GOBIN=$GOPATH/bin'

  log_success "Go shell configuration added to ~/.bashrc and ~/.zshrc"
}

setup_golang_envars() {
  append_line_if_missing "$HOME/.bashrc" 'export PATH=$PATH:/usr/local/go/bin'
  append_line_if_missing "$HOME/.bashrc" 'export GOPATH=$HOME/go'
  append_line_if_missing "$HOME/.bashrc" 'export GOBIN=$GOPATH/bin'
  log_success "Go environment variables configured in ~/.bashrc"
}

install_nvim_from_source() {
  require_command git
  require_command make

  current_dir="$(pwd)"
  log_info "Cloning Neovim source"
  git clone --depth 1 https://github.com/neovim/neovim.git
  cd neovim

  log_info "Building Neovim"
  make CMAKE_BUILD_TYPE=RelWithDebInfo

  log_info "Installing Neovim"
  sudo make install

  cd "$current_dir"
  rm -rf neovim
  log_success "Neovim installed from source"
}

ensure_fontconfig_installed() {
  if command -v fc-cache >/dev/null 2>&1; then
    return
  fi

  ensure_package_manager
  log_warning "$(color_text value 'fc-cache') was not found; attempting to install $(color_text value 'fontconfig')"

  case "$PACKAGE_MANAGER" in
  apt)
    sudo apt-get install -y fontconfig
    ;;
  dnf)
    sudo dnf install -y fontconfig
    ;;
  yum)
    sudo yum install -y fontconfig
    ;;
  esac

  require_command fc-cache
  log_success "$(color_text value 'fontconfig') installed"
}

install_nerd_fonts() {
  require_command wget
  require_command unzip
  ensure_fontconfig_installed

  current_dir="$(pwd)"
  mkdir -p "$HOME/.local/share/fonts"

  archive_name="${NERD_FONT_NAME}.zip"
  download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${archive_name}"

  log_info "Installing $(color_text value "$NERD_FONT_NAME") Nerd Font from $(color_text value "$NERD_FONT_VERSION")"
  wget -P "$HOME/.local/share/fonts" "$download_url"
  cd "$HOME/.local/share/fonts"
  unzip -o "$archive_name"
  rm -f "$archive_name"
  fc-cache -fv
  cd "$current_dir"
  log_success "${NERD_FONT_NAME} Nerd Font installed"
}

install_lazyvim() {
  require_command git

  if [ -e "$HOME/.config/nvim" ]; then
    log_warning "Backing up existing $(color_text value "$HOME/.config/nvim") to $(color_text value "$HOME/.config/nvim.bak")"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
  fi

  log_info "Installing LazyVim starter config"
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  log_success "LazyVim starter config installed"
}

reinstall_lazyvim() {
  [ -e "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
  [ -e "$HOME/.local/share/nvim" ] && mv "$HOME/.local/share/nvim" "$HOME/.local/share/nvim.bak"
  [ -e "$HOME/.local/state/nvim" ] && mv "$HOME/.local/state/nvim" "$HOME/.local/state/nvim.bak"
  [ -e "$HOME/.cache/nvim" ] && mv "$HOME/.cache/nvim" "$HOME/.cache/nvim.bak"

  log_info "Reinstalling LazyVim after backing up previous state"
  install_lazyvim
}

add_dev_user() {
  username="$1"

  if [ -z "$username" ]; then
    log_error "The add-dev-user action requires --username"
    exit 1
  fi

  if id "$username" >/dev/null 2>&1; then
    log_warning "User $(color_text value "$username") already exists"
  else
    log_info "Creating user $(color_text value "$username")"
    sudo useradd -m -s /bin/bash "$username"
    log_success "User $(color_text value "$username") created"
  fi

  log_info "Setting password for $(color_text value "$username")"
  sudo passwd "$username"

  log_info "Adding $(color_text value "$username") to sudo group"
  sudo usermod -aG sudo "$username"
  printf '%s\n' "$username ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" >/dev/null

  sudo mkdir -p "/home/$username/.ssh"
  sudo chown -R "$username:$username" "/home/$username/.ssh"
  sudo chmod 700 "/home/$username/.ssh"
  sudo touch "/home/$username/.ssh/authorized_keys"
  sudo sh -c "cat '$HOME/.ssh/authorized_keys' >> '/home/$username/.ssh/authorized_keys'"
  sudo chown "$username:$username" "/home/$username/.ssh/authorized_keys"

  log_success "User $(color_text value "$username") is ready for development access"
}

clone_projects() {
  require_command git

  current_dir="$(pwd)"

  if [ -e "$HOME/projects" ]; then
    log_warning "Backing up existing $(color_text value "$HOME/projects") to $(color_text value "$HOME/projects.bak")"
    mv "$HOME/projects" "$HOME/projects.bak"
  fi

  mkdir -p "$HOME/projects"
  cd "$HOME/projects"

  log_info "Cloning standard project set into $(color_text value "$HOME/projects")"
  git clone git@github.com:babbage88/Homelab.Configs.git
  git clone git@github.com:babbage88/infra-cli.git
  git clone git@github.com:babbage88/go-infra.git
  git clone git@github.com:babbage88/infra-kubeinit.git
  git clone git@github.com:babbage88/infra-db.git
  git clone git@github.com:babbage88/db-helper-ui.git
  git clone git@github.com:babbage88/react-trahan-compound.git
  git clone git@github.com:babbage88/smbplusplus.git
  git clone git@github.com:babbage88/goph.git
  git clone git@github.com:babbage88/tint.git
  git clone git@github.com:babbage88/rust-web-test.git
  git clone git@github.com:babbage88/go-acme-cli.git
  git clone git@github.com:babbage88/gofiles.git
  git clone git@github.com:babbage88/infra-svui.git

  cd "$current_dir"
  log_success "Project clone set completed"
}

run_common_bootstrap() {
  install_updates
  install_apt_reqs
  install_rust_cargo
  install_uv
  install_nvm_node
  install_golang
  install_dotnet_sdk
  log_success "Common workstation bootstrap actions completed"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -a|--action)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      ACTION="$2"
      shift 2
      ;;
    -u|--username)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      USERNAME="$2"
      shift 2
      ;;
    -g|--go-version)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      GO_VERSION="$2"
      shift 2
      ;;
    -n|--nvm-version)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      NVM_VERSION="$2"
      shift 2
      ;;
    -s|--dotnet-sdk)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      DOTNET_SDK_VERSION="$2"
      shift 2
      ;;
    -F|--font-version)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      NERD_FONT_VERSION="$2"
      shift 2
      ;;
    -N|--font-name)
      [ "$#" -ge 2 ] || {
        log_error "Missing value for $1"
        exit 1
      }
      NERD_FONT_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$ACTION" ]; then
        ACTION="$1"
        shift
      else
        log_error "Unknown argument: $1"
        usage >&2
        exit 1
      fi
      ;;
    esac
  done
}

run_action() {
  case "$ACTION" in
  updates)
    install_updates
    ;;
  apt-reqs)
    install_apt_reqs
    ;;
  rust-cargo)
    install_rust_cargo
    ;;
  uv)
    install_uv
    ;;
  nvm-node)
    install_nvm_node
    ;;
  dotnet-sdk)
    install_dotnet_sdk
    ;;
  update-golang)
    update_golang
    ;;
  install-golang)
    install_golang
    ;;
  setup-golang-envars)
    setup_golang_envars
    ;;
  nvim-from-source)
    install_nvim_from_source
    ;;
  nerd-fonts)
    install_nerd_fonts
    ;;
  lazyvim)
    install_lazyvim
    ;;
  reinstall-lazyvim)
    reinstall_lazyvim
    ;;
  add-dev-user)
    add_dev_user "$USERNAME"
    ;;
  clone-projects)
    clone_projects
    ;;
  all)
    run_common_bootstrap
    ;;
  "")
    log_error "No action provided"
    usage >&2
    exit 1
    ;;
  *)
    log_error "Unknown action: $ACTION"
    usage >&2
    exit 1
    ;;
  esac
}

main() {
  init_colors
  parse_args "$@"
  run_action
}

main "$@"
