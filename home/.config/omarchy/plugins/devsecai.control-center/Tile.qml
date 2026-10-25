import QtQuick
import qs.Commons

// A large quick-settings tile. Tap runs the main action; the chevron, when
// shown, opens more detail.
Rectangle {
  id: tile

  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property bool active: false
  property bool showMore: false

  signal tapped()
  signal moreTapped()

  property color onColor: Color.accent
  readonly property color ink: active ? Color.background : Color.foreground

  implicitHeight: 76
  radius: 20
  color: active ? onColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  scale: press.pressed || morePress.pressed ? 0.96 : 1

  Behavior on color { ColorAnimation { duration: 160 } }
  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  MouseArea {
    id: press
    anchors.fill: parent
    onClicked: tile.tapped()
  }

  Rectangle {
    id: iconDisc
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    width: 40
    height: 40
    radius: 20
    color: tile.active ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)

    Text {
      anchors.centerIn: parent
      text: tile.icon
      color: tile.ink
      font.family: Style.font.family
      font.pixelSize: 20
    }
  }

  Column {
    anchors.left: iconDisc.right
    anchors.leftMargin: 12
    anchors.right: more.visible ? more.left : parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      width: parent.width
      text: tile.title
      color: tile.ink
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: 15
      font.bold: true
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: tile.subtitle
      color: tile.ink
      opacity: 0.7
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: 12
    }
  }

  Item {
    id: more
    visible: tile.showMore
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 44

    Text {
      anchors.centerIn: parent
      text: "󰅂"
      color: tile.ink
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: 18
    }

    MouseArea {
      id: morePress
      anchors.fill: parent
      onClicked: tile.moreTapped()
    }
  }
}
