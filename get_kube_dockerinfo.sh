#!/usr/bin/env bash
SECRETNAME=$(kubectl get secrets --field-selector type=kubernetes.io/dockerconfigjson,metadata.name=ghcr -o name | cut -d'/' -f2)
NAMESPACE=default

# Function to display usage information and exit
usage() {
	echo "Usage: $(basename "$0") <secret-name>"
	echo "This fuction uses kubectl to get a .dockerconfigjson secret and decode its value to STDOUT."
	echo ""
	echo "Options:"
	echo "  -s, --secret  Kubernetes secret-name. defaults to $SECRETNAME"
	echo "  -n, --namespace  Kubernetes namespace. Uses default namespace if not specified."
	echo "  -h, --help  Display this help message"
	exit 1 # Exit with a non-zero status to indicate an error/incorrect usage
}

function kube_get_dockerinfo {
	local secret
	local namespace=default
	while getopts "hs:n:" opt; do
		case $opt in
		h)
			echo "Usage: $0 [-h] [-s secret] [-n namespace]"
			exit 0
			;;
		s)
			secret=$OPTARG
			;;
		n)
			namespace=$OPTARG
			;;
		\?) # Handle invalid options
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:) # Handle missing arguments (only applicable with a leading ':' in optstring)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
		esac
	done

	# Shift off the options and their arguments so remaining positional parameters can be accessed
	shift $((OPTIND - 1))
	echo "secret after opts parsing: $secret"
	echo "namespace after opts parsing: $namespace"
	if [ -z "$secret" ]; then
		secret=$SECRETNAME
	fi

	echo "secret after empty check: $secret"
	kubectl get secrets $secret -n $namespace -o json | jq -r '.data.".dockerconfigjson"' | base64 -d | jq
}
