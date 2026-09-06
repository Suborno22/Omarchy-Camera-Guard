#!/usr/bin/env python3
"""
Native messaging host for the Camera Guard browser extension.

Talks stdio native-messaging protocol to the extension's background script,
and reads/writes the same ~/.local/state/camera-guard/state.json that the
Omarchy plugin's scripts/cam-state.sh uses — this is the shared source of
truth between "site rules edited in the bar panel" and "camera events seen
inside the browser".
"""
import sys
import json
import struct
import os
import time

STATE_DIR = os.path.expanduser("~/.local/state/camera-guard")
STATE_FILE = os.path.join(STATE_DIR, "state.json")


def load_state():
    os.makedirs(STATE_DIR, exist_ok=True)
    if not os.path.exists(STATE_FILE):
        data = {"enabled": True, "sites": [], "browser_active": []}
        save_state(data)
        return data
    try:
        with open(STATE_FILE) as f:
            data = json.load(f)
    except Exception:
        data = {}
    data.setdefault("enabled", True)
    data.setdefault("sites", [])
    data.setdefault("browser_active", [])
    return data


def save_state(data):
    with open(STATE_FILE, "w") as f:
        json.dump(data, f)


def read_message():
    raw_len = sys.stdin.buffer.read(4)
    if len(raw_len) == 0:
        return None
    msg_len = struct.unpack("<I", raw_len)[0]
    raw = sys.stdin.buffer.read(msg_len)
    return json.loads(raw.decode("utf-8"))


def send_message(msg):
    encoded = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def handle(msg):
    data = load_state()
    mtype = msg.get("type")

    if mtype == "get_sites":
        send_message({"type": "sites", "sites": data.get("sites", [])})

    elif mtype == "camera_active":
        active = [a for a in data.get("browser_active", []) if a.get("tabId") != msg.get("tabId")]
        active.append(
            {
                "tabId": msg.get("tabId"),
                "url": msg.get("url"),
                "hostname": msg.get("hostname"),
                "browser": msg.get("browser"),
                "since": time.time(),
            }
        )
        data["browser_active"] = active
        save_state(data)

    elif mtype == "camera_inactive":
        data["browser_active"] = [
            a for a in data.get("browser_active", []) if a.get("tabId") != msg.get("tabId")
        ]
        save_state(data)


def main():
    while True:
        try:
            msg = read_message()
        except Exception:
            break
        if msg is None:
            break
        try:
            handle(msg)
        except Exception as e:
            sys.stderr.write(f"camera-guard host error: {e}\n")


if __name__ == "__main__":
    main()
