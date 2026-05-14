#!/usr/bin/env bash
cmd_ps() {
  local show_all=0
  local tag_filter=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) show_all=1; shift ;;
      --tag) tag_filter="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option to ps: $1" ;;
    esac
  done
  
  printf "%-5s %-15s %-10s %-10s %-5s %-20s %-15s\n" "ID" "NAME" "STATE" "RAM(MB)" "CPUs" "TAGS" "IP"
  printf "%-5s %-15s %-10s %-10s %-5s %-20s %-15s\n" "──" "──────────" "───────" "───────" "────" "─────────" "──────────────"
  
  tail -n +2 "$REGISTRY_FILE" | while IFS=, read -r id name uuid ram cpus disk os net tags created ssh_user; do
    tags=$(echo "$tags" | tr -d '"')
    
    if [[ -n "$tag_filter" ]]; then
      if [[ ! "$tags" =~ (^|,)($tag_filter)(,|$) ]]; then
        continue
      fi
    fi
    
    local state="missing"
    local ip="-"

    state=$(virsh domstate "$name" 2>/dev/null | tr -d '\r' || true)
    if [[ -z "$state" ]]; then
      state="missing"
    fi

    if [[ "$state" == "running" ]]; then
      # Pipes/filters
      ip=$(virsh domifaddr "$name" 2>/dev/null | awk '/ipv4/{split($4,a,"/");print a[1]}' || echo "-")
      if [[ -z "$ip" ]]; then ip="-"; fi
    fi

    if [[ "$state" == "missing" && $show_all -ne 1 ]]; then
      continue
    fi

    printf "%-5s %-15s %-10s %-10s %-5s %-20s %-15s\n" "$id" "$name" "$state" "$ram" "$cpus" "$tags" "$ip"
  done
}
