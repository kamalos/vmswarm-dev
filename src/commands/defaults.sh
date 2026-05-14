#!/usr/bin/env bash
restore_defaults() {
  if [[ $EUID -ne 0 ]]; then
    log_err $ERR_PERM_DENIED "Restoring defaults requires root."
  fi
  rm -rf /etc/vmswarm
  mkdir -p /etc/vmswarm
  exit 0
}
