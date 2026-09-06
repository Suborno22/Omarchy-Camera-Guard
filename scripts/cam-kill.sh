#!/bin/bash
# Usage: cam-kill.sh [pid]
# With no args: kills every process currently holding any /dev/video* device.
# With a pid: kills just that one (used when the panel's per-process "Stop" is clicked).

if [ -n "$1" ]; then
  kill -TERM "$1" 2>/dev/null
  exit 0
fi

for dev in /dev/video*; do
  [ -e "$dev" ] || continue
  fuser -k -TERM "$dev" 2>/dev/null
done
