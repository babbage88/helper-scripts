#!/usr/bin/env bash
usage() {
  /usr/bin/cat <<EOF
Usage: remove_spaces_from_filenames [OPTIONS]

Find files under a directory and remove spaces from filenames.


Options:
  -p, --path DIR     Directory to search (required)
  -h, --help         Show this help message

Examples:
  rename_spaces_in_filenames --path /tmp/my-files
  rename_spaces_in_filenames -p .
EOF
}

rename_spaces_in_filenames() {
  local search_path=""
  local opts=""

  if ! opts=$(getopt -o hp: --long help,path: -n 'rename_spaces_in_filenames' -- "$@"); then
    return 1
  fi

  eval set -- "$opts"

  while true; do
    case "$1" in
      -p|--path)
        search_path="$2"
        shift 2
        ;;
      -h|--help)
        usage
        return 0
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        return 1
        ;;
    esac
  done

  if [[ -z "$search_path" ]]; then
    echo "Error: --path is required." >&2
    usage
    return 1
  fi

  if [[ ! -d "$search_path" ]]; then
    echo "Error: '$search_path' is not a directory." >&2
    return 1
  fi
  # shellcheck disable=SC2016
  find "$search_path" -depth -type f -name '* *' -print0 \
    | xargs -0 -r -I{} sh -c '
        file_path="$1"
        dir_name=$(dirname "$file_path")
        base_name=$(basename "$file_path")
        new_name=${base_name// /_}

        if [ "$base_name" != "$new_name" ]; then
          mv -- "$file_path" "$dir_name/$new_name"
          printf "Renamed: %s -> %s\n" "$file_path" "$dir_name/$new_name"
        fi
      ' _ "{}"
}
