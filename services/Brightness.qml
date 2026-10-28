pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Display brightness. External monitors over DDC/CI (ddcutil, VCP 0x10), else a
// backlight via brightnessctl. DDC is slow and the bus is shared, so:
//   - reads only when asked (refresh() on control-center open), at most every 30 s
//   - writes are debounced and serialised: one ddcutil at a time, latest value wins
//   - every call runs under nice 19
//
// displays: [{ bus, connector, model, value (0..1), max }], primary: index into it
// (the display on the focused monitor if the connector matches, else the first).
Singleton {
    id: root

    property var displays: []
    property int primary: 0
    property string backend: "" // "ddc" | "backlight" | "" (nothing found yet)
    property bool loading: false
    property double lastRead: 0

    // test path (IPC "activity brightness <v>"): shows a value without touching DDC
    property real fake: -1
    readonly property bool ready: fake >= 0 || displays.length > 0
    readonly property real value: fake >= 0 ? fake : displays.length > 0 ? displays[primary].value : 0
    readonly property string label: displays.length > 0 ? displays[primary].model : ""

    readonly property int minInterval: 30000
    property var queue: ({}) // index -> raw value waiting for the bus
    property int writingIndex: -1

    function simulate(v: real): void {
        fake = Math.max(0, Math.min(1, v));
    }

    function refresh(force: bool): void {
        if (loading || (!force && Date.now() - lastRead < minInterval))
            return;
        loading = true;
        probe.running = true;
    }

    function pickPrimary(screenName: string): void {
        const i = displays.findIndex(d => screenName !== "" && d.connector.endsWith("-" + screenName));
        primary = i >= 0 ? i : 0;
    }

    // v: 0..1. The UI value follows at once, the device after the debounce.
    function set(index: int, v: real): void {
        if (!ready || index < 0 || index >= displays.length)
            return;
        const d = displays.slice();
        const clamped = Math.max(0, Math.min(1, v));
        d[index] = Object.assign({}, d[index], {
            "value": clamped
        });
        displays = d;
        const q = Object.assign({}, queue);
        q[index] = Math.round(clamped * d[index].max);
        queue = q;
        debounce.restart();
    }
    function setPrimary(v: real): void {
        set(primary, v);
    }

    function flush(): void {
        if (writer.running)
            return; // onExited picks up the rest
        const keys = Object.keys(queue);
        if (keys.length === 0)
            return;
        const index = parseInt(keys[0]);
        const raw = queue[index];
        const q = Object.assign({}, queue);
        delete q[index];
        queue = q;
        const d = displays[index];
        const argv = backend === "ddc" ? ["nice", "-n", "19", "ddcutil", "--noverify", ...(d.bus >= 0 ? ["--bus", String(d.bus)] : []), "setvcp", "10", String(raw)] : ["nice", "-n", "19", "brightnessctl", "-q", "-d", d.connector, "set", String(raw)];
        lastRead = Date.now(); // what we just wrote is the freshest value there is
        if (!Exec.allow(`brightness ${d.model}: ${argv.join(" ")}`)) {
            Qt.callLater(flush);
            return;
        }
        writer.command = argv;
        writer.running = true;
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: root.flush()
    }

    Process {
        id: writer
        stderr: StdioCollector {
            id: writerErr
        }
        onExited: code => {
            if (code !== 0)
                console.warn(`luxshell: brightness write failed: ${writerErr.text.trim()}`);
            root.flush();
        }
    }

    // One shell call: ddcutil detect + getvcp per bus, or brightnessctl as fallback.
    // Output lines ("|" separated, models may contain spaces):
    //   ddc|<bus>|<connector>|<model>|<current>|<max>    bl|<device>|<current>|<max>
    Process {
        id: probe
        command: ["sh", "-c", `
            nice -n 19 ddcutil detect --brief 2>/dev/null | awk -v OFS="|" '
                /^Display/ { if (bus != "") print bus, con, mon; bus = ""; con = "-"; mon = "Display" }
                /I2C bus:/ { sub(/.*i2c-/, ""); bus = $0 }
                /DRM connector:/ { con = $NF }
                /Monitor:/ { sub(/.*Monitor:[ \t]*/, ""); n = split($0, p, ":"); mon = (n >= 2 && p[2] != "") ? p[2] : $0 }
                END { if (bus != "") print bus, con, mon }' |
            while IFS="|" read -r bus con mon; do
                v=$(nice -n 19 ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null) || continue
                set -- $v
                [ "$1" = VCP ] && echo "ddc|$bus|$con|$mon|$4|$5"
            done | grep . && exit 0
            brightnessctl -l -m -c backlight 2>/dev/null | awk -F, '{ print "bl|" $1 "|" $3 "|" $5 }'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                let kind = "";
                for (const line of text.split("\n")) {
                    const f = line.trim().split("|");
                    if (f[0] === "ddc" && f.length >= 6) {
                        kind = "ddc";
                        found.push({
                            "bus": parseInt(f[1]),
                            "connector": f[2],
                            "model": f[3],
                            "max": parseInt(f[5]) || 100,
                            "value": (parseInt(f[4]) || 0) / (parseInt(f[5]) || 100)
                        });
                    } else if (f[0] === "bl" && f.length >= 4) {
                        kind = "backlight";
                        found.push({
                            "bus": -1,
                            "connector": f[1],
                            "model": "Built-in display",
                            "max": parseInt(f[3]) || 100,
                            "value": (parseInt(f[2]) || 0) / (parseInt(f[3]) || 100)
                        });
                    }
                }
                // a write queued while we were reading is newer than what we read
                for (const k of Object.keys(root.queue))
                    if (found[k])
                        found[k].value = root.displays[k]?.value ?? found[k].value;
                root.backend = kind;
                root.displays = found;
                if (root.primary >= found.length)
                    root.primary = 0;
                root.lastRead = Date.now();
                root.loading = false;
                if (found.length === 0)
                    console.info("luxshell: no DDC/CI display and no backlight found");
            }
        }
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }
}
