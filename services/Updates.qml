pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Pending package updates for the island's updates widget: `checkupdates` (pacman-contrib,
// own temporary sync database, the system's is never touched) + `paru -Qua` (AUR), both under
// nice 19 / ionice idle. Nothing runs until a widget registers (use()/release()); then one
// check every Settings.islandUpdatesInterval minutes, the answer cached in
// <cacheDir>/updates.json so restarts within that time do not ask again.
// After every pacman transaction (/var/log/pacman.log changes, e.g. the `paru -Syu` started
// from the widget) it counts again, 15 s after the log went quiet.
// upgrade(): `paru -Syu` in the launcher's terminal (Settings.terminal, services/Apps),
// through Exec (LUXSHELL_DRYRUN only logs).
// LUXSHELL_FAKE_UPDATES="12" or "12+3" (repo + AUR) answers without asking; with it a dry-run
// upgrade() empties the count after 2 s (screenshots of the widget hiding).
Singleton {
    id: root

    property int users: 0
    property int repo: 0
    property int aur: 0
    readonly property int count: repo + (Settings.islandUpdatesAur ? aur : 0)
    property var packages: []          // ["linux 6.18.1-1 -> 6.18.2-1", ...] (repo, then AUR)
    property bool checking: false
    property bool failed: false        // last repo check failed (offline, mirror down)
    property double checked: 0         // ms since epoch of the shown answer
    readonly property bool ready: checked > 0

    readonly property string fake: Env.get("LUXSHELL_FAKE_UPDATES")
    readonly property string cacheDir: {
        const own = Env.get("LUXSHELL_CACHE_DIR");
        if (own !== "")
            return own;
        const xdg = Env.get("XDG_CACHE_HOME");
        return (xdg !== "" ? xdg : Env.get("HOME") + "/.cache") + "/luxshell";
    }
    readonly property int maxAge: Math.max(15, Settings.islandUpdatesInterval) * 60 * 1000

    function use(): void {
        users++;
        if (users === 1)
            start();
    }
    function release(): void {
        users = Math.max(0, users - 1);
    }

    // the cache file is read when the first widget registers (its path is bound to users)
    function start(): void {
        if (fake !== "")
            applyFake();
    }
    function applyFake(): void {
        const p = fake.split("+");
        repo = Math.max(0, parseInt(p[0]) || 0);
        aur = Math.max(0, parseInt(p[1]) || 0);
        const list = [];
        for (let i = 0; i < repo; i++)
            list.push(`package-${i + 1} 1.0-1 -> 1.1-1`);
        for (let i = 0; i < aur; i++)
            list.push(`aur-package-${i + 1} 2.0-1 -> 2.1-1`);
        packages = list;
        checked = Date.now();
    }

    // ask now (click, interval, after a pacman transaction)
    function check(): void {
        if (users === 0 || fake !== "" || proc.running)
            return;
        checking = true;
        proc.running = true;
    }

    function upgrade(): void {
        const script = 'paru -Syu; s=$?; echo; [ "$s" -eq 0 ] && echo "Done." || echo "paru exited with $s."; ' + 'printf "Press Enter to close. "; read -r _';
        const argv = Apps.terminalCommand(["sh", "-c", script], false);
        Exec.run(argv, "updates: paru -Syu in a terminal");
        if (Exec.dry && fake !== "")
            fakeDone.restart();
    }
    Timer {
        id: fakeDone
        interval: 2000
        onTriggered: {
            root.repo = 0;
            root.aur = 0;
            root.packages = [];
            root.checked = Date.now();
        }
    }

    Timer {
        running: root.users > 0 && root.fake === ""
        repeat: true
        interval: 5 * 60 * 1000 // checks the age; asks only when the answer is older than the interval
        onTriggered: if (Date.now() - root.checked >= root.maxAge)
            root.check()
    }

    FileView {
        id: cache
        path: root.users > 0 && root.fake === "" ? root.cacheDir + "/updates.json" : ""
        printErrors: false
        onLoaded: {
            if (root.checked > 0 && Date.now() - root.checked < root.maxAge)
                return; // fresher answer in memory (widget removed and added again)
            try {
                const o = JSON.parse(text());
                if (Date.now() - o.time < root.maxAge) {
                    root.repo = o.repo || 0;
                    root.aur = o.aur || 0;
                    root.packages = o.packages || [];
                    root.checked = o.time;
                    return;
                }
            } catch (e) {}
            root.check();
        }
        onLoadFailed: if (!(root.checked > 0 && Date.now() - root.checked < root.maxAge))
            root.check()
    }

    // R <repo line> | A <aur line> | !repo <exit code>
    Process {
        id: proc
        command: ["nice", "-n", "19", "ionice", "-c3", "sh", "-c", 'r=$(checkupdates 2>/dev/null); rc=$?; ' + '[ "$rc" = 0 ] || [ "$rc" = 2 ] || echo "!repo $rc"; [ -n "$r" ] && printf "%s\\n" "$r" | sed "s/^/R /"; ' + 'if command -v paru >/dev/null 2>&1; then a=$(paru -Qua 2>/dev/null); ' + '[ -n "$a" ] && printf "%s\\n" "$a" | grep -v "\\[ignored\\]" | sed "s/^/A /"; fi; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const r = lines.filter(l => l.startsWith("R ")).map(l => l.slice(2).trim()).filter(l => l !== "");
                const a = lines.filter(l => l.startsWith("A ")).map(l => l.slice(2).trim()).filter(l => l !== "");
                root.failed = lines.some(l => l.startsWith("!repo"));
                if (!root.failed)
                    root.repo = r.length;
                root.aur = a.length;
                root.packages = r.concat(a);
                root.checked = Date.now();
                root.checking = false;
                save.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/updates.json"', "sh", root.cacheDir, JSON.stringify({
                        "time": root.checked,
                        "repo": root.repo,
                        "aur": root.aur,
                        "packages": root.packages
                    })];
                save.running = true;
            }
        }
        onExited: root.checking = false
    }
    Process {
        id: save
    }

    // any pacman transaction (paru -Syu from the widget, pacman in a terminal): count again
    // once the log is quiet for a while
    FileView {
        path: root.users > 0 && root.fake === "" ? "/var/log/pacman.log" : ""
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: settle.restart()
    }
    Timer {
        id: settle
        interval: 15000
        onTriggered: root.check()
    }
}
