#!/usr/bin/env bash

set -eu

SCRIPT_NAME="$(basename "$0")"

NAS_HOST="10.0.0.8"
MOVIES_BASE="/mnt/trahan-nas/Movies"
TV_BASE="/mnt/trahan-nas/TV"

COLORS_ENABLED=false
MEDIA_TYPE="movies"
SOURCE_PATH=""
DESTINATION_SUFFIX=""
SANE_DIR=false

RSYNC_DEFAULT_ARGS=(
  -avh
  --progress
)

EXTRA_RSYNC_ARGS=()

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] SOURCE_PATH [DESTINATION_SUFFIX] [-- EXTRA_RSYNC_ARGS...]

Copy a movie or TV download to the NAS with rsync.

Options:
  -m, --movies              Copy into ${MOVIES_BASE} (default)
  -t, --tv                  Copy into ${TV_BASE}
  -d, --dest-subdir NAME    Append a destination subdirectory under Movies or TV
  -s, --sane-dir            Derive a sanitized destination subdirectory from SOURCE_PATH
  -h, --help                Show this help message

Behavior:
  - rsync defaults to: rsync -avh --progress
  - If SOURCE_PATH is a file and no destination subdirectory is provided, a
    sanitized subdirectory is derived from the filename.
  - If SOURCE_PATH is a directory, use --sane-dir to derive a sanitized
    destination subdirectory from the directory name.
  - Spaces become dots in derived directory names.
  - Parentheses, quotes, and other non-sane special characters are removed from
    derived directory names.

Examples:
  $SCRIPT_NAME --movies ~/Downloads/movies/Obsession\\ 2026\\ 1080p\\ WEB-DL\\ HEVC\\ x265\\ 5.1\\ BONE.mkv
  $SCRIPT_NAME --tv ~/Downloads/tv/Andor.S02 Season.02
  $SCRIPT_NAME --tv ~/Downloads/tv/'The Bear (2025)' "The.Bear/Season.04"
  $SCRIPT_NAME --movies --sane-dir ~/Downloads/movies/'Carolina\\ Caroline\\ (2025)\\ 720p\\ WEBRip-LAMA'
  $SCRIPT_NAME --movies ~/Downloads/movies/Dune.Part.Two.2024 -- --bwlimit=20m
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

print_shell_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

trim_slashes() {
  value="$1"
  value="${value#/}"
  value="${value%/}"
  printf '%s' "$value"
}

sanitize_path_segment() {
  value="$1"

  value="$(printf '%s' "$value" | sed -E \
    -e 's/[[:space:]]+/\./g' \
    -e "s/[^[:alnum:]._-]+//g" \
    -e 's/\.+/./g' \
    -e 's/^[._-]+//' \
    -e 's/[._-]+$//')"

  printf '%s' "$value"
}

sanitize_destination_suffix() {
  suffix="$1"
  trimmed_suffix="$(trim_slashes "$suffix")"
  sanitized_suffix=""

  IFS='/' read -r -a suffix_parts <<<"$trimmed_suffix"
  for suffix_part in "${suffix_parts[@]}"; do
    sanitized_part="$(sanitize_path_segment "$suffix_part")"
    [ -n "$sanitized_part" ] || continue

    if [ -n "$sanitized_suffix" ]; then
      sanitized_suffix="${sanitized_suffix}/"
    fi
    sanitized_suffix="${sanitized_suffix}${sanitized_part}"
  done

  printf '%s' "$sanitized_suffix"
}

derived_source_directory_name() {
  source_path="$1"
  source_name="$(basename "$source_path")"

  if [ -f "$source_path" ]; then
    case "$source_name" in
    *.*)
      source_name="${source_name%.*}"
      ;;
    esac
  fi

  sanitize_path_segment "$source_name"
}

base_destination_path() {
  case "$MEDIA_TYPE" in
  movies)
    printf '%s' "$MOVIES_BASE"
    ;;
  tv)
    printf '%s' "$TV_BASE"
    ;;
  *)
    log_error "Unsupported media type: $MEDIA_TYPE"
    exit 1
    ;;
  esac
}

