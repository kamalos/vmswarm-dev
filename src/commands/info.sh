#!/usr/bin/env bash
cmd_info() {
  local target=$1
  if [[ -z "$target" ]]; then log_err $ERR_MISSING_PARAM "Target required for info"; fi
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    echo "========================================"
    echo " VM: $domain"
    echo "========================================"
    virsh dominfo "$domain" || true
    echo "--- Interfaces ---"
    virsh domifaddr "$domain" || true
    echo "--- Block Devices ---"
    virsh domblklist "$domain" || true
    echo "--- vCPU Info ---"
    virsh vcpuinfo "$domain" || true
    echo ""
  done
}
