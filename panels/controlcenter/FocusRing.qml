import QtQuick
import qs.config

// Keyboard selection outline around its parent (rounded like it). gap < 0 draws
// it inside the parent (rows inside a clipping list).
Rectangle {
    property Item target: parent
    property real gap: 3

    anchors.fill: target
    anchors.margins: -(gap + border.width)
    radius: Math.max(0, (target.radius ?? 0) + gap + border.width)
    color: "transparent"
    border.width: 2
    border.color: Theme.textSecondary
    visible: Cc.isCurrent(target)
}
