#!/usr/bin/env bash
cmd_eject() {
  if [[ $# -eq 0 ]]; then
    log_err $ERR_MISSING_PARAM "Target required for eject"
  fi

  local target="$1"
  shift

  if [[ $EUID -ne 0 ]] && [[ ! $(groups) =~ libvirt ]]; then
    log_err $ERR_PERM_DENIED "eject requires root or libvirt group"
  fi

  local resolved
  resolved=$(resolve_target "$target")

  for domain in $resolved; do
    local state
    state=$(virsh domstate "$domain" 2>/dev/null | tr -d '\r')

    local cdrom_target
    cdrom_target=$(virsh domblklist "$domain" --details 2>/dev/null | awk '$2 == "cdrom" { print $3; exit }')
    if [[ -z "$cdrom_target" ]]; then
      cdrom_target=$(virsh dumpxml "$domain" | awk '
      /<disk / && /device=["\x27]cdrom["\x27]/ { in_cd=1 }
      in_cd && /<target dev=/ { print; exit }
      /<\/disk>/ { in_cd=0 }
      ' | sed -E "s/.*dev=['\"]([^'\"]+)['\"].*/\1/")
    fi
    if [[ -z "$cdrom_target" ]]; then
      log_info "No CD-ROM device found for $domain, skipping."
      continue
    fi

    log_info "Ejecting CD-ROM media from $domain ($cdrom_target)..."
    
    local success=0
    # Try both config and live if VM is running
    if [[ "$state" == "running" ]]; then
      if virsh change-media "$domain" "$cdrom_target" --eject --config --live >/dev/null 2>&1; then
        success=1
      fi
    fi
    
    if [[ $success -eq 0 ]]; then
      if virsh change-media "$domain" "$cdrom_target" --eject --config >/dev/null 2>&1; then
        success=1
      fi
    fi

    # Fallback to general change-media without config
    if [[ $success -eq 0 ]]; then
      if virsh change-media "$domain" "$cdrom_target" --eject >/dev/null 2>&1; then
        success=1
      fi
    fi

    if [[ $success -eq 1 ]]; then
      log_info "Successfully unplugged/ejected ISO from $domain"
    else
      log_err 116 "Failed to eject CD-ROM media from $domain"
    fi
  done
}
