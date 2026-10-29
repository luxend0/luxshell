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
    property int fontSize: 15 // px; Theme.fontScale = fontSize / 15 * lookFontScale (settings app text)
    property real animationSpeed: 1 // divides every animation duration (config/Motion ms())
    property real uiScale: 0.85 // whole shell, applied at start by tools/run.sh (QT_SCALE_FACTOR); 0.85 = video size on a 27" QHD at luxend's 31.5" (93 PPI)
    property string terminal: "kitty" // launcher "> cmd" and Terminal=true apps (services/Apps)
    property string searchEngine: "duckduckgo" // launcher web search (services/SearchEngines)
    property bool webResults: true // web search row under every launcher query
    property real notifTimeout: 5 // s a normal notification peek stays (services/Notifs)
    property real notifTimeoutLow: 3.5 // s, low urgency and transient
    property real notifTimeoutCritical: 9 // s, critical

    // ---- island* : Bar & Island (layout, size, workspaces, click/scroll) ----
    // widgets per state and slot, in order (island/bar/BarRegistry.qml lists the widget ids;
    // "spacer" may repeat). The default is the video's island; the settings app edits it by
    // drag and drop (apps/settings/island/IslandEditor.qml)
    property var islandLayout: ({
            "collapsed": {
                "left": ["workspaces"],
                "center": ["clock"],
                "right": ["network", "volume"]
            },
            "hover": {
                "top": {
                    "left": ["media", "window"],
                    "center": ["clock", "date"],
                    "right": ["settings", "power", "notifications"]
                },
                "bottom": {
                    "left": ["workspaces"],
                    "center": [],
                    "right": ["tray", "network", "volume"]
                }
            }
        })
    property real islandScale: 1 // size of the island only (collapsed + hover), panels keep theirs
    property int islandMargin: 0 // px from the top edge; 0 = flush with the edge (video), > 0 = floating pill
    property int islandHoverDelay: 0 // ms the pointer rests on the island before it expands
    property bool islandHoverExpand: true // false: the island expands on click instead of hover
    property string islandClickAction: "controlcenter" // controlcenter | notifications | launcher | none
    property string islandScrollAction: "volume" // volume | workspaces | none
    property string islandMiddleClick: "none" // none | controlcenter | notifications | launcher | overview | playpause | mute
    // per-widget options (the island editor shows them next to the preview)
    property bool islandClockSeconds: false // clock widget shows seconds (clock format: clockFormat)
    property string islandWorkspaceStyle: "capsules" // capsules (video) | dots | numbers
    property string islandNetworkStyle: "bars" // bars (video) | icon
    property bool islandVolumePercent: false // volume widget: percentage after the glyph
    property bool islandWindowTitle: true // window widget: app icon + title (false = icon only)
    property int islandWindowMaxWidth: 300 // px, longest window title in the hover island
    property bool islandWindowYield: true // window widget hides while the media chip shows in the same slot (video)
    property bool islandNotifLabel: true // notifications widget: "All caught up" text next to the bell
    property bool islandBatteryPercent: true // battery widget: percentage next to the glyph
    property string islandWeatherLocation: "" // wttr.in location, "" = by IP
    property string islandWeatherUnit: "c" // c | f
    property int islandSysmonInterval: 3 // s between cpu/ram samples (2..10)
    property string islandKeyboardStyle: "code" // code ("DE") | name ("German")
    property int islandSpacerWidth: 24 // px of the spacer widget
    // bar info + tool widgets (palette only, island/widgets: Gpu, Temp, NetSpeed, Updates, Tool, Privacy)
    property string islandGpuShow: "load" // gpu widget: load | vram | both
    property string islandGpuVram: "gb" // gpu widget VRAM: gb (used, GiB) | pct
    property string islandTempShow: "both" // temps widget: cpu | gpu | both
    property string islandTempCpuSensor: "tctl" // tctl (Tctl / Tdie / Package) | ccd (hottest CCD)
    property string islandTempGpuSensor: "edge" // amdgpu hwmon: edge | junction | mem
    property string islandNetSpeedShow: "both" // netspeed widget: both | down | up
    property bool islandNetSpeedBits: false // netspeed in bits per second (Mb/s) instead of bytes
    property string islandNetSpeedIface: "" // netspeed interface, "" = default route
    property bool islandUpdatesHideZero: true // updates widget only while updates are pending
    property bool islandUpdatesAur: true // updates widget counts AUR updates (paru -Qua)
    property int islandUpdatesInterval: 60 // min between update checks (15..240)
    property string islandPickerFormat: "hex" // colour picker: hex | rgb | hsl (hyprpicker -f)
    property string islandPrivacyStyle: "icons" // privacy widget: icons (dot + what is in use) | dot
    // bar menus + switches (palette only, island/widgets/BarToggle and friends, panels/SheetMenu)
    property bool islandNetworkMenu: true // network widget: click opens the network menu (off: the click falls through to the island)
    property bool islandVolumeMenu: true // volume widget: click opens the sound menu (off: the click falls through to the island)
    property bool islandBluetoothBattery: true // bluetooth widget: battery of the connected device next to the glyph
    property bool islandBluetoothName: false // bluetooth widget: name of the connected device
    property bool islandDisplayPercent: false // display widget: brightness percentage
    property int islandDisplayStep: 5 // % per scroll notch on the display widget (1..20)
    property bool islandMicRecording: true // microphone widget turns red while an app records
    property bool islandMicPercent: false // microphone widget: input volume percentage
    property bool islandNightLightTemp: false // night light widget: temperature next to the glyph
    property int islandNightLightStep: 100 // K per scroll notch on the night light widget (50..500)
    property bool islandPowerProfileLabel: false // power mode widget: profile name next to the glyph
    property bool islandCaffeineTime: true // caffeine widget: time left next to the glyph
    property int islandCaffeineClick: 0 // minutes a click on the caffeine widget keeps the session awake, 0 = until turned off

    // ---- look* : Appearance (colours, font, radius, transparency, shadow, border, scale) ----
    property real lookRadiusScale: 1 // corner radius factor: island + panels (island/IslandShape) and cards (Theme.rad)
    property bool lookEars: true // concave fillets where the island meets the screen edge (video)
    property bool lookBorder: false // outline around the island and panels
    property real lookBorderWidth: 1.5 // px
    property string lookBorderColor: "" // "" = theme (text over the island, 20 %), else #rrggbb
    property bool lookShadow: false // drop shadow under the island and panels
    property real lookShadowStrength: 0.5 // 0..1: blur, opacity and offset of the shadow
    property real lookIslandOpacity: 1 // island fill, collapsed + hover (1 = solid like the video)
    property real lookPanelOpacity: 1 // island fill while a panel or overlay is shown
    property real lookFontScale: 1 // text size factor of the whole shell (Theme.tx: island, panels, OSD, lock; settings app via Theme.fontScale)
    property string lookMonoFont: "" // monospace text (launcher command + calculator line, hex fields); "" = the interface font

    // ---- motion* : Motion (animations, hover delays) ----
    property string motionStyle: "video" // island morph + panel timing (config/Motion): video (fitted to the video) | spring (slight overshoot) | fast | reduced (cross-fades only)

    // ---- launcher* : Launcher (modes, prefixes) ----
    // panels/Launcher + services/Apps; terminal, searchEngine, webResults above keep their names
    property var launcherProviders: ["calc", "apps", "windows", "commands", "web"] // enabled modes, in result order: calc apps windows commands web
    property var launcherPrefixes: ({ "calc": "=", "windows": "w ", "commands": ">", "web": "?" }) // text that switches the field to one mode
    property int launcherRows: 6 // result rows before the list scrolls (Theme.launcher.visibleRows)
    property bool launcherRankUsage: true // used apps rank higher (services/AppUsage); off = match quality, then A-Z
    property var launcherHiddenApps: [] // desktop entry ids the launcher never lists

    // ---- notif* : Notifications (focus schedule, app exceptions) ----
    property bool notifCenterGroup: true // notification center: one group per app (folded stacks); off = newest first, one header per run of the same app
    property int notifCenterMaxHeight: 760 // px the notification center may grow to, then it scrolls (Theme.nc.maxHeight)
    property bool notifPeek: true // new notifications peek in the island (off: only the history and the bell)
    property bool notifSound: false // play notifSoundFile on a new notification (pw-play; not during Focus, not for muted apps)
    property string notifSoundFile: "" // "" = /usr/share/sounds/freedesktop/stereo/message.oga
    property bool notifFocusSchedule: false // services/Focus switches dnd on/off at the edges of the schedule
    property var notifFocusDays: [1, 2, 3, 4, 5] // ISO weekdays (1 = Monday) on which the schedule STARTS
    property var notifFocusTime: ({
            "from": "22:00",
            "to": "07:00"
        }) // span; "to" earlier than "from" ends on the next day, equal = the whole day
    property var notifRules: [] // per app: [{ "app": "Discord", "id": "vesktop", "mode": "mute" | "nopeek" | "always" | "nostore" }]
    property int notifHistoryLimit: 0 // notifications kept in the history, oldest dismissed first; 0 = unlimited
    property string notifFocusEdge: "" // runtime state (services/Focus): schedule state last applied, "on" | "off" | ""

    // ---- cc* : Control Center (tiles, order) ----
    // panels/controlcenter/CcLayout packs them: up to two tiles per row (round buttons join a
    // row while the tiles stay >= Theme.ccLayout.minTile wide), then one slider per row
    property var ccTiles: ["network", "focus", "lock", "bluetooth", "gamemode"] // tiles + round buttons in reading order (CcLayout.catalog)
    property var ccSliders: ["sound", "display"] // slider cards below the tiles: sound display mic
    property int ccNightTemp: 4000 // K, night light tile (wlsunset)
    property string ccScreenshotMode: "region" // screenshot button: region (slurp) | screen
    property string ccScreenshotDir: "~/Pictures/Screenshots" // screenshot button saves here (and copies to the clipboard)
    property string ccThemeA: "noir" // theme button switches between A and B (B = on)
    property string ccThemeB: "wallpaper"

    // ---- media* : Media panel ----
    property bool mediaChip: true // media chip in the hover island while a player has a track (Media.hasTrack)
    property string mediaPreferred: "" // player key (Media.playerKey) shown first, "" = the one that played last
    property var mediaHidden: [] // player keys luxshell ignores (no chip, no panel, no player pill)

    // ---- lock* : Lock Screen ----
    property string lockClockFormat: "" // "" = like the island (clockFormat), else "24h" | "12h" | "12h-ampm"
    property bool lockDate: true // date line above the clock
    property real lockBlur: 1 // backdrop blur, 0..1 of Theme.lock.blurMax
    property real lockDim: 0.55 // darkening over the blurred backdrop, 0..0.9 (Theme.lock.dim)
    property string lockHint: "Press Any Key to Enter Password" // line under the user name; "" = none

    // ---- wallpaper* : Wallpaper ----
    property bool wallpaperVideos: true // wallpaper picker lists videos (mp4, webm, ...) next to images
    property bool wallpaperPauseCovered: true // video wallpapers pause while a window covers the workspace (background/WallpaperLayer)
    property int wallpaperFade: 700 // ms cross-fade to a new wallpaper
    property bool wallpaperShuffle: false // pick a random wallpaper from the folders every wallpaperShuffleMinutes
    property int wallpaperShuffleMinutes: 30

    // ---- keys* : Keybinds (outside luxshell, opt-in, default off) ----
    property bool keysEnabled: false // write + load the Hyprland binds below (services/Keybinds -> luxshell-keys.lua)
    property var keysBinds: ({
            "launcher": "SUPER + Super_L",
            "controlcenter": "SUPER + SHIFT + D",
            "notifications": "SUPER + SHIFT + N",
            "overview": "SUPER + TAB",
            "wallpaper": "SUPER + COMMA",
            "themes": "SUPER + SHIFT + Y",
            "settings": "",
            "media": "",
            "lock": "SUPER + L",
            "power": "SUPER + ESCAPE",
            "focus": "",
            "playPause": "",
            "next": "",
            "previous": ""
        }) // action -> Hyprland keys ("SUPER + SHIFT + D"; a lone modifier key = tap, bound on release); "" = unbound

    // ---- overview* : Workspace overview (panels/Overview) ----
    property string overviewPreview: "live" // live (selected / hovered card streams) | still (frames from opening) | icons (no capture)
    property bool overviewGroup: true // cards grouped per workspace under a heading; off = one grid
    property real overviewCardSize: 1 // card scale, 0.7 .. 1.4 (Theme.overview card sizes)

    // ---- picker* : Theme and wallpaper picker ----
    property bool pickerThemePreview: true // theme picker shows the highlighted theme live on the island

    // ---- integration* : apps theme, Hyprland look (outside luxshell, opt-in, default off) ----
    property bool integrationKitty: false // marked include line for <cache>/kitty-theme.conf in kitty.conf (services/AppThemes)
    property bool integrationGtk: false // marked @import line for <cache>/gtk.css in gtk-3.0 + gtk-4.0 gtk.css
    property bool integrationHypr: false // Hyprland look via hyprctl eval (services/HyprLook); previous values restored when off
    property bool integrationHyprBorder: true // window border: active = accent, inactive = theme
    property int integrationHyprBorderSize: 2 // px
    property bool integrationHyprGaps: true
    property int integrationHyprGapsIn: 5 // px between windows
    property int integrationHyprGapsOut: 10 // px to the screen edge
    property bool integrationHyprRounding: true
    property int integrationHyprRadius: 12 // px window rounding at corner radius factor 1 (follows lookRadiusScale)
    property bool integrationBlur: false // Hyprland layer rule: blur behind the island while it is translucent
    property string integrationHyprSaved: "" // Hyprland values the integration replaced, JSON {option: value} (runtime state)

    // ---- power* : Power menu (panels/PowerMenu, services/Power) ----
    property var powerActions: ["lock", "logout", "suspend", "reboot", "poweroff", "firmware"] // shown actions in menu order (firmware only where logind supports it)
    property var powerConfirm: ({
            "lock": false,
            "logout": true,
            "suspend": false,
            "reboot": true,
            "poweroff": true,
            "firmware": true
        }) // per action: true = second click / Enter within powerConfirmTime runs it, the row turns red meanwhile
    property real powerConfirmTime: 3 // s the armed (red) row waits for the second click, then falls back
    property var powerCommands: ({
            "lock": "",
            "logout": "",
            "suspend": "",
            "reboot": "",
            "poweroff": "",
            "firmware": ""
        }) // per action: own shell command (sh -c); "" = default (luxshell lock, hl.dsp.exit(), systemctl ...)
    property bool powerDetails: true // info line under each action: lock keybind, open windows, kernel / updates since boot, uptime

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
    readonly property var _state: ["gameMode", "gameModeSaved", "integrationHyprSaved", "notifFocusEdge"]
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
