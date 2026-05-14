#!/usr/bin/env bash
echo "Starting CPU stress..."
dd if=/dev/urandom | gzip > /dev/null &
PID=$!
sleep 10
kill $PID
echo "CPU stress done."
