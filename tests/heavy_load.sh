#!/usr/bin/env bash
echo "Starting heavy load..."
if command -v stress-ng >/dev/null 2>&1; then
    stress-ng --cpu 2 --timeout 30
else
    yes > /dev/null &
    PID=$!
    sleep 30
    kill $PID
fi
echo "Heavy load done."
