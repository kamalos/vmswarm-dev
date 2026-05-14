#!/usr/bin/env bash
# CONFIG
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  else
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    if [[ -w "$CONFIG_DIR" ]]; then
      cat << EOF > "$CONFIG_FILE"
VMSWARM_LOG_DIR=/var/log/vmswarm
VMSWARM_IMAGE_DIR=/var/lib/vmswarm/images
VMSWARM_SSH_USER=ubuntu
VMSWARM_DEFAULT_RAM=1024
VMSWARM_DEFAULT_CPUS=1
VMSWARM_DEFAULT_DISK=10
VMSWARM_DEFAULT_NETWORK=default
VMSWARM_DEFAULT_OS=generic
EOF
      # shellcheck disable=SC1090
      source "$CONFIG_FILE"
    else
      VMSWARM_LOG_DIR="/tmp/vmswarm/log"
      VMSWARM_IMAGE_DIR="/tmp/vmswarm/images"
      VMSWARM_SSH_USER="ubuntu"
      VMSWARM_DEFAULT_RAM=1024
      VMSWARM_DEFAULT_CPUS=1
      VMSWARM_DEFAULT_DISK=10
      VMSWARM_DEFAULT_NETWORK="default"
      VMSWARM_DEFAULT_OS="generic"
    fi
  fi
  
  if [[ -n "${OPT_LOG_DIR:-}" ]]; then
    LOG_DIR="$OPT_LOG_DIR"
  else
    LOG_DIR="$VMSWARM_LOG_DIR"
  fi
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  mkdir -p "$VMSWARM_IMAGE_DIR" 2>/dev/null || true
  
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    if [[ -w "$CONFIG_DIR" ]]; then
      echo "ID,NAME,UUID,RAM,CPUS,DISK_GB,OS_VARIANT,NETWORK,TAGS,CREATED_AT,SSH_USER" > "$REGISTRY_FILE"
    else
      REGISTRY_FILE="/tmp/vmswarm/registry.csv"
      mkdir -p "/tmp/vmswarm" 2>/dev/null || true
      echo "ID,NAME,UUID,RAM,CPUS,DISK_GB,OS_VARIANT,NETWORK,TAGS,CREATED_AT,SSH_USER" > "$REGISTRY_FILE"
    fi
  fi
}
