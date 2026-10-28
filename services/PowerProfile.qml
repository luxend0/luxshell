pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Power mode tile of the control center (power-profiles-daemon via powerprofilesctl, only
// when it answers). Read when the control center opens (refresh()), never polled; set()
// goes through Exec (LUXSHELL_DRYRUN only logs).
//
//   profiles  the ones the daemon offers, in the order power-saver, balanced, performance
//   profile   the active one ("" = unknown)
//   cycle()   next profile (wraps)
Singleton {
    id: root

    readonly property var order: ["power-saver", "balanced", "performance"]
    property var profiles: []
    property string profile: ""
    readonly property bool available: profiles.length > 1

    function label(p: string): string {
        return p === "power-saver" ? "Power Saver" : p === "performance" ? "Performance" : p === "balanced" ? "Balanced" : "Unknown";
    }
    function icon(p: string): string {
        return p === "power-saver" ? "leaf" : p === "performance" ? "zap" : "gauge";
    }

    function refresh(): void {
        if (!list.running)
            list.running = true;
    }

    function set(p: string): void {
        if (!profiles.includes(p) || p === profile)
            return;
        Exec.run(["powerprofilesctl", "set", p], `power profile ${p}`);
        if (!Exec.dry)
            recheck.restart();
    }

    function cycle(): void {
        if (!available)
            return;
        const i = profiles.indexOf(profile);
        set(profiles[(i + 1) % profiles.length]);
    }

    Timer {
        id: recheck
        interval: 400
        onTriggered: root.refresh()
    }

    // "* balanced:" = active, "  performance:" = offered; detail lines are indented deeper
    Process {
        id: list
        running: true
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                let cur = "";
                for (const line of text.split("\n")) {
                    const m = /^([* ]) ([a-z-]+):\s*$/.exec(line);
                    if (!m)
                        continue;
                    found.push(m[2]);
                    if (m[1] === "*")
                        cur = m[2];
                }
                root.profiles = root.order.filter(p => found.includes(p));
                root.profile = cur;
            }
        }
    }
}
