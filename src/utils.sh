#!/usr/bin/env bash
# HELP TEXT
show_help() {
  cat << 'EOF'
NAME
  vmswarm — KVM/libvirt VM orchestration framework

SYNOPSIS
  vmswarm [OPTIONS] COMMAND [ARGS]

DESCRIPTION
  VMSwarm is a bash-first CLI tool to spin up, manage, and
  orchestrate multiple KVM virtual machines.

IMPORTANT OPTIONS
  -n <count>   Number of VMs for batch create
  -h           Show this short help message

IMPORTANT COMMANDS
  create      Provision a new KVM VM (from ISO or qcow2 import)
  start       Start VM(s)
  stop        Graceful shutdown of VM(s)
  ps          List VMs with state, RAM, CPUs, tags, IP

For full documentation and all commands/options, see the man page:
  man vmswarm
EOF
}

# ENVIRONMENT & PREREQUISITE CHECK
check_prerequisites() {
  local missing=()
  command -v virsh >/dev/null 2>&1 || missing+=("libvirt-clients (virsh)")
  command -v virt-install >/dev/null 2>&1 || missing+=("virtinst (virt-install)")
  command -v virt-manager >/dev/null 2>&1 || missing+=("virt-manager")
  command -v qemu-img >/dev/null 2>&1 || missing+=("qemu-utils (qemu-img)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing required dependencies: ${missing[*]}"
    read -p "Do you want to install the required packages now? [Y/n]: " install_deps
    if [[ -z "$install_deps" || "$install_deps" == "y" || "$install_deps" == "Y" ]]; then
      echo "Installing missing packages (${missing[*]})..."
      sudo apt update >/dev/null 2>&1
      sudo apt install -y qemu-kvm libvirt-daemon-system virtinst virt-manager qemu-utils >/dev/null 2>&1
      echo "Installation complete."
    else
      log_err $ERR_TOOL_MISSING "Required tools (${missing[*]}) are missing."
    fi
  fi

  if [[ ! -e /dev/kvm ]] && ! lsmod | grep -q kvm; then
    log_err $ERR_KVM_NOT_LOADED "KVM kernel module not loaded (or /dev/kvm missing)"
  fi

  if ! systemctl is-active --quiet libvirtd; then
    read -p "libvirtd service is not active. Do you want to start and enable it now? [Y/n]: " start_libvirtd
    if [[ -z "$start_libvirtd" || "$start_libvirtd" == "y" || "$start_libvirtd" == "Y" ]]; then
      sudo systemctl enable --now libvirtd
    else
      log_err $ERR_LIBVIRTD_NOT_RUNNING "libvirtd is not active"
    fi
  fi

  if [[ $EUID -ne 0 ]] && ! groups | grep -q '\blibvirt\b'; then
    read -p "User is not in the libvirt group. Do you want to add $USER to the libvirt group? [Y/n]: " add_group
    if [[ -z "$add_group" || "$add_group" == "y" || "$add_group" == "Y" ]]; then
      sudo usermod -aG libvirt $USER
      echo "Added $USER to libvirt group. Note: You may need to log out and log back in (or run 'newgrp libvirt') for this to take effect."
    else
      log_err $ERR_PERM_DENIED "User is not root and not in libvirt group"
    fi
  fi
}

# TARGET RESOLUTION
resolve_target() {
  local target=$1
  local resolved=""
  
  if [[ "$target" == "all" ]]; then
    resolved=$(awk -F, 'NR>1 {print $2}' "$REGISTRY_FILE" | tr '\n' ' ')
  elif [[ "$target" =~ ^tag:(.+)$ ]]; then
    local t=${BASH_REMATCH[1]}
    resolved=$(registry_get_by_tag "$t" | awk -F, '{print $2}' | tr '\n' ' ')
  elif [[ "$target" =~ ^id:(.+)$ ]]; then
    local ids
    IFS=',' read -ra id_arr <<< "${BASH_REMATCH[1]}"
    for id in "${id_arr[@]}"; do
      local name
      name=$(registry_get_by_id "$id" | awk -F, '{print $2}')
      if [[ -n "$name" ]]; then
        resolved="$resolved $name"
      fi
    done
  elif [[ "$target" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    # Regex
    local start=${BASH_REMATCH[1]}
    local end=${BASH_REMATCH[2]}
    for (( i=start; i<=end; i++ )); do
      local name
      name=$(registry_get_by_id "$i" | awk -F, '{print $2}')
      if [[ -n "$name" ]]; then
        resolved="$resolved $name"
      fi
    done
  elif [[ "$target" =~ ^[0-9]+$ ]]; then
    local name
    name=$(registry_get_by_id "$target" | awk -F, '{print $2}')
    if [[ -n "$name" ]]; then
      resolved="$name"
    fi
  else
    local name
    name=$(registry_get_by_name "$target" | awk -F, '{print $2}')
    if [[ -n "$name" ]]; then
      resolved="$name"
    fi
  fi
  
  resolved=$(echo "$resolved" | xargs)
  if [[ -z "$resolved" ]]; then
    log_err $ERR_VM_NOT_FOUND "No VMs matched target: $target"
  fi
  echo "$resolved"
}
