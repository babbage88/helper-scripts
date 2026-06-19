#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_BIN_DIR="${HOME}/.scripts"
TARGET_BIN_PATH="${TARGET_BIN_DIR}/install_dev_utils.sh"

BASH_COMPLETION_DIR="${HOME}/.scripts/completions/bash"
BASH_COMPLETION_PATH="${BASH_COMPLETION_DIR}/install_dev_utils.bash"

ZSH_COMPLETION_DIR="${HOME}/.scripts/completions/zsh"
ZSH_COMPLETION_FILE="${ZSH_COMPLETION_DIR}/install_dev_utils.zsh"
ZSH_COMPLETION_FUNC="${ZSH_COMPLETION_DIR}/_install_dev_utils"

BASH_RC="${HOME}/.bashrc"
ZSH_RC="${HOME}/.zshrc"

PATH_MARKER="# Added by ${SCRIPT_NAME} for ~/.scripts"
PATH_EXPORT='export PATH="$HOME/.scripts:$PATH"'

BASH_COMPLETION_MARKER="# Added by ${SCRIPT_NAME} for install_dev_utils bash completion"
BASH_COMPLETION_LINE='source "$HOME/.scripts/completions/bash/install_dev_utils.bash"'

ZSH_FPATH_MARKER="# Added by ${SCRIPT_NAME} for install_dev_utils zsh completion"
ZSH_FPATH_LINE='fpath=("$HOME/.scripts/completions/zsh" $fpath)'
ZSH_COMPINIT_LINE='autoload -Uz compinit && compinit -i'
ZSH_COMPLETION_SOURCE_LINE='source "$HOME/.scripts/completions/zsh/install_dev_utils.zsh"'

COLORS_ENABLED=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME

Installs:
  - install_dev_utils.sh to \$HOME/.scripts
  - Bash completion to \$HOME/.scripts/completions/bash
  - Zsh completion files to \$HOME/.scripts/completions/zsh

It also ensures:
  - \$HOME/.scripts is on PATH in ~/.bashrc and ~/.zshrc
  - Bash completion is sourced from ~/.bashrc
  - Zsh completion directory is added to fpath in ~/.zshrc
  - compinit is initialized in ~/.zshrc
  - install_dev_utils.zsh is sourced from ~/.zshrc
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

log_error() {
  printf '%s %s\n' "$(color_text error 'Error:')" "$1" >&2
}

require_file() {
  file_path="$1"

  [ -f "$file_path" ] || {
    log_error "Required file not found: $file_path"
    exit 1
  }
}

ensure_line_in_file() {
  file_path="$1"
  marker_line="$2"
  managed_line="$3"

  touch "$file_path"

  if grep -F "$managed_line" "$file_path" >/dev/null 2>&1; then
    return
  fi

  {
    printf '\n%s\n' "$marker_line"
    printf '%s\n' "$managed_line"
  } >> "$file_path"
}

ensure_zsh_compinit() {
  touch "$ZSH_RC"

  if grep -F "compinit" "$ZSH_RC" >/dev/null 2>&1; then
    return
  fi

  {
    printf '\n%s\n' "$ZSH_FPATH_MARKER"
    printf '%s\n' "$ZSH_COMPINIT_LINE"
  } >> "$ZSH_RC"
}

copy_script_assets() {
  require_file "${SOURCE_DIR}/install_dev_utils.sh"
  require_file "${SOURCE_DIR}/install_dev_utils.bash"
  require_file "${SOURCE_DIR}/install_dev_utils.zsh"

  mkdir -p "$TARGET_BIN_DIR" "$BASH_COMPLETION_DIR" "$ZSH_COMPLETION_DIR"

  install -m 0755 "${SOURCE_DIR}/install_dev_utils.sh" "$TARGET_BIN_PATH"
  install -m 0644 "${SOURCE_DIR}/install_dev_utils.bash" "$BASH_COMPLETION_PATH"
  install -m 0644 "${SOURCE_DIR}/install_dev_utils.zsh" "$ZSH_COMPLETION_FILE"
  install -m 0644 "${SOURCE_DIR}/install_dev_utils.zsh" "$ZSH_COMPLETION_FUNC"

  log_success "Installed script to $(color_text value "$TARGET_BIN_PATH")"
  log_success "Installed Bash completion to $(color_text value "$BASH_COMPLETION_PATH")"
  log_success "Installed Zsh completions to $(color_text value "$ZSH_COMPLETION_DIR")"
}

ensure_path_setup() {
  ensure_line_in_file "$BASH_RC" "$PATH_MARKER" "$PATH_EXPORT"
  ensure_line_in_file "$ZSH_RC" "$PATH_MARKER" "$PATH_EXPORT"
  log_success "Ensured $(color_text value '$HOME/.scripts') is configured in ~/.bashrc and ~/.zshrc"
}

ensure_bash_completion_setup() {
  ensure_line_in_file "$BASH_RC" "$BASH_COMPLETION_MARKER" "$BASH_COMPLETION_LINE"
  log_success "Ensured Bash completion is sourced from $(color_text value "$BASH_RC")"
}

ensure_zsh_completion_setup() {
  ensure_line_in_file "$ZSH_RC" "$ZSH_FPATH_MARKER" "$ZSH_FPATH_LINE"
  ensure_zsh_compinit
  ensure_line_in_file "$ZSH_RC" "$ZSH_FPATH_MARKER" "$ZSH_COMPLETION_SOURCE_LINE"
  log_success "Ensured Zsh completion directory is on fpath and initialized from $(color_text value "$ZSH_RC")"
}

main() {
  init_colors

  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  copy_script_assets
  ensure_path_setup
  ensure_bash_completion_setup
  ensure_zsh_completion_setup

  log_info "Open a new shell or run $(color_text value "source ~/.bashrc") / $(color_text value "source ~/.zshrc") to load the updates"
}

main "$@"
