import QtQuick
import qs.Commons

// A thick, finger-sized slider with its icon inside, like iOS Control Center.
// Drag or tap anywhere along it; tapping the icon runs iconTapped.
Rectangle {
  id: slider

  property real value: 0 // 0..1
  property string icon: ""

  signal moved(real value)
  signal iconTapped()

  implicitHeight: 52
  radius: height / 2
  clip: true
  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

  Rectangle {
    id: fill
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.max(slider.height, slider.width * Math.max(0, Math.min(1, slider.value)))
    radius: slider.radius
    color: Color.accent
    Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    preventStealing: true

    function update(mouse) {
      var v = Math.max(0, Math.min(1, mouse.x / width))
      slider.value = v
      slider.moved(v)
    }

    onPressed: function(mouse) {
      if (mouse.x < slider.height) return
      update(mouse)
    }
    onPositionChanged: function(mouse) { if (pressed && mouse.x >= 0) update(mouse) }
    onClicked: function(mouse) { if (mouse.x < slider.height) slider.iconTapped() }
  }

  Text {
    x: (slider.height - width) / 2
    anchors.verticalCenter: parent.verticalCenter
    text: slider.icon
    color: Color.background
    font.family: Style.font.family
    font.pixelSize: 20
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: 18
    anchors.verticalCenter: parent.verticalCenter
    text: Math.round(slider.value * 100) + "%"
    // Dark on the fill once the fill reaches it, so it stays readable.
    readonly property bool onFill: fill.width > x - 6
    color: onFill ? Color.background : Color.foreground
    opacity: onFill ? 0.85 : 0.75
    font.family: Style.font.family
    font.pixelSize: 13
    font.bold: true
  }
}
