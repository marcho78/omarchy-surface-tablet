import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons

// One open window in the app switcher: its app's icon and name above a live
// picture of the window. Tap the picture to switch to the window; slide it up
// to close the window, as on iOS and Android.
Item {
  id: card

  property var toplevel: null
  property string appName: ""
  property string iconSource: ""
  // Width over height, until the window's picture arrives with its own size.
  property real windowAspect: 1.5
  property bool live: true

  signal tapped()
  signal closeRequested()

  readonly property int headerHeight: 38
  readonly property real boxHeight: height - headerHeight
  readonly property real aspect: view.hasContent && view.sourceSize.height > 0
    ? view.sourceSize.width / view.sourceSize.height : windowAspect

  // Slid up past this share of its height, the card closes its window.
  readonly property real closeShare: 0.28
  property real lift: 0
  property bool closing: false

  Item {
    id: body
    width: card.width
    height: card.height
    y: card.lift
    opacity: 1 - Math.min(1, -card.lift / card.height) * 0.85

    Behavior on y {
      enabled: !slide.active
      NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Row {
      id: header
      anchors.horizontalCenter: parent.horizontalCenter
      height: card.headerHeight
      spacing: 10

      Image {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        source: card.iconSource
        sourceSize.width: 52
        sourceSize.height: 52
        asynchronous: true
        visible: status === Image.Ready
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, card.width - 40)
        text: card.appName
        elide: Text.ElideRight
        color: "white"
        font.family: Style.font.family
        font.pixelSize: 15
        font.bold: true
      }
    }

    // The window's picture, fitted into the box below the header, rounded.
    Item {
      id: frame
      anchors.horizontalCenter: parent.horizontalCenter
      y: card.headerHeight
      width: Math.min(card.width, card.boxHeight * card.aspect)
      height: width / card.aspect
      scale: tap.pressed && !slide.active ? 0.97 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Rectangle {
        id: mask
        anchors.fill: parent
        radius: 18
        visible: false
        layer.enabled: true
      }

      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: mask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }

        Rectangle {
          anchors.fill: parent
          color: Color.background
        }

        ScreencopyView {
          id: view
          anchors.fill: parent
          captureSource: card.toplevel ? card.toplevel.wayland : null
          live: card.live
        }

        // Until the picture arrives: the app's icon on the window colour.
        Image {
          anchors.centerIn: parent
          width: 64
          height: 64
          visible: !view.hasContent
          source: card.iconSource
          sourceSize.width: 128
          sourceSize.height: 128
          asynchronous: true
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
      }

      TapHandler {
        id: tap
        onTapped: if (!card.closing) card.tapped()
      }

      DragHandler {
        id: slide
        target: null
        xAxis.enabled: false
        enabled: !card.closing
        onActiveTranslationChanged: if (active) card.lift = Math.min(0, activeTranslation.y)
        onActiveChanged: {
          if (active) return
          if (-card.lift > card.height * card.closeShare) {
            card.closing = true
            card.lift = -card.height * 1.5
            closeAfterSlide.start()
          } else {
            card.lift = 0
          }
        }
      }
    }
  }

  // Close once the card has slid off; if the window is still here a moment
  // later (an app asking to save first, say), bring the card back.
  Timer {
    id: closeAfterSlide
    interval: 200
    onTriggered: {
      card.closeRequested()
      stillOpen.start()
    }
  }

  Timer {
    id: stillOpen
    interval: 1500
    onTriggered: {
      card.closing = false
      card.lift = 0
    }
  }
}
