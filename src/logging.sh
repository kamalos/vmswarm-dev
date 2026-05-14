#!/usr/bin/env bash
# LOGGING SYSTEM
rotate_logs() {
  local log_file="$LOG_DIR/history.log"
  # Conditions, File ops, Compression
  if [[ -f "$log_file" ]]; then
    local size
    size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    if [[ $size -gt 10485760 ]]; then
      local i=1
      while [[ -f "$log_file.$i.gz" ]]; do
        ((i++))
      done
      gzip -c "$log_file" > "$log_file.$i.gz"
      > "$log_file"
    fi
  fi
}

log_info() {
  local msg="$*"
  local ts
  ts=$(date +%Y-%m-%d-%H-%M-%S)
  # Env vars
  local log_line="$ts : $USER : INFOS : $msg"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  echo "$log_line" | { tee -a "$LOG_DIR/history.log" 2>/dev/null || true; }
  rotate_logs
}

log_err() {
  local code=$1
  shift
  local msg="$*"
  local ts
  ts=$(date +%Y-%m-%d-%H-%M-%S)
  local log_line="$ts : $USER : ERROR : $msg"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  echo "$log_line" | { tee -a "$LOG_DIR/history.log" 2>/dev/null || true; } >&2
  echo "Exiting with code: $code" >&2
  show_help >&2
  exit "$code"
}
