pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Focus schedule: switches Settings.dnd at the edges of a weekly span
// (Settings.notifFocusSchedule / notifFocusDays / notifFocusTime, Notifications page).
//
//   days     ISO weekdays the span STARTS on (Mon-Fri 22:00-07:00 = Monday night to Saturday morning)
//   span     "to" earlier than "from" ends on the next day; from == to = the whole day
//
// Only edges write: a manual toggle in between (control center, IPC) stays until the next
// edge. The schedule state last applied is runtime state (Settings.notifFocusEdge, saved,
// never exported), so an edge that passed while the shell was not running is applied at
// start and a manual change survives a restart. Turning the schedule on inside the span
// switches Focus on at once; turning it on outside leaves Focus as it is. Turning it off
// ends a Focus the schedule had switched on.
//
// IPC: qs -c luxshell ipc call focus toggle | on | off | state
Singleton {
    id: root

    readonly property bool enabled: Settings.notifFocusSchedule
    readonly property date now: Clock.now // minute clock (LUXSHELL_FAKE_CLOCK applies)
    readonly property bool inside: enabled && within(now)

    // "HH:MM" -> minutes, -1 when malformed
    function minutes(t: var): int {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(t ?? ""));
        if (!m)
            return -1;
        const v = parseInt(m[1]) * 60 + parseInt(m[2]);
        return v >= 0 && v < 1440 ? v : -1;
    }
    function iso(d: date): int {
        return d.getDay() === 0 ? 7 : d.getDay();
    }
    function within(d: date): bool {
        const days = Array.from(Settings.notifFocusDays ?? []);
        const span = Settings.notifFocusTime ?? {};
        const from = minutes(span.from), to = minutes(span.to);
        if (from < 0 || to < 0 || days.length === 0)
            return false;
        const day = iso(d);
        const prev = day === 1 ? 7 : day - 1;
        const m = d.getHours() * 60 + d.getMinutes();
        if (from === to)
            return days.includes(day);
        if (from < to)
            return days.includes(day) && m >= from && m < to;
        return (days.includes(day) && m >= from) || (days.includes(prev) && m < to);
    }

    // next moment the schedule flips, null when it never does
    function nextEdge(): var {
        const span = Settings.notifFocusTime ?? {};
        const marks = [minutes(span.from), minutes(span.to)].filter(m => m >= 0);
        if (marks.length === 0)
            return null;
        const base = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const cands = [];
        for (let day = 0; day <= 8; day++)
            for (const m of marks)
                cands.push(new Date(base.getFullYear(), base.getMonth(), base.getDate() + day, Math.floor(m / 60), m % 60));
        cands.sort((a, b) => a - b);
        const cur = within(now);
        return cands.find(t => t > now && within(t) !== cur) ?? null;
    }

    // one line for the settings page: "On until 07:00" / "Starts Mon 22:00"
    function describe(): string {
        if (!enabled)
            return "Off";
        const t = nextEdge();
        const loc = Qt.locale("en_US");
        const fmt = Settings.clockFormat === "24h" ? "HH:mm" : "h:mm AP";
        if (!t)
            return inside ? "On all week" : "Never (pick days)";
        const sameDay = t.toDateString() === now.toDateString();
        const when = (sameDay ? "" : t.toLocaleDateString(loc, "ddd") + " ") + t.toLocaleTimeString(loc, fmt);
        if (!inside)
            return `Next Focus ${when}`;
        return Settings.dnd ? `Focus on until ${when}` : `Turned off by hand until ${when}`;
    }

    function apply(): void {
        if (!Settings.ready)
            return;
        const edge = Settings.notifFocusEdge;
        if (!enabled) {
            if (edge === "on" && Settings.dnd)
                Settings.set("dnd", false);
            if (edge !== "")
                Settings.set("notifFocusEdge", "");
            return;
        }
        const want = inside ? "on" : "off";
        if (edge === want)
            return; // no edge since the last one: a manual toggle stays
        Settings.set("notifFocusEdge", want);
        // fresh schedule outside its span: leave a manual Focus alone
        if (edge === "" && !inside)
            return;
        if (Settings.dnd !== inside) {
            Settings.set("dnd", inside);
            console.info(`luxshell: focus schedule turned Focus ${inside ? "on" : "off"}`);
        }
    }

    onInsideChanged: apply()
    onEnabledChanged: apply()
    Connections {
        target: Settings
        function onReadyChanged(): void {
            root.apply();
        }
    }
    Component.onCompleted: apply()

    IpcHandler {
        target: "focus"

        function toggle(): void {
            Settings.set("dnd", !Settings.dnd);
        }
        function on(): void {
            Settings.set("dnd", true);
        }
        function off(): void {
            Settings.set("dnd", false);
        }
        function state(): string {
            return JSON.stringify({
                "dnd": Settings.dnd,
                "schedule": root.enabled,
                "inside": root.inside,
                "edge": Settings.notifFocusEdge,
                "summary": root.describe()
            });
        }
    }
}
