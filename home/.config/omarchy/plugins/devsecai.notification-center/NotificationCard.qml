import QtQuick
import Quickshell
import qs.Commons

// One notification. Tap opens its app; slide it sideways to dismiss it.
Item {
  id: card

  property var entry: ({})
  property string appName: ""
  property string timeText: ""
  property bool showApp: true
  property bool swipeEnabled: true

  signal tapped()
  signal dismissed()

  readonly property string glyph: String(entry.glyph || "")
  readonly property string iconSource: {
    var icon = String(entry.appIcon || "")
    if (icon === "") return ""
    if (icon.indexOf("/") === 0) return "file://" + icon
    if (icon.indexOf("file://") === 0) return icon
    return Quickshell.iconPath(icon, true)
  }

  implicitHeight: body.implicitHeight + 28

  // Slid past this share of its width, a card goes; short of it, it springs back.
  readonly property real dismissShare: 0.35
  property bool leaving: false

  Rectangle {
    id: face
    width: parent.width
    height: parent.height
    radius: 22
    color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.94)
    border.width: 1
    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
    opacity: 1 - Math.min(1, Math.abs(x) / card.width) * 0.9
    scale: tap.pressed && !slide.active ? 0.98 : 1

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on x {
      enabled: !slide.active
      NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    onXChanged: if (card.leaving && Math.abs(x) >= card.width) card.dismissed()

    Row {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      // App icon: the app's own icon when it sent one, else its glyph.
      Rectangle {
        width: 40
        height: 40
        radius: 12
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)

        Image {
          id: icon
          anchors.fill: parent
          anchors.margins: 4
          source: card.iconSource
          sourceSize.width: 64
          sourceSize.height: 64
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: !icon.visible
          text: card.glyph !== "" ? card.glyph : (card.appName.charAt(0) || "?").toUpperCase()
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: card.glyph !== "" ? 20 : 17
          font.bold: card.glyph === ""
        }
      }

      Column {
        width: parent.width - 52
        spacing: 3

        Item {
          width: parent.width
          height: appLabel.implicitHeight
          visible: card.showApp || card.timeText !== ""

          Text {
            id: appLabel
            anchors.left: parent.left
            anchors.right: timeLabel.left
            anchors.rightMargin: 8
            visible: card.showApp
            text: card.appName
            elide: Text.ElideRight
            color: Color.foreground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
          }

          Text {
            id: timeLabel
            anchors.right: parent.right
            text: card.timeText
            color: Color.foreground
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: 12
          }
        }

        Text {
          width: parent.width
          text: String(card.entry.summary || "")
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 15
          font.bold: true
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: String(card.entry.body || "")
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          color: Color.foreground
          opacity: 0.8
          font.family: Style.font.family
          font.pixelSize: 13
        }
      }
    }
  }

  TapHandler {
    id: tap
    onTapped: card.tapped()
  }

  DragHandler {
    id: slide
    enabled: card.swipeEnabled && !card.leaving
    target: face
    yAxis.enabled: false
    xAxis.minimum: -card.width
    xAxis.maximum: card.width

    onActiveChanged: {
      if (active) return
      if (Math.abs(face.x) > card.width * card.dismissShare) {
        card.leaving = true
        face.x = face.x > 0 ? card.width : -card.width
      } else {
        face.x = 0
      }
    }
  }
}
