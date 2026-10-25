import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Edge swipes for tablet mode, iPad style:
//   bottom edge, swipe up a little   -> reveal the dock
//   bottom edge, swipe up partway    -> Stage Control (marcho78.stage-control:
//                                       every window, desktops to drag them to)
//   bottom edge, swipe up further    -> Search (marcho78.o-spotlight)
//   bottom edge, swipe up far        -> app drawer (over whatever is open)
//   bottom-right corner, swipe up    -> on-screen keyboard
// Which of these a bottom swipe does goes by distance alone, shown while
// swiping by a small list with the current choice lit.
//   top edge, right side, pull down  -> Control Center
//   top edge, left side, pull down   -> Notification Center
// The dock option is offered only while the dock is set to auto-hide; it asks
// the dock to come up (omarchy.dock reveal, from dock-reveal.patch), and the
// dock tucks itself away again a few seconds later.
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
  // Bottom swipe zones, as shares of the screen height: up to dockFraction
  // the dock, up to switcherFraction Stage Control, up to searchFraction
  // Search, beyond it the app drawer. (Timing a pause to tell them apart
  // proved unreliable: a finger meaning to pause was often still moving when
  // it lifted.)
  readonly property real dockFraction: 0.15
  readonly property real switcherFraction: 0.45
  readonly property real searchFraction: 0.62

  // The choice at a height up from the bottom edge.
  function zoneAt(up) {
    if (dockAutohide && up < screenH * dockFraction) return "dock"
    if (up < screenH * switcherFraction) return "switcher"
    if (up < screenH * searchFraction) return "search"
    return "drawer"
  }

  // On the way back down, each swipeStep below the highest point reached steps
  // one choice lower (about a row of the hint), so Stage Control to Dock is a
  // short slide rather than all the way back to the bottom band.
  readonly property int swipeStep: 50

  // What letting go of the current bottom swipe would do. Going up it follows
  // the zones; coming back down it steps down from the highest one reached,
  // ending on the dock (the lowest choice) rather than dropping out under
  // swipeMin; without the dock, back under swipeMin cancels.
  readonly property string swipeTarget: {
    if (!swipe.pressed || swipe.forKeyboard || !swipe.armed) return ""
    if (!dockAutohide && swipe.up < swipeMin) return ""
    var order = (dockAutohide ? ["dock"] : []).concat(["switcher", "search", "drawer"])
    var steps = Math.floor((swipe.peak - swipe.up) / swipeStep)
    return order[Math.max(0, order.indexOf(zoneAt(swipe.peak)) - steps)]
  }

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

  // The dock's auto-hide setting, as Omarchy keeps it in shell.json. With the
  // dock always shown there is nothing to bring up, so no dock option.
  property bool dockAutohide: false

  FileView {
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var config = JSON.parse(text())
        root.dockAutohide = !!(config.dock && config.dock.autohide === true)
      } catch (e) {}
    }
  }

  // The dock comes up for a few seconds; the swipe strip steps aside
  // meanwhile so the dock's icons take every tap.
  function showDock() {
    dockUp = true
    dockTimeout.restart()
    run("omarchy-shell -q omarchy.dock reveal")
  }

  function hideDock() {
    dockUp = false
    dockTimeout.stop()
  }

  Timer {
    id: dockTimeout
    interval: 5000
    onTriggered: root.hideDock()
  }

  // The on-screen keyboard (squeekboard or wvkbd) maps a layer while it shows.
  readonly property var oskLayers: ["osk", "squeekboard", "wvkbd"]
  property bool oskUp: false

  function isOsk(namespace) {
    return oskLayers.indexOf(String(namespace)) >= 0
  }

  // Pick up a keyboard that was already open when the shell started.
  Process {
    running: true
    command: ["bash", "-c", "hyprctl layers -j | grep -qE '\"namespace\": \"(osk|squeekboard|wvkbd)\"'"]
    onExited: function(exitCode) { if (exitCode === 0) root.oskUp = true }
  }

  function toggleKeyboard() {
    run(home + "/.local/bin/surface-osk toggle")
  }

  // Apps shrink to stay above the keyboard, and grow back when it closes.
  // The word being typed starts over either way.
  onOskUpChanged: {
    if (tablet) refit.restart()
    run(home + "/.local/bin/surface-osk reset")
    if (oskUp) dictationCheck.running = true
    // The mic lives on the keyboard: putting the keyboard away stops it.
    else if (dictationState === "listening") run(home + "/.local/bin/surface-dictate stop")
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
      else if (name === "openwindow" && String(event.data).split(",")[2] === "org.omarchy.screensaver")
        root.screensaverAddress = String(event.data).split(",")[0]
      else if (name === "closewindow" && String(event.data) === root.screensaverAddress)
        root.screensaverAddress = ""
      else if (name === "openwindow" && root.dockUp) hideDelay.restart()
      // activewindowv2 also comes whenever the active window's title changes
      // (a terminal's spinner, a browser tab loading), so only a different
      // address means the user switched windows.
      else if (name === "activewindowv2" && String(event.data) !== root.activeWindow) {
        root.activeWindow = String(event.data)
        // Opening or switching to an app is the end of using the dock.
        if (root.dockUp) hideDelay.restart()
        // Typing in another window: the word being typed there starts over.
        if (root.oskUp) root.run(root.home + "/.local/bin/surface-osk reset")
      }
    }
  }

  property string activeWindow: ""

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
      // How far up the finger is from where it started.
      property real up: 0
      // Whether it has gone far enough up to count as a swipe (swipeMin).
      property bool armed: false
      // The highest it has been.
      property real peak: 0
      readonly property bool forKeyboard: startX > width * 0.82

      onPressed: function(mouse) {
        startX = mouse.x
        startY = mouse.y
        up = 0
        armed = false
        peak = 0
      }

      onPositionChanged: function(mouse) {
        up = startY - mouse.y
        if (up >= root.swipeMin) armed = true
        if (up > peak) peak = up
      }

      onReleased: function(mouse) {
        up = startY - mouse.y
        if (!armed) return
        if (forKeyboard) {
          if (up >= root.swipeMin) root.toggleKeyboard()
          return
        }
        var target = root.swipeTarget
        console.log("GESTDEBUG release up", Math.round(up), "->", target)
        if (target === "drawer") root.run("omarchy-shell shell summon devsecai.app-drawer")
        else if (target === "switcher") root.run("omarchy-shell stage-control toggle")
        else if (target === "search") root.run("omarchy-shell shell summon marcho78.o-spotlight '{\"buttons\":true}'")
        else if (target === "dock") root.showDock()
      }
    }
  }

  // ------------------------------------------------------------ swipe hint

  // While swiping up from the bottom edge: what letting go will do, as a
  // short list (far to near, top to bottom) with the current choice lit.
  // Always mapped, so it shows the instant a swipe starts; it never takes
  // touches.
  PanelWindow {
    visible: root.tablet && !!root.screen
    screen: root.screen
    anchors { bottom: true }
    margins { bottom: Math.round(root.screenH * 0.42) }
    implicitWidth: 268
    implicitHeight: hintColumn.implicitHeight + 20
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-gesture-hint"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      radius: 24
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.94)
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
      opacity: root.swipeTarget !== "" ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 90 } }

      Column {
        id: hintColumn
        anchors.centerIn: parent
        spacing: 4

        Repeater {
          model: [
            { key: "drawer", icon: "󰀻", label: "Apps" },
            { key: "search", icon: "󰍉", label: "Search" },
            { key: "switcher", icon: "󰕰", label: "Stage Control" }
          ].concat(root.dockAutohide ? [{ key: "dock", icon: "󰍜", label: "Dock" }] : [])

          Rectangle {
            required property var modelData
            readonly property bool current: root.swipeTarget === modelData.key
            width: 248
            height: 46
            radius: 17
            color: current ? Color.accent : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }

            Row {
              anchors.left: parent.left
              anchors.leftMargin: 18
              anchors.verticalCenter: parent.verticalCenter
              spacing: 14

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.icon
                color: parent.parent.current ? Color.background : Color.foreground
                opacity: parent.parent.current ? 1 : 0.6
                font.family: Style.font.family
                font.pixelSize: 20
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: parent.parent.current ? Color.background : Color.foreground
                opacity: parent.parent.current ? 1 : 0.6
                font.family: Style.font.family
                font.pixelSize: 15
                font.bold: parent.parent.current
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ screensaver

  // Omarchy's screensaver is a full-screen terminal that closes on a key press
  // or when it loses focus, and a tap is neither: in tablet mode there is no
  // keyboard to close it with. While it shows, a tap anywhere closes it, with
  // the SIGHUP omarchy-screensaver traps to exit and bring the cursor back.
  property string screensaverAddress: ""

  PanelWindow {
    visible: root.tablet && root.screensaverAddress !== "" && !!root.screen
    screen: root.screen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-screensaver-tap"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      onPressed: root.run("pkill -HUP -f 'bin/[o]marchy-screensaver'")
    }
  }

  // ------------------------------------------------------------ suggestion strip

  // Gboard's top row, above the on-screen keyboard while it shows: Esc, three
  // word suggestions (the best in the middle), the mic for voice typing and the
  // button that puts the keyboard away. Tap a suggestion to type it
  // (surface-osk-keys does the typing). The strip reserves its height like the
  // keyboard does, so Hyprland stacks it on top of the keyboard and apps sit
  // above both. Coloured like wvkbd.
  property var suggestions: []

  // Voice typing: the mic starts and stops surface-dictate (Vosk, through
  // nerd-dictation), which types what you say at the cursor while you speak.
  // Shown once it is installed; red while listening (its state file). Omarchy's
  // own dictation keys stay on Voxtype, which types once you stop.
  property bool dictationReady: false
  property string dictationState: "idle"

  Process {
    id: dictationCheck
    running: true
    command: [root.home + "/.local/bin/surface-dictate", "check"]
    onExited: function(exitCode) { root.dictationReady = exitCode === 0 }
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/surface-dictate/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.dictationState = text().trim()
    onLoadFailed: root.dictationState = "idle"
  }

  // Dictated words aren't the keyboard's: the next word starts fresh.
  onDictationStateChanged: if (dictationState === "idle") run(home + "/.local/bin/surface-osk reset")

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/surface-osk/suggestions.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.suggestions = JSON.parse(text()).suggestions || []
      } catch (e) {}
    }
  }

  PanelWindow {
    visible: root.oskUp && !!root.screen
    screen: root.screen
    anchors { left: true; right: true; bottom: true }
    implicitHeight: 48
    color: "#0f0f0f"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: implicitHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-osk-strip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Row {
      id: stripRow
      anchors.fill: parent
      readonly property real cell: (width - escKey.width - mic.width - hideKeyboard.width) / 3

      // Esc, one tap away, for terminals, menus and dialogs (wvkbd keeps it two
      // pages from the letters, on =\<).
      Item {
        id: escKey
        width: 68
        height: stripRow.height

        Rectangle {
          anchors.centerIn: parent
          width: 52
          height: 36
          radius: 12
          color: "#2d2d2d"
          visible: escPress.pressed
        }

        Text {
          anchors.centerIn: parent
          text: "Esc"
          color: "white"
          opacity: escPress.pressed ? 0.45 : 0.85
          font.family: Style.font.family
          font.pixelSize: 15
          font.bold: true
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 1
          height: parent.height * 0.45
          color: "#3a3a3a"
        }

        MouseArea {
          id: escPress
          anchors.fill: parent
          onClicked: root.run("wtype -k Escape; " + root.home + "/.local/bin/surface-osk reset")
        }
      }

      // Left the second best, the middle the best, right the third.
      Repeater {
        model: [1, 0, 2]

        Item {
          id: slot
          required property int modelData
          readonly property string word: root.suggestions.length > modelData ? root.suggestions[modelData] : ""
          width: stripRow.cell
          height: stripRow.height

          Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 12
            color: "#2d2d2d"
            visible: press.pressed && slot.word !== ""
          }

          Text {
            anchors.centerIn: parent
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: slot.word
            color: "white"
            opacity: slot.modelData === 0 ? 1 : 0.85
            font.family: Style.font.family
            font.pixelSize: 17
            font.bold: slot.modelData === 0
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.45
            color: "#3a3a3a"
          }

          MouseArea {
            id: press
            anchors.fill: parent
            enabled: slot.word !== ""
            onClicked: root.run(root.home + "/.local/bin/surface-osk accept " + slot.modelData)
          }
        }
      }

      Item {
        id: mic
        readonly property bool listening: root.dictationState === "listening"
        visible: root.dictationReady
        width: visible ? 68 : 0
        height: stripRow.height

        Rectangle {
          id: micPill
          anchors.centerIn: parent
          width: 46
          height: 36
          radius: 18
          color: mic.listening ? "#e5484d" : "#2d2d2d"
          visible: mic.listening || micPress.pressed

          // A slow pulse while it listens.
          SequentialAnimation on opacity {
            running: mic.listening
            loops: Animation.Infinite
            onRunningChanged: if (!running) micPill.opacity = 1
            NumberAnimation { to: 0.6; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "󰍬"
          color: "white"
          opacity: mic.listening ? 1 : (micPress.pressed ? 0.45 : 0.85)
          font.family: Style.font.family
          font.pixelSize: 22
        }

        MouseArea {
          id: micPress
          anchors.fill: parent
          onClicked: root.run(root.home + "/.local/bin/surface-dictate toggle")
        }
      }

      Item {
        id: hideKeyboard
        width: 68
        height: stripRow.height

        Text {
          anchors.centerIn: parent
          text: "󰌐"
          color: "white"
          opacity: hidePress.pressed ? 0.45 : 0.85
          font.family: Style.font.family
          font.pixelSize: 22
        }

        MouseArea {
          id: hidePress
          anchors.fill: parent
          onClicked: root.toggleKeyboard()
        }
      }
    }
  }

  // ------------------------------------------------------------ top edge

  // The tablet bar is for reading, not tapping: pull down on its right side for
  // the Control Center, on its left side for the Notification Center. The middle
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
    command: "omarchy-shell shell toggle devsecai.notification-center"
  }
}
