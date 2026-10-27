import QtQuick
import qs.config
import qs.services
import qs.widgets

// Vertical capsules for workspaces 1..Hypr.count. Every slot has the same centre
// spacing; the active capsule grows around its centre (as in the video).
// Fills the bar: each capsule places its own centre relative to the island centre,
// between its collapsed and hover rest position, with its own lag (Motion.lag):
// the capsule at the front of the motion leads (inner one on close, outer on open).
//   pw  horizontal progress   ps  size progress   cy  vertical centre
Item {
    id: root

    property real pw: 0
    property real ps: 0
    property real cy: Theme.collapsed.centerY
    property var screen: null
    readonly property int active: Hypr.activeFor(screen)

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    function mix(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }
    // rest centre of capsule i relative to the island centre in layout g
    function rest(g: QtObject, i: int): real {
        return g.padLeft + i * g.pillStep + g.pillWidth / 2 - g.width / 2;
    }
    readonly property real pillW: mix(c.pillWidth, h.pillWidth, ps)
    readonly property real pillH: mix(c.pillHeight, h.pillHeight, ps)
    readonly property real activeW: mix(c.activeWidth, h.activeWidth, ps)
    readonly property real activeH: mix(c.activeHeight, h.activeHeight, ps)

    Repeater {
        model: Hypr.count

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property bool occupied: Hypr.occupied(wsId)
            readonly property real k: Motion.workspaceLag(index, Hypr.count)
            readonly property real cx: root.width / 2 + root.mix(root.rest(root.c, index), root.rest(root.h, index), Motion.lagged(root.pw, k))
            property real on: root.active === wsId ? 1 : 0
            Behavior on on {
                Anim {
                    ms: Theme.fadeIn
                }
            }

            width: root.pillW + (root.activeW - root.pillW) * on
            height: root.pillH + (root.activeH - root.pillH) * on
            radius: width / 2
            x: cx - width / 2
            y: root.cy - height / 2
            color: Theme.mix(occupied ? Theme.wsOccupied : Theme.wsEmpty, Theme.accent, on)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.pw > 0.9
                onClicked: Hypr.focus(pill.wsId)
            }
        }
    }
}
