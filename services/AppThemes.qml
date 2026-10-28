pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Settings > Integrations, apps theme (opt-in, default off). ThemeSync writes the applied
// theme to luxshell's cache; these switches hook other apps up to those files by adding
// ONE marked line to their config, and remove exactly that line when switched off:
//
//   kitty  <config>/kitty/kitty.conf, at the end (kitty reads includes in order):
//            # luxshell theme (... removes them)        <- marker
//            include <cache>/kitty-theme.conf
//          running kitty windows reload on SIGUSR1 (after the switch and on every theme
//          change); kitty without that support picks it up on its next start
//   GTK    <config>/gtk-3.0/gtk.css and <config>/gtk-4.0/gtk.css, at the top (@import must
//          come first): @import url("file://<cache>/gtk.css"); /* luxshell theme ... */
//          GTK reads it when an app starts
//
// The files are edited in place (a symlinked config keeps its link and permissions); the
// first edit keeps a copy as <file>.bak-luxshell. Missing files / folders are created, and a
// file that only held our line is deleted again when the switch goes off.
// Tests: LUXSHELL_INTEGRATION_ROOT=<dir> edits <dir>/.config/... instead of $HOME; with
// LUXSHELL_DRYRUN=1 and no such root nothing is edited (and the kitty signal only logs).
Singleton {
    id: root

    readonly property bool redirected: Env.integrationRoot !== ""
    readonly property bool blocked: Exec.dry && !redirected
    readonly property string home: redirected ? Env.integrationRoot : Env.get("HOME")
    readonly property string configHome: !redirected && Env.get("XDG_CONFIG_HOME") !== "" ? Env.get("XDG_CONFIG_HOME") : home + "/.config"
    readonly property string kittyConf: !redirected && Env.get("KITTY_CONFIG_DIRECTORY") !== "" ? Env.get("KITTY_CONFIG_DIRECTORY") + "/kitty.conf" : configHome + "/kitty/kitty.conf"
    readonly property var gtkFiles: [configHome + "/gtk-3.0/gtk.css", configHome + "/gtk-4.0/gtk.css"]

    readonly property string kittyTheme: Wallpapers.cacheDir + "/kitty-theme.conf"
    readonly property string gtkTheme: Wallpapers.cacheDir + "/gtk.css"
    readonly property string kittyMarker: "# luxshell theme (Settings > Integrations > kitty added the next line; switching it off removes both)"
    readonly property string kittyLine: "include " + kittyTheme
    readonly property string gtkLine: `@import url("file://${gtkTheme}"); /* luxshell theme (Settings > Integrations > GTK added this line; switching it off removes it) */`

    // per file: "on" (our lines are there) | "off" | "missing" (no such file) | "" (not checked)
    property var status: ({})

    function tilde(p: string): string {
        const h = Env.get("HOME");
        return h !== "" && p.startsWith(h + "/") ? "~" + p.slice(h.length) : p;
    }
    function statusOf(file: string): string {
        return status[file] ?? "";
    }

    readonly property bool kittyWanted: Settings.integrationKitty
    readonly property bool gtkWanted: Settings.integrationGtk
    onKittyWantedChanged: if (Settings.ready)
        syncKitty(true)
    onGtkWantedChanged: if (Settings.ready)
        syncGtk(true)

    // start: bring the files in line with the switches (a switch turned off while luxshell
    // was not running still removes its line; nothing happens to files without our lines)
    property bool started: false
    Connections {
        target: Settings
        function onReadyChanged(): void {
            root.start();
        }
    }
    Component.onCompleted: start()
    function start(): void {
        if (started || !Settings.ready)
            return;
        started = true;
        syncKitty(false);
        syncGtk(false);
    }

    function syncKitty(user: bool): void {
        job(kittyWanted ? "add" : "remove", kittyConf, "bottom", [kittyMarker, kittyLine], user);
    }
    function syncGtk(user: bool): void {
        for (const f of gtkFiles)
            job(gtkWanted ? "add" : "remove", f, "top", [gtkLine], user);
    }
    function recheck(): void {
        job("check", kittyConf, "bottom", [kittyMarker, kittyLine], false);
        for (const f of gtkFiles)
            job("check", f, "top", [gtkLine], false);
    }

    function reloadKitty(): void {
        Exec.run(["pkill", "-USR1", "-x", "kitty"], "reload kitty (SIGUSR1)");
    }

    // a theme change rewrote kitty-theme.conf: running kitty windows follow
    Connections {
        target: ThemeSync
        function onExported(names: var): void {
            if (root.kittyWanted && names.includes("kitty-theme.conf"))
                root.reloadKitty();
        }
    }

    // ---- file jobs: one at a time -------------------------------------------------------
    property var queue: []
    function job(op: string, file: string, pos: string, lines: var, user: bool): void {
        if (blocked) {
            if (op !== "check")
                console.info(`luxshell[dry]: integration ${op} ${file} skipped (set LUXSHELL_INTEGRATION_ROOT to test)`);
            return;
        }
        queue = [...queue, {
                "op": op,
                "file": file,
                "pos": pos,
                "lines": lines,
                "user": user
            }];
        if (!proc.running)
            next();
    }
    function next(): void {
        if (queue.length === 0)
            return;
        const j = queue[0];
        queue = queue.slice(1);
        proc.current = j;
        proc.command = ["bash", "-c", script, "luxshell-integration", j.op, j.file, j.pos, ...j.lines];
        proc.running = true;
    }

    // add | remove | check <file> <top|bottom> <exact lines...>; prints on | off | missing,
    // plus "changed" when the file was rewritten
    readonly property string script: `
op=$1 f=$2 pos=$3; shift 3
t=$(readlink -f -- "$f" 2>/dev/null); [ -n "$t" ] || t=$f
ours() { local line l; while IFS= read -r line || [ -n "$line" ]; do for l in "$@"; do [ "$line" = "$l" ] && break; done; [ "$line" = "$l" ] || printf '%s\\n' "$line"; done <"$t"; }
count=0; total=$#
if [ -f "$t" ]; then for l in "$@"; do grep -qxF -- "$l" "$t" && count=$((count + 1)); done; fi
case $op in
check)
    [ -e "$t" ] || { echo missing; exit 0; }
    [ "$count" = "$total" ] && echo on || echo off ;;
add)
    [ "$count" = "$total" ] && { echo on; exit 0; }
    mkdir -p -- "$(dirname -- "$t")" || exit 1
    tmp=$t.luxshell-tmp
    if [ -f "$t" ]; then
        [ -e "$t.bak-luxshell" ] || cp -p -- "$t" "$t.bak-luxshell"
        if [ "$pos" = top ]; then { printf '%s\\n' "$@"; ours "$@"; } >"$tmp"; else { ours "$@"; printf '%s\\n' "$@"; } >"$tmp"; fi
    else
        printf '%s\\n' "$@" >"$tmp"
    fi
    cat -- "$tmp" >"$t" && rm -f -- "$tmp" || exit 1
    echo on; echo changed ;;
remove)
    [ -f "$t" ] && [ "$count" -gt 0 ] || { [ -e "$t" ] && echo off || echo missing; exit 0; }
    tmp=$t.luxshell-tmp
    ours "$@" >"$tmp" || exit 1
    # a file that only ever held our lines (we created it, so no backup exists) goes away again
    if [ ! -s "$tmp" ] && [ ! -e "$t.bak-luxshell" ]; then rm -f -- "$tmp" "$t"; echo missing; echo changed; exit 0; fi
    [ -e "$t.bak-luxshell" ] || cp -p -- "$t" "$t.bak-luxshell"
    cat -- "$tmp" >"$t" && rm -f -- "$tmp" || exit 1
    echo off; echo changed ;;
esac`

    Process {
        id: proc
        property var current: null
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            const j = proc.current;
            const words = out.text.split("\n").map(s => s.trim()).filter(s => s !== "");
            if (code !== 0) {
                console.warn(`luxshell: integration ${j.op} ${j.file} failed: ${err.text.trim()}`);
            } else {
                const s = Object.assign({}, root.status);
                s[j.file] = words[0] ?? "";
                root.status = s;
                if (words.includes("changed")) {
                    console.info(`luxshell: integration ${j.op === "add" ? "added to" : "removed from"} ${j.file}`);
                    if (j.file === root.kittyConf)
                        root.reloadKitty();
                }
            }
            root.next();
        }
    }
}
