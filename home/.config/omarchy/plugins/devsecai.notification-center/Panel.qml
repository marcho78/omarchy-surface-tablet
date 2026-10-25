import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Tablet-mode Notification Center: the notifications Omarchy has recorded,
// grouped by app. Tap one to open its app, slide one away to dismiss it.
// Toggle with: omarchy-shell shell toggle devsecai.notification-center
//
// Omarchy's notification service keeps its history in history.json (and what
// is on screen in live.json); this reads those. Dismissing one card hides it
// here (a plugin can't edit the service's history); Clear All clears it in
// the service too.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: (manifest && manifest.id) || "devsecai.notification-center"
  readonly property string home: Quickshell.env("HOME")
  readonly property string storeDir: home + "/.local/state/omarchy/notifications"
  readonly property string dismissedPath: home + "/.local/state/tablet-mode/notifications-dismissed.json"

  property var historyRows: []
  property var liveRows: []
  property var dismissedKeys: ({})
  property bool dnd: false
  property string expandedGroup: ""
  property bool confirmClear: false

  readonly property var groups: buildGroups(historyRows, liveRows, dismissedKeys)

  // ---------------------------------------------------------------- panel API

  function open(payloadJson) {
    expandedGroup = ""
    confirmClear = false
    opened = true
    historyFile.reload()
    liveFile.reload()
    dndRead.running = true
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

  // ---------------------------------------------------------------- data

  function parseRows(text) {
    try {
      var rows = JSON.parse(String(text || "[]"))
      return Array.isArray(rows) ? rows : []
    } catch (e) {
      return []
    }
  }

  // "omarchy-action" reads as "Omarchy"; anything else keeps its name with
  // a capital first letter.
  function appLabel(row) {
    var name = String(row.source || row.app || "")
    if (name.indexOf("omarchy") === 0) return "Omarchy"
    if (name === "") return "Notification"
    return name.charAt(0).toUpperCase() + name.slice(1)
  }

  function buildGroups(history, live, dismissed) {
    var seen = {}
    var rows = []
    var all = live.concat(history)
    for (var i = 0; i < all.length; i++) {
      var row = all[i]
      var key = String(row.key || "")
      if (key === "" || seen[key] || dismissed[key]) continue
      seen[key] = true
      rows.push(row)
    }
    rows.sort(function(a, b) { return Number(b.ts || 0) - Number(a.ts || 0) })

    var byKey = {}
    var out = []
    for (var j = 0; j < rows.length; j++) {
      var r = rows[j]
      var groupKey = String(r.groupKey || ("app:" + (r.app || "")))
      var group = byKey[groupKey]
      if (!group) {
        group = { key: groupKey, label: appLabel(r), app: String(r.app || r.source || ""), items: [] }
        byKey[groupKey] = group
        out.push(group)
      }
      group.items.push(r)
    }
    return out
  }

  function relativeTime(ts, now) {
    var seconds = Math.max(0, now.getTime() / 1000 - Number(ts || 0))
    if (seconds < 60) return "now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
    return Qt.formatDateTime(new Date(Number(ts) * 1000), "ddd d MMM")
  }

  function hide(keys) {
    var next = {}
    for (var k in dismissedKeys) next[k] = true
    for (var i = 0; i < keys.length; i++) next[String(keys[i])] = true
    dismissedKeys = next
    saveDismissed()
  }

  // Only keys still in the history are worth remembering.
  function saveDismissed() {
    var present = {}
    var all = liveRows.concat(historyRows)
    for (var i = 0; i < all.length; i++) present[String(all[i].key || "")] = true
    var keep = []
    for (var k in dismissedKeys) if (present[k]) keep.push(k)
    dismissedFile.setText(JSON.stringify(keep))
  }

  function clearAll() {
    confirmClear = false
    dismissedKeys = ({})
    dismissedFile.setText("[]")
    historyRows = []
    liveRows = []
    run("omarchy-shell -q notifications dismissAll; omarchy-shell -q notifications clear")
  }

  function openApp(app) {
    // Start it first: hiding the panel tears this object down.
    run("sleep 0.2; " + JSON.stringify(home + "/.local/bin/tablet-open-app") + " " + JSON.stringify(app))
    dismiss()
  }

  FileView {
    id: historyFile
    path: root.storeDir + "/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.historyRows = root.parseRows(text())
  }

  FileView {
    id: liveFile
    path: root.storeDir + "/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.liveRows = root.parseRows(text())
  }

  FileView {
    id: dismissedFile
    path: root.dismissedPath
    printErrors: false
    onLoaded: {
      var keys = root.parseRows(text())
      var next = {}
      for (var i = 0; i < keys.length; i++) next[String(keys[i])] = true
      root.dismissedKeys = next
    }
  }

  Process {
    id: dndRead
    command: ["omarchy-shell", "notifications", "dndState"]
    stdout: StdioCollector {
      onStreamFinished: root.dnd = String(text || "").trim() === "on"
    }
  }

  Process {
    id: dndToggle
    command: ["omarchy-shell", "notifications", "toggleDnd"]
    stdout: StdioCollector {
      onStreamFinished: root.dnd = String(text || "").trim() === "on"
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // ---------------------------------------------------------------- window

  // A swipe up closes the panel, like pushing a sheet back up.
  component SwipeUpArea: MouseArea {
    property real startY: 0
    onPressed: function(mouse) { startY = mouse.y }
    onPositionChanged: function(mouse) { if (startY - mouse.y > 40) root.dismiss() }
  }

  // An edge of a folded stack's lower cards, peeking out below the top card.
  component StackEdge: Rectangle {
    property int depth: 1
    property real cardHeight: 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: cardHeight - 22 + depth * 8
    width: parent.width - depth * 28
    height: 22
    radius: 16
    color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
    border.width: 1
    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)
    opacity: 1 - depth * 0.25
  }

  component Pill: Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    property bool active: false
    property color activeColor: Color.accent
    signal tapped()

    width: pillRow.implicitWidth + 28
    height: 40
    radius: 20
    color: active ? activeColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
    scale: pillArea.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 8

      Text {
        visible: pill.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: pill.icon
        color: pill.active ? Color.background : Color.foreground
        font.family: Style.font.family
        font.pixelSize: 17
      }

      Text {
        visible: pill.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: pill.label
        color: pill.active ? Color.background : Color.foreground
        font.family: Style.font.family
        font.pixelSize: 13
        font.bold: true
      }
    }

    MouseArea {
      id: pillArea
      anchors.fill: parent
      onClicked: pill.tapped()
    }
  }

  OverlayWindow {
    id: window
    shown: root.opened
    WlrLayershell.namespace: "devsecai-notification-center"

    // Tap beside the notifications (the bar's strip included), or swipe up,
    // to close.
    SwipeUpArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    // The dimmed, frosted backdrop starts below the bar, so the bar stays put
    // and readable above the Notification Center.
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

    Flickable {
      id: scroller
      width: Math.min(620, parent.width - 32)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.bar.sizeHorizontal + 16
      contentWidth: width
      contentHeight: Math.max(height, content.implicitHeight + 32)
      boundsBehavior: Flickable.DragOverBounds
      clip: true

      opacity: root.opened ? 1 : 0
      transform: Translate { y: root.opened ? 0 : -24; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
      Behavior on opacity { NumberAnimation { duration: 200 } }

      // Pulled up past the end: put the sheet away.
      onDragEnded: if (contentY > Math.max(0, contentHeight - height) + 80) root.dismiss()

      // Empty space below the list closes too.
      MouseArea {
        width: scroller.contentWidth
        height: scroller.contentHeight
        onClicked: root.dismiss()
      }

      Column {
        id: content
        width: parent.width
        spacing: 12

        // Time and date, large, like the lock screen.
        Column {
          width: parent.width
          spacing: 2
          bottomPadding: 10

          Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font.family: Style.font.family
            font.pixelSize: 56
            font.bold: true
          }

          Text {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: "white"
            opacity: 0.85
            font.family: Style.font.family
            font.pixelSize: 17
          }
        }

        Item {
          width: parent.width
          height: 40

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: "white"
            font.family: Style.font.family
            font.pixelSize: 20
            font.bold: true
          }

          Row {
            anchors.right: parent.right
            spacing: 8

            Pill {
              icon: root.dnd ? "󰂛" : "󰂚"
              label: root.dnd ? "Silenced" : ""
              active: root.dnd
              activeColor: Color.urgent
              onTapped: dndToggle.running = true
            }

            // Two taps to clear, so a stray touch can't wipe everything.
            Pill {
              visible: root.groups.length > 0
              icon: root.confirmClear ? "" : "󰎟"
              label: root.confirmClear ? "Clear all" : "Clear"
              active: root.confirmClear
              activeColor: Color.urgent
              onTapped: root.confirmClear ? root.clearAll() : (root.confirmClear = true)
            }
          }
        }

        // Nothing to show.
        Column {
          visible: root.groups.length === 0
          width: parent.width
          topPadding: 60
          spacing: 10

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰂜"
            color: "white"
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: 44
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No notifications"
            color: "white"
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: 15
          }
        }

        Repeater {
          model: root.groups

          delegate: Column {
            id: group
            required property var modelData
            readonly property var items: modelData.items
            readonly property bool expanded: root.expandedGroup === modelData.key || items.length === 1

            width: content.width
            spacing: 8

            // Header of an opened stack: its app, fold it back, or clear it.
            Item {
              visible: group.items.length > 1 && group.expanded
              width: parent.width
              height: 36

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: group.modelData.label
                color: "white"
                font.family: Style.font.family
                font.pixelSize: 17
                font.bold: true
              }

              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Pill {
                  height: 34
                  label: "Show less"
                  onTapped: root.expandedGroup = ""
                }

                Pill {
                  height: 34
                  icon: "󰅖"
                  onTapped: {
                    var keys = []
                    for (var i = 0; i < group.items.length; i++) keys.push(group.items[i].key)
                    root.hide(keys)
                    root.expandedGroup = ""
                  }
                }
              }
            }

            // Opened (or a single notification): every card.
            Repeater {
              model: group.expanded ? group.items : []

              NotificationCard {
                required property var modelData
                width: group.width
                entry: modelData
                appName: group.modelData.label
                showApp: group.items.length === 1
                timeText: root.relativeTime(modelData.ts, clock.date)
                onTapped: root.openApp(group.modelData.app)
                onDismissed: root.hide([modelData.key])
              }
            }

            // Folded stack: the newest card on top of the others' edges.
            // Tap to open the stack; slide it away to dismiss the whole app.
            Item {
              visible: !group.expanded
              width: parent.width
              height: top.height + 16

              // The cards underneath peek out below the top one.
              StackEdge { depth: 2; cardHeight: top.height; visible: group.items.length > 2 }
              StackEdge { depth: 1; cardHeight: top.height }

              NotificationCard {
                id: top
                width: parent.width
                entry: group.items[0]
                appName: group.modelData.label + "  ·  " + group.items.length
                timeText: root.relativeTime(group.items[0].ts, clock.date)
                onTapped: root.expandedGroup = group.modelData.key
                onDismissed: {
                  var keys = []
                  for (var i = 0; i < group.items.length; i++) keys.push(group.items[i].key)
                  root.hide(keys)
                }
              }
            }
          }
        }
      }
    }
  }
}
