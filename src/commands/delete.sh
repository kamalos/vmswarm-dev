#!/usr/bin/env bash
cmd_delete() {
  local target=$1
  if [[ -z "$target" ]]; then log_err $ERR_MISSING_PARAM "Target required for delete"; fi
  if [[ $EUID -ne 0 ]] && [[ ! $(groups) =~ libvirt ]]; then
    log_err $ERR_PERM_DENIED "delete requires root or libvirt group"
  fi
  local resolved
  resolved=$(resolve_target "$target")
  
  local cmds=()
  for domain in $resolved; do
    cmds+=("virsh destroy $domain 2>/dev/null || true; virsh undefine $domain --remove-all-storage 2>/dev/null || true")
  done
  
  execute_cmds "${cmds[@]}"
  
  for domain in $resolved; do
    registry_remove "$domain"
    log_info "Removed $domain from registry"
  done
}
