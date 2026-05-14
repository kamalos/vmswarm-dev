#!/usr/bin/env bash
cmd_run() {
  if [[ $# -eq 0 ]]; then
    log_err $ERR_MISSING_PARAM "Target required for run"
  fi

  local target=$1
  shift
  local script_file=""
  local args=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --script) script_file="$2"; shift 2 ;;
      --args) args="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to run: $1" ;;
    esac
  done
  
  local resolved
  resolved=$(resolve_target "$target")

  # Start VM(s) headlessly when no script is provided.
  if [[ -z "$script_file" ]]; then
    local cmds=()
    for domain in $resolved; do
      local state
      state=$(virsh domstate "$domain" 2>/dev/null | tr -d '\r')
      if [[ "$state" == "running" ]]; then
        log_info "VM $domain is already running"
        continue
      fi
      cmds+=("virsh start $domain")
    done
    execute_cmds "${cmds[@]}"
    return 0
  fi

  if [[ ! -f "$script_file" ]]; then log_err $ERR_SCRIPT_NOT_FOUND "Script not found: $script_file"; fi
  
  local cmds=()
  for domain in $resolved; do
    local ip
    ip=$(virsh domifaddr "$domain" 2>/dev/null | awk '/ipv4/{split($4,a,"/");print a[1]}')
    if [[ -z "$ip" ]]; then
      log_info "Could not resolve IP for $domain, skipping."
      continue
    fi
    local ssh_user
    ssh_user=$(registry_get_by_name "$domain" | awk -F, '{print $11}')
    if [[ -z "$ssh_user" ]]; then ssh_user="$VMSWARM_SSH_USER"; fi
    
    local r_cmd="scp -q $(realpath "$script_file") $ssh_user@$ip:/tmp/vmswarm_run.sh && ssh -q $ssh_user@$ip \"bash /tmp/vmswarm_run.sh $args\" | awk -v prefix=\"[$domain]: \" '{print prefix \$0}'"
    cmds+=("$r_cmd")
  done
  
  execute_cmds "${cmds[@]}"
}
