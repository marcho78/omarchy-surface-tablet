import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons

// Sound, Android style: the system volume, the microphone, a slider for each
// app playing sound, and where sound goes (and comes from). Tap a slider's icon
// to mute. Lists hold plain ids and names, never PipeWire nodes: a node removed
// while a delegate still holds it crashes the shell (Omarchy's audio panel does
// the same); each row finds its node again with nodeFor().
Column {
  id: page

  signal back()

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property color subtle: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

  spacing: 14

  // ------------------------------------------------------------ nodes

  function props(node) {
    return node && node.ready && node.properties ? node.properties : {}
  }

  function isPlayback(node) {
    if (!node || !node.isStream) return false
    if (node.isSink === true) return true
    return String(node.type || "").indexOf("Output") !== -1
  }

  readonly property var sinkNodes: nodes.filter(function(n) { return n && n.isSink && !n.isStream && !!n.audio })
  readonly property var sourceNodes: nodes.filter(function(n) {
    return n && !n.isSink && !n.isStream && !!n.audio && String(n.name || "") !== "quickshell"
  })
  readonly property var streamNodes: nodes.filter(function(n) {
    return isPlayback(n) && !!n.audio && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0
  })

  PwObjectTracker { objects: page.sinkNodes }
  PwObjectTracker { objects: page.sourceNodes }
  PwObjectTracker { objects: page.streamNodes }
  PwObjectTracker { objects: [page.sink, page.source].filter(function(n) { return !!n }) }

  function rows(list) {
    var out = []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].id !== undefined) out.push({ id: list[i].id, name: String(list[i].name || "") })
    return out
  }

  // Snapshots taken a moment after PipeWire changes, so a removal has settled.
  property var sinkRows: []
  property var sourceRows: []
  property var streamRows: []

  function snapshot() {
    sinkRows = rows(sinkNodes)
    sourceRows = rows(sourceNodes)
    streamRows = rows(streamNodes)
  }

  onNodesChanged: settle.restart()
  onVisibleChanged: if (visible) snapshot()
  Component.onCompleted: snapshot()

  Timer {
    id: settle
    interval: 150
    onTriggered: page.snapshot()
  }

  function nodeFor(row) {
    if (!row) return null
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.id === row.id && String(n.name || "") === row.name) return n
    }
    return null
  }

  function deviceName(node) {
    if (!node) return "Unknown"
    var p = props(node)
    // The machine's own sound card says what it is to a person, not its chip.
    var id = String(node.name || "")
    if (/^alsa_(output|input)\.pci/.test(id) && !/hdmi/i.test(id))
      return node.isSink ? "Speakers" : "Built-in microphone"
    var label = String(node.nickname || p["node.nick"] || node.description || p["node.description"] || node.name || "Unknown")
    return label.replace(/^Built-?in Audio\s+/i, "").replace(/\s+(Output|Input)$/i, "")
  }

  function appName(node) {
    var p = props(node)
    return String(p["application.name"] || node.description || p["media.name"] || node.name || "App")
  }

  function appDetail(node) {
    var p = props(node)
    // A file player names the whole path; the file is enough.
    var media = String(p["media.name"] || "").replace(/^.*\//, "")
    return media !== "" && media !== appName(node) ? media : ""
  }

  function deviceGlyph(node, input) {
    var blob = String([node ? node.name : "", node ? node.description : "", props(node)["device.icon-name"] || ""].join(" ")).toLowerCase()
    if (/head(phone|set)|earbud|airpod/.test(blob)) return "󰋋"
    if (blob.indexOf("bluetooth") !== -1 || blob.indexOf("bluez") !== -1) return "󰂯"
    if (blob.indexOf("hdmi") !== -1 || blob.indexOf("display") !== -1) return "󰍹"
    return input ? "󰍬" : "󰓃"
  }

  function volumeGlyph(node) {
    if (!node || !node.audio || node.audio.muted) return "󰝟"
    var v = node.audio.volume
    return v > 0.66 ? "󰕾" : (v > 0.25 ? "󰖀" : "󰕿")
  }

  // ------------------------------------------------------------ pieces

  component Heading: Text {
    color: Color.foreground
    opacity: 0.6
    font.family: Style.font.family
    font.pixelSize: 12
    font.bold: true
  }

  // A labelled slider: what it is (and what is playing) above, the slider below.
  component Level: Column {
    id: level
    property var node: null
    property string label: ""
    property string detail: ""
    property string glyph: ""
    readonly property bool muted: !!node && !!node.audio && node.audio.muted

    width: page.width
    spacing: 6

    Row {
      width: parent.width
      spacing: 8

      Text {
        text: level.label
        color: Color.foreground
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width * 0.55)
        font.family: Style.font.family
        font.pixelSize: 14
        font.bold: true
      }

      Text {
        visible: text !== ""
        text: level.muted ? "Muted" : level.detail
        color: Color.foreground
        opacity: 0.55
        elide: Text.ElideRight
        width: parent.width * 0.45 - 8
        font.family: Style.font.family
        font.pixelSize: 12
      }
    }

    PillSlider {
      width: parent.width
      icon: level.glyph
      opacity: level.muted ? 0.55 : 1
      value: level.node && level.node.audio ? level.node.audio.volume : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      onMoved: function(v) {
        if (!level.node || !level.node.audio) return
        level.node.audio.volume = v
        if (level.node.audio.muted && v > 0) level.node.audio.muted = false
      }
      onIconTapped: if (level.node && level.node.audio) level.node.audio.muted = !level.node.audio.muted
    }
  }

  // A device to send sound to (or take it from); the one in use is lit.
  component Device: Rectangle {
    id: device
    property string glyph: ""
    property string label: ""
    property bool selected: false
    signal tapped()

    width: page.width
    height: 52
    radius: 18
    color: selected ? Color.accent : page.subtle
    scale: area.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
      id: disc
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      width: 36
      height: 36
      radius: 18
      color: device.selected ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)

      Text {
        anchors.centerIn: parent
        text: device.glyph
        color: device.selected ? Color.background : Color.foreground
        font.family: Style.font.family
        font.pixelSize: 18
      }
    }

    Text {
      anchors.left: disc.right
      anchors.leftMargin: 12
      anchors.right: check.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: device.label
      elide: Text.ElideRight
      color: device.selected ? Color.background : Color.foreground
      font.family: Style.font.family
      font.pixelSize: 14
      font.bold: device.selected
    }

    Text {
      id: check
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: "󰄬"
      visible: device.selected
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: 18
    }

    MouseArea {
      id: area
      anchors.fill: parent
      onClicked: device.tapped()
    }
  }

  // ------------------------------------------------------------ page

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
      text: "Sound"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 18
      font.bold: true
    }
  }

  Level {
    node: page.sink
    label: "System"
    detail: page.deviceName(page.sink)
    glyph: page.volumeGlyph(page.sink)
  }

  Level {
    visible: !!page.source
    node: page.source
    label: "Microphone"
    detail: page.deviceName(page.source)
    glyph: muted ? "󰍭" : "󰍬"
  }

  Heading { text: "APPS" }

  Text {
    visible: page.streamRows.length === 0
    text: "Nothing is playing"
    color: Color.foreground
    opacity: 0.5
    font.family: Style.font.family
    font.pixelSize: 13
  }

  Repeater {
    model: page.streamRows

    Level {
      required property var modelData
      node: page.nodeFor(modelData)
      label: node ? page.appName(node) : ""
      detail: node ? page.appDetail(node) : ""
      glyph: page.volumeGlyph(node)
    }
  }

  Heading {
    visible: page.sinkRows.length > 1
    text: "PLAY ON"
  }

  Repeater {
    model: page.sinkRows.length > 1 ? page.sinkRows : []

    Device {
      required property var modelData
      readonly property var node: page.nodeFor(modelData)
      glyph: page.deviceGlyph(node, false)
      label: page.deviceName(node)
      selected: !!node && !!page.sink && node.id === page.sink.id
      onTapped: if (node) Pipewire.preferredDefaultAudioSink = node
    }
  }

  Heading {
    visible: page.sourceRows.length > 1
    text: "RECORD FROM"
  }

  Repeater {
    model: page.sourceRows.length > 1 ? page.sourceRows : []

    Device {
      required property var modelData
      readonly property var node: page.nodeFor(modelData)
      glyph: page.deviceGlyph(node, true)
      label: page.deviceName(node)
      selected: !!node && !!page.source && node.id === page.source.id
      onTapped: if (node) Pipewire.preferredDefaultAudioSource = node
    }
  }
}
