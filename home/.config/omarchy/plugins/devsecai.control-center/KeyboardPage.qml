import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// On-screen keyboard settings: layout style and height. Your preferred
// language (from the system settings) is added by surface-osk itself.
// Saved and applied by `surface-osk set`, which restarts the keyboard.
Column {
  id: page

  signal back()

  readonly property string home: Quickshell.env("HOME")
  property string style: "standard"
  property string size: "medium"

  spacing: 14

  FileView {
    path: page.home + "/.config/surface-osk/settings"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: page.parse(text())
  }

  function parse(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^(\w+)=(.*)$/)
      if (!m) continue
      var value = m[2].replace(/^'(.*)'$/, "$1")
      if (m[1] === "STYLE") style = value
      else if (m[1] === "SIZE") size = value
    }
  }

  function set(key, value) {
    Quickshell.execDetached([home + "/.local/bin/surface-osk", "set", key, value])
  }

  readonly property color subtle: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

  component Choice: Rectangle {
    id: choice
    property string label: ""
    property string detail: ""
    property bool selected: false
    signal tapped()

    height: detail !== "" ? 64 : 44
    radius: 16
    color: selected ? Color.accent : page.subtle
    scale: area.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Column {
      anchors.centerIn: parent
      width: parent.width - 16
      spacing: 2

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: choice.label
        color: choice.selected ? Color.background : Color.foreground
        font.family: Style.font.family
        font.pixelSize: 14
        font.bold: true
      }

      Text {
        width: parent.width
        visible: choice.detail !== ""
        horizontalAlignment: Text.AlignHCenter
        text: choice.detail
        color: choice.selected ? Color.background : Color.foreground
        opacity: 0.7
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: 11
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      onClicked: choice.tapped()
    }
  }

  component Heading: Text {
    color: Color.foreground
    opacity: 0.6
    font.family: Style.font.family
    font.pixelSize: 12
    font.bold: true
  }

  // Back to the main page.
  Item {
    width: parent.width
    height: 40

    Rectangle {
      id: backButton
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 40
      height: 40
      radius: 20
      color: page.subtle
      scale: backArea.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Text {
        anchors.centerIn: parent
        text: "󰅁"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 20
      }

      MouseArea {
        id: backArea
        anchors.fill: parent
        onClicked: page.back()
      }
    }

    Text {
      anchors.left: backButton.right
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: "Keyboard"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 18
      font.bold: true
    }
  }

  Heading { text: "LAYOUT" }

  Row {
    width: parent.width
    spacing: 10
    readonly property real cell: (width - 2 * spacing) / 3

    Choice {
      width: parent.cell
      label: "Standard"
      detail: "Letters, arrows"
      selected: page.style === "standard"
      onTapped: page.set("style", "standard")
    }
    Choice {
      width: parent.cell
      label: "Full"
      detail: "Numbers row"
      selected: page.style === "full"
      onTapped: page.set("style", "full")
    }
    Choice {
      width: parent.cell
      label: "Simple"
      detail: "Big keys"
      selected: page.style === "simple"
      onTapped: page.set("style", "simple")
    }
  }

  Heading { text: "HEIGHT" }

  Row {
    width: parent.width
    spacing: 10
    readonly property real cell: (width - 2 * spacing) / 3

    Choice {
      width: parent.cell
      label: "Small"
      selected: page.size === "small"
      onTapped: page.set("size", "small")
    }
    Choice {
      width: parent.cell
      label: "Medium"
      selected: page.size === "medium"
      onTapped: page.set("size", "medium")
    }
    Choice {
      width: parent.cell
      label: "Large"
      selected: page.size === "large"
      onTapped: page.set("size", "large")
    }
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Symbols and emoji are behind the bottom-left key on the keyboard."
    color: Color.foreground
    opacity: 0.55
    font.family: Style.font.family
    font.pixelSize: 11
  }
}
