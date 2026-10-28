import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Clock of the island: 21 px collapsed, 30 px hover (t mixes), Medium. The MorphText itself
// is the widget (no wrapper: the bar places it exactly like the video's clock); it scales
// around its centre, visualWidth is what shows. carryScale: a widget riding next to it (the
// date) shrinks and grows with it (BarWidget). Seconds (Settings.islandClockSeconds) run
// their own second clock, only while shown.
MorphText {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property bool seconds: Settings.islandClockSeconds
    readonly property string clockText: seconds ? withSeconds(secClock.date) : Clock.time

    // BarWidget contract
    readonly property real wC: measureC.implicitWidth * c.clockSize / measureC.font.pixelSize
    readonly property real wH: measureH.implicitWidth * h.clockSize / measureH.font.pixelSize
    readonly property real textBase: anchorY + visualCapHeight / 2
    readonly property bool carryScale: true
    readonly property real sc: size / h.clockSize

    function withSeconds(d: date): string {
        const f = Settings.clockFormat;
        const now = Env.fakeClock !== "" ? Clock.now : d;
        const pad = n => String(n).padStart(2, "0");
        if (f === "12h")
            return `${now.getHours() % 12 || 12}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
        return now.toLocaleTimeString(Clock.locale, f === "12h-ampm" ? "h:mm:ss AP" : "HH:mm:ss");
    }

    text: clockText
    size: c.clockSize + (h.clockSize - c.clockSize) * t
    font.weight: Font.Medium

    SystemClock {
        id: secClock
        precision: SystemClock.Seconds
        enabled: root.seconds && Env.fakeClock === ""
    }
    Txt {
        id: measureC
        visible: false
        text: root.clockText
        font.pixelSize: Math.round(root.c.clockSize)
        font.weight: Font.Medium
    }
    Txt {
        id: measureH
        visible: false
        text: root.clockText
        font.pixelSize: Math.round(root.h.clockSize)
        font.weight: Font.Medium
    }
}
