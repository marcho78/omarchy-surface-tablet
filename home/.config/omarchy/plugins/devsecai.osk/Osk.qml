import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "devsecai.osk"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    tooltipText: "On-screen keyboard"
    onPressed: function(b) {
      root.bar.run(Quickshell.env("HOME") + "/.local/bin/surface-osk toggle")
    }
  }
}
