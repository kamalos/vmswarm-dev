#!/usr/bin/env bash

create_vm_instance() {
  local name="$1"
  local ram="$2"
  local cpu="$3"
  local disk="$4"
  local os="$5"
  local network="$6"
  local tags="$7"
  local iso="$8"
  local import_qcow2="$9"
  
  # Resolve defaults
  ram="${ram:-$VMSWARM_DEFAULT_RAM}"
  cpu="${cpu:-$VMSWARM_DEFAULT_CPUS}"
  disk="${disk:-$VMSWARM_DEFAULT_DISK}"
  os="${os:-$VMSWARM_DEFAULT_OS}"
  network="${network:-$VMSWARM_DEFAULT_NETWORK}"
  
  if [[ -z "$name" ]]; then
    log_err $ERR_MISSING_PARAM "VM name is missing"
  fi
  
  if [[ -z "$iso" && -z "$import_qcow2" ]]; then
    log_err $ERR_MISSING_PARAM "VM $name requires either ISO or Import path"
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

  local disk_size="$disk"
  if [[ ! "$disk_size" =~ [KkMmGgTt]$ ]]; then
    disk_size="${disk_size}G"
  fi

  if virsh dominfo "$name" >/dev/null 2>&1; then
    log_err 116 "Guest name '$name' is already in use by libvirt. Please delete it first or choose another name."
  fi
  
  local img_path="$VMSWARM_IMAGE_DIR/${name}.qcow2"
  local xml_tmp
  local xml_raw_tmp
  xml_tmp=$(mktemp "/tmp/vmswarm-${name}.XXXXXX.xml")
  xml_raw_tmp=$(mktemp "/tmp/vmswarm-${name}.XXXXXX.raw")
  
  if [[ -n "$import_qcow2" ]]; then
    qemu-img create -b "$(realpath "$import_qcow2")" -F qcow2 -f qcow2 "$img_path" >/dev/null
    virt-install --name "$name" --ram "$ram" --vcpus "$cpu" \
      --disk "$img_path",format=qcow2 --import --os-variant "$os" \
      --network "network=$network" --noautoconsole --check disk_size=off \
      --print-xml > "$xml_raw_tmp" || log_err 105 "Failed to generate VM definition for $name"
  elif [[ -n "$iso" ]]; then
    qemu-img create -f qcow2 "$img_path" "$disk_size" >/dev/null
    virt-install --name "$name" --ram "$ram" --vcpus "$cpu" \
      --disk "$img_path",format=qcow2 --cdrom "$(realpath "$iso")" --os-variant "$os" \
      --network "network=$network" --noautoconsole --check disk_size=off \
      --boot hd,cdrom --print-xml > "$xml_raw_tmp" || log_err 105 "Failed to generate VM definition for $name"
  fi

  # Keep only the first domain XML block in case virt-install prints extra content.
  awk '
    /<domain[[:space:]][^>]*>/ { if (!inside) inside=1 }
    inside { print }
    /<\/domain>/ { if (inside) exit }
  ' "$xml_raw_tmp" > "$xml_tmp"
  rm -f "$xml_raw_tmp"

  if ! grep -q '</domain>' "$xml_tmp"; then
    rm -f "$xml_tmp"
    log_err 105 "Failed to parse VM definition XML for $name"
  fi

  virsh define "$xml_tmp" >/dev/null || {
    rm -f "$xml_tmp"
    log_err 105 "Failed to define VM $name"
  }
  rm -f "$xml_tmp"
  
  local ts
  ts=$(date +%Y-%m-%d-%H-%M-%S)
  local uuid
  if [[ -e /proc/sys/kernel/random/uuid ]]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
  else
    uuid="00000000-0000-0000-0000-000000000000"
  fi
  registry_add "$name" "$uuid" "$ram" "$cpu" "$disk" "$os" "$network" "$tags" "$ts" "$VMSWARM_SSH_USER"
  log_info "Created and defined VM $name (state: stopped)"
}

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
  local config_file=""
  local auto_install=0
  
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
      --config|--conf|-c) config_file="$2"; shift 2 ;;
      --auto-install) auto_install=1; shift ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to create: $1" ;;
    esac
  done

  if [[ $auto_install -eq 1 ]]; then
    log_info "Create now only defines VM(s) without starting. Use 'vmswarm install <vm>' for unattended install."
  fi
  
  if [[ -n "$config_file" ]]; then
    if [[ ! -f "$config_file" ]]; then
      log_err $ERR_FILE_NOT_FOUND "Configuration file not found: $config_file"
    fi
    log_info "Creating VMs from configuration file: $config_file"
    
    while read -r line || [[ -n "$line" ]]; do
      # Strip leading/trailing whitespace
      line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      # Skip comments and empty lines
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      
      local l_name="" l_ram="" l_cpu="" l_disk="" l_iso="" l_import="" l_network="" l_tags="" l_os=""
      local remaining="$line"
      
      while [[ -n "$remaining" ]]; do
        if [[ "$remaining" =~ ^[[:space:]]*([a-zA-Z0-9_]+)=\"([^\"]*)\"(.*)$ ]]; then
          local key="${BASH_REMATCH[1]}"
          local val="${BASH_REMATCH[2]}"
          remaining="${BASH_REMATCH[3]}"
        elif [[ "$remaining" =~ ^[[:space:]]*([a-zA-Z0-9_]+)=\'([^\']*)\'(.*)$ ]]; then
          local key="${BASH_REMATCH[1]}"
          local val="${BASH_REMATCH[2]}"
          remaining="${BASH_REMATCH[3]}"
        elif [[ "$remaining" =~ ^[[:space:]]*([a-zA-Z0-9_]+)=([^[:space:]]+)(.*)$ ]]; then
          local key="${BASH_REMATCH[1]}"
          local val="${BASH_REMATCH[2]}"
          remaining="${BASH_REMATCH[3]}"
        else
          remaining="${remaining#?}"
          continue
        fi
        
        case "$key" in
          name) l_name="$val" ;;
          ram) l_ram="$val" ;;
          cpu|cpus) l_cpu="$val" ;;
          disk) l_disk="$val" ;;
          iso) l_iso="$val" ;;
          import|path) l_import="$val" ;;
          network|net) l_network="$val" ;;
          tag|tags) l_tags="$val" ;;
          os) l_os="$val" ;;
        esac
      done
      
      local final_name="${l_name:-$name}"
      local final_ram="${l_ram:-$ram}"
      local final_cpu="${l_cpu:-$cpu}"
      local final_disk="${l_disk:-$disk}"
      local final_iso="${l_iso:-$iso}"
      local final_import="${l_import:-$import_qcow2}"
      local final_network="${l_network:-$network}"
      local final_tags="${l_tags:-$tags}"
      local final_os="${l_os:-$os}"
      
      if [[ -z "$final_name" ]]; then
        log_info "Skipping line (missing name): $line"
        continue
      fi
      
      create_vm_instance "$final_name" "$final_ram" "$final_cpu" "$final_disk" "$final_os" "$final_network" "$final_tags" "$final_iso" "$final_import"
    done < "$config_file"
    
  else
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
    
    local i
    for (( i=1; i<=NUM_VMS; i++ )); do
      local vm_name="$name"
      if [[ $NUM_VMS -gt 1 ]]; then
        vm_name="${name}-${i}"
      fi
      create_vm_instance "$vm_name" "$ram" "$cpu" "$disk" "$os" "$network" "$tags" "$iso" "$import_qcow2"
    done
  fi
}
