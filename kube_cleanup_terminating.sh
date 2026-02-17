kube_cleanup_terminating_pods() {
    usage() {
        /usr/bin/cat <<EOF
Usage: kube_cleanup_terminating_pods [OPTIONS]

Find and delete pods stuck in "Terminating" state.

Options:
  -n, --namespace NS     Specify the namespace to search in
  --all-namespaces   Search across all namespaces
  --show-only        Only list terminating pods (do not delete)
  -h, --help             Show this help message
EOF
    }

    namespace=""
    all_namespaces=""
    show_only=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--namespace)
                shift
                [ -z "$1" ] && { echo "Error: missing namespace name" >&2; usage; return 1; }
                namespace="--namespace=$1"
                ;;
            --all-namespaces)
                all_namespaces="--all-namespaces"
                ;;
            --show-only)
                show_only=1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                return 1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [ -n "$namespace" ] && [ -n "$all_namespaces" ]; then
        echo "Error: Cannot use both --namespace and --all-namespaces" >&2
        usage
        return 1
    fi
    if [ -n "$all_namespaces" ]; then
        pods=$(kubectl get pods --all-namespaces | grep Terminating | awk '{print $2 "|" $1}')
        if [ -z "$pods" ]; then
            echo "No terminating pods found"
            return 0
        fi
        echo "$pods" | while IFS="|" read -r pod ns; do
            if [ -n "$show_only" ]; then
                echo "Terminating pod: $pod (namespace: $ns)"
            else
                echo "Deleting pod: $pod (namespace: $ns)"
                kubectl delete pod "$pod" --namespace="$ns" --grace-period=0 --force
            fi
        done
    else
        pods=$(kubectl get pods $namespace | grep Terminating | awk '{print $1}')
        if [ -z "$pods" ]; then
            echo "No terminating pods found"
            return 0
        fi
        for p in $pods; do
            if [ -n "$show_only" ]; then
                echo "Terminating pod: $p $namespace"
            else
                echo "Deleting pod: $p $namespace"
                kubectl delete pod "$p" $namespace --grace-period=0 --force
            fi
        done
    fi
  }
  # zsh completion for kube_cleanup_terminating_pods
  _kube_cleanup_terminating_pods() {
    local -a opts
    opts=(
      '-n[Specify namespace]:namespace:_kube_namespaces'
      '--namespace[Specify namespace]:namespace:_kube_namespaces'
      '--all-namespaces[Search across all namespaces]'
      '--show-only[Only show terminating pods]'
      '-h[Show help]'
      '--help[Show help]'
    )

    _arguments -s $opts
  }

# Helper function to fetch namespaces dynamically
_kube_namespaces() {
  local -a namespaces
  namespaces=($(kubectl get ns --no-headers -o custom-columns=:metadata.name 2>/dev/null))
  _values 'namespaces' $namespaces
}

# Register the completion
compdef _kube_cleanup_terminating_pods kube_cleanup_terminating_pods

delete_zero() {
    local namespace="default"
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -n | --namespace)
            namespace="$2"
            shift 2
            ;;
        -h | --help)
            echo "Usage: delete_zero [--namespace <namespace>]"
            echo "  -n, --namespace   Base Github URL (default: $namespace)"
            echo "  -h, --help    Show this help message"
            return 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use -h or --help for usage information."
            return 1
            ;;
        esac
    done
    export namespace
    echo "Deleteing replicasets with 0 replicas in namespace: $namespace"
    kubectl -n $namespace get replicaset -o json |
        jq -r '.items[] | select(.spec.replicas == 0) | .metadata.name' |
        xargs kubectl -n $namespace delete replicaset
}
