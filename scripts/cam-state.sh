#!/bin/bash
# Tiny state store for Camera Guard.
# cam-state.sh get              -> prints current state as JSON
# cam-state.sh set-enabled true|false
# cam-state.sh add-site example.com allow|block
# cam-state.sh remove-site example.com

STATE_DIR="$HOME/.local/state/camera-guard"
STATE_FILE="$STATE_DIR/state.json"
mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
  echo '{"enabled":true,"sites":[]}' > "$STATE_FILE"
fi

cmd="$1"

read_state() { cat "$STATE_FILE"; }

case "$cmd" in
  get)
    read_state
    ;;
  set-enabled)
    val="$2"
    python3 - "$STATE_FILE" "$val" <<'PY'
import json, sys
path, val = sys.argv[1], sys.argv[2] == "true"
with open(path) as f:
    data = json.load(f)
data["enabled"] = val
with open(path, "w") as f:
    json.dump(data, f)
print(json.dumps(data))
PY
    ;;
  add-site)
    site="$2"
    mode="${3:-block}"
    python3 - "$STATE_FILE" "$site" "$mode" <<'PY'
import json, sys
path, site, mode = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
data["sites"] = [s for s in data.get("sites", []) if s["site"] != site]
data["sites"].append({"site": site, "mode": mode})
with open(path, "w") as f:
    json.dump(data, f)
print(json.dumps(data))
PY
    ;;
  remove-site)
    site="$2"
    python3 - "$STATE_FILE" "$site" <<'PY'
import json, sys
path, site = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data["sites"] = [s for s in data.get("sites", []) if s["site"] != site]
with open(path, "w") as f:
    json.dump(data, f)
print(json.dumps(data))
PY
    ;;
  *)
    echo "usage: cam-state.sh get|set-enabled|add-site|remove-site" >&2
    exit 1
    ;;
esac
