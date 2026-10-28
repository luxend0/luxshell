import QtQuick
import qs.config

// Keyboard selection outline of the notification center (the control center's FocusRing
// look, but driven by the center's own selection instead of the Cc singleton).
// gap < 0 draws it inside the target.
Rectangle {
    property Item target: parent
    property real gap: 3
    property bool shown: false

    anchors.fill: target
    anchors.margins: -(gap + border.width)
    radius: Math.max(0, (target.radius ?? 0) + gap + border.width)
    color: "transparent"
    border.width: 2
    border.color: Theme.nc.ring
    visible: shown
}
