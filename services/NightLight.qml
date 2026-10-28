pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Night light tile of the control center: a warm screen through wlsunset (only when it is
// installed). On = wlsunset runs (ours or one the user started); on starts ours at a fixed
// temperature (Settings.ccNightTemp; low/high one kelvin apart, so the time of day does not
// matter), off ends every wlsunset. Both go through Exec (LUXSHELL_DRYRUN only logs).
// wlsunset is started detached: it keeps running across shell restarts, like the setting
// it stands for. State is read with pgrep when the control center opens (refresh()), never
// polled.
Singleton {
    id: root

    property bool available: false
    property bool active: false

    function refresh(): void {
        if (available && !check.running)
            check.running = true;
    }

    function toggle(): void {
        set(!active);
    }

    function set(on: bool): void {
        if (!available)
            return;
        if (on) {
            const t = Math.round(Settings.ccNightTemp);
            Exec.run(["sh", "-c", 'pkill -x wlsunset; sleep 0.2; exec wlsunset -t "$1" -T "$(($1 + 1))" -S 06:00 -s 18:00', "sh", String(t)], `night light on (${t} K)`);
        } else {
            Exec.run(["pkill", "-x", "wlsunset"], "night light off");
        }
        if (!Exec.dry)
            recheck.restart();
    }

    // a new temperature while it is on restarts it (debounced: slider drags)
    Connections {
        target: Settings
        function onCcNightTempChanged() {
            if (root.active)
                retemp.restart();
        }
    }
    Timer {
        id: retemp
        interval: 500
        onTriggered: if (root.active)
            root.set(true)
    }
    Timer {
        id: recheck
        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: code => {
            root.available = code === 0;
            root.refresh();
        }
    }
    Process {
        id: check
        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.active = code === 0
    }
}
