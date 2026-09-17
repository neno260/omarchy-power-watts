import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Live power consumption bar widget. Reads the JSON published by the
// omarchy-power-monitor system service (/run/omarchy-power/watts.json)
// and repaints whenever the file is rewritten.
BarWidget {
  id: root
  moduleName: "neno.power-watts"

  property real watts: 0
  property var components: ({})

  readonly property string wattsPath: "/run/omarchy-power/watts.json"

  function applyState(raw) {
    try {
      if (typeof raw !== "string" || raw.length === 0 || raw.length > 4096) return
      var state = JSON.parse(raw)
      if (state === null) return
      if (typeof state.watts === "number" && isFinite(state.watts)) {
        root.watts = Math.max(0, state.watts)
      }
      if (typeof state.components === "object" && state.components !== null) {
        root.components = state.components
      }
    } catch (error) {
      // malformed or partial write; keep last good state
    }
  }

  function titleCase(value) {
    var s = String(value || "")
    return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s
  }

  function tooltipText() {
    var lines = ["Total power draw", ""]
    for (var key in root.components) {
      var w = Number(root.components[key])
      if (isFinite(w) && w >= 0) {
        lines.push(root.titleCase(key) + ": " + w.toFixed(1) + " W")
      }
    }
    lines.push("")
    lines.push(root.watts.toFixed(1) + " W total")
    return lines.join("\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: root.wattsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyState(text())
    onFileChanged: reload()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipText()
    text: "\uf0e7 " + root.watts.toFixed(1) + "W"
    onPressed: function(button) {
      // informational widget; nothing to open
    }
  }
}