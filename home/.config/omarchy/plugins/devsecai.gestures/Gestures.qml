import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Edge swipes for tablet mode, iPad style:
//   bottom edge, short swipe up      -> reveal the dock
//   bottom edge, long swipe up       -> Home (tuck apps away, show the app grid)
//   bottom-right corner, swipe up    -> on-screen keyboard
//   top edge, right side, pull down  -> Control Center
//   top edge, left side, pull down   -> recent notifications
// The dock reveals when the pointer reaches the screen edge, so revealing it
// warps the (hidden) pointer there, and tucking it away warps it back.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  property bool tablet: false
  property bool dockUp: false

  readonly property var screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  readonly property int screenW: screen ? screen.width : 0
  readonly property int screenH: screen ? screen.height : 0

  // How far a finger must travel to count, in logical px.
  readonly property int swipeMin: 24
  readonly property real homeFraction: 0.3

  FileView {
    path: root.home + "/.local/state/tablet-mode/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.tablet = text().trim() === "on"
  }

  function run(command) {
    Quickshell.execDetached(["bash", "-c", command])
  }

  function warp(x, y) {
    Quickshell.execDetached(["hyprctl", "dispatch",
      "hl.dsp.cursor.move({ x = " + Math.round(x) + ", y = " + Math.round(y) + " })"])
  }

  function showDock() {
    dockUp = true
    warp(screenW / 2, screenH - 1)
    dockTimeout.restart()
  }

  function hideDock() {
    if (!dockUp) return
    dockUp = false
    dockTimeout.stop()
    warp(screenW / 2, screenH / 2)
  }

  Timer {
    id: dockTimeout
    interval: 8000
    onTriggered: root.hideDock()
  }

  // The on-screen keyboard (squeekboard or wvkbd) maps a layer while it shows.
  readonly property var oskLayers: ["osk", "squeekboard", "wvkbd"]
  property bool oskUp: false
  property int oskHeight: screenH > screenW ? 400 : 300

  function isOsk(namespace) {
    return oskLayers.indexOf(String(namespace)) >= 0
  }

  // Pick up a keyboard that was already open when the shell started.
  Process {
    running: true
    command: ["bash", "-c", "hyprctl layers -j | grep -qE '\"namespace\": \"(osk|squeekboard|wvkbd)\"'"]
    onExited: function(exitCode) { if (exitCode === 0) root.oskUp = true }
  }

  // The keyboard reserves its height at the bottom of the screen; read it so
  // the dismiss tab sits right on top of it.
  Process {
    id: oskMeasure
    command: ["bash", "-c", "hyprctl monitors -j | jq '(first(.[] | select(.focused)) // .[0]).reserved[3]'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var h = parseInt(String(text || "").trim(), 10)
        if (h > 40) root.oskHeight = h
      }
    }
  }

  Timer {
    id: oskMeasureSoon
    interval: 150
    onTriggered: oskMeasure.running = true
  }

  function toggleKeyboard() {
    run(home + "/.local/bin/surface-osk toggle")
  }

  // Apps shrink to stay above the keyboard, and grow back when it closes.
  onOskUpChanged: {
    if (oskUp) oskMeasureSoon.restart()
    if (tablet) refit.restart()
  }

  Timer {
    id: refit
    interval: 200
    onTriggered: root.run(root.home + "/.local/bin/tablet-mode refit")
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "openlayer" && root.isOsk(event.data)) root.oskUp = true
      else if (name === "closelayer" && root.isOsk(event.data)) root.oskUp = false
      // Opening or switching to an app is the end of using the dock.
      else if (root.dockUp && (name === "activewindowv2" || name === "openwindow")) hideDelay.restart()
    }
  }

  Timer {
    id: hideDelay
    interval: 250
    onTriggered: root.hideDock()
  }

  // ------------------------------------------------------------ bottom edge

  PanelWindow {
    id: bottom
    visible: root.tablet && !root.dockUp && !root.oskUp && !!root.screen
    screen: root.screen
    anchors { left: true; right: true; bottom: true }
    implicitHeight: 14
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-gesture-bottom"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The home indicator: a hint that this edge can be swiped.
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      width: 132
      height: 5
      radius: 3
      color: Color.foreground
      opacity: swipe.pressed ? 0.75 : 0.35
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: 22
      anchors.verticalCenter: parent.verticalCenter
      text: "󰌌"
      color: Color.foreground
      opacity: 0.3
      font.family: Style.font.family
      font.pixelSize: 11
    }

    MouseArea {
      id: swipe
      anchors.fill: parent
      preventStealing: true

      property real startX: 0
      property real startY: 0

      onPressed: function(mouse) {
        startX = mouse.x
        startY = mouse.y
      }

      onReleased: function(mouse) {
        var up = startY - mouse.y
        if (up < root.swipeMin) return
        if (startX > width * 0.82) root.toggleKeyboard()
        else if (up > root.screenH * root.homeFraction) root.run(root.home + "/.local/bin/tablet-mode home")
        else root.showDock()
      }
    }
  }

  // ------------------------------------------------------------ keyboard dismiss

  // A tab sitting on the keyboard's top-right corner: tap it, or swipe it
  // down, to put the keyboard away.
  PanelWindow {
    visible: root.oskUp && !!root.screen
    screen: root.screen
    anchors { right: true; bottom: true }
    margins { right: 14; bottom: root.oskHeight + 8 }
    implicitWidth: 72
    implicitHeight: 44
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-osk-dismiss"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Color.background
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
      scale: dismiss.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Text {
        anchors.centerIn: parent
        text: "󰌐"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 22
      }
    }

    MouseArea {
      id: dismiss
      anchors.fill: parent
      preventStealing: true
      onReleased: root.toggleKeyboard()
    }
  }

  // ------------------------------------------------------------ top edge

  // The tablet bar is for reading, not tapping: pull down on its right side for
  // the Control Center, on its left side for recent notifications. The middle
  // (workspaces) stays tappable. Fires as soon as the finger has pulled far
  // enough, without waiting for it to lift.
  readonly property int barHeight: Math.max(Style.bar.sizeHorizontal, 30)
  readonly property real pullZone: 0.38

  component PullDown: PanelWindow {
    id: zone
    property bool right: false
    property string command: ""
    property alias pressed: pull.pressed

    visible: root.tablet && !!root.screen
    screen: root.screen
    anchors { top: true; left: !zone.right; right: zone.right }
    implicitWidth: Math.round(root.screenW * root.pullZone)
    implicitHeight: root.barHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: zone.right ? "devsecai-gesture-top-right" : "devsecai-gesture-top-left"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      id: pull
      anchors.fill: parent
      preventStealing: true

      property real startY: 0
      property bool fired: false

      onPressed: function(mouse) {
        startY = mouse.y
        fired = false
      }
      onPositionChanged: function(mouse) {
        if (fired || mouse.y - startY < root.swipeMin) return
        fired = true
        root.run(zone.command)
      }
    }
  }

  PullDown {
    right: true
    command: "omarchy-shell shell toggle devsecai.control-center"

    // Grabber under the status icons: a hint that this edge pulls down.
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 44
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      width: 40
      height: 4
      radius: 2
      color: Color.foreground
      opacity: parent.pressed ? 0.7 : 0.3
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }

  PullDown {
    right: false
    command: "omarchy-shell -q notifications showHistory"
  }
}
