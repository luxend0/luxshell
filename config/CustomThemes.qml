pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Custom themes: one JSON file per theme in <Env.configDir>/themes/<id>.json
// (~/.config/luxshell/themes, tests point LUXSHELL_CONFIG_DIR elsewhere). Themes.qml merges
// them into its palettes, so they show up in the theme picker, the settings app and IPC
// like the built-in ones. The theme editor (apps/settings/pages/ThemeEditor.qml) creates
// them by duplicating any theme, then edits, renames and deletes them.
//
// File format (every key optional except the colours you want to change; missing or
// invalid colours fall back to the theme named in "from", then to noir):
//   {
//     "luxshell": "theme",
//     "from": "nord",                       theme it was duplicated from (per-colour reset)
//     "island": "#000000", "base": "#2e3440", "surface": ..., "surfaceHigh": ..., "text": ...,
//     "textSecondary": ..., "textDim": ..., "muted": ..., "accent": ..., "onAccent": ...,
//     "wsOccupied": ..., "wsEmpty": ...,
//     "swatches": ["#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0"]
//   }
// The file name is the theme's id (lowercase letters, digits, "-"), shown in the picker.
// Edits made with another editor are picked up live (folder + file watches).
Singleton {
    id: root

    readonly property string dir: Env.configDir + "/themes"
    // id -> complete palette (Themes.qml keys) / id -> { "from": id }
    property var themes: ({})
    property var meta: ({})
    readonly property var ids: Object.keys(themes).sort()
    // first scan done: until then a saved custom theme is not known yet (ThemeSync waits)
    property bool ready: false

    readonly property var roles: ["island", "base", "surface", "surfaceHigh", "text", "textSecondary", "textDim", "muted", "accent", "onAccent", "wsOccupied", "wsEmpty"]
    readonly property var reserved: ["wallpaper", "custom", "new"]

    function isCustom(id: string): bool {
        return _has(themes, id);
    }
    function sourceOf(id: string): string {
        return meta[id]?.from ?? "";
    }
    function fileOf(id: string): string {
        return dir + "/" + id + ".json";
    }

    // "My Sunset 2" -> "my-sunset-2"
    function slug(name: string): string {
        return name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40);
    }
    // "" = fine as a new id for `self` (its current id may stay); else the reason
    function nameError(name: string, self: string): string {
        const id = slug(name);
        if (id === "")
            return "Use letters or digits";
        if (id === self)
            return "";
        if (Themes.fixed.hasOwnProperty(id) || reserved.includes(id))
            return `"${id}" is a built-in name`;
        if (isCustom(id))
            return `"${id}" exists`;
        return "";
    }
    function uniqueId(base: string): string {
        let b = slug(base) || "theme";
        if (nameError(b, "") === "")
            return b;
        for (let i = 2; i < 100; i++)
            if (nameError(`${b}-${i}`, "") === "")
                return `${b}-${i}`;
        return `${b}-${Date.now()}`;
    }

    // ---- editing (memory first, the file follows) -------------------------------------
    // copy of any theme (built-in, wallpaper or custom); returns the new id
    function duplicate(from: string): string {
        const src = Themes.palettes[from] ?? Themes.fixed.noir;
        const id = uniqueId(`${from}-copy`);
        const p = _complete(src, Themes.fixed.noir);
        _put(id, p, {
            "from": from
        });
        _save(id);
        return id;
    }

    // path: a role ("accent") or "swatches.N"
    function colour(id: string, path: string): string {
        const p = themes[id];
        if (!p)
            return "";
        if (path.startsWith("swatches."))
            return p.swatches[parseInt(path.slice(9))] ?? "";
        return p[path] ?? "";
    }
    function setColour(id: string, path: string, value: string): bool {
        if (!isCustom(id) || !/^#[0-9a-fA-F]{6}$/.test(value))
            return false;
        const p = JSON.parse(JSON.stringify(themes[id]));
        const v = value.toLowerCase();
        if (path.startsWith("swatches.")) {
            const i = parseInt(path.slice(9));
            if (!(i >= 0 && i < 6) || p.swatches[i] === v)
                return true;
            p.swatches[i] = v;
        } else {
            if (!roles.includes(path) || p[path] === v)
                return true;
            p[path] = v;
        }
        _put(id, p, meta[id]);
        _save(id);
        return true;
    }
    // the colour the theme it came from has there ("" when that theme is gone)
    function sourceColour(id: string, path: string): string {
        const from = sourceOf(id);
        if (from === "" || from === id || !Themes.palettes.hasOwnProperty(from))
            return "";
        const p = Themes.palettes[from];
        return path.startsWith("swatches.") ? (p.swatches[parseInt(path.slice(9))] ?? "") : (p[path] ?? "");
    }

    // returns the new id ("" when the name is not usable); the applied theme follows
    function rename(id: string, name: string): string {
        if (!isCustom(id) || nameError(name, id) !== "")
            return "";
        const to = slug(name);
        if (to === id)
            return id;
        const t = Object.assign({}, themes);
        const m = Object.assign({}, meta);
        t[to] = t[id];
        m[to] = m[id];
        delete t[id];
        delete m[id];
        themes = t;
        meta = m;
        _save(to);
        _job(["rm", "-f", fileOf(id)]);
        if (Settings.theme === id)
            Settings.set("theme", to);
        return to;
    }

    function remove(id: string): void {
        if (!isCustom(id))
            return;
        const from = sourceOf(id);
        const t = Object.assign({}, themes);
        const m = Object.assign({}, meta);
        delete t[id];
        delete m[id];
        themes = t;
        meta = m;
        _job(["rm", "-f", fileOf(id)]);
        if (Settings.theme === id)
            Settings.set("theme", from !== "" && Themes.palettes.hasOwnProperty(from) ? from : "noir");
    }

    // ---- internals --------------------------------------------------------------------
    function _has(o: var, k: string): bool {
        return o !== null && o !== undefined && Object.prototype.hasOwnProperty.call(o, k);
    }
    function _hex(v: var): bool {
        return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v);
    }
    // every role + six swatches, from `obj` where valid, else from `base`
    function _complete(obj: var, base: var): var {
        const p = {};
        for (const r of roles)
            p[r] = (_hex(obj?.[r]) ? obj[r] : (base[r] ?? "#000000")).toLowerCase();
        const sw = Array.isArray(obj?.swatches) ? obj.swatches : [];
        p.swatches = [0, 1, 2, 3, 4, 5].map(i => (_hex(sw[i]) ? sw[i] : base.swatches[i]).toLowerCase());
        return p;
    }
    function _put(id: string, p: var, m: var): void {
        const t = Object.assign({}, themes);
        const mm = Object.assign({}, meta);
        t[id] = p;
        mm[id] = m ?? {};
        themes = t;
        meta = mm;
    }
    function _text(id: string): string {
        const out = {
            "luxshell": "theme"
        };
        if (sourceOf(id) !== "")
            out.from = sourceOf(id);
        Object.assign(out, themes[id]);
        return JSON.stringify(out, null, 2) + "\n";
    }

    // what we wrote last per file: our own write coming back through the watch is no edit
    property var _written: ({})
    property var _dirty: ({})

    function _save(id: string): void {
        const d = Object.assign({}, _dirty);
        d[id] = true;
        _dirty = d;
        saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 250 // colour drags become one write
        onTriggered: {
            for (const id in root._dirty)
                if (root.isCustom(id)) {
                    const text = root._text(id);
                    const w = Object.assign({}, root._written);
                    w[id] = text;
                    root._written = w;
                    root._job(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" >"$2.part" && mv -f "$2.part" "$2"', "luxshell-theme", root.dir, root.fileOf(id), text]);
                }
            root._dirty = {};
        }
    }

    // one file job at a time, in order
    property var _queue: []
    function _job(argv: var): void {
        _queue = [..._queue, argv];
        if (!worker.running)
            _next();
    }
    function _next(): void {
        if (_queue.length === 0)
            return;
        worker.command = _queue[0];
        _queue = _queue.slice(1);
        worker.running = true;
    }
    Process {
        id: worker
        onExited: (code, status) => {
            if (code !== 0)
                console.warn(`luxshell: theme file job failed (${code}): ${worker.command.slice(0, 2).join(" ")}`);
            // a folder created by our first write is not watched yet: point the model at it again
            if (folder.count === 0 && root._queue.length === 0)
                root._rescan();
            root._next();
        }
    }

    // a file read from disk (first scan or an outside edit)
    function _loaded(id: string, text: string): void {
        if ((isCustom(id) && _written[id] === text) || _dirty[id])
            return;
        let obj;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            console.warn(`luxshell: ${fileOf(id)} is no valid JSON (${e}); theme skipped`);
            return;
        }
        if (obj === null || typeof obj !== "object" || Array.isArray(obj))
            return;
        if (slug(id) !== id || Themes.fixed.hasOwnProperty(id) || reserved.includes(id)) {
            console.warn(`luxshell: theme file "${id}.json" needs a name of lowercase letters, digits and "-" that is no built-in theme; skipped`);
            return;
        }
        const from = typeof obj.from === "string" ? obj.from : "";
        const base = Themes.fixed[from] ?? (from !== "" && from !== id ? themes[from] : undefined) ?? Themes.fixed.noir;
        const w = Object.assign({}, _written);
        w[id] = text;
        _written = w;
        _put(id, _complete(obj, base), {
            "from": from
        });
    }
    // a file left the folder model: deleted outside luxshell, or only a rescan (checked
    // a moment later; our own rename/remove already dropped the theme)
    property var _maybeGone: []
    function _gone(id: string): void {
        if (!isCustom(id) || _dirty[id])
            return;
        _maybeGone = [..._maybeGone, id];
        goneTimer.restart();
    }
    Timer {
        id: goneTimer
        interval: 400
        onTriggered: {
            const present = [];
            for (let i = 0; i < folder.count; i++)
                present.push(folder.get(i, "fileBaseName"));
            const t = Object.assign({}, root.themes);
            let changed = false;
            for (const id of root._maybeGone)
                if (!present.includes(id) && !root._dirty[id] && t[id]) {
                    delete t[id];
                    changed = true;
                }
            root._maybeGone = [];
            if (changed)
                root.themes = t;
        }
    }

    // FolderListModel lists the working directory (~) when its folder does not exist, which
    // read every ~/*.json as a theme: the folder is created first, nothing matches until then
    property bool dirMade: false
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: {
            root.dirMade = true;
            root._rescan();
        }
    }
    // point the model at the folder again (a folder created after the first scan is not
    // watched); "/." names the same folder with another url, an empty one would mean ~
    function _rescan(): void {
        folder.folder = "file://" + root.dir + "/.";
        folder.folder = Qt.binding(() => "file://" + root.dir);
    }
    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: root.dirMade ? ["*.json"] : ["luxshell-no-theme-before-mkdir"]
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        onStatusChanged: root._checkReady()
        onCountChanged: root._checkReady()
    }

    property int loadedCount: 0
    function _checkReady(): void {
        if (!ready && dirMade && folder.status === FolderListModel.Ready && loadedCount >= folder.count)
            ready = true;
    }
    Timer {
        // missing folder or a file that never loads: never wait longer than this
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }

    Instantiator {
        model: folder
        delegate: FileView {
            required property string fileBaseName
            required property string filePath
            property bool counted: false
            path: filePath
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                root._loaded(fileBaseName, text());
                if (!counted) {
                    counted = true;
                    root.loadedCount++;
                    root._checkReady();
                }
            }
            onLoadFailed: if (!counted) {
                counted = true;
                root.loadedCount++;
                root._checkReady();
            }
            Component.onDestruction: {
                if (counted)
                    root.loadedCount--;
                root._gone(fileBaseName);
            }
        }
    }
}
