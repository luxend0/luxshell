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
// Temperature (bar widget scroll, display menu slider): setTemp() / stepTemp() write
// Settings.ccNightTemp within minTemp..maxTemp (the settings slider's range); a running
// night light follows (debounced restart below).
// LUXSHELL_FAKE_SWITCHES=1: available, and with LUXSHELL_DRYRUN the switch follows clicks
// (nothing is started or read).
Singleton {
    id: root

    property bool available: false
    property bool active: false

    readonly property bool fake: Env.get("LUXSHELL_FAKE_SWITCHES") === "1"
    readonly property int minTemp: 2500
    readonly property int maxTemp: 6000

    function setTemp(k: real): void {
        const v = Math.max(minTemp, Math.min(maxTemp, Math.round(k / 50) * 50));
        if (v !== Settings.ccNightTemp)
            Settings.set("ccNightTemp", v);
    }
    function stepTemp(delta: real): void {
        setTemp(Settings.ccNightTemp + delta);
    }

    function refresh(): void {
        if (fake)
            return;
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
        if (fake)
            active = on;
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
            root.available = root.fake || code === 0;
            root.refresh();
        }
    }
    Process {
        id: check
        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.active = code === 0
    }
}
