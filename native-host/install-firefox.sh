#!/bin/bash
# Run once, from the native-host/ directory:
#   ./install-firefox.sh
#
# Firefox lets an extension pin its own ID via manifest.json's
# browser_specific_settings.gecko.id (already set to
# "camera-guard@suborno251.github.io" in extension-firefox/manifest.json),
# so — unlike Chrome — no key generation is needed here.

set -euo pipefail
cd "$(dirname "$0")"

HOST_NAME="io.github.suborno251.camera_guard"
HOST_SCRIPT="$(pwd)/cam_guard_host.py"
EXT_ID="camera-guard@suborno251.github.io"
chmod +x "$HOST_SCRIPT"

cat > /tmp/camguard-host-manifest.json <<EOF
{
  "name": "$HOST_NAME",
  "description": "Camera Guard native messaging host",
  "path": "$HOST_SCRIPT",
  "type": "stdio",
  "allowed_extensions": ["$EXT_ID"]
}
EOF

mkdir -p "$HOME/.mozilla/native-messaging-hosts"
cp /tmp/camguard-host-manifest.json "$HOME/.mozilla/native-messaging-hosts/$HOST_NAME.json"
rm -f /tmp/camguard-host-manifest.json

echo "Registered native host in ~/.mozilla/native-messaging-hosts/$HOST_NAME.json"
echo
echo "Next steps:"
echo "1. Open about:debugging#/runtime/this-firefox"
echo "2. Click 'Load Temporary Add-on...', select:"
echo "   $(cd ../extension-firefox && pwd)/manifest.json"
echo
echo "Note: a temporary add-on is unloaded when Firefox restarts. For a"
echo "permanent install you'd need to sign the extension through Mozilla's"
echo "add-on signing (required even for self-distributed .xpi files) —"
echo "fine to skip while you're just testing this yourself."
