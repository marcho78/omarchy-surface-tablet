import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Edge swipes for tablet mode:
//   bottom edge, swipe up            -> app drawer (over whatever is open)
//   bottom-right corner, swipe up    -> on-screen keyboard
//   right edge, middle, swipe in     -> radial menu: your AI agent, Search,
//                                       Apps, Stage Control and Dock around
//                                       the finger; slide to one and let go,
//                                       or tap one
//   long press on the desktop        -> the same menu, all round the finger
//   top edge, right side, pull down  -> Control Center
//   top edge, left side, pull down   -> Notification Center
// The dock choice is offered only while the dock is set to auto-hide; it asks
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
      if (["fullscreen", "workspacev2", "activewindowv2", "closewindow", "movewindowv2"].indexOf(name) >= 0)
        fullscreenCheck.restart()
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

  // Swipe up anywhere along it for the app drawer; the right-hand corner is
  // the keyboard's.
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
      readonly property bool forKeyboard: startX > width * 0.82

      onPressed: function(mouse) {
        startX = mouse.x
        startY = mouse.y
      }

      onReleased: function(mouse) {
        if (startY - mouse.y < root.swipeMin) return
        if (forKeyboard) root.toggleKeyboard()
        else root.run("omarchy-shell shell summon devsecai.app-drawer")
      }
    }
  }

  // ------------------------------------------------------------ radial menu

  // Search, Apps, Stage Control and Dock around the finger. Choose by sliding
  // towards one and letting go (by direction: more forgiving than how far),
  // or let go first and tap one; tap anywhere else to put it away.
  property bool menuOpen: false
  property real menuX: 0
  property real menuY: 0
  // "left": fanned out to the left of the right edge; "around": all round.
  property string menuFan: "left"
  // The choice the finger is heading for.
  property string menuHot: ""
  // Wider when fanned out on one side, so five choices keep their room.
  readonly property real menuRadius: menuFan === "left" ? 170 : 140

  // AI opens the user's default agent (`omarchy default agent`), whichever it
  // is, through omarchy-agent; with none set, Omarchy's picker.
  readonly property var menuItems: {
    var items = [
      { key: "ai", icon: "󱚤", label: "AI" },
      { key: "search", icon: "󰍉", label: "Search" },
      { key: "drawer", icon: "󰀻", label: "Apps" },
      { key: "switcher", icon: "󰕰", label: "Stage Control" }
    ]
    if (dockAutohide) items.push({ key: "dock", icon: "󰍜", label: "Dock" })
    return items
  }

  // Where choice i sits, in screen coordinates.
  function itemPoint(i) {
    var n = menuItems.length
    var degrees = menuFan === "left"
      ? 90 + (n > 1 ? i * 180 / (n - 1) : 90)
      : 90 - i * 360 / n
    var a = degrees * Math.PI / 180
    return { x: menuX + menuRadius * Math.cos(a), y: menuY - menuRadius * Math.sin(a) }
  }

  // The choice nearest the finger once it has left the middle.
  function hotAt(x, y) {
    if (Math.hypot(x - menuX, y - menuY) < 46) return ""
    var best = "", bestDistance = 1e9
    for (var i = 0; i < menuItems.length; i++) {
      var p = itemPoint(i)
      var d = Math.hypot(x - p.x, y - p.y)
      if (d < bestDistance) { bestDistance = d; best = menuItems[i].key }
    }
    return best
  }

  function openMenu(x, y, fan) {
    var room = menuRadius + 64
    menuFan = fan
    menuX = fan === "left" ? screenW - 72 : Math.max(room, Math.min(screenW - room, x))
    menuY = Math.max(room, Math.min(screenH - room, y))
    menuHot = ""
    menuOpen = true
  }

  function chooseMenu(key) {
    menuOpen = false
    menuHot = ""
    if (key === "drawer") run("omarchy-shell shell summon devsecai.app-drawer")
    else if (key === "switcher") run("omarchy-shell stage-control toggle")
    else if (key === "search") run("omarchy-shell shell summon marcho78.o-spotlight '{\"buttons\":true}'")
    else if (key === "dock") showDock()
    // Omarchy's default agent (omarchy default agent), in a terminal.
    else if (key === "ai") run("omarchy-agent --pick")
  }

  // The middle of the right edge: swipe in to open the menu, and keep going.
  PanelWindow {
    id: side
    visible: root.tablet && !root.oskUp && !!root.screen
    screen: root.screen
    anchors { right: true }
    implicitWidth: 16
    implicitHeight: Math.round(root.screenH * 0.36)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-gesture-side"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // A hint that this edge does something.
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 3
      anchors.verticalCenter: parent.verticalCenter
      width: 5
      height: 72
      radius: 3
      color: Color.foreground
      opacity: sideSwipe.pressed ? 0.75 : 0.3
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
      id: sideSwipe
      anchors.fill: parent
      preventStealing: true

      property real startX: 0

      // The strip sits centred on the right edge.
      function screenPoint(mouse) {
        return { x: root.screenW - side.width + mouse.x, y: (root.screenH - side.height) / 2 + mouse.y }
      }

      onPressed: function(mouse) { startX = mouse.x }

      onPositionChanged: function(mouse) {
        var p = screenPoint(mouse)
        if (!root.menuOpen && startX - mouse.x >= root.swipeMin) root.openMenu(p.x, p.y, "left")
        if (root.menuOpen) root.menuHot = root.hotAt(p.x, p.y)
      }

      onReleased: if (root.menuOpen && root.menuHot !== "") root.chooseMenu(root.menuHot)
    }
  }

  // Long press on the desktop (wherever no window is): the same menu, all
  // round the finger. Sits just above the wallpaper, under every window.
  PanelWindow {
    visible: root.tablet && !!root.screen
    screen: root.screen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "devsecai-gesture-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      pressAndHoldInterval: 450
      onPressAndHold: function(mouse) { root.openMenu(mouse.x, mouse.y, "around") }
      onPositionChanged: function(mouse) { if (root.menuOpen) root.menuHot = root.hotAt(mouse.x, mouse.y) }
      onReleased: if (root.menuOpen && root.menuHot !== "") root.chooseMenu(root.menuHot)
    }
  }

  // The menu itself: drawn over everything while open; takes the taps once the
  // finger that opened it has let go.
  PanelWindow {
    visible: root.menuOpen && !!root.screen
    screen: root.screen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-radial-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: root.menuOpen ? 0.55 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // A faint ring through the choices, so they read as one menu.
    Rectangle {
      x: root.menuX - width / 2
      y: root.menuY - height / 2
      width: root.menuRadius * 2
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 2
      border.color: Qt.rgba(1, 1, 1, 0.12)
      opacity: root.menuOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) {
        for (var i = 0; i < root.menuItems.length; i++) {
          var p = root.itemPoint(i)
          if (Math.hypot(mouse.x - p.x, mouse.y - p.y) < 52) {
            root.chooseMenu(root.menuItems[i].key)
            return
          }
        }
        root.menuOpen = false
      }
    }

    // Where it opened.
    Rectangle {
      x: root.menuX - width / 2
      y: root.menuY - height / 2
      width: 14
      height: 14
      radius: 7
      color: Color.foreground
      opacity: 0.5
    }

    Repeater {
      model: root.menuItems

      Item {
        id: choice
        required property var modelData
        required property int index
        readonly property var point: root.itemPoint(index)
        readonly property bool hot: root.menuHot === modelData.key
        x: point.x - width / 2
        y: point.y - 42
        width: 132
        height: 124

        // Springs out from the middle, one after another.
        scale: root.menuOpen ? (hot ? 1.18 : 1) : 0.5
        opacity: root.menuOpen ? 1 : 0
        Behavior on scale {
          SequentialAnimation {
            PauseAnimation { duration: root.menuOpen && !choice.hot ? choice.index * 35 : 0 }
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
          }
        }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        RectangularShadow {
          anchors.fill: disc
          radius: disc.radius
          blur: 24
          offset.y: 6
          color: Qt.rgba(0, 0, 0, 0.55)
        }

        Rectangle {
          id: disc
          anchors.horizontalCenter: parent.horizontalCenter
          width: 84
          height: 84
          radius: 42
          color: choice.hot ? Color.accent : Color.popups.background
          border.width: 2
          border.color: choice.hot ? Qt.lighter(Color.accent, 1.3)
            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: choice.modelData.icon
            color: choice.hot ? Color.background : Color.foreground
            font.family: Style.font.family
            font.pixelSize: 34
          }
        }

        // The name on a dark pill, readable over any wallpaper or app.
        Rectangle {
          anchors.top: disc.bottom
          anchors.topMargin: 8
          anchors.horizontalCenter: parent.horizontalCenter
          width: label.implicitWidth + 20
          height: label.implicitHeight + 8
          radius: height / 2
          color: choice.hot ? Color.accent : Qt.rgba(0, 0, 0, 0.7)

          Text {
            id: label
            anchors.centerIn: parent
            text: choice.modelData.label
            color: choice.hot ? Color.background : "white"
            font.family: Style.font.family
            font.pixelSize: 15
            font.bold: true
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

  // ------------------------------------------------------------ full screen

  // A full-screen app has no titlebar; in tablet mode there is no keyboard to
  // leave full screen with. While one fills the screen, the top centre (between
  // the two pull-downs) brings it back: pull down, or tap the pill.
  property bool fullscreen: false

  Timer {
    id: fullscreenCheck
    interval: 120
    onTriggered: fullscreenProc.running = true
  }

  Process {
    id: fullscreenProc
    running: true
    command: ["bash", "-c", "hyprctl activeworkspace -j | jq -r .hasfullscreen"]
    stdout: StdioCollector {
      onStreamFinished: root.fullscreen = String(text || "").trim() === "true"
    }
  }

  function leaveFullscreen() {
    run("hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"unset\" })'")
    fullscreenCheck.restart()
  }

  PanelWindow {
    visible: root.tablet && root.fullscreen && !!root.screen
    screen: root.screen
    anchors { top: true }
    implicitWidth: Math.round(root.screenW * (1 - 2 * root.pullZone))
    implicitHeight: 32
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "devsecai-gesture-fullscreen"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The pill: what to pull, over whatever the app shows there.
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 8
      width: 64
      height: 6
      radius: 3
      color: "white"
      opacity: fullscreenPull.pressed ? 0.95 : 0.6
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.35)
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
      id: fullscreenPull
      anchors.fill: parent
      preventStealing: true
      property real startY: 0
      property bool fired: false
      onPressed: function(mouse) { startY = mouse.y; fired = false }
      onPositionChanged: function(mouse) {
        if (fired || mouse.y - startY < root.swipeMin) return
        fired = true
        root.leaveFullscreen()
      }
      onClicked: if (!fired) root.leaveFullscreen()
    }
  }
}
