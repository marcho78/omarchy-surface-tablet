import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Large time with the date beside it, for the tablet bar.
BarWidget {
  id: root
  moduleName: "devsecai.tablet-clock"

  implicitWidth: row.implicitWidth + 16
  implicitHeight: root.bar ? root.bar.barSize : 32

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    x: 8
    spacing: 10

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Color.bar.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 1.45)
      font.bold: true
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, "ddd d MMM")
      color: Color.bar.text
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }
  }
}
