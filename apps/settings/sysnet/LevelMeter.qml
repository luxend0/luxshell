import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.apps.settings

// Bare custom row (System > Sound > Input): what the default microphone hears, live. A Pipewire
// peak monitor (Quickshell's "Peak detect" stream, which services/Privacy does not count as a
// recording) runs only while this row exists and the window is open, i.e. while the Sound
// page shows. Bars light up to the peak, the loudest recent one holds a moment. Right of the
// title: which apps record right now (services/Mic), or "Muted".
// LUXSHELL_FAKE_LEVEL=1: a talking-like demo level instead of the microphone (screenshots).
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    readonly property bool fake: Env.get("LUXSHELL_FAKE_LEVEL") === "1"
    readonly property bool live: SettingsApp.open && Mic.ready && !Mic.muted

    implicitHeight: g.rowHeight

    PwNodePeakMonitor {
        id: peak
        node: root.fake ? null : Mic.source
        enabled: root.live && !root.fake
    }

    // Pipewire's peak is on the same cubic (perceived) scale as its volumes: shown as it is
    // (a quiet room ~0.1, speech 0.3 .. 0.7)
    property real fakePeak: 0
    readonly property real raw: fake ? fakePeak : (peak.enabled ? peak.peak : 0)
    readonly property real level: Math.max(0, Math.min(1, raw))
    property real shown: 0
    property real hold: 0
    onLevelChanged: {
        shown = Math.max(level, shown);
        if (level >= hold) {
            hold = level;
            holdTimer.restart();
        }
    }
    Timer {
        // fall-off: the bars sink smoothly between peaks
        running: root.shown > 0 || root.fake
        interval: 50
        repeat: true
        onTriggered: {
            root.shown = Math.max(root.level, root.shown - 0.06);
            if (root.fake && root.live) {
                const t = Date.now() / 1000;
                const talk = Math.max(0, Math.sin(t * 2.1) * 0.5 + Math.sin(t * 7.3) * 0.3 + 0.25);
                root.fakePeak = 0.09 + 0.55 * talk * (0.6 + 0.4 * Math.random());
            }
        }
    }
    Timer {
        id: holdTimer
        interval: 900
        onTriggered: root.hold = root.level
    }

    Column {
        x: root.g.rowInset
        anchors.verticalCenter: parent.verticalCenter
        width: meter.x - x - 16
        spacing: 3
        SText {
            width: parent.width
            elide: Text.ElideRight
            text: root.opt?.title ?? "Input level"
        }
        SText {
            width: parent.width
            elide: Text.ElideRight
            size: 13.5
            font.weight: Font.Normal
            text: !Mic.ready ? "No microphone" : Mic.muted ? "Muted" : Mic.recording ? `In use by ${Mic.recorders.join(", ")}` : "Speak to test the microphone"
            color: Mic.recording && !Mic.muted ? Theme.danger : root.g.value
        }
    }

    Row {
        id: meter
        x: parent.width - root.g.rowInset - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.s.meterGap
        opacity: root.live ? 1 : 0.4

        Repeater {
            model: root.s.meterBars
            Rectangle {
                required property int index
                readonly property real at: (index + 0.5) / root.s.meterBars
                readonly property bool lit: root.live && at <= root.shown
                readonly property bool held: root.live && root.hold > 0.02 && Math.abs(at - root.hold) < 0.5 / root.s.meterBars + 0.001
                width: root.s.meterBarWidth
                height: root.s.meterHeight
                radius: 2
                color: lit || held ? (at > 0.86 ? root.s.meterHot : Theme.accent) : root.s.meterOff
                opacity: held && !lit ? 0.7 : 1
            }
        }
    }
}
