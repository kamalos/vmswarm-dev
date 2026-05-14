#!/usr/bin/env bash
cmd_install() {
  if [[ $# -eq 0 ]]; then
    log_err $ERR_MISSING_PARAM "Target required for install"
  fi

  local target="$1"
  shift
  local iso_override=""
  local install_hostname=""
  local install_username="user"
  local install_password=""

  if [[ -f "$SRC_DIR/installer.sh" ]]; then
    source "$SRC_DIR/installer.sh"
  else
    log_err $ERR_SCRIPT_NOT_FOUND "Installer module not found at $SRC_DIR/installer.sh"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso) iso_override="$2"; shift 2 ;;
      --hostname) install_hostname="$2"; shift 2 ;;
      --username) install_username="$2"; shift 2 ;;
      --password) install_password="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to install: $1" ;;
    esac
  done

  if [[ -z "$install_password" ]]; then
    while true; do
      local password_first=""
      local password_second=""
      read -s -p "Enter password for unattended install: " password_first
      echo ""
      read -s -p "Re-type password for unattended install: " password_second
      echo ""
      if [[ -z "$password_first" ]]; then
        echo "Error: Password cannot be empty."
        continue
      fi
      if [[ "$password_first" == "$password_second" ]]; then
        install_password="$password_first"
        break
      fi
      echo "Error: Passwords do not match. Please try again."
    done
  fi

  local resolved
  resolved=$(resolve_target "$target")

  for domain in $resolved; do
    local state
    state=$(virsh domstate "$domain" 2>/dev/null | tr -d '\r')
    if [[ "$state" == "running" ]]; then
      log_err 116 "VM '$domain' is running. Stop it before unattended install."
    fi

    local iso_path="$iso_override"
    if [[ -z "$iso_path" ]]; then
      iso_path=$(virsh dumpxml "$domain" | awk '
        /<disk / && /device=["\x27]cdrom["\x27]/ { in_cd=1 }
        in_cd && /<source file=/ { print; exit }
        /<\/disk>/ { in_cd=0 }
      ' | sed -E "s/.*file=['\"]([^'\"]+)['\"].*/\1/")
    fi

    if [[ -z "$iso_path" ]] || [[ ! -f "$iso_path" ]]; then
      log_err $ERR_FILE_NOT_FOUND "Could not find an ISO for $domain. Provide --iso /path/to/linuxmint.iso"
    fi

    local host_for_domain
    host_for_domain="${install_hostname:-$domain}"

    local preseed_file
    local preseed_iso
    local base_iso_name
    preseed_file=$(get_preseed_path "$domain")
    base_iso_name=$(basename "$iso_path" .iso)
    preseed_iso="${VMSWARM_IMAGE_DIR}/${base_iso_name}-${domain}-preseed.iso"

    log_info "Generating preseed file for $domain..."
    generate_preseed "$host_for_domain" "$install_username" "$install_password" "$preseed_file"
    log_info "Injecting preseed into ISO for unattended installation..."
    inject_preseed_into_iso "$iso_path" "$preseed_file" "$preseed_iso"

    local cdrom_target
    cdrom_target=$(virsh dumpxml "$domain" | awk '
      /<disk / && /device=["\x27]cdrom["\x27]/ { in_cd=1 }
      in_cd && /<target dev=/ { print; exit }
      /<\/disk>/ { in_cd=0 }
    ' | sed -E "s/.*dev=['\"]([^'\"]+)['\"].*/\1/")
    if [[ -z "$cdrom_target" ]]; then
      cdrom_target="hdb"
    fi

    virsh change-media "$domain" "$cdrom_target" --config --insert "$preseed_iso" >/dev/null 2>&1 || \
      virsh attach-disk "$domain" "$preseed_iso" "$cdrom_target" --type cdrom --mode readonly --config >/dev/null

    virsh start "$domain" >/dev/null || log_err 116 "Failed to start VM '$domain' for unattended install"
    log_info "Started unattended installation for $domain (no GUI)."
  done
}
