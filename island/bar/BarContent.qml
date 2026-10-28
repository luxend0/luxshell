import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// Content of the island when no panel is shown, ONE layout for collapsed and hover.
// Shared elements (workspaces, clock, signal, volume) move and scale between their
// collapsed and hover rest positions; hover-only elements fade in late.
//
// Driven by the island's content progress (Island.cxp/cyp/wyp, config/Motion.qml):
//   pw  horizontal progress (positions, clock size)   ph  vertical progress (rows, sizes)
//   pr  vertical progress of the workspace row (trails ph in both directions)
// While opening, the content trails the shape; while closing it moves with it.
// Each element follows its own lagged copy q = p^k (Motion.lag), so the elements
// at the front of the motion lead (ref/14: signal before volume, inner capsule first).
// Shared elements are placed relative to the island centre, independent of the
// animated body width (the body clips); the hover-only top row rides the edges.
Item {
    id: bar

    property real pw: 0
    property real ph: 0
    property real pr: 0
    property real topAlpha: 0 // own animation in Island: late in, out at once
    property var screen: null
    readonly property bool holdOpen: tray.openMenus > 0

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property var lag: Motion.lag
    readonly property var reveal: Motion.reveal
    readonly property real statusOpacity: mix(c.statusOpacity, h.statusOpacity, pw)

    function mix(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }
    // x for a point given relative to the island centre in both layouts
    function cx(relC: real, relH: real, t: real): real {
        return width / 2 + mix(relC, relH, t);
    }

    // ---- left: workspaces (row 2 in hover) ---------------------------------
    Workspaces {
        anchors.fill: parent
        screen: bar.screen
        pw: bar.pw
        ps: Motion.lagged(bar.pr, bar.lag.workspacesSize)
        cy: bar.mix(bar.c.centerY, bar.h.row2Y, bar.pr)
    }

    // ---- centre: clock, date joins on hover (group stays centred) ----------
    MorphText {
        id: clock
        readonly property real cx: bar.cx(0, -(bar.h.dateGap + date.implicitWidth) / 2, bar.pw)
        readonly property real cy: bar.mix(bar.c.centerY, bar.h.clockY, Motion.lagged(bar.ph, bar.lag.clockY))
        readonly property real baseY: cy + visualCapHeight / 2
        text: Clock.time
        size: bar.mix(bar.c.clockSize, bar.h.clockSize, bar.pw)
        font.weight: Font.Medium
        x: cx - width / 2
        y: cy - anchorY
    }
    Txt {
        id: date
        // shrinks with the clock, baseline on the clock's baseline
        readonly property real sc: clock.size / bar.h.clockSize
        visible: opacity > 0.001
        opacity: Motion.smooth(bar.pw, bar.reveal.date)
        text: Clock.date
        color: Theme.textDim
        font.pixelSize: bar.h.dateSize
        font.weight: Font.Medium
        scale: sc
        transformOrigin: Item.Left
        x: clock.cx + clock.visualWidth / 2 + bar.h.dateGap * sc
        y: clock.baseY - height / 2 - (baselineOffset - height / 2) * sc
    }

    // ---- right: volume + signal (row 2 in hover, dimmed) --------------------
    Icon {
        id: volume
        readonly property real rightX: bar.cx(bar.c.width / 2 - bar.c.padRight, bar.h.width / 2 - bar.h.padRight, Motion.lagged(bar.pw, bar.lag.volumeX))
        name: Audio.icon
        size: bar.mix(bar.c.volumeSize, bar.h.volumeSize, bar.ph)
        color: Theme.text
        opacity: bar.statusOpacity
        x: rightX - width
        y: bar.mix(bar.c.statusY, bar.h.statusY, Motion.lagged(bar.ph, bar.lag.volumeY)) - height / 2
    }
    SignalBars {
        id: signal
        // rest: right-aligned in front of the volume glyph
        readonly property real relC: bar.c.width / 2 - bar.c.padRight - bar.c.volumeSize - bar.c.statusGap
        readonly property real relH: bar.h.width / 2 - bar.h.padRight - bar.h.volumeSize - bar.h.statusGap
        readonly property real cy: bar.mix(bar.c.statusY, bar.h.statusY, Motion.lagged(bar.ph, bar.lag.signalY))
        p: bar.ph
        opacity: bar.statusOpacity
        x: bar.cx(relC, relH, Motion.lagged(bar.pw, bar.lag.signalX)) - width
        y: cy - height / 2
    }
    // scroll over signal + volume = volume; the handler is the only writer to the sink
    Item {
        x: signal.x - 6
        y: Math.min(signal.y, volume.y) - 6
        width: volume.x + volume.width - x + 6
        height: Math.max(signal.y + signal.height, volume.y + volume.height) - y + 6
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => Audio.step(e.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // ---- hover only: top row rides the island edges -------------------------
    // while a player has a track the media chip takes the window title's slot (cross-fade)
    property real mediaIn: Media.hasTrack ? 1 : 0
    Behavior on mediaIn {
        Anim {
            ms: Theme.media.swap
        }
    }

    WindowLabel {
        textOpacity: Motion.smooth(bar.pw, bar.reveal.topText)
        opacity: bar.topAlpha * Motion.smooth(bar.pw, bar.reveal.topIcon) * (1 - bar.mediaIn)
        visible: opacity > 0.001
        x: bar.mix(bar.h.topStartLeft, bar.h.padLeft, bar.pw)
        y: notif.cy - height / 2
    }

    MediaLabel {
        textOpacity: Motion.smooth(bar.pw, bar.reveal.topText)
        opacity: bar.topAlpha * Motion.smooth(bar.pw, bar.reveal.topIcon) * bar.mediaIn
        visible: opacity > 0.001
        enabled: bar.mediaIn > 0.5
        x: bar.mix(bar.h.topStartLeft, bar.h.padLeft, bar.pw)
        y: notif.cy - height / 2
        onOpenRequested: Ui.open("media", bar.screen ? bar.screen.name : undefined)
    }

    NotifStatus {
        id: notif
        readonly property real cy: bar.mix(bar.h.topStartY, bar.h.row1Y, Motion.lagged(bar.ph, bar.lag.topY))
        textOpacity: Motion.smooth(bar.pw, bar.reveal.topText)
        opacity: bar.topAlpha * Motion.smooth(bar.pw, bar.reveal.topIcon)
        visible: opacity > 0.001
        x: bar.width - bar.mix(bar.h.topStartRight, bar.h.padRight, bar.pw) - width
        y: cy - height / 2
    }

    // ---- hover only: extras, last in and first out ---------------------------
    Row {
        id: system
        opacity: bar.topAlpha * Motion.smooth(bar.pw, bar.reveal.extras)
        visible: opacity > 0.001
        spacing: 4
        x: notif.x - bar.h.systemGap - width
        y: notif.cy - height / 2

        IconButton {
            icon: "settings"
            size: bar.h.systemIconSize
            color: Theme.text
            restOpacity: 0.6
            onClicked: Ui.toggle("settings")
        }
        IconButton {
            icon: "power"
            size: bar.h.systemIconSize
            color: Theme.danger
            restOpacity: 0.85
            onClicked: Ui.toggle("powermenu")
        }
    }

    TrayRow {
        id: tray
        opacity: bar.topAlpha * Motion.smooth(bar.pw, bar.reveal.extras)
        visible: opacity > 0.001
        x: signal.x - bar.h.trayGap - width
        y: signal.cy - height / 2
    }
}
