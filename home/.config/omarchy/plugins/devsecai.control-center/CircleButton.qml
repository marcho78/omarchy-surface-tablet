import QtQuick
import qs.Commons

Rectangle {
  id: button

  property string icon: ""
  property bool danger: false

  signal tapped()

  implicitWidth: 48
  implicitHeight: 48
  radius: 24
  color: danger ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.85)
                : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  scale: area.pressed ? 0.92 : 1
  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  Text {
    anchors.centerIn: parent
    text: button.icon
    color: button.danger ? Color.background : Color.foreground
    font.family: Style.font.family
    font.pixelSize: 20
  }

  MouseArea {
    id: area
    anchors.fill: parent
    onClicked: button.tapped()
  }
}
