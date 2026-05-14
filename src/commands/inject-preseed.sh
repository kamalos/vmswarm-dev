#!/usr/bin/env bash
# Preseed Injection Command - Injects preseed files into Linux Mint ISO for unattended installation

cmd_inject-preseed() {
  local vm_name=""
  local iso_path=""
  local preseed_file=""
  local output_iso=""
  
  # Source installer module
  if [[ -f "$SRC_DIR/installer.sh" ]]; then
    source "$SRC_DIR/installer.sh"
  else
    log_err $ERR_SCRIPT_NOT_FOUND "Installer module not found"
  fi
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --vm) vm_name="$2"; shift 2 ;;
      --iso) iso_path="$2"; shift 2 ;;
      --preseed) preseed_file="$2"; shift 2 ;;
      --output) output_iso="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
    esac
  done
  
  # Validate inputs
  if [[ -z "$iso_path" ]] || [[ ! -f "$iso_path" ]]; then
    log_err $ERR_FILE_NOT_FOUND "ISO file not found or not specified: $iso_path"
  fi
  
  # If preseed file not provided, try to find it for the VM
  if [[ -z "$preseed_file" ]]; then
    if [[ -n "$vm_name" ]]; then
      preseed_file=$(get_preseed_path "$vm_name")
      if [[ ! -f "$preseed_file" ]]; then
        log_err $ERR_FILE_NOT_FOUND "Preseed file not found for VM $vm_name. Run 'vmswarm create --auto-install' first."
      fi
    else
      log_err $ERR_MISSING_PARAM "Either --vm or --preseed must be specified"
    fi
  fi
  
  if [[ ! -f "$preseed_file" ]]; then
    log_err $ERR_FILE_NOT_FOUND "Preseed file not found: $preseed_file"
  fi
  
  # Set output ISO path
  if [[ -z "$output_iso" ]]; then
    local base_name
    base_name=$(basename "$iso_path" .iso)
    output_iso="${VMSWARM_IMAGE_DIR}/${base_name}-preseed.iso"
  fi
  
  # Check for required tools
  if ! command -v xorriso >/dev/null 2>&1; then
    log_info "Installing xorriso for ISO modification..."
    sudo apt update >/dev/null 2>&1
    sudo apt install -y xorriso >/dev/null 2>&1
  fi
  
  log_info "Injecting preseed file into ISO..."
  log_info "Source ISO: $iso_path"
  log_info "Preseed file: $preseed_file"
  log_info "Output ISO: $output_iso"
  
  local work_dir="/tmp/vmswarm_iso_inject_$$"
  mkdir -p "$work_dir"
  
  # Extract ISO
  log_info "Extracting ISO contents..."
  if ! xorriso -osirrox on -indev "$iso_path" -extract / "$work_dir" 2>/dev/null; then
    rm -rf "$work_dir"
    log_err 105 "Failed to extract ISO. Ensure the ISO file is valid."
  fi
  
  # Copy preseed file to ISO root
  cp "$preseed_file" "$work_dir/preseed.cfg"
  log_info "Preseed file injected into ISO"
  
  # Rebuild ISO
  log_info "Rebuilding ISO with preseed file..."
  
  # Check for BIOS boot configuration
  local boot_options=""
  if [[ -f "$work_dir/isolinux/isolinux.bin" ]]; then
    boot_options="-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table"
  elif [[ -f "$work_dir/EFI/BOOT/BOOTX64.EFI" ]]; then
    boot_options="-efi-boot EFI/BOOT/BOOTX64.EFI -no-emul-boot"
  fi
  
  if ! xorriso -as mkisofs -r -V "Linux Mint Auto" \
    $boot_options \
    -o "$output_iso" "$work_dir" 2>/dev/null; then
    rm -rf "$work_dir"
    log_err 105 "Failed to rebuild ISO with preseed"
  fi
  
  # Cleanup
  rm -rf "$work_dir"
  
  if [[ -f "$output_iso" ]]; then
    log_info "Modified ISO successfully created: $output_iso"
    echo ""
    echo "============================================"
    echo "Preseed ISO Ready"
    echo "============================================"
    echo "Modified ISO: $output_iso"
    echo ""
    echo "To use this ISO for unattended installation:"
    echo "1. Create a new VM with the modified ISO:"
    echo "   vmswarm create --name my-vm --iso $output_iso"
    echo ""
    echo "2. The VM will automatically boot with preseed"
    echo "3. Installation will proceed automatically"
    echo "============================================"
  else
    log_err 105 "Failed to create modified ISO"
  fi
}
