import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.suborno251.camera-guard"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var guard: null   // the BarWidget instance, injected by BarWidget.qml
  property var sites: []
  property var browserActive: []
  property string newSiteText: ""

  function open() { root.controller.show(); refreshSites() }
  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function scriptPath(name) {
    return Qt.resolvedUrl(name).toString().replace("file://", "")
  }

  function refreshSites() {
    sitesReader.command = [scriptPath("scripts/cam-state.sh"), "get"]
    sitesReader.running = true
  }

  function addSite(site, mode) {
    if (!site || site.length === 0) return
    siteWriter.command = [scriptPath("scripts/cam-state.sh"), "add-site", site, mode]
    siteWriter.running = true
  }

  function removeSite(site) {
    siteWriter.command = [scriptPath("scripts/cam-state.sh"), "remove-site", site]
    siteWriter.running = true
  }

  Process {
    id: sitesReader
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.sites = data.sites || []
          root.browserActive = data.browser_active || []
        } catch (e) { /* ignore */ }
      }
    }
  }

  Process {
    id: siteWriter
    running: false
    onExited: root.refreshSites()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // --- Header: status + on/off ---
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width - toggleBtn.width - Style.space(8)
            text: guard && guard.enabled
              ? (guard.cameraActive ? "Camera is ON — used by " + guard.activeProcess : "Camera Guard: enabled")
              : "Camera is OFF (blocked)"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Button {
            id: toggleBtn
            text: guard && guard.enabled ? "Turn Off" : "Turn On"
            onClicked: if (guard) guard.setEnabled(!guard.enabled)
          }
        }

        // --- List of processes currently holding the camera ---
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: guard && guard.activeEntries && guard.activeEntries.length > 0

          Text {
            text: "Currently using the camera:"
            color: root.barForeground
            font.pixelSize: Style.font.caption
            opacity: 0.7
          }

          Repeater {
            model: guard ? guard.activeEntries : []
            delegate: Row {
              width: content.width
              spacing: Style.space(8)
              Text {
                width: parent.width - stopBtn.width - Style.space(8)
                text: modelData.process + "  (pid " + modelData.pid + ", " + modelData.device + ")"
                color: root.barForeground
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
              Button {
                id: stopBtn
                text: "Stop"
                onClicked: if (guard) guard.killPid(modelData.pid)
              }
            }
          }
        }

        // --- Sites the browser extension has actually seen requesting the camera ---
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.sites && root.browserActive && root.browserActive.length > 0

          Text {
            text: "Browser tabs using the camera:"
            color: root.barForeground
            font.pixelSize: Style.font.caption
            opacity: 0.7
          }

          Repeater {
            model: root.browserActive
            delegate: Text {
              width: content.width
              text: "• " + modelData.hostname + "  (" + modelData.browser + ")"
              color: root.barForeground
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.barForeground; opacity: 0.15 }

        // --- Per-site list (enforced by the companion browser extension) ---
        Text {
          width: parent.width
          text: "Site rules"
          color: root.barForeground
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: "Configured here, but actually enforced inside the browser by the Camera Guard companion extension — this panel alone can't see individual tabs."
          color: root.barForeground
          font.pixelSize: Style.font.caption
          opacity: 0.7
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.sites
          delegate: Row {
            width: content.width
            spacing: Style.space(8)
            Text {
              width: parent.width - removeBtn.width - modeLabel.width - Style.space(16)
              text: modelData.site
              color: root.barForeground
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              id: modeLabel
              text: modelData.mode
              color: modelData.mode === "block" ? "#ff5555" : "#55cc88"
              font.pixelSize: Style.font.caption
            }
            Button {
              id: removeBtn
              text: "Remove"
              onClicked: root.removeSite(modelData.site)
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          TextField {
            id: siteInput
            width: parent.width - allowBtn.width - blockBtn.width - Style.space(12)
            placeholderText: "example.com"
          }
          Button {
            id: allowBtn
            text: "Allow"
            onClicked: { root.addSite(siteInput.text, "allow"); siteInput.text = "" }
          }
          Button {
            id: blockBtn
            text: "Block"
            onClicked: { root.addSite(siteInput.text, "block"); siteInput.text = "" }
          }
        }
      }
    }
  }
}
