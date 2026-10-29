pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config

// Idle daemon (replaces Ambxst's idle listeners): four stages, each an IdleMonitor of its own
// (ext-idle-notify, respectInhibitors: a fullscreen video's Wayland idle inhibitor holds them).
// The compositor counts the time; nothing here polls.
//
//   dim        Settings.idleDimAfter (150 s)      displays to idleDimLevel %, back on input
//   lock       idleLockAfter (300 s)              lock screen (services/Lock, same as `ipc call luxshell lock`)
//   screen off idleScreenOffAfter (330 s)         hl.dsp.dpms({ action = "off" }), "on" on input
//   sleep      idleSuspendAfter (1800 s)          lock (idleLockBeforeSleep), then systemctl suspend
//
// Paused (every monitor off, counting starts again afterwards) while Caffeine is on or, with
// idleMediaPause, an MPRIS player plays. Pausing ends a stage like input does (screen on,
// brightness back). Settings.idleEnabled off = nothing at all (another idle daemon's job).
//
// logind (system bus, `gdbus monitor`, read only):
//   PrepareForSleep(true)   lock first (idleLockBeforeSleep); a delay inhibitor
//                           (systemd-inhibit --what=sleep --mode=delay) holds the suspend until
//                           the lock surface is up, then it is released
//   PrepareForSleep(false)  displays on, brightness back, every stage counts from zero again
//   Session.Lock            `loginctl lock-session` of this session: lock screen
//
// Every action goes through services/Exec: LUXSHELL_DRYRUN=1 only logs (also no inhibitor).
// LUXSHELL_IDLE_SCALE multiplies every timeout (sandbox: 0.02 -> 3 / 6 / 6.6 / 36 s),
// LUXSHELL_IDLE_LOGIND_BUS=session listens to a fake logind on the sandbox's private bus.
// IPC: qs -c luxshell ipc call idle state | sleep true|false | lockSession | caffeine true|false
Singleton {
    id: root

    readonly property real scale: Math.max(0.001, parseFloat(Env.get("LUXSHELL_IDLE_SCALE")) || 1)
    // sandbox: a fake logind on the private session bus (LUXSB_DBUS=1) instead of the real one
    readonly property string bus: Env.get("LUXSHELL_IDLE_LOGIND_BUS") === "session" ? "--session" : "--system"

    readonly property bool enabled: Settings.ready && Settings.idleEnabled
    readonly property var playing: Media.allPlayers.filter(p => p.isPlaying)
    // why the stages wait: "" | "caffeine" | "media"
    readonly property string pausedBy: !enabled ? "" : Caffeine.active ? "caffeine" : Settings.idleMediaPause && playing.length > 0 ? "media" : ""
    property bool rearming: false
    readonly property bool armed: enabled && pausedBy === "" && !rearming

    // reached stages (for the settings page and IPC)
    readonly property bool dimmed: saved !== null
    property bool screenIsOff: false
    readonly property string stage: suspendMon.isIdle ? "sleep" : offMon.isIdle ? "screen off" : lockMon.isIdle ? "lock" : dimMon.isIdle ? "dim" : ""

    function seconds(s: real): real {
        return Math.max(1, s) * scale;
    }
    function log(text: string): void {
        console.info(`luxshell: idle: ${text}`);
    }
    function duration(s: real): string {
        s = Math.round(s);
        if (s < 60)
            return `${s} s`;
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        if (h > 0)
            return m > 0 ? `${h} h ${m} min` : `${h} h`;
        return r > 0 ? `${m}:${String(r).padStart(2, "0")} min` : `${m} min`;
    }
    // one line for the settings page
    function describe(): string {
        if (!Settings.idleEnabled)
            return "Off";
        if (pausedBy === "caffeine")
            return Caffeine.leftLong !== "" ? `Paused: Caffeine is on (${Caffeine.leftLong} left)` : "Paused: Caffeine is on";
        if (pausedBy === "media")
            return `Paused: ${playing[0]?.identity || "media"} is playing`;
        const next = [["idleDim", "idleDimAfter", "dims"], ["idleLock", "idleLockAfter", "locks"], ["idleScreenOff", "idleScreenOffAfter", "turns the screen off"], ["idleSuspend", "idleSuspendAfter", "sleeps"]].filter(s => Settings[s[0]]).sort((a, b) => Settings[a[1]] - Settings[b[1]]);
        if (next.length === 0)
            return "No stage is on";
        const what = next[0][2];
        return `${what.charAt(0).toUpperCase()}${what.slice(1)} after ${duration(Settings[next[0][1]])} without input`;
    }

    onPausedByChanged: {
        if (pausedBy === "caffeine")
            log("paused while Caffeine is on");
        else if (pausedBy === "media")
            log(`paused while media plays (${playing.map(p => p.identity).join(", ")})`);
        else if (enabled)
            log("counting again");
    }
    function plan(on: bool, after: real): string {
        return on ? `${Math.round(seconds(after) * 10) / 10} s` : "off";
    }
    onEnabledChanged: log(enabled ? `on (dim ${plan(Settings.idleDim, Settings.idleDimAfter)}, lock ${plan(Settings.idleLock, Settings.idleLockAfter)}, screen off ${plan(Settings.idleScreenOff, Settings.idleScreenOffAfter)}, sleep ${plan(Settings.idleSuspend, Settings.idleSuspendAfter)}${scale !== 1 ? `, LUXSHELL_IDLE_SCALE ${scale}` : ""})` : "off")

    // why a stage ended without input (its monitor was switched off)
    function why(): string {
        return rearming ? "wake" : !enabled ? "idle off" : pausedBy !== "" ? `${pausedBy} pause` : "stage off";
    }

    // every monitor once off and on: counting starts from now (after waking up)
    function rearm(): void {
        rearming = true;
        rearmTimer.restart();
    }
    Timer {
        id: rearmTimer
        interval: 100
        onTriggered: root.rearming = false
    }

    // ---- stages -----------------------------------------------------------------------------
    IdleMonitor {
        id: dimMon
        enabled: root.armed && Settings.idleDim
        timeout: root.seconds(Settings.idleDimAfter)
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.dim() : root.undim(enabled ? "input" : root.why())
    }
    IdleMonitor {
        id: lockMon
        enabled: root.armed && Settings.idleLock
        timeout: root.seconds(Settings.idleLockAfter)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            root.lockNow(`${root.duration(timeout)} idle`)
    }
    IdleMonitor {
        id: offMon
        enabled: root.armed && Settings.idleScreenOff
        timeout: root.seconds(Settings.idleScreenOffAfter)
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.screenOff() : root.screenOn(enabled ? "input" : root.why(), false)
    }
    IdleMonitor {
        id: suspendMon
        enabled: root.armed && Settings.idleSuspend
        timeout: root.seconds(Settings.idleSuspendAfter)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!isIdle) {
                suspendDelay.stop();
                return;
            }
            root.log(`${root.duration(timeout)} idle -> sleep`);
            if (Settings.idleLockBeforeSleep)
                root.lockNow("before sleep");
            suspendDelay.restart();
        }
    }
    // the lock surface shows before the machine sleeps; input in between cancels the suspend
    Timer {
        id: suspendDelay
        interval: 1200
        onTriggered: if (suspendMon.isIdle)
            Exec.run(["systemctl", "suspend"], "idle sleep")
    }

    // ---- dim: brightness read fresh, set to idleDimLevel, the read values come back on input
    property var saved: null // [{ index, model, value }] while dimmed
    property bool dimPending: false

    function dim(): void {
        if (saved !== null || dimPending)
            return;
        log(`${duration(dimMon.timeout)} idle -> dim to ${Settings.idleDimLevel} %`);
        dimPending = true;
        dimWait.restart();
        // values older than 30 s are read again (another tool or the monitor's buttons may have
        // changed them); fresh ones (the control center's slider writes them too) are used as they are
        Brightness.refresh(false);
        if (!Brightness.loading)
            applyDim();
    }
    function applyDim(): void {
        dimPending = false;
        dimWait.stop();
        const level = Math.max(0, Math.min(100, Settings.idleDimLevel)) / 100;
        saved = Brightness.displays.map((d, i) => ({
                    "index": i,
                    "model": d.model,
                    "value": d.value
                }));
        if (saved.length === 0)
            log("no DDC/CI display or backlight to dim");
        for (const s of saved)
            if (s.value > level)
                Brightness.set(s.index, level);
    }
    function undim(why: string): void {
        if (dimPending) {
            dimPending = false;
            dimWait.stop();
            return;
        }
        if (saved === null)
            return;
        const list = saved;
        saved = null;
        log(`${why} -> brightness back (${list.map(s => `${s.model} ${Math.round(s.value * 100)} %`).join(", ") || "nothing dimmed"})`);
        restore(list);
    }
    // after a config reload Brightness has not read its displays yet: restore once it has
    property var restorePending: null
    function restore(list: var): void {
        if (list.some(s => s.index >= Brightness.displays.length)) {
            restorePending = list;
            if (!Brightness.loading)
                Brightness.refresh(true);
            return;
        }
        restorePending = null;
        for (const s of list)
            Brightness.set(s.index, s.value);
    }
    Connections {
        target: Brightness
        function onDisplaysChanged(): void {
            if (root.dimPending && !Brightness.loading)
                root.applyDim();
        }
        function onLoadingChanged(): void {
            if (Brightness.loading)
                return;
            if (root.dimPending)
                root.applyDim();
            if (root.restorePending !== null)
                root.restore(root.restorePending.filter(s => s.index < Brightness.displays.length));
        }
    }
    // the read failed or hangs: dim what is known
    Timer {
        id: dimWait
        interval: 8000
        onTriggered: if (root.dimPending)
            root.applyDim()
    }

    // ---- lock + screen ------------------------------------------------------------------------
    function lockNow(why: string): void {
        if (Lock.locked)
            return;
        log(`${why} -> lock`);
        if (Exec.allow(`idle lock (${why}): luxshell lock screen (Lock.lock)`))
            Lock.lock();
    }
    function screenOff(): void {
        log(`${duration(offMon.timeout)} idle -> screen off`);
        screenIsOff = true;
        if (Exec.allow('idle screen off: hl.dsp.dpms({ action = "off" })'))
            Hyprland.dispatch('hl.dsp.dpms({ action = "off" })');
    }
    // force: also when this shell did not turn them off (after waking up)
    function screenOn(why: string, force: bool): void {
        if (!screenIsOff && !force)
            return;
        screenIsOff = false;
        log(`${why} -> screen on`);
        if (Exec.allow('idle screen on: hl.dsp.dpms({ action = "on" })'))
            Hyprland.dispatch('hl.dsp.dpms({ action = "on" })');
    }

    // ---- logind: sleep and lock-session ---------------------------------------------------------
    property string sessionPath: "" // /org/freedesktop/login1/session/_32 ("" = unknown: every session's Lock counts)
    property bool sleeping: false

    function beforeSleep(): void {
        sleeping = true;
        log("system goes to sleep");
        if (Settings.idleLockBeforeSleep)
            lockNow("before sleep");
        release.restart();
    }
    function afterSleep(): void {
        sleeping = false;
        release.stop();
        log("woke up");
        screenOn("wake", true);
        undim("wake");
        rearm();
    }
    function sessionLock(): void {
        lockNow("loginctl lock-session");
    }

    function login1Line(line: string): void {
        const sleep = /\.login1\.Manager\.PrepareForSleep \((true|false)/.exec(line);
        if (sleep) {
            if (sleep[1] === "true")
                beforeSleep();
            else
                afterSleep();
            return;
        }
        const lock = /^(\S+): org\.freedesktop\.login1\.Session\.Lock \(/.exec(line);
        if (lock && (sessionPath === "" || lock[1] === sessionPath))
            sessionLock();
    }

    Process {
        id: session
        running: root.enabled
        command: ["gdbus", "call", root.bus, "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.GetSession", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /'([^']+)'/.exec(text);
                root.sessionPath = m ? m[1] : "";
            }
        }
    }
    Process {
        id: login1
        running: root.enabled
        command: ["gdbus", "monitor", root.bus, "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => root.login1Line(line)
        }
        // logind restarted or gdbus died: listen again
        onExited: if (root.enabled)
            relisten.restart()
    }
    Timer {
        id: relisten
        interval: 5000
        onTriggered: if (root.enabled && !login1.running)
            login1.running = true
    }

    // delay inhibitor: logind waits (InhibitDelayMaxSec, 5 s) until the lock is up before sleeping
    readonly property bool wantDelay: enabled && Settings.idleLockBeforeSleep
    property bool released: false
    readonly property bool mayInhibit: wantDelay && !Exec.dry
    onWantDelayChanged: if (wantDelay && Exec.dry)
        Exec.allow("idle: sleep delay lock (systemd-inhibit --what=sleep --mode=delay) not taken")
    Process {
        id: delay
        running: root.mayInhibit && !root.released
        command: ["systemd-inhibit", "--what=sleep", "--who=luxshell", "--why=Lock the screen before sleep", "--mode=delay", "sleep", "infinity"]
    }
    // the lock surface needs a moment to be drawn; then the system may sleep
    Timer {
        id: release
        interval: 700
        onTriggered: root.released = true
    }
    onSleepingChanged: if (!sleeping)
        released = false

    // ---- config reload (qs reloads on file changes): give back what this shell turned down
    PersistentProperties {
        id: persist
        reloadableId: "luxshellIdle"

        property string saved: "" // JSON of root.saved (a JS value cannot cross into the new engine)
        property bool screenIsOff: false

        onReloaded: {
            if (screenIsOff) {
                root.screenIsOff = true;
                root.screenOn("reload", false);
            }
            if (saved !== "") {
                try {
                    root.saved = JSON.parse(saved);
                } catch (e) {
                    root.saved = null;
                }
                if (Array.isArray(root.saved))
                    root.undim("reload");
                root.saved = null;
            }
        }
    }
    onSavedChanged: persist.saved = saved === null ? "" : JSON.stringify(saved)
    onScreenIsOffChanged: persist.screenIsOff = screenIsOff

    IpcHandler {
        target: "idle"

        function state(): string {
            return JSON.stringify({
                "enabled": root.enabled,
                "pausedBy": root.pausedBy,
                "armed": root.armed,
                "stage": root.stage,
                "dimmed": root.dimmed,
                "screenOff": root.screenIsOff,
                "session": root.sessionPath,
                "scale": root.scale,
                "timeouts": [dimMon.timeout, lockMon.timeout, offMon.timeout, suspendMon.timeout],
                "summary": root.describe()
            });
        }
        // test path: what logind's PrepareForSleep(true / false) does
        function sleep(going: bool): void {
            if (going)
                root.beforeSleep();
            else
                root.afterSleep();
        }
        // test path: what `loginctl lock-session` does (never run that in the sandbox: it locks the real session)
        function lockSession(): void {
            root.sessionLock();
        }
        function caffeine(on: bool): void {
            Caffeine.set(on);
        }
    }
}
