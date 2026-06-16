#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"
STARTING_CUR_DIR="$(pwd)"
DOWNLOAD_DIR="/tmp"
INSTALL_DIR="/usr/local/bin"
INSTALL_BIN_NAME="tree-sitter"
TREE_SITTER_VERSION="v0.25.10"
ARCH=""
OS_ARCH=""
FORCE_DOWNLOAD=false
USER_INSTALL=false

COLORS_ENABLED=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -v, --version TAG        Tree-sitter version tag to install
  -a, --arch ARCH          Release architecture (default: auto-detect)
  -o, --os OS              Release OS name (default: auto-detect)
  -d, --download-dir DIR   Directory used for the downloaded binary
  -i, --install-dir DIR    Directory where the binary is installed
  -u, --user-install       Install to \$HOME/.local/bin for the current user
  -b, --bin-name NAME      Installed binary name
  -f, --force              Re-download even if the archive already exists
  -h, --help               Show this help message

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --version v0.25.10
  $SCRIPT_NAME --user-install
  $SCRIPT_NAME -v v0.25.10 -d /tmp/tree-sitter-downloads
  $SCRIPT_NAME -v v0.25.10 -o macos -a arm64 -i "\$HOME/.local/bin"
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

path_contains_dir() {
  search_path="$1"
  target_dir="$2"

  case ":$search_path:" in
  *:"$target_dir":*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

shell_rc_file() {
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
  zsh)
    echo "$HOME/.zshrc"
    ;;
  bash)
    echo "$HOME/.bashrc"
    ;;
  *)
    if [ -f "$HOME/.zshrc" ]; then
      echo "$HOME/.zshrc"
    else
      echo "$HOME/.bashrc"
    fi
    ;;
  esac
}

ensure_user_path() {
  rc_file="$(shell_rc_file)"
  path_export_line="export PATH=\"$INSTALL_DIR:\$PATH\""
  path_marker="# Added by $SCRIPT_NAME for tree-sitter user install"

  if path_contains_dir "$PATH" "$INSTALL_DIR"; then
    log_success "$(color_text value "$INSTALL_DIR") is already available in the current PATH"
    return
  fi

  PATH="$INSTALL_DIR:$PATH"
  export PATH

  mkdir -p "$INSTALL_DIR"
  touch "$rc_file"

  if grep -F "$INSTALL_DIR" "$rc_file" >/dev/null 2>&1; then
    log_success "$(color_text value "$INSTALL_DIR") is already configured in $(color_text value "$rc_file")"
    log_info "Added $(color_text value "$INSTALL_DIR") to PATH for the current run"
    return
  fi

  {
    printf '\n%s\n' "$path_marker"
    printf '%s\n' "$path_export_line"
  } >> "$rc_file"

  log_success "Added $(color_text value "$INSTALL_DIR") to PATH in $(color_text value "$rc_file")"
  log_info "Run $(color_text value "source $rc_file") or open a new shell to load the updated PATH"
}

require_command() {
  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    log_error "Required command not found: $command_name"
    exit 1
  }
}

detect_release_os() {
  case "$(uname -s)" in
  Darwin)
    echo "macos"
    ;;
  Linux)
    echo "linux"
    ;;
  *)
    log_error "Unsupported operating system: $(uname -s)"
    exit 1
    ;;
  esac
}

detect_release_arch() {
  case "$(uname -m)" in
  x86_64|amd64)
    echo "x64"
    ;;
  arm64|aarch64)
    echo "arm64"
    ;;
  *)
    log_error "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
  esac
}

resolve_release_target() {
  if [ -z "$OS_ARCH" ]; then
    OS_ARCH="$(detect_release_os)"
  fi

  if [ -z "$ARCH" ]; then
    ARCH="$(detect_release_arch)"
  fi
}

build_release_names() {
  TS_FULL_NAME="tree-sitter-$OS_ARCH-$ARCH"
  TS_GZ_NAME="$TS_FULL_NAME.gz"
  FULL_INSTALL_PATH="$INSTALL_DIR/$INSTALL_BIN_NAME"
  TS_BIN_URL="https://github.com/tree-sitter/tree-sitter/releases/download/$TREE_SITTER_VERSION/$TS_GZ_NAME"
}

download_tree_sitter_bin() {
  archive_path="$DOWNLOAD_DIR/$TS_GZ_NAME"
  extracted_path="$DOWNLOAD_DIR/$TS_FULL_NAME"

  mkdir -p "$DOWNLOAD_DIR"
  cd "$DOWNLOAD_DIR"

  if [ -f "$archive_path" ] && [ "$FORCE_DOWNLOAD" != true ]; then
    log_warning "Using existing archive $(color_text value "$archive_path")"
  else
    log_info "Downloading $(color_text value "$TS_BIN_URL")"
    rm -f "$archive_path"
    wget -O "$archive_path" "$TS_BIN_URL"
  fi

  log_info "Extracting $(color_text value "$archive_path")"
  gunzip -f "$archive_path"

  if [ ! -f "$extracted_path" ]; then
    log_error "Expected extracted binary at $extracted_path"
    exit 1
  fi

  cd "$STARTING_CUR_DIR"
}

install_tree_sitter_bin() {
  extracted_path="$DOWNLOAD_DIR/$TS_FULL_NAME"

  if [ ! -f "$extracted_path" ]; then
    log_error "Binary not found: $extracted_path"
    exit 1
  fi

  mkdir -p "$INSTALL_DIR"
  chmod +x "$extracted_path"

  log_info "Installing $(color_text value "$extracted_path") to $(color_text value "$FULL_INSTALL_PATH")"
  install -m 0755 "$extracted_path" "$FULL_INSTALL_PATH"
  log_success "Installed $(color_text value "$FULL_INSTALL_PATH")"

  if [ "$USER_INSTALL" = true ]; then
    ensure_user_path
  elif ! path_contains_dir "$PATH" "$INSTALL_DIR"; then
    log_warning "$(color_text value "$INSTALL_DIR") is not currently in PATH"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -v|--version)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires a version tag."
        usage
        exit 1
      }
      TREE_SITTER_VERSION="$2"
      shift
      ;;
    -a|--arch)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires an architecture value."
        usage
        exit 1
      }
      ARCH="$2"
      shift
      ;;
    -o|--os)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires an OS value."
        usage
        exit 1
      }
      OS_ARCH="$2"
      shift
      ;;
    -d|--download-dir)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires a directory path."
        usage
        exit 1
      }
      DOWNLOAD_DIR="$2"
      shift
      ;;
    -i|--install-dir)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires a directory path."
        usage
        exit 1
      }
      INSTALL_DIR="$2"
      shift
      ;;
    -u|--user-install)
      USER_INSTALL=true
      INSTALL_DIR="${HOME}/.local/bin"
      ;;
    -b|--bin-name)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires a binary name."
        usage
        exit 1
      }
      INSTALL_BIN_NAME="$2"
      shift
      ;;
    -f|--force)
      FORCE_DOWNLOAD=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
}

main() {
  init_colors
  parse_args "$@"
  resolve_release_target
  build_release_names

  require_command wget
  require_command gunzip
  require_command install

  if [ "$USER_INSTALL" = true ]; then
    log_info "User install enabled; target directory is $(color_text value "$INSTALL_DIR")"
  fi

  log_info "Preparing Tree-sitter $(color_text value "$TREE_SITTER_VERSION") for $(color_text value "$OS_ARCH/$ARCH")"
  download_tree_sitter_bin
  install_tree_sitter_bin
}

main "$@"
