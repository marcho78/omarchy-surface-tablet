import QtQuick
import Quickshell
import qs.Commons

// Set a reminder by touch: pick when, add a message if you like, Set. Uses
// Omarchy's own `omarchy-reminder <minutes> [message]` (a notification when it
// is due), whose own setter asks in a terminal. Lists the ones coming up.
Column {
  id: page

  signal back()
  // Asks the panel to read the reminders again.
  signal changed()

  // From `omarchy-reminder show --json`, read by the panel.
  property var reminders: []
  property int minutes: 10

  readonly property string home: Quickshell.env("HOME")
  readonly property color subtle: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

  spacing: 14

  function run(args) {
    Quickshell.execDetached(args)
  }

  function setReminder() {
    var text = message.text.trim()
    run(["omarchy-reminder", String(minutes)].concat(text !== "" ? [text] : []))
    message.text = ""
    message.focus = false
    run([home + "/.local/bin/surface-osk", "hide"])
    refresh.restart()
  }

  // omarchy-reminder sets up a systemd timer; read again once it's there.
  Timer {
    id: refresh
    interval: 600
    onTriggered: page.changed()
  }

  component Choice: Rectangle {
    id: choice
    property string label: ""
    property bool selected: false
    property bool strong: false
    signal tapped()

    height: 44
    radius: 16
    color: selected || strong ? Color.accent : page.subtle
    scale: area.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Text {
      anchors.centerIn: parent
      text: choice.label
      color: choice.selected || choice.strong ? Color.background : Color.foreground
      font.family: Style.font.family
      font.pixelSize: 14
      font.bold: true
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
        onClicked: {
          page.run([page.home + "/.local/bin/surface-osk", "hide"])
          page.back()
        }
      }
    }

    Text {
      anchors.left: backButton.right
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: "Reminder"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 18
      font.bold: true
    }
  }

  Heading { text: "REMIND ME IN" }

  Row {
    width: parent.width
    spacing: 8
    readonly property real cell: (width - 4 * spacing) / 5

    Repeater {
      model: [5, 10, 15, 30, 60]

      Choice {
        required property int modelData
        width: parent.cell
        label: modelData + " min"
        selected: page.minutes === modelData
        onTapped: page.minutes = modelData
      }
    }
  }

  Heading { text: "MESSAGE (OPTIONAL)" }

  // Tap for the on-screen keyboard.
  Rectangle {
    width: parent.width
    height: 44
    radius: 16
    color: page.subtle
    border.width: message.activeFocus ? 2 : 0
    border.color: Color.accent

    TextInput {
      id: message
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 14
      anchors.verticalCenter: parent.verticalCenter
      color: Color.foreground
      selectionColor: Color.accent
      font.family: Style.font.family
      font.pixelSize: 15
      clip: true
      maximumLength: 200
      Keys.onReturnPressed: page.setReminder()
      Keys.onEnterPressed: page.setReminder()

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: message.text === ""
        text: "Reminder"
        color: Color.foreground
        opacity: 0.45
        font: message.font
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        message.forceActiveFocus()
        page.run([page.home + "/.local/bin/surface-osk", "show"])
      }
    }
  }

  Row {
    width: parent.width
    spacing: 10
    readonly property real cell: (width - spacing) / 2

    Choice {
      width: parent.cell
      label: "Set for " + page.minutes + " min"
      strong: true
      onTapped: page.setReminder()
    }
    Choice {
      width: parent.cell
      label: "Clear all"
      onTapped: {
        page.run(["omarchy-reminder", "clear"])
        refresh.restart()
      }
    }
  }

  Heading {
    visible: page.reminders.length > 0
    text: "COMING UP"
  }

  Repeater {
    model: page.reminders

    Text {
      required property var modelData
      width: page.width
      elide: Text.ElideRight
      text: modelData.label + "  ·  " + modelData.atTime + " (in " + modelData.remaining + ")"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 14
    }
  }
}
