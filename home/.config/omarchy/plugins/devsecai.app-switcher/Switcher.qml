import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Tablet-mode app switcher, like iOS's and Android's: every open window as a
// live card in a row, most recently used first, minimized ones included. Tap
// a card to switch to that window, slide a card up to close it, tap above or
// below the row to go back.
// Open with: omarchy-shell shell summon devsecai.app-switcher (the gestures
// plugin does, for a swipe up from the bottom edge held still).
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: (manifest && manifest.id) || "devsecai.app-switcher"
  readonly property string home: Quickshell.env("HOME")

  // Card size: a good share of the screen, shaped like it.
  readonly property real screenAspect: window.height > 0 ? window.width / window.height : 1.5
  readonly property real cardWidth: Math.min(window.width * 0.42, 620)
  readonly property real cardHeight: 38 + cardWidth / screenAspect

  // ---------------------------------------------------------------- windows

  function appInfo(appClass) {
    var entry = appClass ? DesktopEntries.heuristicLookup(appClass) : null
    var name = entry && entry.name ? String(entry.name) : appClass
    var icon = entry && entry.icon ? String(entry.icon) : appClass.toLowerCase()
    var source = icon.indexOf("/") === 0 ? "file://" + icon : Quickshell.iconPath(icon, true)
    return { name: name, icon: source }
  }

  // Open windows on workspaces and minimized to the dock; not ones on other
  // special workspaces (scratchpads), not the screensaver.
  readonly property var windows: {
    var rows = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      if (!t || !t.wayland) continue
      var ipc = t.lastIpcObject || {}
      var workspace = t.workspace ? String(t.workspace.name) : String(ipc.workspace ? ipc.workspace.name : "")
      if (workspace.indexOf("special:") === 0 && workspace !== "special:minimized") continue
      var appClass = String(ipc.class || t.wayland.appId || "")
      if (appClass === "org.omarchy.screensaver") continue
      var address = String(t.address)
      if (address.indexOf("0x") !== 0) address = "0x" + address
      var size = ipc.size || [16, 10]
      var info = appInfo(appClass)
      rows.push({
        toplevel: t,
        address: address,
        name: info.name || String(t.title || ""),
        icon: info.icon,
        aspect: size[1] > 0 ? size[0] / size[1] : 1.6,
        order: ipc.focusHistoryID !== undefined ? Number(ipc.focusHistoryID) : 9999
      })
    }
    rows.sort(function(a, b) { return a.order - b.order })
    return rows
  }

  // ---------------------------------------------------------------- panel API

  function open(payloadJson) {
    Hyprland.refreshToplevels()
    opened = true
    list.currentIndex = 0
    list.positionViewAtBeginning()
  }

  function close() {
    opened = false
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function run(command) {
    Quickshell.execDetached(["bash", "-c", command])
  }

  function focusWindow(address) {
    run("sleep 0.15; " + JSON.stringify(home + "/.local/bin/tablet-open-app") + " --address " + address)
    dismiss()
  }

  function closeWindow(address) {
    run("hyprctl dispatch 'hl.dsp.window.close({ window = \"address:" + address + "\" })'")
  }

  // ---------------------------------------------------------------- window

  OverlayWindow {
    id: window
    shown: root.opened
    WlrLayershell.namespace: "devsecai-app-switcher"

    // Tap above or below the cards to go back.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    // Dimmed, frosted backdrop below the bar, which stays put above it.
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.bar.sizeHorizontal
      color: "black"
      opacity: root.opened ? 0.45 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()
    }

    ListView {
      id: list
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Style.bar.sizeHorizontal / 2
      height: root.cardHeight
      orientation: ListView.Horizontal
      spacing: 32
      model: root.windows
      boundsBehavior: Flickable.DragOverBounds

      // Cards settle centred, one at a time, as on a phone.
      readonly property real side: (width - root.cardWidth) / 2
      preferredHighlightBegin: side
      preferredHighlightEnd: side + root.cardWidth
      highlightRangeMode: ListView.StrictlyEnforceRange
      highlightMoveDuration: 250

      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 1.06
      Behavior on opacity { NumberAnimation { duration: 200 } }
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

      delegate: WindowCard {
        required property var modelData
        width: root.cardWidth
        height: root.cardHeight
        toplevel: modelData.toplevel
        appName: modelData.name
        iconSource: modelData.icon
        windowAspect: modelData.aspect
        live: root.opened
        onTapped: root.focusWindow(modelData.address)
        onCloseRequested: root.closeWindow(modelData.address)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.windows.length === 0
      text: "No open apps"
      color: "white"
      opacity: 0.75
      font.family: Style.font.family
      font.pixelSize: 17
    }
  }
}
