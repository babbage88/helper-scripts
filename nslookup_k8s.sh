nslookup_k8s() {
  usage() {
    /usr/bin/cat <<EOF
Usage: nslookup_k8s [OPTIONS]

Run an nslookup inside a Kubernetes pod to test DNS/service resolution.
If an existing pod/container is not specified, one will be created with 
the name debug-nslookup

Options:
  -p, --pod POD           Pod name to exec into (default: debug-nslookup)
  -c, --container NAME    Container name within the pod (default: debug-nslookup)
  -t, --target HOSTNAME   Hostname or pod/service name to resolve (required)
  -n, --namespace NS      Kubernetes namespace (default: current kubectl context namespace)
  -h, --help              Show this help message and exit

Examples:
  # Use defaults (pod/container "debug-nslookup") in current namespace
  nslookup_k8s --target my-service.default.svc.cluster.local

  # Pick a pod/container and namespace explicitly
  nslookup_k8s --pod mypod --container app --target kubernetes --namespace kube-system
EOF
  }

  pod="debug-nslookup"
  container="debug-nslookup"
  target=""
  namespace=""

  # short + long option parsing
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--pod)        pod=$2; shift 2 ;;
      -c|--container)  container=$2; shift 2 ;;
      -t|--target)     target=$2; shift 2 ;;
      -n|--namespace)  namespace="--namespace=$2"; shift 2 ;;
      -h|--help)       usage; return 0 ;;
      --)              shift; break ;;
      -*)
        echo "Unknown option: $1" >&2
        usage
        return 1
        ;;
      *) break ;;
    esac
  done

  if [ -z "$target" ]; then
    echo "Error: --target is required." >&2
    usage
    return 1
  fi

  # Check if pod exists
  if ! kubectl get pod "$pod" $namespace &>/dev/null; then
    echo "Pod $pod not found, creating..."
    kubectl run "$pod" $namespace --image=debian:trixie-slim --restart=Never -- sleep infinity

    echo "Waiting for pod $pod to be ready..."
    kubectl wait $namespace --for=condition=Ready pod/"$pod" --timeout=60s
    if [ $? -ne 0 ]; then
      echo "Pod $pod did not become ready in time." >&2
      return 1
    fi
  fi

  # Run nslookup inside the pod
  kubectl exec -it "$pod" $namespace --container "$container" -- \
    /bin/bash -c "apt-get update -qq && apt-get install -y -qq dnsutils && nslookup $target"
}

# ---------------------- zsh completion for nslookup_k8s -----------------------
# Helper: discover namespace already typed on the command line
_nslookup_k8s_cli_namespace() {
  local i
  for (( i=1; i<=$#words; i++ )); do
    case ${words[i]} in
      -n|--namespace)
        echo ${words[i+1]}
        return
        ;;
      --namespace=*)
        echo ${words[i]#--namespace=}
        return
        ;;
    esac
  done
}

# Helper: discover exec pod already typed (defaults to debug-nslookup if not set)
_nslookup_k8s_cli_pod() {
  local i
  for (( i=1; i<=$#words; i++ )); do
    case ${words[i]} in
      -p|--pod)
        echo ${words[i+1]}
        return
        ;;
      --pod=*)
        echo ${words[i]#--pod=}
        return
        ;;
    esac
  done
  echo "debug-nslookup"
}

# Complete namespaces via kubectl
_k8s_namespaces() {
  local -a ns
  ns=($(kubectl get ns --no-headers -o custom-columns=:metadata.name 2>/dev/null))
  _values 'namespaces' $ns
}

# Complete pods for a given namespace (or current if none)
_k8s_pods_for_ns() {
  local nsflag=()
  [[ -n "$1" ]] && nsflag=(--namespace "$1")
  local -a pods
  pods=($(kubectl get pods "${nsflag[@]}" --no-headers -o custom-columns=:metadata.name 2>/dev/null))
  _values 'pods' $pods
}

# target completion = pods in namespace, excluding the exec pod
_nslookup_k8s_complete_target() {
  local ns="$(_nslookup_k8s_cli_namespace)"
  local execpod="$(_nslookup_k8s_cli_pod)"
  local nsflag=()
  [[ -n "$ns" ]] && nsflag=(--namespace "$ns")
  local -a pods filtered
  pods=($(kubectl get pods "${nsflag[@]}" --no-headers -o custom-columns=:metadata.name 2>/dev/null))
  filtered=()
  for p in $pods; do
    [[ "$p" == "$execpod" ]] && continue
    filtered+="$p"
  done
  compadd -a filtered
}

# Main completion dispatcher
_nslookup_k8s() {
  local curcontext="$curcontext" state
  typeset -A opt_args

  _arguments -s -S \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-p --pod)'{-p,--pod}'[Pod to exec into (default: debug-nslookup)]:pod name:->pod' \
    '(-c --container)'{-c,--container}'[Container within the pod (default: debug-nslookup)]:container name:' \
    '(-t --target)'{-t,--target}'[Pod/hostname to resolve]:target:->target' \
    '(-n --namespace)'{-n,--namespace}'[Kubernetes namespace]:namespace:_k8s_namespaces' \
    '*::arg:->rest' && return

  case $state in
    pod)
      _k8s_pods_for_ns "$(_nslookup_k8s_cli_namespace)"
      ;;
    target)
      _nslookup_k8s_complete_target
      ;;
  esac
}

# Register completion for the function
autoload -U +X compinit 2>/dev/null && compinit
compdef _nslookup_k8s nslookup_k8s
