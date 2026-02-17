nodepods() {
    local node_name=$1
    if [[ -z "$node_name" ]]; then
      echo "Please specify the node name."
      return 1
    fi
    kubectl get pods --field-selector spec.nodeName="$node_name" --all-namespaces -o wide
}

# Auto-completion for node names
_nodepods_completion() {
  local nodes=($(kubectl get nodes --no-headers -o custom-columns=:metadata.name 2>/dev/null))
  _describe 'nodes' nodes
}

# Register the auto-completion for the nodepods function
compdef _nodepods_completion nodepods
