pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU load and memory in use for the island widgets, read from /proc every
// Settings.islandSysmonInterval seconds (at least 2), only while a widget uses it.
Singleton {
    id: root

    property int users: 0
    property real cpu: 0      // 0..1 since the previous sample
    property real ram: 0      // 0..1 (MemTotal - MemAvailable) / MemTotal
    property bool ready: false
    property var last: null

    function use(): void {
        users++;
        if (users === 1)
            sample();
    }
    function release(): void {
        users = Math.max(0, users - 1);
    }

    function sample(): void {
        stat.reload();
        mem.reload();
    }

    Timer {
        running: root.users > 0
        repeat: true
        interval: Math.max(2, Settings.islandSysmonInterval) * 1000
        onTriggered: root.sample()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const line = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = line[3] + (line[4] || 0);
            const total = line.reduce((a, b) => a + b, 0);
            if (root.last) {
                const dt = total - root.last.total;
                if (dt > 0)
                    root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / dt));
                root.ready = true;
            }
            root.last = {
                "idle": idle,
                "total": total
            };
        }
    }
    FileView {
        id: mem
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const t = text();
            const get = k => {
                const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m"));
                return m ? Number(m[1]) : 0;
            };
            const total = get("MemTotal");
            if (total > 0)
                root.ram = Math.max(0, Math.min(1, (total - get("MemAvailable")) / total));
        }
    }
}
