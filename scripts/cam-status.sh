#!/bin/bash
# Reports which processes currently hold any /dev/video* device open.
# Output: {"active":true,"entries":[{"device":"/dev/video0","pid":1234,"process":"firefox"}]}
# No dependency on jq — built by hand so it works on a bare Omarchy install.

entries=()
for dev in /dev/video*; do
  [ -e "$dev" ] || continue
  pids=$(fuser "$dev" 2>/dev/null)
  for pid in $pids; do
    pid="${pid//[!0-9]/}"
    [ -z "$pid" ] && continue
    name=$(ps -p "$pid" -o comm= 2>/dev/null)
    [ -z "$name" ] && continue
    entries+=("{\"device\":\"$dev\",\"pid\":$pid,\"process\":\"$name\"}")
  done
done

if [ "${#entries[@]}" -eq 0 ]; then
  echo '{"active":false,"entries":[]}'
else
  joined=$(IFS=,; echo "${entries[*]}")
  echo "{\"active\":true,\"entries\":[$joined]}"
fi
