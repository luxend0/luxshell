pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Display brightness, READ ONLY (the OSD only shows it; whoever changes brightness,
// e.g. a keybind running brightnessctl / ddcutil, calls `ipc call luxshell flash brightness`).
// Same public surface as the control center's service (value, ready, refresh(force)),
// so either implementation can back the OSD.
//
//   backlight via brightnessctl (fast), else the first DDC/CI display via ddcutil (slow,
//   shared bus: one read at a time, nice 19, a request while reading is queued once).
//   LUXSHELL_FAKE_BRIGHTNESS=0..1 replaces the hardware (sandbox, screenshots).
Singleton {
    id: root

    readonly property real fake: {
        const v = parseFloat(Env.get("LUXSHELL_FAKE_BRIGHTNESS"));
        return isNaN(v) ? -1 : Math.max(0, Math.min(1, v));
    }
    property real hw: -1
    property bool loading: false
    property bool again: false

    readonly property bool ready: fake >= 0 || hw >= 0
    readonly property real value: fake >= 0 ? fake : Math.max(0, hw)

    // test hook (ipc call activity brightness <v>): pretend the hardware reported v
    function simulate(v: real): void {
        hw = Math.max(0, Math.min(1, v));
    }

    function refresh(force: bool): void {
        if (fake >= 0)
            return;
        if (loading) {
            again = again || force;
            return;
        }
        if (!force && hw >= 0)
            return;
        loading = true;
        probe.running = true;
    }

    // prints "<current> <max>"
    Process {
        id: probe
        command: ["nice", "-n", "19", "sh", "-c", `
            l=$(brightnessctl -m -c backlight info 2>/dev/null) && { echo "$l" | awk -F, '{ print $3, $5 }'; exit 0; }
            ddcutil getvcp 10 --brief 2>/dev/null | awk '$1 == "VCP" { print $4, $5 }'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                const cur = parseFloat(f[0]);
                const max = parseFloat(f[1]);
                if (!isNaN(cur) && max > 0)
                    root.hw = Math.max(0, Math.min(1, cur / max));
            }
        }
        onExited: {
            root.loading = false;
            if (root.again) {
                root.again = false;
                root.refresh(true);
            }
        }
    }
}
