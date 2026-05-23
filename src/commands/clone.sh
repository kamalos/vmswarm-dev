#!/usr/bin/env bash
cmd_clone() {
  local src=$1
  shift
  local name=""
  local tags=""
  local count="${NUM_VMS:-1}"
  local o_ram=""
  local o_cpu=""
  local o_network=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --tag|--tags) tags="$2"; shift 2 ;;
      --count|-n) count="$2"; shift 2 ;;
      --ram) o_ram="$2"; shift 2 ;;
      --cpu|--cpus) o_cpu="$2"; shift 2 ;;
      --network|--net) o_network="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to clone: $1" ;;
    esac
  done
  
  if [[ -z "$src" ]]; then log_err $ERR_MISSING_PARAM "Source VM required"; fi
  if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
  
  if ! virsh dominfo "$src" >/dev/null 2>&1; then
    log_err $ERR_CLONE_SRC_NOT_FOUND "Clone source $src not found"
  fi
  
  if [[ ! "$count" =~ ^[0-9]+$ || "$count" -lt 1 ]]; then
    log_err $ERR_MISSING_PARAM "Invalid clone count: $count"
  fi
  
  local cmds=()
  local i
  for (( i=1; i<=count; i++ )); do
    local clone_name="$name"
    if [[ $count -gt 1 ]]; then
      clone_name="${name}-${i}"
    fi
    
    if virsh dominfo "$clone_name" >/dev/null 2>&1; then
      log_err 116 "Guest name '$clone_name' is already in use by libvirt. Please delete it first or choose another name."
    fi
    
    cmds+=("virt-clone --original $src --name $clone_name --auto-clone")
  done
  
  execute_cmds "${cmds[@]}"
  
  local src_row
  src_row=$(registry_get_by_name "$src")
  
  for (( i=1; i<=count; i++ )); do
    local clone_name="$name"
    if [[ $count -gt 1 ]]; then
      clone_name="${name}-${i}"
    fi
    
    # Check if the clone was successfully created in libvirt
    if virsh dominfo "$clone_name" >/dev/null 2>&1; then
      local ram cpus disk os net ssh_user
      if [[ -z "$src_row" ]]; then
        ram="${o_ram:-$VMSWARM_DEFAULT_RAM}"
        cpus="${o_cpu:-$VMSWARM_DEFAULT_CPUS}"
        disk="$VMSWARM_DEFAULT_DISK"
        os="$VMSWARM_DEFAULT_OS"
        net="${o_network:-$VMSWARM_DEFAULT_NETWORK}"
        ssh_user="$VMSWARM_SSH_USER"
      else
        local s_ram s_cpus s_disk s_os s_net s_ssh_user
        s_ram=$(echo "$src_row" | awk -F, '{print $4}')
        s_cpus=$(echo "$src_row" | awk -F, '{print $5}')
        s_disk=$(echo "$src_row" | awk -F, '{print $6}')
        s_os=$(echo "$src_row" | awk -F, '{print $7}')
        s_net=$(echo "$src_row" | awk -F, '{print $8}')
        s_ssh_user=$(echo "$src_row" | awk -F, '{print $11}')
        
        ram="${o_ram:-$s_ram}"
        cpus="${o_cpu:-$s_cpus}"
        disk="$s_disk"
        os="$s_os"
        net="${o_network:-$s_net}"
        ssh_user="$s_ssh_user"
      fi
      
      # Apply customizations to VM in libvirt
      if [[ -n "$o_ram" ]]; then
        virsh setmaxmem "$clone_name" "${ram}M" --config >/dev/null 2>&1 || true
        virsh setmem "$clone_name" "${ram}M" --config >/dev/null 2>&1 || true
      fi
      
      if [[ -n "$o_cpu" ]]; then
        virsh setvcpus "$clone_name" "$cpus" --config --maximum >/dev/null 2>&1 || true
        virsh setvcpus "$clone_name" "$cpus" --config >/dev/null 2>&1 || true
      fi
      
      if [[ -n "$o_network" ]]; then
        local tmp_xml; tmp_xml=$(mktemp)
        virsh dumpxml "$clone_name" > "$tmp_xml" 2>/dev/null || true
        if grep -q "source network=" "$tmp_xml"; then
          sed -i "s/<source network='[^']*'\/>/<source network='$net'\/>/g" "$tmp_xml"
          sed -i "s/<source network=\"[^\"]*\"\/>/<source network=\"$net\"\/>/g" "$tmp_xml"
          virsh define "$tmp_xml" >/dev/null 2>&1 || true
        fi
        rm -f "$tmp_xml"
      fi
      
      local uuid; uuid=$(cat /proc/sys/kernel/random/uuid || echo "00000000-0000-0000-0000-000000000000")
      local ts; ts=$(date +%Y-%m-%d-%H-%M-%S)
      
      registry_add "$clone_name" "$uuid" "$ram" "$cpus" "$disk" "$os" "$net" "$tags" "$ts" "$ssh_user"
      log_info "Registered cloned VM $clone_name (RAM: ${ram}MB, CPUs: $cpus, Network: $net)"
    fi
  done
}
