#!/usr/bin/env bash
set -euo pipefail

DATE="$(date +%Y_%m_%d)"
LOG_DIR="/scripts/logs"

FILTER_MODE="exclude"
FILTER_FILE="/scripts/exclude_from_backup.txt"
VERBOSE=false
DRY_RUN=false
DELETE_EXCLUDED=true

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -v, --verbose                 Print rclone logs to STDOUT and log file
  -n, --dry-run                 Run rclone with --dry-run
  -f, --filter-from FILE        Use rclone --filter-from FILE
  -e, --exclude-from FILE       Use rclone --exclude-from FILE
      --no-delete-excluded      Do not delete excluded files from destination
  -h, --help                    Show this help

Examples:
  $0
  $0 --dry-run --verbose
  $0 --filter-from /scripts/include_only_movies.txt

Manual rclone example:
  rclone sync /mnt/trahan-nas/Movies/ b2_media:backup-trah-nas/Movies/ \\
    --exclude-from /scripts/exclude_from_backup.txt \\
    --multi-thread-streams=8 \\
    --log-level=INFO \\
    --stats=30s \\
    --stats-one-line \\
    --delete-excluded \\
    --log-file=/scripts/logs/\$(date +%Y_%m_%d)_b2_rclone_movies.log
EOF
}

while getopts ":vnf:e:h-:" opt; do
  case "$opt" in
  v) VERBOSE=true ;;
  n) DRY_RUN=true ;;
  f)
    FILTER_MODE="filter"
    FILTER_FILE="$OPTARG"
    ;;
  e)
    FILTER_MODE="exclude"
    FILTER_FILE="$OPTARG"
    ;;
  h)
    usage
    exit 0
    ;;
  -)
    case "$OPTARG" in
    verbose) VERBOSE=true ;;
    dry-run) DRY_RUN=true ;;
    filter-from)
      FILTER_MODE="filter"
      FILTER_FILE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    exclude-from)
      FILTER_MODE="exclude"
      FILTER_FILE="${!OPTIND}"
      OPTIND=$((OPTIND + 1))
      ;;
    no-delete-excluded)
      DELETE_EXCLUDED=false
      ;;
    help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: --$OPTARG" >&2
      usage
      exit 1
      ;;
    esac
    ;;
  \?)
    echo "Unknown option: -$OPTARG" >&2
    usage
    exit 1
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    usage
    exit 1
    ;;
  esac
done

mkdir -p "$LOG_DIR"

append_filter_file_args() {
  local -n rclone_args_ref="$1"

  case "$FILTER_MODE" in
  filter)
    rclone_args_ref+=(--filter-from "$FILTER_FILE")
    ;;
  exclude)
    rclone_args_ref+=(--exclude-from "$FILTER_FILE")
    ;;
  *)
    echo "Unsupported FILTER_MODE: $FILTER_MODE" >&2
    exit 1
    ;;
  esac
}

print_shell_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

run_rclone_sync() {
  local log_file="$1"
  shift

  if [[ "$VERBOSE" == true ]]; then
    echo "Rclone command:"
    print_shell_command rclone "$@"
    echo "Log capture:"
    print_shell_command tee -a "$log_file"
    rclone "$@" 2>&1 | tee -a "$log_file"
  else
    local command=(rclone "$@" --log-file "$log_file")
    echo "Rclone command:"
    print_shell_command "${command[@]}"
    "${command[@]}"
  fi
}

sync_media() {
  local name="$1"
  local src="$2"
  local dst="$3"
  local log_file="${LOG_DIR}/${DATE}_b2_rclone_${name}.log"

  local args=(
    sync "$src" "$dst"
    --multi-thread-streams=8
    --log-level=INFO
    --stats=30s
    --stats-one-line
  )

  append_filter_file_args args

  if [[ "$DELETE_EXCLUDED" == true ]]; then
    args+=(--delete-excluded)
  fi

  if [[ "$DRY_RUN" == true ]]; then
    args+=(--dry-run)
  fi

  echo "Starting ${name} backup..."
  echo "Source:      $src"
  echo "Destination: $dst"
  echo "Filter mode: $FILTER_MODE"
  echo "Filter file: $FILTER_FILE"
  echo "Log file:    $log_file"

  run_rclone_sync "$log_file" "${args[@]}"

  echo "Finished ${name} backup."
}

sync_media "movies" "/mnt/trahan-nas/Movies/" "b2_media:backup-trah-nas/Movies/"
sync_media "tv" "/mnt/trahan-nas/TV/" "b2_media:backup-trah-nas/TV/"
