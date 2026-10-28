pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persisted user settings: <Env.configDir>/settings.json. How to add a key, the
// prefixes per area and the option kinds of the settings app: apps/settings/README.md.
//
// Every key is a plain property in the KEYS block below and its initial value IS the
// default (one place, literals only, no bindings). Consumers bind to Settings.<key>;
// every change is live and saved. Only values that differ from the default are
// written, so a plain start never touches the disk and a changed default reaches
// everyone who never touched that key. The file is re-read live on external edits.
//
//   get(path)               key ("hoverHold") or a path into an object key ("islandLayout.hover.left")
//   set(path, value)        validated write (unknown key or wrong type: warning, false); paths
//                           clone the object, change the leaf and reassign it, so bindings fire
//   setPath(path, value)    same as set(), reads better for nested paths
//   reset(path), resetMany([paths]), resetAll()      back to the default
//   isDefault(path), defaultOf(path)                  live in bindings
//   keys()                  every key, in declaration order; isState(key): runtime state, no preference
//   snapshot(), restore(snap)                         undo for bulk changes (reset page, import)
//   exportData(), importData(obj)                     settings file backup (apps/settings/Backup)
//   edited(key)             signal after any key changed (set, reset, import, file edit)
//
// Value types: string, bool, int, real, list<string>, var (objects / arrays, JSON). No
// color/url properties: store colours as "#rrggbb" strings.
Singleton {
    id: root

    readonly property string path: Env.configDir + "/settings.json"
    // true once the file was read (or found missing): consumers that must see the saved
    // values first (Panels' size probes, theme) wait for it
    property bool ready: false

    signal edited(string key)

    // ==== KEYS (initial value = default) ===================================================
    // ---- shell-wide, from before the area prefixes (kept as they are, never renamed) ----
    property string theme: "noir"
    property string accent: "" // "" = theme accent, else #rrggbb
    property bool dnd: false // Focus / do not disturb (control center); notification popups read it
    property bool gameMode: false // services/GameMode is on (runtime state, see _state)
    property string gameModeSaved: "" // Hyprland values game mode replaced, JSON {option: value} (runtime state)
    property string wallpaper: "" // absolute path of the applied wallpaper (image or video)
    property list<string> wallpaperDirs: ["~/Pictures/Wallpapers", "~/.local/share/luxos"] // read only, searched 4 levels deep
    property bool wallpaperLayer: false // luxshell paints the wallpaper itself (also LUXSHELL_WALLPAPER=1); off = Ambxst does
    property bool themeExport: true // write the applied theme to ~/.cache/luxshell (kitty, gtk.css, palette.json)
    property string mediaGlow: "soft" // media panel glow from the cover: soft (muted colour) | color | mono | off
    property bool lockAvatar: false // lock screen: user picture (~/.face, AccountsService) instead of the person glyph (video)
    property string lockPam: "login" // lock screen PAM service in /etc/pam.d; "login" keeps pam_faillock (3 misses = 10 min lockout, like hyprlock). "" = <shell>/pam/luxshell-lock (no faillock, unlimited guesses)
    property int workspaceCount: 5 // island capsules (services/Hypr count), 2..6
    property int hoverHold: 160 // ms the pointer may leave the island before it collapses
    property string clockFormat: "24h" // "24h" | "12h" | "12h-ampm" (services/Clock)
    property string dateFormat: "ddd, MMM d" // Qt date format of the hover date (services/Clock)
    property string fontFamily: "Inter" // Theme.fontFamily, every text of the shell
    property int fontSize: 15 // px; Theme.fontScale = fontSize / 15 (settings app text)
    property real animationSpeed: 1 // divides every animation duration (config/Motion ms())
    property real uiScale: 0.85 // whole shell, applied at start by tools/run.sh (QT_SCALE_FACTOR); 0.85 = video size on a 27" QHD at luxend's 31.5" (93 PPI)
    property string terminal: "kitty" // launcher "> cmd" and Terminal=true apps (services/Apps)
    property string searchEngine: "duckduckgo" // launcher web search (services/SearchEngines)
    property bool webResults: true // web search row under every launcher query
    property real notifTimeout: 5 // s a normal notification peek stays (services/Notifs)
    property real notifTimeoutLow: 3.5 // s, low urgency and transient
    property real notifTimeoutCritical: 9 // s, critical

    // ---- island* : Bar & Island (layout, size, workspaces, click/scroll) ----

    // ---- look* : Appearance (colours, font, radius, transparency, shadow, border, scale) ----

    // ---- motion* : Motion (animations, hover delays) ----

    // ---- launcher* : Launcher (modes, prefixes) ----

    // ---- notif* : Notifications (focus schedule, app exceptions) ----

    // ---- cc* : Control Center (tiles, order) ----

    // ---- media* : Media panel ----

    // ---- lock* : Lock Screen ----

    // ---- wallpaper* : Wallpaper ----

    // ---- keys* : Keybinds (outside luxshell, opt-in, default off) ----

    // ---- integration* : apps theme, Hyprland look (outside luxshell, opt-in, default off) ----

    // ==== END OF KEYS ======================================================================

    // ---- API -------------------------------------------------------------------------------
    function keys(): var {
        _init();
        return Object.keys(_defaults);
    }

    // runtime state (gameMode ...), not a preference: no export, import, resetAll
    function isState(key: string): bool {
        return _state.includes(key);
    }

    function get(path: string): var {
        const parts = path.split(".");
        let v = root[parts[0]]; // read through the property: bindings depend on the key
        for (let i = 1; i < parts.length && v !== undefined && v !== null; i++)
            v = v[parts[i]];
        return v;
    }

    function defaultOf(path: string): var {
        _init();
        const parts = path.split(".");
        let v = _has(_defaults, parts[0]) ? _defaults[parts[0]] : undefined;
        for (let i = 1; i < parts.length && v !== undefined && v !== null; i++)
            v = v[parts[i]];
        return _clone(v);
    }

    function isDefault(path: string): bool {
        return _same(get(path), defaultOf(path));
    }

    function set(path: string, value: var): bool {
        _init();
        const parts = path.split(".");
        const key = parts[0];
        if (!_has(_defaults, key)) {
            console.warn(`luxshell: unknown setting "${key}"`);
            return false;
        }
        let next;
        if (parts.length === 1) {
            if (!_fits(key, value)) {
                console.warn(`luxshell: setting "${key}" expects ${_kind(_defaults[key])}, got ${_kind(value)}`);
                return false;
            }
            next = _clone(value);
        } else {
            const cur = root[key];
            const k = _kind(cur);
            if (k !== "object" && k !== "array" && k !== "null") {
                console.warn(`luxshell: setting "${key}" is a ${k}, "${path}" needs an object`);
                return false;
            }
            next = cur === null || cur === undefined ? {} : _clone(cur);
            let o = next;
            for (let i = 1; i < parts.length - 1; i++) {
                if (o[parts[i]] === null || typeof o[parts[i]] !== "object")
                    o[parts[i]] = {};
                o = o[parts[i]];
            }
            const leaf = parts[parts.length - 1];
            if (value === undefined)
                delete o[leaf];
            else
                o[leaf] = _clone(value);
        }
        if (!_same(root[key], next))
            root[key] = next; // the change handler saves
        return true;
    }

    function setPath(path: string, value: var): bool {
        return set(path, value);
    }

    function reset(path: string): void {
        _init();
        const key = path.split(".")[0];
        if (!_has(_defaults, key)) {
            console.warn(`luxshell: unknown setting "${key}"`);
            return;
        }
        set(path, defaultOf(path)); // a path missing in the default is removed (undefined)
    }

    function resetMany(paths: var): void {
        for (const p of paths)
            reset(p);
    }

    // every preference (runtime state like gameMode stays)
    function resetAll(): void {
        resetMany(keys().filter(k => !_state.includes(k)));
    }

    // all preferences (no runtime state), deep copies
    function snapshot(): var {
        _init();
        const out = {};
        for (const k in _defaults)
            if (!_state.includes(k))
                out[k] = _clone(root[k]);
        return out;
    }
    function restore(snap: var): void {
        importData(snap);
    }

    function exportData(): var {
        return {
            "luxshell": "settings",
            "version": 1,
            "exported": new Date().toISOString(),
            "settings": snapshot()
        };
    }

    // obj: exportData() output or a plain settings.json. Replaces every preference:
    // keys missing in obj go back to the default; unknown keys and wrong types are
    // skipped (listed in the result). Runtime state is never touched.
    function importData(obj: var): var {
        _init();
        const src = obj && typeof obj === "object" && obj.luxshell === "settings" && obj.settings ? obj.settings : obj;
        const res = {
            "ok": false,
            "applied": 0,
            "skipped": [],
            "unknown": []
        };
        if (src === null || typeof src !== "object" || Array.isArray(src))
            return res;
        const s = _migrate(Object.assign({}, src));
        for (const k in s)
            if (!_has(_defaults, k))
                res.unknown.push(k);
        for (const k in _defaults) {
            if (_state.includes(k))
                continue;
            if (!_has(s, k)) {
                reset(k);
            } else if (_fits(k, s[k])) {
                set(k, s[k]);
                res.applied++;
            } else {
                res.skipped.push(k);
            }
        }
        res.ok = true;
        return res;
    }

    // ---- internals -----------------------------------------------------------------------
    // properties of this object that are not keys (besides "_"-prefixed ones and functions)
    readonly property var _internal: ["objectName", "reloadableId", "children", "path", "ready"]
    // runtime state, not preferences: never exported, imported or reset by resetAll()
    readonly property var _state: ["gameMode", "gameModeSaved"]
    // renamed keys { "oldKey": "newKey" }: applied when the file is read or imported
    readonly property var _renamed: ({})

    property var _defaults: null
    property var _extra: ({})        // keys in the file this version does not know: kept on save
    property bool _applying: false   // reading the file: no save
    property bool _writing: false
    property bool _dirMade: false
    property string _lastText: ""    // what the file holds (read or written by us)

    Component.onCompleted: _init()

    function _has(o: var, k: string): bool {
        return o !== null && o !== undefined && Object.prototype.hasOwnProperty.call(o, k);
    }
    function _clone(v: var): var {
        return v === null || v === undefined || typeof v !== "object" ? v : JSON.parse(JSON.stringify(v));
    }
    function _same(a: var, b: var): bool {
        if (a === b)
            return true;
        if (a === undefined || b === undefined)
            return false;
        return JSON.stringify(a) === JSON.stringify(b);
    }
    function _kind(v: var): string {
        if (v === null || v === undefined)
            return "null";
        if (typeof v !== "object")
            return typeof v;
        return JSON.stringify(v).startsWith("[") ? "array" : "object"; // list<string> is no Array
    }
    function _fits(key: string, v: var): bool {
        const want = _kind(_defaults[key]);
        return want === "null" || want === _kind(v);
    }
    function _migrate(obj: var): var {
        for (const o in _renamed)
            if (_has(obj, o)) {
                if (!_has(obj, _renamed[o]))
                    obj[_renamed[o]] = obj[o];
                delete obj[o];
            }
        return obj;
    }

    // defaults = the declared values, captured before anything is applied
    function _init(): void {
        if (_defaults !== null)
            return;
        const d = {};
        for (const k in root) {
            if (k.startsWith("_") || _internal.includes(k))
                continue;
            const v = root[k];
            if (typeof v === "function")
                continue;
            d[k] = _clone(v);
        }
        _defaults = d;
        for (const k in d)
            root[k + "Changed"].connect(() => root._changed(k));
    }

    function _changed(key: string): void {
        if (!_applying)
            saveTimer.restart();
        edited(key);
    }

    function _overrides(): var {
        const out = Object.assign({}, _extra);
        for (const k in _defaults)
            if (!_same(root[k], _defaults[k]))
                out[k] = _clone(root[k]);
        return out;
    }

    function _write(): void {
        const text = JSON.stringify(_overrides(), null, 2) + "\n";
        if (text === _lastText)
            return;
        _lastText = text;
        if (!_dirMade) {
            mkdir.running = true; // writes once the directory exists
            return;
        }
        _writing = true;
        file.setText(text);
    }

    function _read(text: string): void {
        _init();
        if (text === _lastText) { // our own write coming back
            ready = true;
            return;
        }
        let obj = {};
        if (text.trim() !== "") {
            try {
                obj = JSON.parse(text);
            } catch (e) {
                console.warn(`luxshell: ${path} is no valid JSON (${e}); kept the current settings, the file is copied to settings.json.broken`);
                Quickshell.execDetached(["cp", "-f", path, path + ".broken"]);
                ready = true;
                return;
            }
        }
        if (obj === null || typeof obj !== "object" || Array.isArray(obj)) {
            console.warn(`luxshell: ${path} holds no JSON object; kept the current settings`);
            ready = true;
            return;
        }
        _lastText = text;
        obj = _migrate(obj);
        const extra = {};
        for (const k in obj)
            if (!_has(_defaults, k))
                extra[k] = obj[k];
        _applying = true;
        for (const k in _defaults) {
            let v = _defaults[k];
            if (_has(obj, k)) {
                if (_fits(k, obj[k]))
                    v = obj[k];
                else
                    console.warn(`luxshell: settings.json: "${k}" should be ${_kind(_defaults[k])}, using the default`);
            }
            if (!_same(root[k], v))
                root[k] = _clone(v);
        }
        _applying = false;
        _extra = extra;
        ready = true;
    }

    Timer {
        id: saveTimer
        interval: 60 // bursts (reset page, import, slider drags) become one write
        onTriggered: root._write()
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Env.configDir]
        onExited: {
            root._dirMade = true;
            root._writing = true;
            file.setText(root._lastText);
        }
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        // our own pending write wins over whatever the watcher reports meanwhile
        onFileChanged: if (!root._writing && !saveTimer.running)
            reload()
        onLoaded: {
            root._dirMade = true;
            root._read(text());
        }
        onLoadFailed: root.ready = true // missing file = defaults
        onSaved: {
            root._writing = false;
            root._dirMade = true;
            if (!loaded) // a file created by our first save is not watched yet; reloading arms the watch
                reload();
        }
        onSaveFailed: err => {
            root._writing = false;
            console.warn(`luxshell: could not save ${root.path}: ${err}`);
        }
    }
}
