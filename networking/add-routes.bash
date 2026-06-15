_add_routes_script_path() {
  local completion_dir
  completion_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "$completion_dir/add-routes.sh"
}

_add_routes_load_entries() {
  local script_path
  script_path="$(_add_routes_script_path)"

  [ -r "$script_path" ] || return 1

  mapfile -t ADD_ROUTES_COMPLETION_ENTRIES < <(
    sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1/p' "$script_path"
  )
}

_add_routes_networks() {
  local entry network

  for entry in "${ADD_ROUTES_COMPLETION_ENTRIES[@]}"; do
    IFS='|' read -r network _ <<<"$entry"
    printf '%s\n' "$network"
  done
}

_add_routes_netmask_to_prefix() {
  local netmask="$1"
  local prefix=0
  local octet

  IFS='.' read -r octet1 octet2 octet3 octet4 <<<"$netmask"

  for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
    case "$octet" in
    255) prefix=$((prefix + 8)) ;;
    254) prefix=$((prefix + 7)) ;;
    252) prefix=$((prefix + 6)) ;;
    248) prefix=$((prefix + 5)) ;;
    240) prefix=$((prefix + 4)) ;;
    224) prefix=$((prefix + 3)) ;;
    192) prefix=$((prefix + 2)) ;;
    128) prefix=$((prefix + 1)) ;;
    0) ;;
    *) return 1 ;;
    esac
  done

  printf '%s\n' "$prefix"
}

_add_routes_cidrs() {
  local entry network netmask prefix

  for entry in "${ADD_ROUTES_COMPLETION_ENTRIES[@]}"; do
    IFS='|' read -r network netmask _ <<<"$entry"
    prefix="$(_add_routes_netmask_to_prefix "$netmask")" || continue
    printf '%s/%s\n' "$network" "$prefix"
  done
}

_add_routes_netmasks_for_network() {
  local wanted_network="$1"
  local entry network netmask

  for entry in "${ADD_ROUTES_COMPLETION_ENTRIES[@]}"; do
    IFS='|' read -r network netmask _ <<<"$entry"
    if [ "$network" = "$wanted_network" ]; then
      printf '%s\n' "$netmask"
    fi
  done
}

_add_routes_gateways_for_route() {
  local wanted_network="$1"
  local wanted_netmask="$2"
  local entry network netmask gateway

  for entry in "${ADD_ROUTES_COMPLETION_ENTRIES[@]}"; do
    IFS='|' read -r network netmask gateway <<<"$entry"
    if [ "$network" = "$wanted_network" ] && [ "$netmask" = "$wanted_netmask" ]; then
      printf '%s\n' "$gateway"
    fi
  done
}

_add_routes_all_gateways() {
  local entry gateway

  for entry in "${ADD_ROUTES_COMPLETION_ENTRIES[@]}"; do
    IFS='|' read -r _ _ gateway <<<"$entry"
    printf '%s\n' "$gateway"
  done
}

_add_routes_complete() {
  local cur prev action_index route_spec network netmask
  local -a suggestions

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [ "$COMP_CWORD" -gt 0 ]; then
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  COMPREPLY=()
  _add_routes_load_entries || return 0

  action_index=-1
  for ((i = 1; i < COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
    --add-route|--delete-route)
      action_index="$i"
      break
      ;;
    esac
  done

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "-r --reset -d --remove-all --add-route --delete-route -h --help" -- "$cur"))
    return 0
  fi

  case "$prev" in
  --add-route|--delete-route)
    mapfile -t suggestions < <(
      {
        _add_routes_networks
        _add_routes_cidrs
      } | awk '!seen[$0]++'
    )
    COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
    return 0
    ;;
  esac

  if [ "$action_index" -ge 0 ] && [ "$COMP_CWORD" -gt "$action_index" ]; then
    route_spec="${COMP_WORDS[action_index+1]:-}"

    if [[ "$route_spec" == */* ]]; then
      case $((COMP_CWORD - action_index)) in
      2)
        mapfile -t suggestions < <(
          {
            _add_routes_networks
            _add_routes_cidrs
          } | awk '!seen[$0]++'
        )
        COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
        ;;
      3)
        mapfile -t suggestions < <(_add_routes_all_gateways | awk '!seen[$0]++')
        COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
        ;;
      esac
      return 0
    fi

    network="$route_spec"
    netmask="${COMP_WORDS[action_index+2]:-}"

    case $((COMP_CWORD - action_index)) in
    2)
      mapfile -t suggestions < <(
        {
          _add_routes_networks
          _add_routes_cidrs
        } | awk '!seen[$0]++'
      )
      COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
      ;;
    3)
      mapfile -t suggestions < <(_add_routes_netmasks_for_network "$network" | awk '!seen[$0]++')
      COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
      ;;
    4)
      mapfile -t suggestions < <(
        {
          _add_routes_gateways_for_route "$network" "$netmask"
          _add_routes_all_gateways
        } | awk '!seen[$0]++'
      )
      COMPREPLY=($(compgen -W "${suggestions[*]}" -- "$cur"))
      ;;
    esac

    return 0
  fi

  COMPREPLY=($(compgen -W "-r --reset -d --remove-all --add-route --delete-route -h --help" -- "$cur"))
}

complete -F _add_routes_complete add-routes.sh add-routes networking/add-routes.sh ./networking/add-routes.sh
