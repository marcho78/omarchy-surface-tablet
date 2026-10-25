import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Tablet-mode app drawer, laid out like Android's drawer and iPadOS's App
// Library: a search pill, a row of suggestions (recently opened from here),
// then every app A to Z as large icons with names. Rises from the bottom over
// a frosted background; tap an app to open it, swipe down or tap beside the
// grid to close. Toggle with: omarchy-shell shell toggle devsecai.app-drawer
//
// Apps, icons, search ranking and launching all come from Omarchy's app
// library, the same one its own app grid and menu use.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: (manifest && manifest.id) || "devsecai.app-drawer"
  readonly property string home: Quickshell.env("HOME")
  readonly property var appLibrary: shell ? shell.appLibrary : null

  property string query: ""
  property var apps: []
  property var allApps: []
  property var recentIds: []
  property bool keyboardShown: false

  readonly property int suggestionCount: Math.min(columns, 6)
  // Suggestions load just after the drawer opens; the header grows then, so
  // scroll back to show it.
  onSuggestionsChanged: if (opened && query === "") Qt.callLater(function() { grid.positionViewAtBeginning() })

  readonly property var suggestions: {
    var out = []
    for (var i = 0; i < recentIds.length && out.length < suggestionCount; i++) {
      for (var j = 0; j < allApps.length; j++) {
        if (String(allApps[j].id) === recentIds[i]) {
          out.push(allApps[j])
          break
        }
      }
    }
    return out
  }

  // Grid geometry: whole columns of roughly phone-launcher size.
  readonly property int iconSize: 64
  readonly property real gridWidth: Math.min(window.width - 48, 1180)
  readonly property int columns: Math.max(4, Math.floor(gridWidth / 132))
  readonly property real cellWidth: gridWidth / columns
  readonly property int cellHeight: 122

  // ---------------------------------------------------------------- panel API

  function open(payloadJson) {
    query = ""
    search.text = ""
    if (appLibrary) appLibrary.refreshIcons()
    rebuild()
    opened = true
    grid.positionViewAtBeginning()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function close() {
    opened = false
    if (keyboardShown) {
      keyboardShown = false
      run(home + "/.local/bin/surface-osk hide")
    }
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function run(command) {
    Quickshell.execDetached(["bash", "-c", command])
  }

  // ---------------------------------------------------------------- apps

  function entriesFor(text) {
    if (!appLibrary) return []
    return appLibrary.sortedEntries(text).map(function(row) { return row.entry || row })
  }

  function rebuild() {
    allApps = entriesFor("")
    apps = query === "" ? allApps : entriesFor(query)
  }

  function nameOf(entry) {
    return appLibrary ? appLibrary.entryName(entry) : String(entry.name || "")
  }

  function iconOf(entry) {
    return appLibrary ? appLibrary.iconSource(entry.icon) : ""
  }

  function launch(entry) {
    if (!entry || !appLibrary) return
    var id = String(entry.id || "")
    var next = [id]
    for (var i = 0; i < recentIds.length && next.length < 12; i++)
      if (recentIds[i] !== id) next.push(recentIds[i])
    recentIds = next
    recentFile.setText(JSON.stringify(next))
    // Launch first: hiding the drawer tears this object down.
    appLibrary.launch(id, nameOf(entry))
    dismiss()
  }

  function showKeyboard() {
    search.forceActiveFocus()
    if (!keyboardShown) {
      keyboardShown = true
      run(home + "/.local/bin/surface-osk show")
    }
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() { if (root.opened) root.rebuild() }
  }

  FileView {
    id: recentFile
    path: root.home + "/.local/state/tablet-mode/recent-apps.json"
    printErrors: false
    onLoaded: {
      try {
        var ids = JSON.parse(text())
        root.recentIds = Array.isArray(ids) ? ids.map(String) : []
      } catch (e) {
        root.recentIds = []
      }
    }
  }

  // ---------------------------------------------------------------- window

  OverlayWindow {
    id: window
    shown: root.opened
    WlrLayershell.namespace: "devsecai-app-drawer"

    // Tap outside the grid to close.
    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: root.opened ? 0.35 : 0
      Behavior on opacity { NumberAnimation { duration: 220 } }

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: sheet
      anchors.fill: parent
      opacity: root.opened ? 1 : 0
      transform: Translate {
        y: root.opened ? 0 : 70
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
      }
      Behavior on opacity { NumberAnimation { duration: 220 } }

      // Search pill. Tap it for the on-screen keyboard; with a keyboard
      // attached, just start typing.
      Rectangle {
        id: searchPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.bar.sizeHorizontal + 22
        width: Math.min(560, parent.width - 48)
        height: 50
        radius: 25
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, search.activeFocus ? 0.18 : 0.13)
        border.width: 1
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
          id: searchIcon
          anchors.left: parent.left
          anchors.leftMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          text: "󰍉"
          color: "white"
          opacity: 0.75
          font.family: Style.font.family
          font.pixelSize: 20
        }

        TextInput {
          id: search
          anchors.left: searchIcon.right
          anchors.leftMargin: 12
          anchors.right: clearButton.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          color: "white"
          selectionColor: Color.accent
          font.family: Style.font.family
          font.pixelSize: 17
          clip: true
          onTextChanged: {
            root.query = text.trim()
            root.rebuild()
            grid.positionViewAtBeginning()
          }
          Keys.onReturnPressed: if (root.apps.length > 0) root.launch(root.apps[0])
          Keys.onEnterPressed: if (root.apps.length > 0) root.launch(root.apps[0])
          Keys.onEscapePressed: {
            if (text !== "") text = ""
            else root.dismiss()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Search apps"
            color: "white"
            opacity: 0.55
            font: search.font
          }
        }

        Text {
          id: clearButton
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          visible: search.text !== ""
          text: "󰅙"
          color: "white"
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: 20

          TapHandler { onTapped: search.text = "" }
        }

        TapHandler {
          onTapped: root.showKeyboard()
        }
      }

      GridView {
        id: grid
        anchors.top: searchPill.bottom
        anchors.topMargin: 22
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.gridWidth
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        clip: true
        boundsBehavior: Flickable.DragOverBounds
        model: root.apps

        // Pulled down from the top: put the drawer away, as on a phone.
        onDragEnded: if (verticalOvershoot < -90) root.dismiss()

        header: Column {
          width: grid.width
          visible: root.query === "" && root.suggestions.length > 0
          height: visible ? implicitHeight : 0
          spacing: 6

          Row {
            Repeater {
              model: root.suggestions

              AppIcon {
                required property var modelData
                width: root.cellWidth
                height: root.cellHeight
                iconSize: root.iconSize
                name: root.nameOf(modelData)
                iconSource: root.iconOf(modelData)
                onTapped: root.launch(modelData)
              }
            }
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 32
            height: 1
            color: "white"
            opacity: 0.15
          }

          Item { width: 1; height: 10 }
        }

        delegate: AppIcon {
          required property var modelData
          width: grid.cellWidth
          height: grid.cellHeight
          iconSize: root.iconSize
          name: root.nameOf(modelData)
          iconSource: root.iconOf(modelData)
          onTapped: root.launch(modelData)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 60
          visible: root.apps.length === 0 && root.query !== ""
          text: "No apps match “" + root.query + "”"
          color: "white"
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: 15
        }
      }
    }
  }
}
