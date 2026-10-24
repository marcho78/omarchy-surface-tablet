import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.Ui
import qs.Commons

// Status icons for the tablet bar. Display only: pulling down on this side of
// the bar opens the Control Center (see the devsecai.gestures plugin).
BarWidget {
  id: root
  moduleName: "devsecai.tablet-status"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var battery: UPower.displayDevice
  readonly property int percent: battery && battery.isPresent ? Math.round(battery.percentage * 100) : -1
  readonly property bool charging: !!battery && battery.state === UPowerDeviceState.Charging
  readonly property int iconPx: Math.round(Style.font.baseSize * 1.35)

  function batteryIcon() {
    if (charging) return "󰂄"
    var icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return icons[Math.max(0, Math.min(10, Math.round(percent / 10)))]
  }

  implicitWidth: pill.width
  implicitHeight: root.bar ? root.bar.barSize : 32

  Rectangle {
    id: pill
    anchors.verticalCenter: parent.verticalCenter
    width: row.implicitWidth + 28
    height: parent.height - 6
    radius: height / 2
    color: "transparent"

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 16

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Networking.wifiEnabled ? "󰖩" : "󰖪"
        color: Color.bar.text
        font.family: Style.font.family
        font.pixelSize: root.iconPx
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.adapter
        text: root.adapter && root.adapter.enabled ? "󰂯" : "󰂲"
        color: Color.bar.text
        font.family: Style.font.family
        font.pixelSize: root.iconPx
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.percent >= 0
        spacing: 6

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.batteryIcon()
          color: root.percent <= 15 && !root.charging ? Color.urgent : Color.bar.text
          font.family: Style.font.family
          font.pixelSize: root.iconPx
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.percent + "%"
          color: Color.bar.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }
    }
  }
}
