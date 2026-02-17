kube_tls_extract() {
  local SECRET_NAME=""
  local NAMESPACE=""
  local OUTPUT_FILE=""

  local OPTS
  OPTS=$(getopt -o h --long help,secret-name:,namespace:,output-file: -n 'kube_tls_extract' -- "$@")
  if [ $? != 0 ]; then
    return 1
  fi

  eval set -- "$OPTS"

  while true; do
    case "$1" in
      --secret-name)
        SECRET_NAME="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --output-file)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      -h|--help)
        cat <<EOF
Usage:
  kube_tls_extract --secret-name NAME --namespace NAMESPACE [--output-file FILE]

Description:
  Extracts tls.crt and tls.key from a kubernetes.io/tls Secret,
  base64-decodes them, and outputs combined PEM.

  If --output-file is not specified, output is written to STDOUT.

Options:
  --secret-name   Name of the Kubernetes TLS secret (required)
  --namespace     Namespace containing the secret (required)
  --output-file   Write output to file instead of STDOUT
  -h, --help      Show this help message

Examples:
  kube_tls_extract --secret-name my-tls --namespace default
  kube_tls_extract --secret-name my-tls --namespace default --output-file tls.pem
EOF
        return 0
        ;;
      --)
        shift
        break
        ;;
    esac
  done

  if [[ -z "$SECRET_NAME" || -z "$NAMESPACE" ]]; then
    echo "Error: --secret-name and --namespace are required" >&2
    return 1
  fi

  if [[ -n "$OUTPUT_FILE" ]]; then
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json \
      | jq -r '.data["tls.crt"], .data["tls.key"]' \
      | base64 -d > "$OUTPUT_FILE"
  else
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json \
      | jq -r '.data["tls.crt"], .data["tls.key"]' \
      | base64 -d
  fi
}


# Zsh completion for kube_tls_extract / ktls
_kube_tls_extract() {
  local context state state_descr
  typeset -A opt_args

  _arguments -C \
    '--secret-name=[TLS secret name]:secret name:->secrets' \
    '--namespace=[Kubernetes namespace]:namespace:->namespaces' \
    '--output-file=[Output PEM file]:file:_files' \
    '--help[Show help]'

  case $state in
    namespaces)
      local -a ns_list
      ns_list=("${(@f)$(kubectl get namespaces \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)}")

      (( ${#ns_list[@]} )) && _describe 'namespaces' ns_list
      ;;
    secrets)
      local ns
      local -a secret_list

      ns="${opt_args[--namespace]}"
      [[ -z "$ns" ]] && return 0

      secret_list=("${(@f)$(kubectl get secrets -n "$ns" \
        --field-selector type=kubernetes.io/tls \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)}")

      (( ${#secret_list[@]} )) && _describe 'tls secrets' secret_list
      ;;
  esac
}

# Register completion for function and alias
compdef _kube_tls_extract kube_tls_extract
compdef _kube_tls_extract ktls

