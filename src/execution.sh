#!/usr/bin/env bash
# PARALLEL EXECUTION WRAPPER
execute_cmds() {
  local cmds=("$@")
  if [[ ${#cmds[@]} -eq 0 ]]; then
    return
  fi
  
  if [[ "$EXEC_MODE" == "seq" ]]; then
    # Loops
    for cmd in "${cmds[@]}"; do
      if [[ $VERBOSE -eq 1 ]]; then echo "[SEQ] Executing: $cmd"; fi
      eval "$cmd"
    done
  elif [[ "$EXEC_MODE" == "subshell" ]]; then
    # Subshell execution
    for cmd in "${cmds[@]}"; do
      if [[ $VERBOSE -eq 1 ]]; then echo "[SUBSHELL] Spawning: $cmd"; fi
      ( bash -c "$cmd" )
    done
  elif [[ "$EXEC_MODE" == "fork" ]]; then
    # Fork execution
    local bin_path="$(dirname "${BASH_SOURCE[0]}")/../../bin/vmswarm_fork"
    [[ -x "/usr/local/lib/vmswarm/vmswarm_fork" ]] && bin_path="/usr/local/lib/vmswarm/vmswarm_fork"
    if [[ ! -x "$bin_path" ]]; then
      bin_path="$(dirname "${BASH_SOURCE[0]}")/../bin/vmswarm_fork"
    fi
    if [[ ! -x "$bin_path" ]]; then
      log_err $ERR_BIN_MISSING "vmswarm_fork binary missing. Run make."
    fi
    "$bin_path" "${cmds[@]}"
  elif [[ "$EXEC_MODE" == "thread" ]]; then
    # Thread execution
    local bin_path="$(dirname "${BASH_SOURCE[0]}")/../../bin/vmswarm_thread"
    [[ -x "/usr/local/lib/vmswarm/vmswarm_thread" ]] && bin_path="/usr/local/lib/vmswarm/vmswarm_thread"
    if [[ ! -x "$bin_path" ]]; then
      bin_path="$(dirname "${BASH_SOURCE[0]}")/../bin/vmswarm_thread"
    fi
    if [[ ! -x "$bin_path" ]]; then
      log_err $ERR_BIN_MISSING "vmswarm_thread binary missing. Run make."
    fi
    "$bin_path" "${cmds[@]}"
  fi
}

run_parallel() {
  local virsh_cmd=$1
  shift
  if [[ $# -eq 0 ]]; then
    log_err $ERR_MISSING_PARAM "Target required for $virsh_cmd"
  fi
  local target=$1
  local resolved
  resolved=$(resolve_target "$target")
  
  local cmds=()
  for domain in $resolved; do
    cmds+=("virsh $virsh_cmd $domain")
  done
  
  execute_cmds "${cmds[@]}"
}
