import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.suborno251.camera-guard"

  // enabled = guard is allowing the camera to work.
  // When the user flips this off, we actively kill anything that opens the camera.
  property bool enabled: true
  property bool cameraActive: false
  property string activeProcess: ""
  property var activeEntries: []

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.guard = root
  }

  function scriptPath(name) {
    return Qt.resolvedUrl(name).toString().replace("file://", "")
  }

  function setEnabled(val) {
    root.enabled = val
    stateWriter.command = [scriptPath("scripts/cam-state.sh"), "set-enabled", val ? "true" : "false"]
    stateWriter.running = true
  }

  function killPid(pid) {
    killProc.command = [scriptPath("scripts/cam-kill.sh"), String(pid)]
    killProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: stateReader
    running: false
    command: [root.scriptPath("scripts/cam-state.sh"), "get"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.enabled = data.enabled !== false
        } catch (e) { /* ignore malformed output */ }
      }
    }
  }

  Process {
    id: stateWriter
    running: false
  }

  Process {
    id: statusProc
    running: false
    command: [root.scriptPath("scripts/cam-status.sh")]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.cameraActive = data.active === true
          root.activeEntries = data.entries || []
          root.activeProcess = root.activeEntries.length > 0 ? root.activeEntries[0].process : ""
          // Guard mode: if the user has switched the camera off but something
          // just grabbed it anyway, kill it immediately.
          if (root.cameraActive && !root.enabled) {
            killProc.command = [root.scriptPath("scripts/cam-kill.sh")]
            killProc.running = true
          }
        } catch (e) { /* ignore malformed output */ }
      }
    }
  }

  Process {
    id: killProc
    running: false
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      stateReader.running = true
      statusProc.running = true
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.enabled
      ? (root.cameraActive ? "REC" : "CAM")
      : "OFF"
    labelVisible: true
    hasVisualContent: true
    opacity: root.enabled ? 1.0 : 0.5
    tooltipText: root.enabled
      ? (root.cameraActive ? "Camera ON - used by " + root.activeProcess : "Camera Guard: enabled")
      : "Camera Guard: disabled (blocked)"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
