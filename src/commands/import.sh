#!/usr/bin/env bash
cmd_import() {
  local file=""
  local new_name=""
  local tags=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      --name) new_name="$2"; shift 2 ;;
      --tag) tags="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
    esac
  done
  if [[ -z "$file" ]]; then log_err $ERR_MISSING_PARAM "--file required"; fi
  if [[ ! -f "$file" ]]; then log_err $ERR_FILE_NOT_FOUND "File not found: $file"; fi
  
  local tmp_dir
  tmp_dir=$(mktemp -d)
  tar -xzf "$file" -C "$tmp_dir" || log_err $ERR_ARCHIVE_CORRUPTED "Failed to extract archive"
  
  local xml_file
  xml_file=$(find "$tmp_dir" -name "*.xml" | head -n 1)
  local qcow2_file
  qcow2_file=$(find "$tmp_dir" -name "*.qcow2" | head -n 1)
  
  if [[ -z "$xml_file" ]] || [[ -z "$qcow2_file" ]]; then
    log_err $ERR_ARCHIVE_CORRUPTED "Archive missing xml or qcow2"
  fi
  
  local orig_name
  orig_name=$(basename "$xml_file" .xml)
  local target_name="${new_name:-$orig_name}"
  
  if [[ -n "$new_name" ]]; then
    sed -i "s/<name>$orig_name<\/name>/<name>$new_name<\/name>/" "$xml_file"
    sed -i "s|$VMSWARM_IMAGE_DIR/$orig_name.qcow2|$VMSWARM_IMAGE_DIR/$new_name.qcow2|g" "$xml_file"
  fi
  
  mv "$qcow2_file" "$VMSWARM_IMAGE_DIR/$target_name.qcow2"
  virsh define "$xml_file"
  
  local uuid; uuid=$(cat /proc/sys/kernel/random/uuid || echo "00000000-0000-0000-0000-000000000000")
  local ts; ts=$(date +%Y-%m-%d-%H-%M-%S)
  registry_add "$target_name" "$uuid" "$VMSWARM_DEFAULT_RAM" "$VMSWARM_DEFAULT_CPUS" "$VMSWARM_DEFAULT_DISK" "$VMSWARM_DEFAULT_OS" "$VMSWARM_DEFAULT_NETWORK" "$tags" "$ts" "$VMSWARM_SSH_USER"
  
  rm -rf "$tmp_dir"
  log_info "Imported VM as $target_name"
}
