#!/usr/bin/env bash
cmd_ssh() {
  if [[ $# -eq 0 ]]; then log_err $ERR_MISSING_PARAM "Target required for ssh"; fi
  local target=$1
  shift
  
  local extra_args=()
  if [[ "${1:-}" == "--" ]]; then
    shift
    extra_args=("$@")
  fi
  
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    local ip
    ip=$(virsh domifaddr "$domain" 2>/dev/null | awk '/ipv4/{split($4,a,"/");print a[1]}')
    if [[ -z "$ip" ]]; then
      log_err $ERR_SSH_FAILED "Could not resolve IP for $domain"
    fi
    local ssh_user
    ssh_user=$(registry_get_by_name "$domain" | awk -F, '{print $11}')
    if [[ -z "$ssh_user" ]]; then ssh_user="$VMSWARM_SSH_USER"; fi
    
    echo "--- SSH into $domain ($ip) ---"
    # error code 106
    ssh "${extra_args[@]}" "$ssh_user@$ip" || log_err $ERR_SSH_FAILED "SSH connection failed to $domain"
  done
}
