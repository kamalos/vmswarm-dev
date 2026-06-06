#!/usr/bin/env bash
cmd_ssh() {
  if [[ $# -eq 0 ]]; then log_err $ERR_MISSING_PARAM "Target required for ssh"; fi
  local target=$1
  shift
  
  local ssh_user_override=""
  local extra_args=()
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) ssh_user_override="$2"; shift 2 ;;
      --) shift; extra_args=("$@"); break ;;
      -*) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
      *) break ;;
    esac
  done
  
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    local ip
    ip=$(virsh domifaddr "$domain" 2>/dev/null | awk '/ipv4/{split($4,a,"/");print a[1]}')
    if [[ -z "$ip" ]]; then
      log_err $ERR_SSH_FAILED "Could not resolve IP for $domain"
    fi
    local ssh_user="$ssh_user_override"
    if [[ -z "$ssh_user" ]]; then
      ssh_user=$(registry_get_by_name "$domain" | awk -F, '{print $11}')
    fi
    if [[ -z "$ssh_user" ]]; then ssh_user="$VMSWARM_SSH_USER"; fi
    
    echo "--- SSH into $domain ($ip) ---"
    # error code 106
    ssh "${extra_args[@]}" "$ssh_user@$ip" || log_err $ERR_SSH_FAILED "SSH connection failed to $domain"
  done
}
