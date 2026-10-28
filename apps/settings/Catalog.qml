pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.apps.settings.pages

// The pages of the settings app, in sidebar order: one line per page, each page is a
// file in pages/ (data: sections of options, see README.md for every option kind).
// Pages without options (or hidden: true) stay out of the sidebar and search.
//
// Catalog fills in what an option with a `key` leaves out (value/set/reset from
// config/Settings), keeps the font list, the file chooser and the search.
Singleton {
    id: root

    readonly property list<QtObject> sources: [
        BarIsland {},
        Media {},
        ClockDate {},
        Appearance {},
        ThemeEditor {},
        Wallpaper {},
        Motion {},
        Launcher {},
        OverviewPickers {},
        Notifications {},
        ControlCenter {},
        LockScreen {},
        PowerPage {},
        Keybinds {},
        Integrations {},
        System {},
        Demo {}
    ]

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    // ---- pages -------------------------------------------------------------------------
    readonly property var pages: sources.map(src => ({
                "id": src.pageId,
                "title": src.title,
                "subtitle": src.subtitle,
                "icon": typeof src.icon === "number" ? (src.icon > 0 ? glyph(src.icon) : "") : src.icon,
                "hidden": src.hidden,
                "sections": src.sections.map(s => ({
                            "title": s.title ?? "",
                            "options": (s.options ?? []).map(o => root.normalize(o))
                        }))
            }))

    readonly property var visiblePages: pages.filter(p => !p.hidden && p.sections.some(s => s.options.length > 0))

    function visible(id: string): bool {
        return visiblePages.some(p => p.id === id);
    }
    function pageById(id: string): var {
        return visiblePages.find(p => p.id === id) ?? visiblePages[0];
    }

    // An option with `key` reads and writes that key of `store` (default config/Settings;
    // any object with get/set/isDefault/reset/defaultOf works). `keys` lists what the
    // reset button restores (default [key]); resettable: false hides it.
    function normalize(o: var): var {
        const n = Object.assign({}, o);
        const store = o.store ?? Settings;
        if (o.key !== undefined) {
            if (n.value === undefined)
                n.value = () => store.get(o.key);
            if (n.set === undefined)
                n.set = v => store.set(o.key, v);
            if (n.apply === undefined && (o.kind === "text"))
                n.apply = t => store.set(o.key, t);
        }
        if (n.valid === undefined)
            n.valid = t => true;
        const keys = o.resettable === false ? [] : (o.keys ?? (o.key !== undefined ? [o.key] : []));
        n.resetKeys = keys;
        if (n.modified === undefined)
            n.modified = keys.length > 0 ? () => keys.some(k => !store.isDefault(k)) : () => false;
        if (n.reset === undefined)
            n.reset = () => keys.forEach(k => store.reset(k));
        if (n.defaultValue === undefined)
            n.defaultValue = keys.length === 1 && o.key !== undefined ? () => store.defaultOf(o.key) : () => undefined;
        if (o.kind === "font" && n.options === undefined)
            n.options = () => root.fontOptions(o.mono === true, n.value());
        return n;
    }

    // ---- reset ---------------------------------------------------------------------------
    function pageOptions(page: var): var {
        const out = [];
        for (const s of page?.sections ?? [])
            for (const o of s.options)
                out.push(o);
        return out;
    }
    // live: options of the page that differ from their default
    function changedOptions(page: var): var {
        return pageOptions(page).filter(o => o.modified());
    }
    function resetPage(page: var): int {
        const opts = changedOptions(page);
        if (opts.length === 0)
            return 0;
        // undo: every Settings key, plus the values of options kept in another store
        const snap = Settings.snapshot();
        const foreign = opts.filter(o => o.store && o.store !== Settings && o.key !== undefined).map(o => ({
                    "o": o,
                    "v": o.store.get(o.key)
                }));
        opts.forEach(o => o.reset());
        SettingsApp.toast(opts.length === 1 ? `Reset 1 option on ${page.title}` : `Reset ${opts.length} options on ${page.title}`, () => {
            Settings.restore(snap);
            foreign.forEach(f => f.o.store.set(f.o.key, f.v));
        });
        return opts.length;
    }
    // live: preferences (Settings keys, no runtime state) that differ from the default
    function changedCount(): int {
        return Settings.keys().filter(k => !Settings.isState(k) && !Settings.isDefault(k)).length;
    }
    function resetAll(): void {
        const n = changedCount();
        const snap = Settings.snapshot();
        Settings.resetAll();
        SettingsApp.toast(n === 1 ? "Reset 1 setting" : `Reset ${n} settings`, snap);
    }

    // ---- fonts -----------------------------------------------------------------------------
    // every installed family (sorted, without the "[foundry]" duplicates); monospace ones
    // from fontconfig, read once on first use
    readonly property var fontFamilies: {
        const seen = {};
        const out = [];
        for (const f of Qt.fontFamilies()) {
            const name = f.replace(/\s*\[.*\]$/, "");
            if (name === "" || seen[name.toLowerCase()])
                continue;
            seen[name.toLowerCase()] = true;
            out.push(name);
        }
        return out.sort((a, b) => a.localeCompare(b));
    }
    property var monoFamilies: []
    property bool monoAsked: false

    function fontOptions(mono: bool, current: string): var {
        if (mono && !monoAsked) {
            monoAsked = true;
            fcMono.running = true;
        }
        let list = mono ? monoFamilies : fontFamilies;
        if (current !== "" && !list.includes(current))
            list = [current, ...list];
        return list.map(f => ({
                    "value": f,
                    "label": f,
                    "detail": "",
                    "font": f
                }));
    }

    Process {
        id: fcMono
        command: ["fc-list", ":spacing=mono", "family"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                for (const line of text.split("\n"))
                    for (const part of line.split(",")) {
                        const n = part.trim();
                        if (n !== "" && !seen[n.toLowerCase()] && !n.includes("\\")) {
                            seen[n.toLowerCase()] = true;
                            out.push(n);
                        }
                    }
                root.monoFamilies = out.sort((a, b) => a.localeCompare(b));
            }
        }
    }

    // ---- file chooser (zenity, when installed) -------------------------------------------
    property bool hasChooser: false
    property var chooserDone: null

    Process {
        running: true
        command: ["sh", "-c", "command -v zenity"]
        onExited: code => root.hasChooser = code === 0
    }

    // mode: "folder" | "file" | "save"; done(path) only when the user picked one
    function choosePath(mode: string, title: string, start: string, done: var): void {
        if (!hasChooser || chooser.running)
            return;
        const argv = ["zenity", "--file-selection", `--title=${title}`];
        if (mode === "folder")
            argv.push("--directory");
        if (mode === "save")
            argv.push("--save");
        if (start !== "")
            argv.push(`--filename=${expand(start)}${mode === "folder" && !start.endsWith("/") ? "/" : ""}`);
        chooserDone = done;
        chooser.command = argv;
        chooser.running = true;
    }

    Process {
        id: chooser
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "" && root.chooserDone)
                    root.chooserDone(root.tilde(p));
                root.chooserDone = null;
            }
        }
    }

    readonly property string home: Env.get("HOME")
    function expand(p: string): string {
        return p === "~" ? home : p.startsWith("~/") ? home + p.slice(1) : p;
    }
    function tilde(p: string): string {
        return home !== "" && (p === home || p.startsWith(home + "/")) ? "~" + p.slice(home.length) : p;
    }

    // ---- search across pages ---------------------------------------------------------------
    // Sections of the result view: one per page with hits, rows in page order.
    // A row matches when every word of the query is found in its label, keywords,
    // section or page title; rows whose label starts with the query come first.
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const words = q.split(/\s+/);
        const out = [];
        for (const p of visiblePages) {
            const hits = [];
            for (const s of p.sections)
                for (const o of s.options) {
                    const hay = `${o.label} ${o.keywords ?? ""} ${s.title} ${p.title}`.toLowerCase();
                    if (!words.every(w => hay.includes(w)))
                        continue;
                    const label = o.label.toLowerCase();
                    hits.push({
                        "o": o,
                        "i": hits.length,
                        "rank": label.startsWith(q) ? 0 : label.includes(q) ? 1 : 2
                    });
                }
            if (hits.length > 0)
                out.push({
                    "title": p.title,
                    "page": p.id,
                    "best": Math.min(...hits.map(h => h.rank)),
                    "options": hits.sort((a, b) => a.rank - b.rank || a.i - b.i).map(h => h.o)
                });
        }
        out.forEach((s, i) => s.i = i);
        return out.sort((a, b) => a.best - b.best || a.i - b.i);
    }
}
