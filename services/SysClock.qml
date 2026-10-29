pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Time zone and network time of the system (Settings > System > Date, Time & Language),
// systemd-timedated:
//   read   `timedatectl show` (Timezone, NTP, CanNTP, NTPSynchronized, LocalRTC) and every zone with
//          its UTC offset right now: `zdump UTC <each zone of timedatectl list-timezones>` (one process,
//          read again whenever the page shows: offsets move with daylight saving time).
//   write  `timedatectl set-timezone <zone>`, `timedatectl set-ntp <bool>` through Exec.call (polkit
//          asks; a refusal lands in `error`, the page shows it until the next change).
//   wall   the system zone's wall time: Clock.now + the zone's offset. The shell read its own TZ
//          once at start, so after a change only this stays right.
Singleton {
    id: root

    property string zone: ""
    property bool ntp: false
    property bool canNtp: false
    property bool synced: false
    property bool localRtc: false
    property var zones: []       // [{ name, offset (minutes east of UTC), abbr }] in timedatectl order
    property var zoneMap: ({})   // name -> the same object
    property bool ready: false
    property string busy: ""     // "zone" | "ntp" while a change runs
    property string error: ""
    signal notice(string text) // a change went through (the page shows it as a toast)

    function refresh(): void {
        if (!state.running)
            state.running = true;
        if (!zoneReader.running)
            zoneReader.running = true;
    }

    function offsetText(min: int): string {
        const a = Math.abs(min);
        return `UTC${min < 0 ? "−" : "+"}${String(Math.floor(a / 60)).padStart(2, "0")}:${String(a % 60).padStart(2, "0")}`;
    }
    function zoneDetail(name: string): string {
        const z = zoneMap[name];
        if (!z)
            return "";
        return /^[A-Za-z]+$/.test(z.abbr) && z.abbr !== "UTC" ? `${z.abbr}, ${offsetText(z.offset)}` : offsetText(z.offset);
    }
    // a Date whose local fields show the wall time of the system zone (for Clock.formatTime and
    // toLocaleDateString); the shell's own zone when the offset is not known yet
    readonly property date wall: {
        const now = Clock.now;
        const z = zoneMap[zone];
        if (!z)
            return now;
        const w = new Date(now.getTime() + z.offset * 60000);
        return new Date(w.getUTCFullYear(), w.getUTCMonth(), w.getUTCDate(), w.getUTCHours(), w.getUTCMinutes(), w.getUTCSeconds());
    }

    function setZone(name: string): void {
        if (name === "" || name === zone || busy !== "" || !zoneMap[name])
            return;
        busy = "zone";
        Exec.call(["timedatectl", "set-timezone", name], `set the time zone to ${name}`, (ok, text) => {
            root.busy = "";
            root.error = ok ? "" : root.tidy(text, "Could not set the time zone");
            if (ok)
                root.notice(text === "dry run" ? `Dry run: time zone ${name} (timedatectl not run)` : `Time zone: ${name}`);
            root.refresh();
        });
    }
    function setNtp(on: bool): void {
        if (on === ntp || busy !== "")
            return;
        busy = "ntp";
        Exec.call(["timedatectl", "set-ntp", on ? "true" : "false"], `${on ? "turn on" : "turn off"} network time`, (ok, text) => {
            root.busy = "";
            root.error = ok ? "" : root.tidy(text, "Could not change network time");
            if (ok)
                root.notice(text === "dry run" ? `Dry run: network time ${on ? "on" : "off"} (timedatectl not run)` : `Network time ${on ? "on" : "off"}`);
            root.refresh();
        });
    }
    // timedatectl's "Failed to set time zone: Access denied" -> one line for the page
    function tidy(text: string, fallback: string): string {
        const t = String(text ?? "").split("\n").map(s => s.trim()).filter(s => s !== "").pop() ?? "";
        return t !== "" ? t : fallback;
    }

    Process {
        id: state
        command: ["timedatectl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        f[line.slice(0, i)] = line.slice(i + 1);
                }
                root.zone = f.Timezone ?? "";
                root.ntp = f.NTP === "yes";
                root.canNtp = f.CanNTP === "yes";
                root.synced = f.NTPSynchronized === "yes";
                root.localRtc = f.LocalRTC === "yes";
                root.ready = true;
            }
        }
    }

    // "Europe/Berlin  Thu Oct 29 21:54:24 2026 CET" per zone, the UTC line first
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    function stamp(parts: var): real {
        // [name, weekday, month, day, hh:mm:ss, year, abbr]
        const t = parts[4].split(":").map(Number);
        return Date.UTC(Number(parts[5]), months.indexOf(parts[2]), Number(parts[3]), t[0], t[1], t[2]);
    }
    Process {
        id: zoneReader
        command: ["nice", "-n", "19", "sh", "-c", 'zdump UTC $(timedatectl list-timezones)']
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const map = {};
                let utc = NaN;
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/);
                    if (p.length < 7)
                        continue;
                    const t = root.stamp(p);
                    if (isNaN(utc)) {
                        utc = t; // the first line is UTC itself
                        continue;
                    }
                    const z = {
                        "name": p[0],
                        "offset": Math.round((t - utc) / 60000 / 15) * 15,
                        "abbr": p[6]
                    };
                    list.push(z);
                    map[z.name] = z;
                }
                root.zones = list;
                root.zoneMap = map;
            }
        }
    }
}
