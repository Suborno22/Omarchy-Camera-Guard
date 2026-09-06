# Camera Guard (Omarchy Quattro plugin)

A bar icon that watches your webcam, tells you which app is using it, and
kills it with one click. Shows "CAM" when idle, "REC" (in red-ish/active
state per your theme) when something's actively using it, and dims to
"OFF" when you've switched the guard off.

## What this plugin can and can't see

- **Can:** detect that `/dev/video*` is open, which PID/process opened it
  (e.g. `firefox`, `chromium`, `zoom`), and kill that process.
- **Can't:** tell you *which browser tab or website* triggered it on its
  own — that's why `extension-chrome/` and `extension-firefox/` exist (see
  below). Together with `native-host/`, they close that gap: the panel's
  site list is now actually enforced inside the browser.

## Install

**Published:** install straight from GitHub in one step:

```sh
omarchy plugin add https://github.com/suborno251/camera-guard.git --enable
```

This clones the repo into `~/.config/omarchy/plugins/`, validates the
manifest, and enables it. If Omarchy asks which bar section to use, either
is fine — the manifest already defaults to `right`.

To pull a later update you've pushed to the repo:

```sh
omarchy plugin update io.github.suborno251.camera-guard
```

To remove it:

```sh
omarchy plugin disable io.github.suborno251.camera-guard
omarchy plugin remove io.github.suborno251.camera-guard
```

**Local development instead** (editing the code yourself, not installing a
release): copy the files in by hand rather than using `plugin add`, since
`plugin add` expects to manage its own git checkout.

```sh
mkdir -p ~/.config/omarchy/plugins/io.github.suborno251.camera-guard
cp -r manifest.json BarWidget.qml Panel.qml scripts \
  ~/.config/omarchy/plugins/io.github.suborno251.camera-guard/
chmod +x ~/.config/omarchy/plugins/io.github.suborno251.camera-guard/scripts/*.sh
omarchy-restart-shell
```

Then validate:

```sh
PLUGIN_DIR=~/.config/omarchy/plugins/io.github.suborno251.camera-guard
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

## How the kill-switch actually works

`scripts/cam-status.sh` polls every 2s for any process holding a
`/dev/video*` device (via `fuser`). If you've toggled the guard to "Off"
and something grabs the camera anyway, `scripts/cam-kill.sh` sends it
`SIGTERM`. On Chrome/Firefox this normally only kills the tab/renderer
process actually using the camera, not the whole browser — but it *can*
still crash the tab, so treat "Off" as a hard kill-switch, not a gentle
mute.

State (on/off + site list) is stored at
`~/.local/state/camera-guard/state.json`.

### Optional: a real hardware-level block

`fuser -k` only reacts after something opens the camera. If you want it to
be refused outright, you can instead revoke device permissions while
"Off" and restore them while "On":

```sh
sudo chmod 000 /dev/video0   # off
sudo chmod 660 /dev/video0   # on (adjust to your distro's default)
```

This needs passwordless `sudo`/a polkit rule for those two commands
specifically — I left it out of the scripts by default since granting
passwordless root for a device-permission change is a real security
tradeoff and I didn't want to make that call for you. Happy to wire it in
if you set up the polkit rule.

## Browser extension (site-level detection + blocking)

Two extension builds — `extension-chrome/` (Chrome, Brave, Edge, any
Chromium browser) and `extension-firefox/` (Firefox) — share the same
approach:

1. `inject.js` runs in the page's own JS world, before the page's scripts,
   and wraps `navigator.mediaDevices.getUserMedia`. Any request for video
   is paused and asked "should this be allowed?" instead of going straight
   to the camera.
2. `content.js` relays that question to `background.js`, which checks the
   site allow/block list. Denied requests get a real `NotAllowedError` —
   the page sees exactly what it'd see if you'd clicked "Block" in the
   browser's own permission prompt.
3. `background.js` also reports which hostname/tab/browser is actively
   using the camera to a **native messaging host**
   (`native-host/cam_guard_host.py`), which writes it into the *same*
   `~/.local/state/camera-guard/state.json` the Omarchy panel already
   reads and writes. That's how the panel's site editor and the browser
   end up sharing one source of truth without you syncing anything by
   hand.

### Setup

```sh
cd native-host
./install-chrome.sh    # Chrome / Brave / Chromium / Edge
./install-firefox.sh   # Firefox
```

`install-chrome.sh` generates a keypair so the unpacked extension gets a
**fixed** ID (Chrome normally assigns a random one every reload of an
unpacked extension, which would break the native-messaging allowlist) and
patches it into `extension-chrome/manifest.json` automatically.
`install-firefox.sh` doesn't need that step — Firefox lets an extension
pin its own ID via `browser_specific_settings.gecko.id`, already set in
`extension-firefox/manifest.json`.

Each script prints the exact next step (load-unpacked path for Chrome,
`about:debugging` for Firefox).

**Caveat on Firefox permanence:** `about:debugging` → "Load Temporary
Add-on" only lasts until Firefox restarts. A permanent install needs the
extension signed through Mozilla's add-on signing service, even for
something you only run yourself — worth doing once you're happy with it,
skippable while testing.

**Caveat on the native messaging wire format:** the length-prefixed JSON
protocol in `cam_guard_host.py` matches Chrome/Firefox's documented
native-messaging spec, but — same as the QML above — I haven't been able
to run an actual browser against it here to confirm end-to-end. If
`chrome.runtime.connectNative` fails silently, check
`chrome://extensions` → your extension → "service worker" console for
connection errors first; that's almost always a mismatched extension ID
in the host manifest's `allowed_origins`/`allowed_extensions`.

## Notes on the QML

Confirmed working on real Quickshell/Omarchy — with one gotcha worth
recording: `WidgetButton` needs `labelVisible: true` and
`hasVisualContent: true` explicitly set, or it renders nothing at all
regardless of what `text` contains. Found by diffing against the real
`omarchy.clock` widget's source (`omarchy plugin clone omarchy.clock
--edit`) — worth doing that for any future widget that renders blank
despite `validate`/`qmllint` passing clean, since neither of those checks
catches a missing runtime-only property like this one.