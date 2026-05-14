#!/usr/bin/env bash
cmd_delete() {
  local target=$1
  if [[ -z "$target" ]]; then log_err $ERR_MISSING_PARAM "Target required for delete"; fi
  if [[ $EUID -ne 0 ]] && [[ ! $(groups) =~ libvirt ]]; then
    log_err $ERR_PERM_DENIED "delete requires root or libvirt group"
  fi
  local resolved
  resolved=$(resolve_target "$target")
  
  read -p "Are you sure you want to permanently delete these VMs: $resolved? [y/N]: " confirm_del
  if [[ ! "$confirm_del" =~ ^[Yy]$ ]]; then
    echo "Deletion cancelled."
    return 0
  fi
  
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
