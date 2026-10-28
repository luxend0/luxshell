pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "fuzzy.js" as Fuzzy

// Desktop entries: icon lookup for windows, ranking + launching for the launcher.
//
// rank(query): fuzzy quality (fuzzy.js) x 100 + usage boost (AppUsage: frecency 0..14,
// "picked after typing this" 0..18). Empty query: used apps by frecency, then A-Z.
// Settings (Launcher page): launcherRankUsage off = no usage boost, nothing recorded, empty
// query A-Z; launcherHiddenApps = desktop ids rank() never returns.
Singleton {
    id: root

    readonly property var all: [...DesktopEntries.applications.values].filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    // lower-cased fields + boundary masks, rebuilt only when the entries change
    readonly property var records: all.map(e => Fuzzy.index(e))

    function entryFor(appId: string): var {
        return appId !== "" ? DesktopEntries.heuristicLookup(appId) : null;
    }

    // themed icon path, "" if nothing resolves (caller shows a fallback glyph)
    function iconFor(appId: string): string {
        const name = entryFor(appId)?.icon || appId;
        return name ? Quickshell.iconPath(name, true) : "";
    }

    function iconPath(name: string): string {
        if (!name)
            return "";
        if (name.startsWith("/"))
            return "file://" + name;
        return Quickshell.iconPath(name, true);
    }

    // icon of a desktop entry: Icon=, then the id and its last reverse-DNS part,
    // so entries with an icon name the theme lacks still find one; "" if none resolves
    function iconSource(entry: var): string {
        if (!entry)
            return "";
        const icon = entry.icon ?? "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        const id = String(entry.id ?? "").replace(/\.desktop$/, "");
        const names = [icon, icon.toLowerCase(), id, id.split(".").pop(), id.split(".").pop().toLowerCase()];
        for (const n of names) {
            if (n === "")
                continue;
            const path = Quickshell.iconPath(n, true);
            if (path !== "")
                return path;
        }
        return "";
    }

    // second line of a launcher row: GenericName, else Comment (ref/16)
    function subtitle(entry: var): string {
        const g = entry?.genericName ?? "";
        if (g !== "" && g !== entry.name)
            return g;
        return entry?.comment ?? "";
    }

    readonly property var hidden: {
        const h = {};
        for (const id of Array.from(Settings.launcherHiddenApps ?? []))
            h[id] = true;
        return h;
    }

    function rank(query: string): var {
        const p = Fuzzy.prepare(query);
        void AppUsage.revision; // re-rank after launches and external edits
        const usage = Settings.launcherRankUsage;
        const hide = hidden;
        if (p.q === "") {
            const used = [];
            const rest = [];
            for (const r of records) {
                if (hide[r.id])
                    continue;
                const f = usage ? AppUsage.frecency(r.id) : 0;
                if (f > 0)
                    used.push({
                        "e": r.entry,
                        "f": f
                    });
                else
                    rest.push(r.entry);
            }
            used.sort((a, b) => b.f - a.f || a.e.name.localeCompare(b.e.name));
            return used.map(u => u.e).concat(rest);
        }
        const hits = [];
        for (const r of records) {
            if (hide[r.id])
                continue;
            const q = Fuzzy.quality(r, p.q, p.tokens);
            if (q <= 0)
                continue;
            hits.push({
                "e": r.entry,
                "s": q * 100 + (usage ? AppUsage.boost(r.id) + AppUsage.queryBonus(r.id, p.q) : 0),
                "n": r.name
            });
        }
        hits.sort((a, b) => b.s - a.s || a.n.length - b.n.length || a.n.localeCompare(b.n));
        return hits.map(h => h.e);
    }

    // kept for other callers: first `limit` ranked entries
    function search(query: string, limit: int): var {
        return rank(query).slice(0, limit);
    }

    // Starts the entry detached (Path= or $HOME as cwd, terminal if Terminal=true)
    // and records the launch. Returns false if there is nothing to run.
    function launch(entry: var, query: string): bool {
        if (!entry)
            return false;
        let argv = [];
        const list = entry.command ?? [];
        for (let i = 0; i < list.length; i++)
            argv.push(String(list[i]));
        if (argv.length === 0 && (entry.execString ?? "") !== "")
            argv = ["sh", "-c", entry.execString.replace(/%[fFuUdDnNickvm]/g, "").trim()];
        if (argv.length === 0) {
            console.warn(`luxshell: "${entry.id}" has nothing to execute`);
            return false;
        }
        if (entry.runInTerminal)
            argv = ["sh", "-c", root.terminalScript, "sh"].concat(argv);
        const ctx = {
            "command": argv
        };
        // Path= from the entry, else $HOME (never the shell's own working directory)
        const dir = (entry.workingDirectory ?? "") !== "" ? entry.workingDirectory : Env.get("HOME");
        if (dir !== "")
            ctx.workingDirectory = dir;
        Quickshell.execDetached(ctx);
        if (Settings.launcherRankUsage)
            AppUsage.record(entry.id, Fuzzy.prepare(query).q);
        return true;
    }

    // ---- helpers for the other launcher providers ----------------------------------
    readonly property var terminal: [Settings.terminal || "kitty"] // settings app, Launcher page

    // match quality of an arbitrary string (window titles), 0 = no match
    function fuzzy(text: string, q: string): real {
        if (q === "" || !text)
            return 0;
        const r = Fuzzy.index({ "name": text, "id": "", "genericName": "", "keywords": [], "comment": "", "execString": "" });
        return Fuzzy.quality(r, Fuzzy.prepare(q).q, Fuzzy.prepare(q).tokens);
    }

    function runInTerminal(argv: var, hold: bool, cwd: string): void {
        Quickshell.execDetached({
            "command": terminalCommand(argv, hold),
            "workingDirectory": cwd || Env.get("HOME")
        });
    }

    // argv in the chosen terminal; hold = the window stays open after the command
    function terminalCommand(argv: var, hold: bool): var {
        const t = terminal[0];
        switch (t) {
        case "kitty":
        case "foot":
            return [t, ...(hold ? ["--hold"] : []), ...argv];
        case "alacritty":
        case "konsole":
            return [t, ...(hold ? ["--hold"] : []), "-e", ...argv];
        case "ghostty":
            return [t, ...(hold ? ["--wait-after-command=true"] : []), "-e", ...argv];
        case "wezterm":
            return [t, "start", "--", ...argv];
        default:
            return [t, ...(hold ? ["-hold"] : []), "-e", ...argv];
        }
    }

    // the chosen terminal, else $TERMINAL, else the first installed of a few common ones, with the right exec flag
    readonly property string terminalScript: 'for t in ' + terminal[0].replace(/[^a-z0-9._-]/gi, "") + ' "$TERMINAL" kitty foot alacritty ghostty wezterm konsole xterm; do ' + '[ -n "$t" ] && command -v "$t" >/dev/null 2>&1 && break; t=; done; ' + '[ -n "$t" ] || exit 127; case "${t##*/}" in ' + 'kitty|foot) exec "$t" "$@" ;; wezterm) exec "$t" start -- "$@" ;; *) exec "$t" -e "$@" ;; esac'
}
