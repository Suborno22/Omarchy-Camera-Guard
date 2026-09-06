#!/bin/bash
# Run once, from the native-host/ directory:
#   ./install-chrome.sh
#
# Generates a keypair so the unpacked extension gets a fixed ID (otherwise
# Chrome assigns a new random ID every reload, which breaks native
# messaging's allowed_origins allowlist). Patches extension-chrome/manifest.json
# in place, then registers the native host for whichever of
# Chrome / Chromium / Brave / Edge are installed.

set -euo pipefail
cd "$(dirname "$0")"

EXT_DIR="../extension-chrome"
HOST_NAME="io.github.suborno251.camera_guard"
HOST_SCRIPT="$(pwd)/cam_guard_host.py"
chmod +x "$HOST_SCRIPT"

echo "Generating a stable extension key..."
openssl genrsa 2048 2>/dev/null > /tmp/camguard-key.pem
openssl rsa -in /tmp/camguard-key.pem -pubout -outform DER -out /tmp/camguard-pub.der 2>/dev/null
PUB_KEY_B64=$(openssl base64 -A -in /tmp/camguard-pub.der)
EXT_ID=$(python3 compute_ext_id.py /tmp/camguard-pub.der)
rm -f /tmp/camguard-key.pem /tmp/camguard-pub.der

echo "Extension ID will be: $EXT_ID"

python3 - "$EXT_DIR/manifest.json" "$PUB_KEY_B64" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data["key"] = key
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

cat > /tmp/camguard-host-manifest.json <<EOF
{
  "name": "$HOST_NAME",
  "description": "Camera Guard native messaging host",
  "path": "$HOST_SCRIPT",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
EOF

targets=(
  "$HOME/.config/google-chrome/NativeMessagingHosts"
  "$HOME/.config/chromium/NativeMessagingHosts"
  "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  "$HOME/.config/microsoft-edge/NativeMessagingHosts"
)

installed_any=false
for dir in "${targets[@]}"; do
  base_dir="$(dirname "$(dirname "$dir")")"
  if [ -d "$base_dir" ]; then
    mkdir -p "$dir"
    cp /tmp/camguard-host-manifest.json "$dir/$HOST_NAME.json"
    echo "Registered native host in $dir"
    installed_any=true
  fi
done
rm -f /tmp/camguard-host-manifest.json

if [ "$installed_any" = false ]; then
  echo "No Chrome-family config dir found. Manually copy the manifest to your"
  echo "browser's NativeMessagingHosts directory as $HOST_NAME.json."
fi

echo
echo "Next steps:"
echo "1. Open chrome://extensions (or brave://extensions, edge://extensions)"
echo "2. Enable Developer Mode, click 'Load unpacked', select: $(cd "$EXT_DIR" && pwd)"
echo "3. Confirm the loaded extension's ID matches: $EXT_ID"
echo "   (it will, since the key is now pinned in manifest.json)"
