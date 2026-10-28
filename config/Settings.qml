pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persisted user settings: <Env.configDir>/settings.json.
// Reads on start and live on external edits. Writes only through set(), so a
// plain start never touches the disk (a missing file just means defaults).
Singleton {
    id: root

    readonly property string path: Env.configDir + "/settings.json"
    // true once the file was read (or found missing): consumers that must see the saved
    // values first (Panels' size probes, theme) wait for it
    property bool ready: false

    // read-only mirrors; change via set()
    readonly property string theme: adapter.theme
    readonly property string accent: adapter.accent
    readonly property bool dnd: adapter.dnd
    readonly property bool gameMode: adapter.gameMode
    readonly property string gameModeSaved: adapter.gameModeSaved
    readonly property string wallpaper: adapter.wallpaper
    readonly property list<string> wallpaperDirs: adapter.wallpaperDirs
    readonly property bool wallpaperLayer: adapter.wallpaperLayer
    readonly property bool themeExport: adapter.themeExport
    readonly property string mediaGlow: adapter.mediaGlow
    readonly property bool lockAvatar: adapter.lockAvatar
    readonly property string lockPam: adapter.lockPam
    // settings app (apps/settings)
    readonly property int workspaceCount: adapter.workspaceCount
    readonly property int hoverHold: adapter.hoverHold
    readonly property string clockFormat: adapter.clockFormat
    readonly property string dateFormat: adapter.dateFormat
    readonly property string fontFamily: adapter.fontFamily
    readonly property int fontSize: adapter.fontSize
    readonly property real animationSpeed: adapter.animationSpeed
    readonly property real uiScale: adapter.uiScale
    readonly property string terminal: adapter.terminal
    readonly property string searchEngine: adapter.searchEngine
    readonly property bool webResults: adapter.webResults
    readonly property real notifTimeout: adapter.notifTimeout
    readonly property real notifTimeoutLow: adapter.notifTimeoutLow
    readonly property real notifTimeoutCritical: adapter.notifTimeoutCritical

    function set(key: string, value: var): bool {
        if (adapter[key] === undefined) {
            console.warn(`luxshell: unknown setting "${key}"`);
            return false;
        }
        adapter[key] = value;
        mkdir.running = true; // writeAdapter() runs once the directory exists
        return true;
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Env.configDir]
        onExited: file.writeAdapter()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.ready = true
        onLoadFailed: root.ready = true
        // a file created by our first save is not watched yet; reloading arms the watch
        onSaved: if (!loaded)
            reload()
        onSaveFailed: err => console.warn(`luxshell: could not save ${root.path}: ${err}`)

        JsonAdapter {
            id: adapter
            property string theme: "noir"
            property string accent: "" // "" = theme accent, else #rrggbb
            property bool dnd: false // Focus / do not disturb (control center); notification popups read it
            property bool gameMode: false // services/GameMode is on
            property string gameModeSaved: "" // Hyprland values game mode replaced, JSON {option: value}
            property string wallpaper: "" // absolute path of the applied wallpaper (image or video)
            property list<string> wallpaperDirs: ["~/Pictures/Wallpapers", "~/.local/share/luxos"] // read only, searched 4 levels deep
            property bool wallpaperLayer: false // luxshell paints the wallpaper itself (also LUXSHELL_WALLPAPER=1); off = Ambxst does
            property bool themeExport: true // write the applied theme to ~/.cache/luxshell (kitty, gtk.css, palette.json)
            property string mediaGlow: "soft" // media panel glow from the cover: soft (muted colour) | color | mono | off
            property bool lockAvatar: false // lock screen: user picture (~/.face, AccountsService) instead of the person glyph (video)
            property string lockPam: "login" // lock screen PAM service in /etc/pam.d; "login" keeps pam_faillock (3 misses = 10 min lockout, like hyprlock). "" = <shell>/pam/luxshell-lock (no faillock, unlimited guesses)
            // settings app (apps/settings/Catalog.qml lists every option with its consumer)
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
        }
    }
}
