#!/usr/bin/env bash
cmd_clone() {
  local src=$1
  shift
  local name=""
  local tags=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --tag) tags="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to clone: $1" ;;
    esac
  done
  
  if [[ -z "$src" ]]; then log_err $ERR_MISSING_PARAM "Source VM required"; fi
  if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
  
  if ! virsh dominfo "$src" >/dev/null 2>&1; then
    log_err $ERR_CLONE_SRC_NOT_FOUND "Clone source $src not found"
  fi
  
  execute_cmds "virt-clone --original $src --name $name --auto-clone"
  
  local src_row
  src_row=$(registry_get_by_name "$src")
  if [[ -z "$src_row" ]]; then
    local uuid; uuid=$(cat /proc/sys/kernel/random/uuid || echo "00000000-0000-0000-0000-000000000000")
    local ts; ts=$(date +%Y-%m-%d-%H-%M-%S)
    registry_add "$name" "$uuid" "$VMSWARM_DEFAULT_RAM" "$VMSWARM_DEFAULT_CPUS" "$VMSWARM_DEFAULT_DISK" "$VMSWARM_DEFAULT_OS" "$VMSWARM_DEFAULT_NETWORK" "$tags" "$ts" "$VMSWARM_SSH_USER"
  else
    local ram cpus disk os net ssh_user
    ram=$(echo "$src_row" | awk -F, '{print $4}')
    cpus=$(echo "$src_row" | awk -F, '{print $5}')
    disk=$(echo "$src_row" | awk -F, '{print $6}')
    os=$(echo "$src_row" | awk -F, '{print $7}')
    net=$(echo "$src_row" | awk -F, '{print $8}')
    ssh_user=$(echo "$src_row" | awk -F, '{print $11}')
    local uuid; uuid=$(cat /proc/sys/kernel/random/uuid || echo "00000000-0000-0000-0000-000000000000")
    local ts; ts=$(date +%Y-%m-%d-%H-%M-%S)
    registry_add "$name" "$uuid" "$ram" "$cpus" "$disk" "$os" "$net" "$tags" "$ts" "$ssh_user"
  fi
  log_info "Registered cloned VM $name"
}
