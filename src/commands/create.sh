#!/usr/bin/env bash
cmd_create() {
  local name=""
  local iso=""
  local import_qcow2=""
  local ram=""
  local cpu=""
  local disk=""
  local os=""
  local network=""
  local tags=""
  local auto_install=0
  local install_hostname=""
  local install_username=""
  local install_password=""
  
  # Source the installer module
  if [[ -f "$SRC_DIR/installer.sh" ]]; then
    source "$SRC_DIR/installer.sh"
  else
    log_err $ERR_SCRIPT_NOT_FOUND "Installer module not found at $SRC_DIR/installer.sh"
  fi
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --iso) iso="$2"; shift 2 ;;
      --import) import_qcow2="$2"; shift 2 ;;
      --ram) ram="$2"; shift 2 ;;
      --cpu) cpu="$2"; shift 2 ;;
      --disk) disk="$2"; shift 2 ;;
      --os) os="$2"; shift 2 ;;
      --network) network="$2"; shift 2 ;;
      --tag) tags="$2"; shift 2 ;;
      --auto-install) auto_install=1; shift ;;
      --hostname) install_hostname="$2"; shift 2 ;;
      --username) install_username="$2"; shift 2 ;;
      --password) install_password="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to create: $1" ;;
    esac
  done
  
  if [[ -z "$name" ]]; then
    read -p "Enter VM name: " name
    if [[ -z "$name" ]]; then
      log_err $ERR_MISSING_PARAM "Missing mandatory parameter --name"
    fi
  fi
  
  if [[ -z "$ram" ]]; then
    read -p "Enter RAM (default $VMSWARM_DEFAULT_RAM): " input_ram
    ram="${input_ram:-$VMSWARM_DEFAULT_RAM}"
  fi
  
  if [[ -z "$cpu" ]]; then
    read -p "Enter CPUs (default $VMSWARM_DEFAULT_CPUS): " input_cpu
    cpu="${input_cpu:-$VMSWARM_DEFAULT_CPUS}"
  fi
  
  if [[ -z "$disk" ]]; then
    read -p "Enter Disk size (default $VMSWARM_DEFAULT_DISK): " input_disk
    disk="${input_disk:-$VMSWARM_DEFAULT_DISK}"
  fi
  
  if [[ -z "$os" ]]; then
    read -p "Enter OS variant (default $VMSWARM_DEFAULT_OS): " input_os
    os="${input_os:-$VMSWARM_DEFAULT_OS}"
  fi
  
  if [[ -z "$network" ]]; then
    read -p "Enter Network [e.g. default (NAT), bridge0] (default $VMSWARM_DEFAULT_NETWORK): " input_net
    network="${input_net:-$VMSWARM_DEFAULT_NETWORK}"
  fi
  
  if [[ -z "$iso" && -z "$import_qcow2" ]]; then
    read -p "Select install method [iso/import] (default iso): " method_choice
    case "${method_choice,,}" in
      import)
        while true; do
          read -e -p "Enter path to qcow2 image: " import_qcow2
          if [[ -f "$import_qcow2" ]]; then break; fi
          echo "Error: File not found or empty path. Please enter a valid path."
        done
        ;;
      *)
        while true; do
          read -e -p "Enter path to ISO file: " iso
          if [[ -f "$iso" ]]; then break; fi
          echo "Error: File not found or empty path. Please enter a valid path."
        done
        ;;
    esac
  fi
  
  if [[ -n "$iso" ]] && [[ ! -f "$iso" ]]; then
    log_err $ERR_FILE_NOT_FOUND "ISO file not found: $iso"
  fi
  if [[ -n "$import_qcow2" ]] && [[ ! -f "$import_qcow2" ]]; then
    log_err $ERR_FILE_NOT_FOUND "Import file not found: $import_qcow2"
  fi
  
  if id -u libvirt-qemu >/dev/null 2>&1; then
    if [[ -n "$iso" ]] && ! sudo -u libvirt-qemu test -r "$iso" 2>/dev/null; then
      echo "WARNING: The ISO file '$iso' is not readable by the 'libvirt-qemu' user (common with shared folders)."
      read -p "Do you want to copy it to $VMSWARM_IMAGE_DIR to fix this? [Y/n]: " do_copy
      if [[ -z "$do_copy" || "$do_copy" == "y" || "$do_copy" == "Y" ]]; then
        local dest="$VMSWARM_IMAGE_DIR/$(basename "$iso")"
        echo "Copying ISO..."
        cp "$iso" "$dest"
        chmod 644 "$dest"
        iso="$dest"
      fi
    fi
    if [[ -n "$import_qcow2" ]] && ! sudo -u libvirt-qemu test -r "$import_qcow2" 2>/dev/null; then
      echo "WARNING: The image file '$import_qcow2' is not readable by the 'libvirt-qemu' user."
      read -p "Do you want to copy it to $VMSWARM_IMAGE_DIR to fix this? [Y/n]: " do_copy
      if [[ -z "$do_copy" || "$do_copy" == "y" || "$do_copy" == "Y" ]]; then
        local dest="$VMSWARM_IMAGE_DIR/$(basename "$import_qcow2")"
        echo "Copying image..."
        cp "$import_qcow2" "$dest"
        chmod 644 "$dest"
        import_qcow2="$dest"
      fi
    fi
  fi
  
  local cmds=()
  local i
  for (( i=1; i<=NUM_VMS; i++ )); do
    local vm_name="$name"
    if [[ $NUM_VMS -gt 1 ]]; then
      vm_name="${name}-${i}"
    fi
    
    if virsh dominfo "$vm_name" >/dev/null 2>&1; then
      log_err 116 "Guest name '$vm_name' is already in use by libvirt. Please delete it first or choose another name."
    fi
    
    local img_path="$VMSWARM_IMAGE_DIR/${vm_name}.qcow2"
    local v_cmd=""
    
    if [[ -n "$import_qcow2" ]]; then
      v_cmd="qemu-img create -b $(realpath "$import_qcow2") -F qcow2 -f qcow2 $img_path && virt-install --name $vm_name --ram $ram --vcpus $cpu --disk $img_path,format=qcow2 --import --os-variant $os --network network=$network --noautoconsole --check disk_size=off"
    elif [[ -n "$iso" ]]; then
      v_cmd="virt-install --name $vm_name --ram $ram --vcpus $cpu --disk size=$disk,format=qcow2 --cdrom $(realpath "$iso") --os-variant $os --network network=$network --noautoconsole --check disk_size=off"

    else
      v_cmd="virt-install --name $vm_name --ram $ram --vcpus $cpu --disk size=$disk,format=qcow2 --import --os-variant $os --network network=$network --noautoconsole --check disk_size=off"
    fi
    
    cmds+=("$v_cmd")
    
    local ts
    ts=$(date +%Y-%m-%d-%H-%M-%S)
    local uuid
    if [[ -e /proc/sys/kernel/random/uuid ]]; then
      uuid=$(cat /proc/sys/kernel/random/uuid)
    else
      uuid="00000000-0000-0000-0000-000000000000"
    fi
    registry_add "$vm_name" "$uuid" "$ram" "$cpu" "$disk" "$os" "$network" "$tags" "$ts" "$VMSWARM_SSH_USER"
    log_info "Registered VM $vm_name in registry"
  done
  
  execute_cmds "${cmds[@]}"
  
  # Handle auto-install workflow
  if [[ $auto_install -eq 1 ]] || [[ -z "$auto_install" ]]; then
    # Only ask about auto-install if using ISO installation
    if [[ -n "$iso" ]]; then
      # If auto-install flag not explicitly set, ask user
      if [[ $auto_install -ne 1 ]]; then
        if ! prompt_install_type; then
          log_info "Manual installation selected. VM is ready for interactive setup."
          return 0
        fi
      fi
      
      # Gather credentials if not provided via command line
      if [[ -z "$install_hostname" ]] || [[ -z "$install_username" ]] || [[ -z "$install_password" ]]; then
        prompt_install_credentials
        install_hostname="${INSTALL_HOSTNAME}"
        install_username="${INSTALL_USERNAME}"
        install_password="${INSTALL_PASSWORD}"
      fi
      
      # Process auto-install for each VM
      for (( i=1; i<=NUM_VMS; i++ )); do
        local vm_name="$name"
        if [[ $NUM_VMS -gt 1 ]]; then
          vm_name="${name}-${i}"
        fi
        
        local preseed_file
        preseed_file=$(get_preseed_path "$vm_name")
        
        # Generate preseed file
        log_info "Generating preseed file for $vm_name..."
        generate_preseed "$install_hostname${i:-}" "$install_username" "$install_password" "$preseed_file"
        
        # Note: For true unattended installation with preseed, you would need to:
        # 1. Inject preseed file into ISO (if modifying the ISO)
        # 2. Boot with preseed file on kernel command line
        # For now, we provide the preseed file and instructions
        log_info "Preseed file created at: $preseed_file"
        echo ""
        echo "============================================"
        echo "Auto-Install Configuration for $vm_name"
        echo "============================================"
        echo "Hostname: $install_hostname${i:-}"
        echo "Username: $install_username"
        echo "Preseed file: $preseed_file"
        echo ""
        echo "To use preseed for unattended installation:"
        echo "1. Boot the VM with the ISO"
        echo "2. At the boot menu, press TAB to edit boot options"
        echo "3. Add: preseed/file=/cdrom/preseed.cfg"
        echo ""
        echo "Or use this command to inject preseed into ISO:"
        echo "  sudo vmswarm inject-preseed --vm $vm_name --iso $(realpath "$iso")"
        echo "============================================"
        echo ""
      done
      
      log_info "Auto-install setup complete. VMs are ready for preseed-based installation."
    else
      log_info "Auto-install is only available for ISO-based installations."
    fi
  fi
}
