import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "devsecai.tablet"

  readonly property string command: Quickshell.env("HOME") + "/.local/bin/tablet-mode"
  property bool tablet: false

  // tablet-mode writes "on" or "off" here whenever the mode changes.
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/tablet-mode/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.tablet = text().trim() === "on"
  }

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row
    anchors.fill: parent

    BarIconButton {
      visible: root.tablet
      bar: root.bar
      text: "󰋜"
      tooltipText: "Home"
      onPressed: function(b) { root.bar.run(root.command + " home") }
    }

    // In tablet mode the Control Center has the switch back to desktop.
    BarIconButton {
      visible: !root.tablet
      bar: root.bar
      text: root.tablet ? "󰓶" : "󰌢"
      active: root.tablet
      tooltipText: root.tablet ? "Tablet mode (tap for desktop)" : "Desktop mode (tap for tablet)"
      onPressed: function(b) { root.bar.run(root.command + " toggle") }
    }
  }
}
