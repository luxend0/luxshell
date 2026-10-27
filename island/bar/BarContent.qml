import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// Content of the island when no panel is shown. One progress value p drives the
// whole collapsed <-> hover morph: shared elements (workspaces, clock, signal,
// volume) interpolate size and position, hover-only elements fade in late.
// Positions are relative to the current island size, which animates with the
// same curve and duration, so everything stays in lockstep without per-item
// animations.
Item {
    id: bar

    property real p: 0
    property var screen: null
    readonly property bool holdOpen: tray.openMenus > 0
    readonly property real reveal: Math.max(0, Math.min(1, (p - 0.45) / 0.55))

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    function mix(a: real, b: real): real {
        return a + (b - a) * p;
    }
    readonly property real padL: mix(c.padLeft, h.padLeft)
    readonly property real padR: mix(c.padRight, h.padRight)
    readonly property real lineY: mix(c.centerY, h.row2Y) // workspaces

    // ---- left: workspaces (row 2 in hover) ---------------------------------
    Workspaces {
        id: workspaces
        p: bar.p
        screen: bar.screen
        x: bar.padL
        y: bar.lineY - height / 2
    }

    // ---- centre: clock, date joins on hover (group stays centred) ----------
    MorphText {
        id: clock
        readonly property real cx: bar.width / 2 - bar.p * (bar.h.dateGap + date.implicitWidth) / 2
        readonly property real cy: bar.mix(bar.c.centerY, bar.h.clockY)
        text: Clock.time
        size: bar.mix(bar.c.clockSize, bar.h.clockSize)
        font.weight: Font.Medium
        x: cx - width / 2
        y: cy - anchorY
    }
    Txt {
        id: date
        visible: bar.reveal > 0
        opacity: bar.reveal
        text: Clock.date
        color: Theme.textDim
        font.pixelSize: bar.h.dateSize
        font.weight: Font.Medium
        x: clock.cx + clock.visualWidth / 2 + bar.h.dateGap
        y: clock.cy + clock.visualCapHeight / 2 - baselineOffset
    }

    // ---- right: signal + volume (row 2 in hover, dimmed) --------------------
    Item {
        id: status
        readonly property real gap: bar.mix(bar.c.statusGap, bar.h.statusGap)
        x: bar.width - bar.padR - width
        y: bar.mix(bar.c.statusY, bar.h.statusY) - height / 2
        width: signal.width + gap + volume.width
        height: Math.max(signal.height, volume.height)
        opacity: bar.mix(bar.c.statusOpacity, bar.h.statusOpacity)

        SignalBars {
            id: signal
            p: bar.p
            anchors.verticalCenter: parent.verticalCenter
        }
        Icon {
            id: volume
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.icon
            size: bar.mix(bar.c.volumeSize, bar.h.volumeSize)
            color: Theme.text
        }
        // scroll = volume; the handler is the only writer to the sink
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => Audio.step(e.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // ---- hover only ---------------------------------------------------------
    WindowLabel {
        visible: bar.reveal > 0
        opacity: bar.reveal
        x: bar.padL
        y: bar.h.row1Y - height / 2
    }

    NotifStatus {
        id: notif
        visible: bar.reveal > 0
        opacity: bar.reveal
        x: bar.width - bar.padR - width
        y: bar.h.row1Y - height / 2
    }

    Row {
        id: system
        visible: bar.reveal > 0
        opacity: bar.reveal
        spacing: 4
        x: notif.x - bar.h.systemGap - width
        y: bar.h.row1Y - height / 2

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
        visible: bar.reveal > 0
        opacity: bar.reveal
        x: status.x - bar.h.trayGap - width
        y: bar.h.statusY - height / 2
    }
}
