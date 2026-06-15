#compdef add-routes.sh add-routes networking/add-routes.sh ./networking/add-routes.sh

_add_routes_script_path() {
  local command_word candidate completion_path

  command_word="${words[1]:-}"

  if [[ "$command_word" == */* ]]; then
    candidate="${~command_word:A}"
    [[ -r "$candidate" ]] && print -r -- "$candidate" && return 0
  fi

  if [[ -n "$command_word" && -n "${commands[$command_word]:-}" ]]; then
    candidate="${commands[$command_word]:A}"
    [[ -r "$candidate" ]] && print -r -- "$candidate" && return 0
  fi

  completion_path="${functions_source[_add_routes]:-${functions_source[_add_routes_script_path]}}"
  completion_path="${completion_path:A}"
  print -r -- "${completion_path:h}/add-routes.sh"
}

_add_routes_entries() {
  local script_path
  script_path="$(_add_routes_script_path)"

  [[ -r "$script_path" ]] || return 1

  sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1/p' "$script_path"
}

_add_routes_networks() {
  local entry

  while IFS= read -r entry; do
    print -r -- "${entry%%|*}"
  done < <(_add_routes_entries)
}

_add_routes_netmask_to_prefix() {
  local netmask="$1"
  local prefix=0
  local octet

  for octet in ${(s:.:)netmask}; do
    case "$octet" in
      255) (( prefix += 8 )) ;;
      254) (( prefix += 7 )) ;;
      252) (( prefix += 6 )) ;;
      248) (( prefix += 5 )) ;;
      240) (( prefix += 4 )) ;;
      224) (( prefix += 3 )) ;;
      192) (( prefix += 2 )) ;;
      128) (( prefix += 1 )) ;;
      0) ;;
      *) return 1 ;;
    esac
  done

  print -r -- "$prefix"
}

_add_routes_cidrs() {
  local entry network remainder netmask prefix

  while IFS= read -r entry; do
    network="${entry%%|*}"
    remainder="${entry#*|}"
    netmask="${remainder%%|*}"
    prefix="$(_add_routes_netmask_to_prefix "$netmask")" || continue
    print -r -- "$network/$prefix"
  done < <(_add_routes_entries)
}

_add_routes_route_specs() {
  _add_routes_networks
  _add_routes_cidrs
}

_add_routes_netmasks() {
  local wanted_network="$1"
  local entry network remainder

  while IFS= read -r entry; do
    network="${entry%%|*}"
    remainder="${entry#*|}"
    if [[ "$network" == "$wanted_network" ]]; then
      print -r -- "${remainder%%|*}"
    fi
  done < <(_add_routes_entries)
}

_add_routes_gateways() {
  local wanted_network="$1"
  local wanted_netmask="$2"
  local entry network remainder netmask gateway

  while IFS= read -r entry; do
    network="${entry%%|*}"
    remainder="${entry#*|}"
    netmask="${remainder%%|*}"
    gateway="${entry##*|}"
    if [[ "$network" == "$wanted_network" && "$netmask" == "$wanted_netmask" ]]; then
      print -r -- "$gateway"
    fi
  done < <(_add_routes_entries)
}

_add_routes_all_gateways() {
  local entry

  while IFS= read -r entry; do
    print -r -- "${entry##*|}"
  done < <(_add_routes_entries)
}

_add_routes() {
  local line_state route_spec network netmask state
  local -a route_specs netmasks gateways
  typeset -A opt_args

  _arguments -s -S \
    '(-r --reset -d --remove-all --add-route --delete-route -h --help)'{-r,--reset}'[Delete existing routes and re-add them]' \
    '(-r --reset -d --remove-all --add-route --delete-route -h --help)'{-d,--remove-all}'[Delete all managed static routes]' \
    '(-r --reset -d --remove-all --add-route --delete-route -h --help)--add-route[Add a single route]' \
    '(-r --reset -d --remove-all --add-route --delete-route -h --help)--delete-route[Delete a single route]' \
    '(-r --reset -d --remove-all --add-route --delete-route -h --help)'{-h,--help}'[Show help message]' \
    '*::route args:->route_args'

  [[ "$state" == route_args ]] || return 0

  if (( words[(I)--add-route] )); then
    line_state="--add-route"
  elif (( words[(I)--delete-route] )); then
    line_state="--delete-route"
  else
    return 0
  fi

  local action_index network_index netmask_index gateway_index
  action_index="${words[(I)$line_state]}"
  network_index=$((action_index + 1))
  netmask_index=$((action_index + 2))
  gateway_index=$((action_index + 3))

  route_spec="${words[network_index]}"

  if (( CURRENT == network_index )); then
    route_specs=(${(u)${(@f)$(_add_routes_route_specs)}})
    (( ${#route_specs[@]} )) && compadd -- "${route_specs[@]}"
    return 0
  fi

  if [[ "$route_spec" == */* ]]; then
    if (( CURRENT == netmask_index )); then
      gateways=(${(u)${(@f)$(_add_routes_all_gateways)}})
      (( ${#gateways[@]} )) && compadd -- "${gateways[@]}"
      return 0
    fi

    return 0
  fi

  network="$route_spec"
  netmask="${words[netmask_index]}"

  if (( CURRENT == netmask_index )); then
    netmasks=(${(u)${(@f)$(_add_routes_netmasks "$network")}})
    (( ${#netmasks[@]} )) && compadd -- "${netmasks[@]}"
    return 0
  fi

  if (( CURRENT == gateway_index )); then
    gateways=(${(u)${(@f)$(_add_routes_gateways "$network" "$netmask")}})
    gateways+=(${(u)${(@f)$(_add_routes_all_gateways)}})
    (( ${#gateways[@]} )) && compadd -- "${gateways[@]}"
    return 0
  fi
}

if ! whence -w compdef >/dev/null 2>&1; then
  autoload -Uz compinit
  compinit -i >/dev/null 2>&1
fi

compdef _add_routes add-routes.sh add-routes networking/add-routes.sh ./networking/add-routes.sh
compdef -p _add_routes '*/add-routes.sh'
