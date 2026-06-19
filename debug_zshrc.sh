#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"
TARGET_FILE="${HOME}/.zshrc"
BACKUP_SUFFIX=".bak"
TOP_LINE='zmodload zsh/zprof'
BOTTOM_LINE='zprof'
COLORS_ENABLED=false
BACKUP_PATH=""

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <on|off|status> [--file PATH]

Toggle zprof profiling lines in a zsh rc file.

Commands:
  on      Ensure '$TOP_LINE' is the first line and '$BOTTOM_LINE' is the last line
  off     Remove lines that exactly match '$TOP_LINE' or '$BOTTOM_LINE'
  status  Show whether the profiling lines are currently present

Options:
  --file PATH   Target rc file (default: ~/.zshrc)
  -h, --help    Show this help message

Examples:
  ./$SCRIPT_NAME on
  ./$SCRIPT_NAME off
  ./$SCRIPT_NAME status
  ./$SCRIPT_NAME on --file /Users/jtrahan/projects/helper-scripts/dotfiles/zsh/macos/.zshrc
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

die() {
  log_error "$1"
  exit 1
}

parse_args() {
  [ $# -gt 0 ] || {
    usage
    exit 1
  }

  ACTION=""

  while [ $# -gt 0 ]; do
    case "$1" in
    on|off|status)
      [ -z "$ACTION" ] || die "Only one command may be specified"
      ACTION="$1"
      ;;
    --file)
      shift
      [ $# -gt 0 ] || die "Missing value for --file"
      TARGET_FILE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done

  [ -n "$ACTION" ] || die "You must specify one of: on, off, status"
}

ensure_target_exists() {
  if [ ! -e "$TARGET_FILE" ]; then
    touch "$TARGET_FILE"
  fi
}

backup_target() {
  local default_backup_path timestamped_backup_path

  default_backup_path="${TARGET_FILE}${BACKUP_SUFFIX}"

  if [ ! -e "$default_backup_path" ] || [ -w "$default_backup_path" ]; then
    BACKUP_PATH="$default_backup_path"
  else
    timestamped_backup_path="${TARGET_FILE}.$(date '+%Y-%m-%dT%H-%M-%S').bak"
    BACKUP_PATH="$timestamped_backup_path"
    log_warning "Default backup path $(color_text value "$default_backup_path") is not writable; using $(color_text value "$BACKUP_PATH") instead"
  fi

  cp "$TARGET_FILE" "$BACKUP_PATH"
}

print_status() {
  local has_top has_bottom

  has_top=false
  has_bottom=false

  grep -qxF "$TOP_LINE" "$TARGET_FILE" && has_top=true || true
  grep -qxF "$BOTTOM_LINE" "$TARGET_FILE" && has_bottom=true || true

  log_info "File: $(color_text value "$TARGET_FILE")"
  log_info "Top line present: $(color_text value "$has_top")"
  log_info "Bottom line present: $(color_text value "$has_bottom")"

  if [ "$has_top" = true ] && [ "$has_bottom" = true ]; then
    log_success "zprof debug toggle is $(color_text value 'ON')"
  else
    log_warning "zprof debug toggle is $(color_text value 'OFF')"
  fi
}

write_on_file() {
  local temp_file
  temp_file="$(mktemp)"

  {
    printf '%s\n' "$TOP_LINE"
    grep -vxF "$TOP_LINE" "$TARGET_FILE" | grep -vxF "$BOTTOM_LINE" || true
    printf '%s\n' "$BOTTOM_LINE"
  } >"$temp_file"

  mv "$temp_file" "$TARGET_FILE"
}

write_off_file() {
  local temp_file
  temp_file="$(mktemp)"

  grep -vxF "$TOP_LINE" "$TARGET_FILE" | grep -vxF "$BOTTOM_LINE" >"$temp_file" || true

  mv "$temp_file" "$TARGET_FILE"
}

main() {
  init_colors
  parse_args "$@"
  ensure_target_exists

  case "$ACTION" in
  status)
    print_status
    ;;
  on)
    backup_target
    write_on_file
    log_success "Enabled zprof profiling in $(color_text value "$TARGET_FILE")"
    log_info "Backup written to $(color_text value "$BACKUP_PATH")"
    ;;
  off)
    backup_target
    write_off_file
    log_success "Disabled zprof profiling in $(color_text value "$TARGET_FILE")"
    log_info "Backup written to $(color_text value "$BACKUP_PATH")"
    ;;
  esac
}

main "$@"
