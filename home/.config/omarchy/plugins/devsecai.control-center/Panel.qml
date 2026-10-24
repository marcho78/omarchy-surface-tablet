import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// Tablet-mode Control Center: big tiles and sliders under the top bar.
// Toggle with: omarchy-shell shell toggle devsecai.control-center
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: (manifest && manifest.id) || "devsecai.control-center"
  readonly property string home: Quickshell.env("HOME")

  // ---------------------------------------------------------------- state

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool bluetoothOn: !!adapter && adapter.enabled
  readonly property bool wifiOn: Networking.wifiEnabled
  property string ssid: ""

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool muted: !!sink && !!sink.audio && sink.audio.muted
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0

  property real brightness: 0

  readonly property var battery: UPower.displayDevice
  readonly property int batteryPercent: battery && battery.isPresent ? Math.round(battery.percentage * 100) : -1
  readonly property bool charging: !!battery && (battery.state === UPowerDeviceState.Charging
    || battery.state === UPowerDeviceState.FullyCharged)

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  // ---------------------------------------------------------------- panel API

  function open(payloadJson) {
    opened = true
    ssidProc.running = true
    brightnessRead.running = true
  }

  function close() {
    opened = false
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  // A swipe up closes the panel, like pushing a sheet back up.
  component SwipeUpArea: MouseArea {
    property real startY: 0
    onPressed: function(mouse) { startY = mouse.y }
    onPositionChanged: function(mouse) { if (startY - mouse.y > 40) root.dismiss() }
  }

  function run(command) {
    Quickshell.execDetached(["bash", "-c", command])
  }

  // Run something that takes over the screen, after the panel is gone. The
  // command starts first: hiding the panel tears this object down.
  function runAndClose(command) {
    run("sleep 0.25; " + command)
    dismiss()
  }

  // ---------------------------------------------------------------- readers

  Process {
    id: ssidProc
    command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1"]
    stdout: StdioCollector {
      onStreamFinished: root.ssid = String(text || "").trim()
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: ssidProc.running = true
  }

  Process {
    id: brightnessRead
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = String(text || "").trim().split(",")
        var pct = parseInt(parts[3], 10)
        if (isFinite(pct)) root.brightness = pct / 100
      }
    }
  }

  // Brightness writes are coalesced so a drag doesn't spawn a process per pixel.
  property real pendingBrightness: -1
  Timer {
    id: brightnessWrite
    interval: 60
    onTriggered: {
      if (root.pendingBrightness < 0) return
      var pct = Math.max(1, Math.round(root.pendingBrightness * 100))
      root.pendingBrightness = -1
      Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"])
    }
  }

  // ---------------------------------------------------------------- window

  OverlayWindow {
    id: window
    shown: root.opened
    WlrLayershell.namespace: "devsecai-control-center"

    // Tap anywhere outside the card, or swipe up anywhere, to close.
    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: root.opened ? 0.28 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }

      SwipeUpArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()
    }

    RectangularShadow {
      anchors.fill: card
      radius: card.radius
      blur: 40
      spread: 0
      offset.y: 10
      color: Qt.rgba(0, 0, 0, 0.45)
      opacity: card.opacity
    }

    Rectangle {
      id: card

      width: Math.min(460, parent.width - 24)
      height: content.implicitHeight + 50
      anchors.right: parent.right
      anchors.rightMargin: 12
      y: Style.bar.sizeHorizontal + 12 + (root.opened ? 0 : -10)
      radius: 28
      color: Color.popups.background
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.97
      transformOrigin: Item.TopRight

      Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 160 } }
      Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

      // Swallow taps on the card so they don't reach the scrim.
      SwipeUpArea { anchors.fill: parent }

      // Grabber: a hint that the card swipes back up.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: 40
        height: 4
        radius: 2
        color: Color.foreground
        opacity: 0.25
      }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 14

        // Header: battery on the left, lock and power on the right.
        Item {
          width: parent.width
          height: 48

          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: 26
              font.bold: true
            }

            Text {
              text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                + (root.batteryPercent >= 0 ? "  ·  " + (root.charging ? "󰂄 " : "󰁹 ") + root.batteryPercent + "%" : "")
              color: Color.foreground
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: 12
            }
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            CircleButton {
              icon: "󰌾"
              onTapped: root.runAndClose("omarchy system lock")
            }

            CircleButton {
              icon: "󰐥"
              danger: true
              onTapped: root.runAndClose("omarchy menu toggle system")
            }
          }
        }

        Grid {
          width: parent.width
          columns: 2
          columnSpacing: 10
          rowSpacing: 10

          readonly property real cell: (width - columnSpacing) / 2

          Tile {
            width: parent.cell
            icon: root.wifiOn ? "󰖩" : "󰖪"
            title: "Wi-Fi"
            subtitle: !root.wifiOn ? "Off" : (root.ssid !== "" ? root.ssid : "Not connected")
            active: root.wifiOn
            showMore: true
            onTapped: Networking.wifiEnabled = !Networking.wifiEnabled
            onMoreTapped: root.runAndClose("omarchy-shell shell toggle omarchy.network")
          }

          Tile {
            width: parent.cell
            icon: root.bluetoothOn ? "󰂯" : "󰂲"
            title: "Bluetooth"
            subtitle: !root.adapter ? "Unavailable" : (root.bluetoothOn ? "On" : "Off")
            active: root.bluetoothOn
            showMore: true
            onTapped: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            onMoreTapped: root.runAndClose("omarchy-shell shell toggle omarchy.bluetooth")
          }

          Tile {
            width: parent.cell
            icon: "󰌌"
            title: "Keyboard"
            subtitle: "Show / hide"
            onTapped: root.runAndClose(root.home + "/.local/bin/surface-osk toggle")
          }

          Tile {
            width: parent.cell
            icon: "󰄀"
            title: "Screenshot"
            subtitle: "Capture screen"
            onTapped: root.runAndClose("omarchy capture screenshot")
          }

          Tile {
            width: parent.cell
            icon: "󰀻"
            title: "Apps"
            subtitle: "App library"
            onTapped: root.runAndClose("omarchy-shell omarchy.dock apps")
          }

          Tile {
            width: parent.cell
            icon: "󰌢"
            title: "Desktop"
            subtitle: "Exit tablet"
            onTapped: root.runAndClose(root.home + "/.local/bin/tablet-mode off")
          }
        }

        PillSlider {
          width: parent.width
          icon: root.muted ? "󰝟" : (root.volume > 0.5 ? "󰕾" : "󰖀")
          value: root.volume
          onMoved: function(v) {
            if (root.sink && root.sink.audio) {
              root.sink.audio.volume = v
              if (root.muted && v > 0) root.sink.audio.muted = false
            }
          }
          onIconTapped: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted
        }

        PillSlider {
          width: parent.width
          icon: "󰃠"
          value: root.brightness
          onMoved: function(v) {
            root.brightness = v
            root.pendingBrightness = v
            brightnessWrite.restart()
          }
        }
      }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
