pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What starts at login (Settings > System > Startup Apps), from three places:
//
//   xdg       $XDG_CONFIG_HOME/autostart/*.desktop (the user's) over $XDG_CONFIG_DIRS/autostart
//             (default /etc/xdg/autostart, the system's): a user file with the name of a system file
//             replaces it. Off = Hidden=true (X-GNOME-Autostart-enabled=false is read as off too).
//             Every write goes through Exec.callUser (tmp + mv, or rm):
//               setXdg(e, on)   user entry: rewrites Hidden= (and X-GNOME-Autostart-enabled=true when on)
//               removeXdg(e)    user entry: deletes the file (the page asks first)
//               setSystem(e, on) system entry, for this user only: off = a copy with Hidden=true and
//                               X-Luxshell-Hides=true in the user folder; on = that copy deleted again
//                               (a copy the user made himself only gets Hidden=false)
//   luxshell  HyprSystem.autostart ([{ cmd, enabled }] -> hl.on("hyprland.start") in luxshell-system.lua):
//             addCommand(cmd), addApp(entry), setLuxshell(i, on), removeLuxshell(i)
//   hyprland  hl.exec_cmd(...) lines of $XDG_CONFIG_HOME/hypr/hyprland.lua and hypr/luxos/*.lua, read only
//             (luxshell-system.lua is luxshell's own list; files ending in .bak-* are not *.lua)
//   runner    XDG entries only start when something runs them: systemd's xdg-desktop-autostart.target
//             (started by a session that pulls it in), dex or uwsm (`runner`: "" = nothing does).
Singleton {
    id: root

    readonly property string configHome: Exec.configHome
    readonly property string userDir: configHome + "/autostart"
    readonly property string hyprDir: configHome + "/hypr"
    readonly property string desktop: Env.get("XDG_CURRENT_DESKTOP")

    property var user: []        // [{ file, path, name, exec, icon, comment, on, why, text, onlyIn, notIn }]
    property var system: []      // same + override (the user's file of the same name or null)
    property var hypr: []        // [{ cmd, file, line, start, nested }]
    readonly property string runner: runnerOf() // what starts XDG entries: "systemd" | "dex" | "uwsm" | ""
    property bool targetActive: false
    property bool ready: false
    property string busy: ""     // path being written
    property string error: ""
    signal notice(string text)   // dry run: what would have been written (the page shows a toast)

    readonly property var luxshell: HyprSystem.autostart

    // ---- .desktop text -------------------------------------------------------------------------
    // keys of the [Desktop Entry] group (unlocalized)
    function fields(text: string): var {
        const f = {};
        let inMain = false;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                inMain = line === "[Desktop Entry]";
                continue;
            }
            if (!inMain || line === "" || line.startsWith("#"))
                continue;
            const i = line.indexOf("=");
            if (i <= 0)
                continue;
            const k = line.slice(0, i).trim();
            if (!(k in f))
                f[k] = line.slice(i + 1).trim();
        }
        return f;
    }
    // text with key=value set in [Desktop Entry] (replaced in place, else right under the header)
    function withKey(text: string, key: string, value: string): string {
        const lines = text.replace(/\n+$/, "").split("\n");
        let start = lines.findIndex(l => l.trim() === "[Desktop Entry]");
        if (start < 0) {
            lines.unshift("[Desktop Entry]");
            start = 0;
        }
        let end = lines.findIndex((l, i) => i > start && l.trim().startsWith("["));
        if (end < 0)
            end = lines.length;
        for (let i = start + 1; i < end; i++) {
            const l = lines[i];
            const j = l.indexOf("=");
            if (j > 0 && l.slice(0, j).trim() === key) {
                lines[i] = `${key}=${value}`;
                return lines.join("\n") + "\n";
            }
        }
        lines.splice(start + 1, 0, `${key}=${value}`);
        return lines.join("\n") + "\n";
    }
    function withoutKey(text: string, key: string): string {
        return text.split("\n").filter(l => {
            const j = l.indexOf("=");
            return !(j > 0 && l.slice(0, j).trim() === key);
        }).join("\n");
    }
    function listOf(v: var): var { // var: a missing key stays undefined (a string parameter would make it "undefined")
        return String(v ?? "").split(";").map(s => s.trim()).filter(s => s !== "");
    }

    function entry(kind: string, path: string, text: string): var {
        const f = fields(text);
        const hidden = String(f.Hidden ?? "").toLowerCase() === "true";
        const gnomeOff = String(f["X-GNOME-Autostart-enabled"] ?? "").toLowerCase() === "false";
        const onlyIn = listOf(f.OnlyShowIn);
        const notIn = listOf(f.NotShowIn);
        const desks = root.desktop.split(":").filter(s => s !== "");
        const skipped = (onlyIn.length > 0 && !onlyIn.some(d => desks.includes(d))) || notIn.some(d => desks.includes(d));
        const file = path.slice(path.lastIndexOf("/") + 1);
        return {
            "kind": kind,
            "file": file,
            "path": path,
            "text": text,
            "name": f.Name || file.replace(/\.desktop$/, ""),
            "exec": f.Exec ?? "",
            "icon": f.Icon ?? "",
            "comment": f.Comment ?? "",
            "on": !hidden && !gnomeOff,
            "why": hidden ? "Hidden=true" : gnomeOff ? "X-GNOME-Autostart-enabled=false" : "",
            "ours": String(f["X-Luxshell-Hides"] ?? "").toLowerCase() === "true",
            "onlyIn": onlyIn,
            "notIn": notIn,
            "skipped": skipped // OnlyShowIn / NotShowIn leave it out in this desktop
        };
    }

    // ---- writes (Exec.callUser) ------------------------------------------------------------------
    function inUserDir(path: string): bool {
        return path.startsWith(userDir + "/") && !path.slice(userDir.length + 1).includes("/") && path.endsWith(".desktop");
    }
    function write(path: string, text: string, what: string): void {
        if (busy !== "")
            return; // one change at a time
        if (!inUserDir(path)) {
            console.warn(`luxshell: autostart: refused to write ${path}`);
            return;
        }
        busy = path;
        Exec.callUser(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" > "$2.luxshell-tmp" && mv -f "$2.luxshell-tmp" "$2"', "sh", userDir, path, text], what, (ok, t) => root.finished(ok, t, what));
    }
    function remove(path: string, what: string): void {
        if (busy !== "")
            return;
        if (!inUserDir(path)) {
            console.warn(`luxshell: autostart: refused to delete ${path}`);
            return;
        }
        busy = path;
        Exec.callUser(["rm", "-f", "--", path], what, (ok, t) => root.finished(ok, t, what));
    }
    function finished(ok: bool, text: string, what: string): void {
        busy = "";
        error = ok ? "" : (text || "could not change the autostart folder");
        if (ok && text === "dry run")
            notice(`Dry run: ${what} (nothing written)`);
        else if (ok)
            refresh();
    }

    function setXdg(e: var, on: bool): void {
        if (!e || e.on === on)
            return;
        let t = withKey(e.text, "Hidden", on ? "false" : "true");
        if (on && e.why === "X-GNOME-Autostart-enabled=false")
            t = withKey(t, "X-GNOME-Autostart-enabled", "true");
        write(e.path, t, `autostart ${on ? "on" : "off"}: ${e.name}`);
    }
    function removeXdg(e: var): void {
        if (e)
            remove(e.path, `autostart remove: ${e.name}`);
    }
    // a system entry for this user only
    function setSystem(e: var, on: bool): void {
        if (!e)
            return;
        const o = e.override;
        const path = userDir + "/" + e.file;
        if (on) {
            if (!o)
                return;
            if (o.ours)
                remove(o.path, `autostart show again: ${e.name} (luxshell's hiding copy deleted)`);
            else
                setXdg(o, true);
            return;
        }
        if (o) {
            setXdg(o, false);
            return;
        }
        let t = withoutKey(e.text, "X-GNOME-Autostart-enabled");
        t = withKey(t, "Hidden", "true");
        t = withKey(t, "X-Luxshell-Hides", "true");
        write(path, `# Hides ${e.path} for this user (luxshell Settings > Startup Apps). Delete this file to undo.\n` + t, `autostart hide for this user: ${e.name}`);
    }

    // ---- luxshell's own list (HyprSystem) ----------------------------------------------------------
    // an app's command line without field codes (%U, %f, ...)
    function commandOf(e: var): string {
        if (!e)
            return "";
        // flatpak's file forwarding (`--file-forwarding app @@u %U @@`) is empty at login
        const s = String(e.execString ?? "").replace(/\s%[fFuUdDnNickvm]/g, "").replace(/%%/g, "%").replace(/\s+@@u?\s+@@/g, "").replace(/\s--file-forwarding\b/, "").trim();
        if (s !== "")
            return s;
        return Array.from(e.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a)).join(" ");
    }
    // the launcher app a command starts, or null
    function appFor(cmd: string): var {
        const c = cmd.trim();
        return Apps.all.find(e => commandOf(e) === c) ?? null;
    }
    function addCommand(cmd: string): bool {
        const c = String(cmd ?? "").trim();
        if (c === "")
            return false;
        if (luxshell.some(e => e.cmd === c))
            return false;
        HyprSystem.setAutostart([...luxshell, {
                "cmd": c,
                "enabled": true
            }]);
        return true;
    }
    function addApp(e: var): bool {
        return addCommand(commandOf(e));
    }
    function setLuxshell(i: int, on: bool): void {
        HyprSystem.setAutostart(luxshell.map((e, j) => j === i ? {
                "cmd": e.cmd,
                "enabled": on
            } : e));
    }
    function removeLuxshell(i: int): var {
        const before = luxshell;
        HyprSystem.setAutostart(luxshell.filter((_, j) => j !== i));
        return before;
    }

    // ---- hyprland.lua: hl.exec_cmd(<lua expression>) -> the command as text ------------------------
    function luaCommand(src: string): string {
        let i = 0, out = "", depth = 0;
        while (i < src.length) {
            const ch = src[i];
            if (ch === '"' || ch === "'") {
                let j = i + 1, s = "";
                while (j < src.length && src[j] !== ch) {
                    if (src[j] === "\\" && j + 1 < src.length) {
                        const n = src[j + 1];
                        s += n === "n" ? "\n" : n === "t" ? "\t" : n;
                        j += 2;
                        continue;
                    }
                    s += src[j++];
                }
                out += s;
                i = j + 1;
                continue;
            }
            const env = /^os\.getenv\(\s*["']([A-Za-z_0-9]+)["']\s*\)/.exec(src.slice(i));
            if (env) {
                out += env[1] === "HOME" ? "~" : "$" + env[1];
                i += env[0].length;
                continue;
            }
            if (src.startsWith("..", i)) {
                i += 2;
                continue;
            }
            if (ch === "," && depth === 0)
                break;
            if (ch === "(")
                depth++;
            if (ch === ")") {
                if (depth === 0)
                    break;
                depth--;
            }
            if (/[A-Za-z_]/.test(ch)) { // a Lua variable: shown by name
                const m = /^[A-Za-z_][A-Za-z_0-9.]*/.exec(src.slice(i));
                out += "<" + m[0] + ">";
                i += m[0].length;
                continue;
            }
            i++;
        }
        return out.trim();
    }
    function parseHypr(text: string): var {
        const out = [];
        for (const line of text.split("\n")) {
            // <file>:<n>:<source line>
            const m = /^(.*?):(\d+):(.*)$/.exec(line);
            if (!m)
                continue;
            const src = m[3];
            const code = src.replace(/--.*$/, "");
            const re = /(^|[^.\w])hl\.exec_cmd\(/g;
            let r;
            while ((r = re.exec(code)) !== null) {
                const cmd = luaCommand(code.slice(r.index + r[0].length));
                if (cmd === "")
                    continue;
                out.push({
                    "cmd": cmd,
                    "file": m[1],
                    "short": m[1].startsWith(root.hyprDir + "/") ? m[1].slice(root.hyprDir.length + 1) : m[1],
                    "line": Number(m[2]),
                    "start": code.includes("hyprland.start"),
                    "nested": /^\s/.test(src) // inside a block (if / function): may not run
                });
            }
        }
        return out;
    }

    // ---- read ------------------------------------------------------------------------------------
    function refresh(): void {
        if (!xdgReader.running)
            xdgReader.running = true;
        if (!hyprReader.running)
            hyprReader.running = true;
        if (!runnerReader.running)
            runnerReader.running = true;
    }

    function readXdg(text: string): void {
        const users = [], systems = [];
        for (const chunk of text.split("\x1e")) {
            const nl = chunk.indexOf("\n");
            if (nl <= 0)
                continue;
            const head = chunk.slice(0, nl).split("\t");
            if (head.length < 2)
                continue;
            const e = entry(head[0], head[1], chunk.slice(nl + 1));
            if (head[0] === "user")
                users.push(e);
            else if (!systems.some(s => s.file === e.file)) // first config dir wins
                systems.push(e);
        }
        const byFile = {};
        for (const u of users)
            byFile[u.file] = u;
        root.system = systems.map(s => Object.assign(s, {
                "override": byFile[s.file] ?? null,
                "on": byFile[s.file] ? byFile[s.file].on : s.on
            })).sort((a, b) => a.name.localeCompare(b.name));
        root.user = users.filter(u => !systems.some(s => s.file === u.file)).sort((a, b) => a.name.localeCompare(b.name));
        root.ready = true;
    }

    // "\x1e<user|system>\t<path>\n<text>" per file
    Process {
        id: xdgReader
        command: ["sh", "-c", 'emit() { for f in "$1"/*.desktop; do [ -f "$f" ] || continue; printf "\\036%s\\t%s\\n" "$2" "$f"; cat "$f"; echo; done; }; emit "$1" user; IFS=:; for d in ${XDG_CONFIG_DIRS:-/etc/xdg}; do emit "$d/autostart" system; done; true', "sh", root.userDir]
        stdout: StdioCollector {
            onStreamFinished: root.readXdg(text)
        }
    }
    // "<file>:<line>:<source>" of every exec_cmd in hyprland.lua and luxos/*.lua
    Process {
        id: hyprReader
        command: ["sh", "-c", 'for f in "$1/hyprland.lua" "$1"/luxos/*.lua; do [ -f "$f" ] || continue; case "$f" in */luxshell-system.lua) continue ;; esac; grep -n "exec_cmd" "$f" | sed "s|^|$f:|"; done; true', "sh", root.hyprDir]
        stdout: StdioCollector {
            onStreamFinished: root.hypr = root.parseHypr(text)
        }
    }
    Process {
        id: runnerReader
        command: ["sh", "-c", 'systemctl --user is-active xdg-desktop-autostart.target 2>/dev/null; true']
        stdout: StdioCollector {
            onStreamFinished: root.targetActive = text.trim() === "active"
        }
    }
    // who starts the XDG entries: the systemd target (now or from luxshell's / Hyprland's list), dex, uwsm
    function runnerOf(): string {
        const cmds = root.hypr.map(h => h.cmd).concat(root.luxshell.filter(e => e.enabled).map(e => e.cmd));
        if (root.targetActive)
            return "systemd";
        if (cmds.some(c => /(^|[\s/])dex(\s|$)/.test(c)))
            return "dex";
        if (cmds.some(c => /(^|[\s/])uwsm(\s|$)/.test(c)) || Env.get("UWSM_FINALIZE_VARNAMES") !== "")
            return "uwsm";
        return "";
    }
}