resolve_destination_directory() {
  base_destination="$(base_destination_path)"

  if [ -n "$DESTINATION_SUFFIX" ]; then
    printf '%s/%s' "$base_destination" "$DESTINATION_SUFFIX"
    return
  fi

  if [ -f "$SOURCE_PATH" ] || [ "$SANE_DIR" = true ]; then
    derived_dir="$(derived_source_directory_name "$SOURCE_PATH")"
    [ -n "$derived_dir" ] || {
      log_error "Could not derive a destination directory from $(color_text value "$SOURCE_PATH")"
      exit 1
    }
    printf '%s/%s' "$base_destination" "$derived_dir"
    return
  fi

  printf '%s' "$base_destination"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -m|--movies)
      MEDIA_TYPE="movies"
      shift
      ;;
    -t|--tv)
      MEDIA_TYPE="tv"
      shift
      ;;
    -d|--dest-subdir)
      [ "$#" -ge 2 ] || {
        log_error "$1 requires a value"
        exit 1
      }
      DESTINATION_SUFFIX="$2"
      shift 2
      ;;
    -s|--sane-dir)
      SANE_DIR=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_RSYNC_ARGS=("$@")
      break
      ;;
    -*)
      log_error "Unknown option: $1"
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$SOURCE_PATH" ]; then
        SOURCE_PATH="$1"
      elif [ -z "$DESTINATION_SUFFIX" ]; then
        DESTINATION_SUFFIX="$1"
      else
        log_error "Unexpected argument: $1"
        usage >&2
        exit 1
      fi
      shift
      ;;
    esac
  done

  [ -n "$SOURCE_PATH" ] || {
    log_error "SOURCE_PATH is required"
    usage >&2
    exit 1
  }
}

validate_inputs() {
  require_command rsync
  require_command ssh

  [ -e "$SOURCE_PATH" ] || {
    log_error "Source path not found: $SOURCE_PATH"
    exit 1
  }

  if [ -n "$DESTINATION_SUFFIX" ]; then
    sanitized_suffix="$(sanitize_destination_suffix "$DESTINATION_SUFFIX")"
    [ -n "$sanitized_suffix" ] || {
      log_error "Destination subdirectory becomes empty after sanitizing: $DESTINATION_SUFFIX"
      exit 1
    }
    DESTINATION_SUFFIX="$sanitized_suffix"
  fi
}

ensure_remote_directory() {
  remote_directory="$1"
  mkdir_command="mkdir -p $(printf '%q' "$remote_directory")"

  log_info "Ensuring remote directory exists on $(color_text value "$NAS_HOST")"
  print_shell_command ssh "$NAS_HOST" "$mkdir_command"
  ssh "$NAS_HOST" "$mkdir_command"
}

run_rsync() {
  destination_directory="$1"
  remote_target="${NAS_HOST}:${destination_directory}/"
  rsync_command=(rsync "${RSYNC_DEFAULT_ARGS[@]}")

  if [ "${#EXTRA_RSYNC_ARGS[@]}" -gt 0 ]; then
    rsync_command+=("${EXTRA_RSYNC_ARGS[@]}")
  fi

  rsync_command+=("$SOURCE_PATH" "$remote_target")

  log_info "Copying $(color_text value "$SOURCE_PATH") to $(color_text value "$remote_target")"
  print_shell_command "${rsync_command[@]}"
  "${rsync_command[@]}"
}

main() {
  init_colors
  parse_args "$@"
  validate_inputs

  destination_directory="$(resolve_destination_directory)"

  log_info "Media target: $(color_text value "$MEDIA_TYPE")"
  log_info "Destination directory: $(color_text value "${NAS_HOST}:${destination_directory}")"

  ensure_remote_directory "$destination_directory"
  run_rsync "$destination_directory"

  log_success "NAS copy completed"
  if [ -n "$DESTINATION_SUFFIX" ]; then
    log_info "Applied destination subdirectory: $(color_text value "$DESTINATION_SUFFIX")"
  elif [ -f "$SOURCE_PATH" ] || [ "$SANE_DIR" = true ]; then
    log_info "Derived destination subdirectory from the source path name"
  fi
}

main "$@"
