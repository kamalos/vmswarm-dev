#!/usr/bin/env bash
cmd_snap() {
  local action=$1
  shift
  local target=$1
  shift
  
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown option: $1" ;;
    esac
  done
  
  local resolved
  resolved=$(resolve_target "$target")
  local cmds=()
  
  for domain in $resolved; do
    case "$action" in
      take)
        if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
        cmds+=("virsh snapshot-create-as $domain $name")
        ;;
      list)
        cmds+=("virsh snapshot-list $domain")
        ;;
      restore)
        if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
        cmds+=("virsh snapshot-revert $domain $name")
        ;;
      delete)
        if [[ -z "$name" ]]; then log_err $ERR_MISSING_PARAM "--name required"; fi
        cmds+=("virsh snapshot-delete $domain $name")
        ;;
      *) log_err $ERR_UNKNOWN_OPT "Unknown snap action: $action" ;;
    esac
  done
  
  execute_cmds "${cmds[@]}"
}
