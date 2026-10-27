import QtQuick
import qs.config
import qs.services
import qs.widgets

// Vertical capsules for workspaces 1..Hypr.count. Every slot has the same
// centre spacing; the active capsule grows around its centre (as in the video).
// p: 0 = collapsed metrics, 1 = hover metrics.
Item {
    id: root

    property real p: 0
    property var screen: null
    readonly property int active: Hypr.activeFor(screen)

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    function mix(a: real, b: real): real {
        return a + (b - a) * p;
    }
    readonly property real step: mix(c.pillStep, h.pillStep)
    readonly property real pillW: mix(c.pillWidth, h.pillWidth)
    readonly property real pillH: mix(c.pillHeight, h.pillHeight)
    readonly property real activeW: mix(c.activeWidth, h.activeWidth)
    readonly property real activeH: mix(c.activeHeight, h.activeHeight)

    implicitWidth: (Hypr.count - 1) * step + pillW
    implicitHeight: activeH

    Repeater {
        model: Hypr.count

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property bool occupied: Hypr.occupied(wsId)
            property real on: root.active === wsId ? 1 : 0
            Behavior on on {
                Anim {
                    duration: Theme.fadeIn
                }
            }

            width: root.pillW + (root.activeW - root.pillW) * on
            height: root.pillH + (root.activeH - root.pillH) * on
            radius: width / 2
            x: index * root.step + root.pillW / 2 - width / 2
            y: (root.height - height) / 2
            color: Theme.mix(occupied ? Theme.wsOccupied : Theme.wsEmpty, Theme.accent, on)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.p > 0.9
                onClicked: Hypr.focus(pill.wsId)
            }
        }
    }
}
