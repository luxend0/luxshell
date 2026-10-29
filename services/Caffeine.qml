pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Caffeine tile of the control center: keeps the session awake (hypridle and friends honour
// logind idle inhibitors) by holding `systemd-inhibit --what=idle` while it is on. The lock
// lives as long as this shell: quitting luxshell ends it, so it is runtime state, never
// saved. Turning it on goes through Exec (LUXSHELL_DRYRUN only logs, the tile stays off).
//
// Duration (bar widget + its menu, panels/menus/CaffeineSheet): start(minutes) keeps it on for
// that long and turns it off by itself, 0 = until turned off (set(true), the tile). `left` is
// the time left in s (0 = no end), leftShort / leftLong the same as text; a 5 s tick keeps
// them fresh only while a timed run is on.
// LUXSHELL_FAKE_SWITCHES=1: with LUXSHELL_DRYRUN the switch follows clicks (no inhibitor).
Singleton {
    id: root

    property bool active: false

    readonly property bool fake: Env.get("LUXSHELL_FAKE_SWITCHES") === "1"
    property int minutes: 0      // duration of the current run, 0 = until turned off
    property double until: 0     // epoch ms the run ends, 0 = no end
    property double now: Date.now()
    readonly property int left: active && until > 0 ? Math.max(0, Math.ceil((until - now) / 1000)) : 0
    readonly property string leftShort: {
        if (left <= 0)
            return "";
        const m = Math.ceil(left / 60);
        return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m`;
    }
    readonly property string leftLong: {
        if (left <= 0)
            return "";
        const m = Math.ceil(left / 60);
        if (m < 60)
            return `${m} min`;
        return m % 60 === 0 ? `${m / 60} h` : `${Math.floor(m / 60)} h ${m % 60} min`;
    }

    function toggle(): void {
        set(!active);
    }

    function set(on: bool): void {
        if (on)
            start(0);
        else
            stop();
    }

    // on for `min` minutes (0 = until turned off); a running one takes the new duration
    function start(min: int): void {
        if (!active && !Exec.allow(`idle inhibit on${min > 0 ? ` for ${min} min` : ""}: systemd-inhibit --what=idle`) && !fake)
            return;
        minutes = Math.max(0, min);
        now = Date.now();
        until = minutes > 0 ? now + minutes * 60000 : 0;
        active = true;
        if (until > 0) {
            expire.interval = minutes * 60000;
            expire.restart();
        } else {
            expire.stop();
        }
    }

    function stop(): void {
        expire.stop();
        active = false;
        minutes = 0;
        until = 0;
    }

    // click on the widget: off -> on for `min` minutes, on -> off
    function toggleFor(min: int): void {
        if (active)
            stop();
        else
            start(min);
    }

    // ends a timed run on time; the tick catches a run whose end passed during suspend
    Timer {
        id: expire
        onTriggered: root.stop()
    }
    Timer {
        running: root.active && root.until > 0
        interval: 5000
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.until)
                root.stop();
        }
    }

    Process {
        running: root.active && !root.fake
        command: ["systemd-inhibit", "--what=idle", "--who=luxshell", "--why=Caffeine (control center)", "--mode=block", "sleep", "infinity"]
        // the inhibitor died on its own (logind restart, killed): the tile follows
        onExited: (code, status) => {
            if (root.active)
                root.stop();
        }
    }
}
