update-bind() {
  local inventory="$HOME/projects/Homelab.Configs/ansible/playbooks/dns/inventory"
  local playbook="$HOME/projects/Homelab.Configs/ansible/playbooks/dns/main.yml"

  while [[ $# -gt 0 ]]; do
      case "$1" in
          --inventory)
              inventory="$2"
              shift 2
              ;;
          --playbook)
              playbook="$2"
              shift 2
              ;;
          -h|--help)
              echo "Usage: run_ansible [--inventory <path>] [--playbook <path>]"
              echo "  --inventory   Path to Ansible inventory file (default: $inventory)"
              echo "  --playbook    Path to Ansible playbook file (default: $playbook)"
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

  ansible-playbook -i "$inventory" "$playbook"
}

flush-dns(){
  sudo systemctl restart systemd-resolved.service
}

