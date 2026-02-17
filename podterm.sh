podterm() {
	local namespace="default"

	# Pre-process long option --namespace into -n for getopts
	local args=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--namespace)
			args+=("-n" "$2")
			shift 2
			;;
		*)
			args+=("$1")
			shift
			;;
		esac
	done

	# Reset positional params to processed args
	set -- "${args[@]}"

	# Parse short options
	while getopts ":n:" opt; do
		case "$opt" in
		n)
			namespace="$OPTARG"
			;;
		\?)
			echo "Unknown option: -$OPTARG"
			return 1
			;;
		:)
			echo "Option -$OPTARG requires an argument."
			return 1
			;;
		esac
	done

	shift $((OPTIND - 1))

	local pod_name="$1"

	if [[ -z "$pod_name" ]]; then
		echo "Please specify the pod name."
		return 1
	fi

	kubectl exec -n "$namespace" -it "$pod_name" -- /bin/sh
}

_podterm_completion() {
	_arguments -C \
		'(-n --namespace)'{-n,--namespace}'[Specify namespace]:namespace:_podterm_namespaces' \
		'1:pod name:_podterm_pods'
}

_podterm_namespaces() {
	local namespaces
	namespaces=($(kubectl get namespaces --no-headers -o custom-columns=:metadata.name 2>/dev/null))
	_describe 'namespaces' namespaces
}

_podterm_pods() {
	local namespace="default"

	# Detect namespace flag in command line
	for ((i = 1; i <= $#words; i++)); do
		if [[ "${words[i]}" == "-n" || "${words[i]}" == "--namespace" ]]; then
			namespace="${words[i + 1]}"
			break
		fi
	done

	local pods
	pods=($(kubectl get pods -n "$namespace" --no-headers -o custom-columns=:metadata.name 2>/dev/null))
	_describe 'pods' pods
}

compdef _podterm_completion podterm
