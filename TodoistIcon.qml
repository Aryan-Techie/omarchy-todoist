import QtQuick
import qs.Commons

// Todoist's checklist motif (three tapered bars), hand-drawn like
// DropboxIcon.qml/TailscaleIcon.qml rather than imported from the fixed-
// brand-color assets/todoist-icon.svg — this recolors with `color` (theme
// foreground/accent) so it matches the built-in wifi/bluetooth/display
// icons instead of staying a fixed red mark regardless of theme.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Column {
    anchors.centerIn: parent
    width: root.iconSize
    spacing: root.iconSize * 0.18

    Bar { widthFactor: 1.0 }
    Bar { widthFactor: 0.75 }
    Bar { widthFactor: 0.55 }
  }

  component Bar: Rectangle {
    property real widthFactor: 1.0
    anchors.left: parent.left
    width: root.iconSize * widthFactor
    height: root.iconSize * 0.16
    radius: height / 2
    color: root.color
  }
}
