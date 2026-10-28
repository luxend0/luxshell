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
    readonly property bool lockAvatar: adapter.lockAvatar
    readonly property string lockPam: adapter.lockPam

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
            property bool lockAvatar: false // lock screen: user picture (~/.face, AccountsService) instead of the person glyph (video)
            property string lockPam: "" // lock screen PAM service in /etc/pam.d ("login" = system stack); "" = <shell>/pam/luxshell-lock
        }
    }
}
