#!/usr/bin/env bash
cmd_export() {
  local target=$1
  shift
  local out_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) out_dir="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
    esac
  done
  
  if [[ -z "$out_dir" ]]; then log_err $ERR_MISSING_PARAM "--out required"; fi
  # File ops, Search/archive
  mkdir -p "$out_dir"
  local resolved
  resolved=$(resolve_target "$target")
  
  for domain in $resolved; do
    log_info "Exporting $domain to $out_dir"
    if virsh list | grep -q " $domain "; then
      virsh destroy "$domain" || true
    fi
    virsh dumpxml "$domain" > "$out_dir/$domain.xml"
    local qcow2_path="$VMSWARM_IMAGE_DIR/$domain.qcow2"
    if [[ -f "$qcow2_path" ]]; then
      cp "$qcow2_path" "$out_dir/"
    fi
    tar -czf "$out_dir/$domain.vmswarm.tar.gz" -C "$out_dir" "$domain.xml" "$domain.qcow2"
    rm -f "$out_dir/$domain.xml" "$out_dir/$domain.qcow2"
    log_info "Exported $domain successfully"
  done
}
