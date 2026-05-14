#!/usr/bin/env bash
cmd_gui() {
  if [[ $# -eq 0 ]]; then log_err $ERR_MISSING_PARAM "Target required for gui"; fi
  local target=$1
  shift
  
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    echo "Opening virt-manager console for $domain..."
    # Discard output to avoid cluttering the terminal, and run in background
    virt-manager --connect qemu:///system --show-domain-console "$domain" >/dev/null 2>&1 &
  done
}
