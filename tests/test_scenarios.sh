#!/usr/bin/env bash
set -e

echo "Creating base image for testing..."
qemu-img create -f qcow2 base.qcow2 1G

echo "=== SCENARIO 1: Light load ==="
time (
  ./vmswarm -s create -n 2 --name light --import base.qcow2 --tag light
  ./vmswarm ps --tag light
  ./vmswarm -s run tag:light --script echo_test.sh
  ./vmswarm -s stop tag:light
)

echo "=== SCENARIO 2: Medium load ==="
time (
  ./vmswarm -n 5 create --name medium --import base.qcow2 --tag medium
  ./vmswarm -f start tag:medium
  ./vmswarm -f run tag:medium --script cpu_stress.sh
  ./vmswarm ps --tag medium
  ./vmswarm -f stop tag:medium
)

echo "=== SCENARIO 3: Heavy load ==="
time (
  ./vmswarm -n 10 create --name heavy --import base.qcow2 --tag heavy
  ./vmswarm -t start tag:heavy
  ./vmswarm -t run tag:heavy --script heavy_load.sh
  ./vmswarm -t snap take tag:heavy --name stress-snap
  ./vmswarm -t stop tag:heavy
  ./vmswarm logs --tail 100
)
