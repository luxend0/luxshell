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
//   relLeftC/H  left edge of the group relative to the island centre per state
//               (island/bar/layout.js; default: padLeft of the video layout)
//   style       capsules (video) | dots | numbers (Settings.islandWorkspaceStyle)
Item {
    id: root

    property real pw: 0
    property real ps: 0
    property real cy: Theme.collapsed.centerY
    property var screen: null
    property real relLeftC: c.padLeft - c.width / 2
    property real relLeftH: h.padLeft - h.width / 2
    property string style: "capsules"
    property bool interactive: true
    property real t: 1               // BarWidget contract (sizes follow ps)
    property real textOpacity: 1
    readonly property int active: Hypr.activeFor(screen)

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    function mix(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }
    readonly property bool dots: style === "dots"
    readonly property bool numbers: style === "numbers"
    // per state: step, resting size, active size
    readonly property real stepC: dots ? wm.dotStep[0] : numbers ? wm.numberStep[0] : c.pillStep
    readonly property real stepH: dots ? wm.dotStep[1] : numbers ? wm.numberStep[1] : h.pillStep
    readonly property real restWC: dots ? wm.dotSize[0] : numbers ? wm.numberSize[0] : c.pillWidth
    readonly property real restWH: dots ? wm.dotSize[1] : numbers ? wm.numberSize[1] : h.pillWidth
    // rest centre of capsule i relative to the island centre
    function restC(i: int): real {
        return relLeftC + i * stepC + restWC / 2;
    }
    function restH(i: int): real {
        return relLeftH + i * stepH + restWH / 2;
    }
    readonly property real pillW: dots ? mix(wm.dotSize[0], wm.dotSize[1], ps) : mix(c.pillWidth, h.pillWidth, ps)
    readonly property real pillH: dots ? pillW : mix(c.pillHeight, h.pillHeight, ps)
    readonly property real activeW: dots ? mix(wm.dotActive[0], wm.dotActive[1], ps) : mix(c.activeWidth, h.activeWidth, ps)
    readonly property real activeH: dots ? pillW : mix(c.activeHeight, h.activeHeight, ps)
    readonly property real digit: mix(wm.numberSize[0], wm.numberSize[1], ps)

    // BarWidget contract: widths per state, live extents of the group (widgets riding it)
    readonly property int n: Hypr.count
    readonly property real wC: (n - 1) * stepC + (dots ? wm.dotActive[0] : restWC)
    readonly property real wH: (n - 1) * stepH + (dots ? wm.dotActive[1] : restWH)
    readonly property real groupLeft: width / 2 + mix(restC(0), restH(0), Motion.lagged(pw, Motion.workspaceLag(0, n))) - (numbers ? digit : pillW) / 2
    readonly property real groupRight: width / 2 + mix(restC(n - 1), restH(n - 1), Motion.lagged(pw, Motion.workspaceLag(n - 1, n))) + (numbers ? digit : pillW) / 2

    Repeater {
        model: Hypr.count

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property bool occupied: Hypr.occupied(wsId)
            readonly property real k: Motion.workspaceLag(index, Hypr.count)
            readonly property real cx: root.width / 2 + root.mix(root.restC(index), root.restH(index), Motion.lagged(root.pw, k))
            property real on: root.active === wsId ? 1 : 0
            Behavior on on {
                Anim {
                    ms: Theme.fadeIn
                }
            }

            width: root.numbers ? root.digit : root.pillW + (root.activeW - root.pillW) * on
            height: root.numbers ? root.digit * 1.3 : root.pillH + (root.activeH - root.pillH) * on
            radius: root.dots || !root.numbers ? Math.min(width, height) / 2 : 0
            x: cx - width / 2
            y: root.cy - height / 2
            color: root.numbers ? "transparent" : Theme.mix(occupied ? Theme.wsOccupied : Theme.wsEmpty, Theme.accent, on)

            Txt {
                visible: root.numbers
                anchors.centerIn: parent
                text: pill.wsId
                font.pixelSize: Math.round(root.digit)
                font.weight: Font.DemiBold
                color: Theme.mix(pill.occupied ? Theme.textSecondary : Theme.muted, Theme.accent, pill.on)
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.interactive && root.pw > 0.9
                onClicked: Hypr.focus(pill.wsId)
            }
        }
    }
}
