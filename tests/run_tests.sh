#!/usr/bin/env bash
set -euo pipefail

# Print banner
echo "================================================="
echo "        Running VMSwarm Duplication Tests        "
echo "================================================="

# Ensure mock executables are executable
chmod +x tests/mocks/qemu-img tests/mocks/virt-install tests/mocks/virt-clone tests/mocks/virsh tests/mocks/virt-manager tests/mocks/lsmod tests/mocks/systemctl

# Create fake installation files so file checks succeed
touch tests/mocks/ubuntu-22.04.iso
touch tests/mocks/mysql-template.qcow2

# Setup fake config and registry to run cleanly in /tmp/vmswarm-test
export CONFIG_DIR="/tmp/vmswarm-test"
export CONFIG_FILE="${CONFIG_DIR}/config"
export REGISTRY_FILE="${CONFIG_DIR}/registry.csv"

rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

# Prepend mocks to PATH
export PATH="$(pwd)/tests/mocks:$PATH"

# Run help command first to ensure basic boot is OK
./vmswarm -h > /dev/null

echo -e "\n--- Scenario 1: CLI Batch Duplicate Creation (-n 2) ---"
# We simulate auto-install and yes answers using echo
echo "y" | ./vmswarm create -n 2 --name test-cli --iso tests/mocks/ubuntu-22.04.iso --ram 1024

echo -e "\n--- Scenario 2: Config-driven Duplicate & Custom Creation (vms.conf) ---"
echo "y" | ./vmswarm create --config tests/vms.conf

echo -e "\n--- Scenario 3: Batch Duplicate Cloning with Custom Configuration Overrides ---"
./vmswarm clone web-1 --name web-clone --count 2 --ram 4096 --network override-net --tag "cloned,test"

echo -e "\n--- Scenario 4: Target Resolution for Duplicates ---"
echo "Testing resolve_target for base name 'web-clone'..."
# Source utils and registry to call resolve_target directly in bash
source src/constants.sh
source src/logging.sh
source src/utils.sh
source src/config.sh
source src/registry.sh
load_config

resolved=$(resolve_target "web-clone")
echo "Resolved 'web-clone' to: $resolved"

echo -e "\n--- Verification: Checking Registry Entries ---"
echo "Registry contents:"
cat "$REGISTRY_FILE"

echo -e "\n--- Assertions ---"
failed=0

# Helper to verify a field in registry
assert_field() {
  local vm_name=$1
  local field_idx=$2
  local expected=$3
  local row
  row=$(grep "^[0-9]*,$vm_name," "$REGISTRY_FILE" || true)
  if [[ -z "$row" ]]; then
    echo "FAIL: VM $vm_name not registered!"
    failed=1
    return
  fi
  local val
  val=$(echo "$row" | awk -F, -v idx="$field_idx" '{print $idx}')
  # Remove quotes if tags
  val=$(echo "$val" | tr -d '"')
  if [[ "$val" != "$expected" ]]; then
    echo "FAIL: VM $vm_name field $field_idx is '$val', expected '$expected'"
    failed=1
  else
    echo "PASS: VM $vm_name field $field_idx is correct ('$expected')"
  fi
}

# Assert CLI duplicates
assert_field "test-cli-1" 2 "test-cli-1"
assert_field "test-cli-1" 4 "1024"
assert_field "test-cli-2" 2 "test-cli-2"
assert_field "test-cli-2" 4 "1024"

# Assert Config duplicates with personalized settings
assert_field "web-1" 2 "web-1"
assert_field "web-1" 4 "2048"
assert_field "web-1" 5 "2"
assert_field "web-1" 8 "default"
assert_field "web-1" 9 "web,prod"

assert_field "web-2" 2 "web-2"
assert_field "web-2" 4 "2048"
assert_field "web-2" 8 "default"

assert_field "db-1" 2 "db-1"
assert_field "db-1" 4 "4096"
assert_field "db-1" 5 "4"
assert_field "db-1" 8 "private"
assert_field "db-1" 9 "db,prod"

# Assert Clone duplicates with overrides
assert_field "web-clone-1" 2 "web-clone-1"
assert_field "web-clone-1" 4 "4096" # Overridden RAM
assert_field "web-clone-1" 8 "override-net" # Overridden Network
assert_field "web-clone-1" 9 "cloned,test" # Overridden tags

assert_field "web-clone-2" 2 "web-clone-2"
assert_field "web-clone-2" 4 "4096" # Overridden RAM
assert_field "web-clone-2" 8 "override-net" # Overridden Network

# Assert Target Resolution
if [[ "$resolved" == "web-clone-1 web-clone-2" ]]; then
  echo "PASS: Base target resolution works correctly"
else
  echo "FAIL: Resolved target is '$resolved', expected 'web-clone-1 web-clone-2'"
  failed=1
fi

if [[ $failed -eq 0 ]]; then
  echo -e "\n================================================="
  echo "         ALL TESTS PASSED SUCCESSFULLY!          "
  echo "================================================="
  exit 0
else
  echo -e "\n================================================="
  echo "             SOME TESTS FAILED!                  "
  echo "================================================="
  exit 1
fi
