#!/usr/bin/env bash
cmd_logs() {
  local tail_n=20
  local grep_pat=""
  local vm_filter=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tail) tail_n="$2"; shift 2 ;;
      --grep) grep_pat="$2"; shift 2 ;;
      --vm) vm_filter="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
    esac
  done
  
  local filter_cmd="cat"
  if [[ -n "$grep_pat" ]]; then filter_cmd="grep -E \"$grep_pat\""; fi
  
  local filter_cmd2="cat"
  if [[ -n "$vm_filter" ]]; then filter_cmd2="grep -E \"$vm_filter\""; fi
  
  if [[ -f "$LOG_DIR/history.log" ]]; then
    eval "$filter_cmd < \"$LOG_DIR/history.log\" | $filter_cmd2 | tail -n \"$tail_n\""
  else
    echo "Log file not found."
  fi
}
