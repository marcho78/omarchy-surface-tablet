import QtQuick
import qs.Commons

// An app in the drawer: a large icon with its name underneath, nothing
// boxed around it, the way phone and tablet launchers show apps.
Item {
  id: cell

  property string name: ""
  property string iconSource: ""
  property int iconSize: 64

  signal tapped()

  Column {
    anchors.centerIn: parent
    width: parent.width - 8
    spacing: 8
    scale: press.pressed ? 0.88 : 1
    opacity: press.pressed ? 0.75 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: cell.iconSize
      height: cell.iconSize

      Image {
        id: icon
        anchors.fill: parent
        source: cell.iconSource
        sourceSize.width: cell.iconSize * 2
        sourceSize.height: cell.iconSize * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
      }

      // Until (or unless) the icon loads: a rounded tile with the initial.
      Rectangle {
        anchors.fill: parent
        visible: !icon.visible
        radius: width * 0.24
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)

        Text {
          anchors.centerIn: parent
          text: (cell.name.charAt(0) || "?").toUpperCase()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: cell.iconSize * 0.42
          font.bold: true
        }
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: cell.name
      elide: Text.ElideRight
      maximumLineCount: 1
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 13
    }
  }

  MouseArea {
    id: press
    anchors.fill: parent
    onClicked: cell.tapped()
  }
}
