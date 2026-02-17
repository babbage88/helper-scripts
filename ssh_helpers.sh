# Function to start an interactive shell in the specified pod
purgessh() {
  local hostname=$1
  if [[ -z "$hostname" ]]; then
    echo "Please specify ssh hostname. eg: jtrahan@10.0.0.32"
    return 1
  fi
  ssh-keygen -R $hostname
}

# Auto-completion for pod names
_purgessh_completion() {
    local pods=($(awk '{print $1}' ~/.ssh/known_hosts 2>/dev/null))
    _describe 'hosts' hosts
}

# Register the auto-completion for the purgessh function
compdef _purgessh_completion purgessh

alias purge-ssh-host=purgessh

# Function to start an interactive shell in the specified pod
getknownhost() {
  local hostname=$1
  if [[ -z "$hostname" ]]; then
    echo "Please specify ssh hostname. eg: jtrahan@10.0.0.32"
    return 1
  fi
  sed -n "/$hostname/p" ~/.ssh/known_hosts
}

# Auto-completion for pod names
_getknownhost_completion() {
  local pods=($(awk '{print $1}' ~/.ssh/known_hosts 2>/dev/null))
  _describe 'hosts' hosts
}

# Register the auto-completion for the purgessh function
compdef _getknownhost_completion getknownhost

alias get-knownhost=getknownhost
