#!/usr/bin/env bash
# ERROR CODES
readonly ERR_UNKNOWN_OPT=100
readonly ERR_MISSING_PARAM=101
readonly ERR_VM_NOT_FOUND=102
readonly ERR_TOOL_MISSING=103
readonly ERR_PERM_DENIED=104
readonly ERR_FILE_NOT_FOUND=105
readonly ERR_SSH_FAILED=106
readonly ERR_SCRIPT_NOT_FOUND=107
readonly ERR_TAG_NOT_FOUND=108
readonly ERR_SNAP_NOT_FOUND=109
readonly ERR_BIN_MISSING=110
readonly ERR_KVM_NOT_LOADED=111
readonly ERR_LIBVIRTD_NOT_RUNNING=112
readonly ERR_NET_EXISTS=113
readonly ERR_CLONE_SRC_NOT_FOUND=114
readonly ERR_ARCHIVE_CORRUPTED=115

# Global defaults
EXEC_MODE="seq" # seq, subshell, fork, thread
NUM_VMS=1
VERBOSE=0
LOG_DIR="/var/log/vmswarm"

# Config files
CONFIG_DIR="/etc/vmswarm"
CONFIG_FILE="${CONFIG_DIR}/config"
REGISTRY_FILE="${CONFIG_DIR}/registry.csv"
