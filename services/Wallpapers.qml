pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Wallpaper files, thumbnails and the applied wallpaper.
//
//   scan()      images + videos in Settings.wallpaperDirs (default ~/Pictures/Wallpapers and
//               ~/.local/share/luxos), 4 levels deep, symlinks followed, hidden entries skipped.
//               Settings.wallpaperVideos off: images only (rescans when it changes).
//               Read only: nothing in those folders is ever written.
//   thumbnails  <cacheDir>/thumbs/<md5(path|mtime|size)>.jpg, 500x300 (5:3 like the picker cards).
//               ONE background job works through the missing ones, nearest to the applied
//               wallpaper first: nice 19, ionice idle, one thread; images via magick (JPEG decoded
//               at reduced size), videos as one ffmpeg frame. Existing thumbnails cost nothing.
//   apply(p)    writes Settings.wallpaper. background/WallpaperLayer paints it when enabled
//               (layerEnabled), the "wallpaper" theme re-derives its palette (ThemeSync).
//   shuffle     Settings.wallpaperShuffle: a random other wallpaper of the folders every
//               wallpaperShuffleMinutes (scans once if nothing was scanned yet); shuffleNow()
//
// cacheDir: LUXSHELL_CACHE_DIR, else $XDG_CACHE_HOME/luxshell (tests point it at a temp dir).
Singleton {
    id: root

    readonly property string home: Env.get("HOME")
    readonly property string cacheDir: {
        const own = Env.get("LUXSHELL_CACHE_DIR");
        if (own !== "")
            return own;
        const xdg = Env.get("XDG_CACHE_HOME");
        return (xdg !== "" ? xdg : home + "/.cache") + "/luxshell";
    }
    readonly property string thumbDir: cacheDir + "/thumbs"

    // own background layer: env for the transition period, setting for later
    readonly property bool layerEnabled: Env.get("LUXSHELL_WALLPAPER") === "1" || Settings.wallpaperLayer
    readonly property string current: Settings.wallpaper
    readonly property var dirs: Settings.wallpaperDirs.map(d => expand(d))

    readonly property var imageExt: ["jpg", "jpeg", "png", "webp", "bmp", "gif", "tif", "tiff"]
    readonly property var videoExt: ["mp4", "webm", "mkv", "mov", "m4v"]

    property var entries: []     // {path, name, video, thumb}, sorted by file name
    property bool scanned: false
    property var ready: ({})     // thumb path -> true once the file exists (no Image load errors)
    property var readyBuf: ({})

    function expand(p: string): string {
        return p === "~" ? home : p.startsWith("~/") ? home + p.slice(1) : p;
    }
    function ext(p: string): string {
        const i = p.lastIndexOf(".");
        return i < 0 ? "" : p.slice(i + 1).toLowerCase();
    }
    function isVideo(p: string): bool {
        return videoExt.includes(ext(p));
    }
    function baseName(p: string): string {
        return p.slice(p.lastIndexOf("/") + 1);
    }
    function url(p: string): string {
        return p === "" ? "" : "file://" + p.split("/").map(s => encodeURIComponent(s)).join("/");
    }
    function indexOf(p: string): int {
        return entries.findIndex(e => e.path === p);
    }

    function apply(p: string): void {
        if (p !== "" && p !== Settings.wallpaper)
            Settings.set("wallpaper", p);
    }

    // ---- shuffle --------------------------------------------------------------------------
    readonly property bool shuffling: Settings.wallpaperShuffle
    onShufflingChanged: if (shuffling && !scanned)
        scan()
    function shuffleNow(): void {
        if (!scanned) {
            shufflePending = true;
            scan();
            return;
        }
        const others = entries.filter(e => e.path !== current);
        if (others.length === 0)
            return;
        apply(others[Math.floor(Math.random() * others.length)].path);
    }
    property bool shufflePending: false
    onScannedChanged: if (scanned && shufflePending) {
        shufflePending = false;
        shuffleNow();
    }
    Timer {
        running: root.shuffling
        repeat: true
        interval: Math.max(1, Settings.wallpaperShuffleMinutes) * 60000
        onTriggered: root.shuffleNow()
    }
    Component.onCompleted: if (shuffling)
        scan()

    function scan(): void {
        if (dirs.length === 0) {
            entries = [];
            scanned = true;
            return;
        }
        if (finder.running) {
            rescan = true;
            return;
        }
        const names = Settings.wallpaperVideos ? [...imageExt, ...videoExt] : imageExt;
        const match = [];
        names.forEach((e, i) => match.push(...(i > 0 ? ["-o"] : []), "-iname", "*." + e));
        finder.command = ["find", "-L", ...dirs, "-mindepth", "1", "-maxdepth", "4", "(", "-name", ".*", "-prune", ")", "-o", "-type", "f", "(", ...match, ")", "-printf", "%T@\\t%s\\t%p\\n"];
        finder.running = true;
    }
    property bool rescan: false

    // the list follows the settings at once (the picker may be open)
    Connections {
        target: Settings
        function onWallpaperVideosChanged() {
            if (root.scanned)
                root.scan();
        }
        function onWallpaperDirsChanged() {
            if (root.scanned)
                root.scan();
        }
    }

    function parse(text: string): void {
        const seen = {};
        const out = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f.length < 3 || seen[f[2]])
                continue;
            const path = f.slice(2).join("\t");
            seen[path] = true;
            out.push({
                "path": path,
                "name": baseName(path),
                "video": isVideo(path),
                "thumb": thumbDir + "/" + Qt.md5(path + "|" + f[0] + "|" + f[1]) + ".jpg"
            });
        }
        out.sort((a, b) => a.name.localeCompare(b.name, undefined, {
                "numeric": true,
                "sensitivity": "base"
            }) || a.path.localeCompare(b.path));
        entries = out;
        scanned = true;
        thumbnails();
    }

    // queue every entry; the job skips existing thumbnails without spawning anything
    function thumbnails(): void {
        if (entries.length === 0)
            return;
        const at = Math.max(0, indexOf(current));
        const order = entries.map((e, i) => [Math.abs(i - at), e]).sort((a, b) => a[0] - b[0]).map(x => x[1]);
        const args = [];
        for (const e of order)
            args.push(e.video ? "v" : "i", e.path, e.thumb);
        queued = args;
        if (!thumbJob.running)
            startThumbs();
    }
    property var queued: null

    function startThumbs(): void {
        if (!queued)
            return;
        const g = Theme.wallpaperPicker;
        thumbJob.command = ["sh", "-c", thumbScript, "luxshell-thumbs", thumbDir, String(g.thumbW), String(g.thumbH), ...queued];
        queued = null;
        thumbJob.running = true;
    }

    readonly property string thumbScript: `
d=$1; W=$2; H=$3; shift 3
mkdir -p "$d" || exit 1
while [ $# -ge 3 ]; do
    kind=$1; src=$2; dst=$3; shift 3
    if [ -s "$dst" ]; then echo "have $dst"; continue; fi
    tmp="$dst.part.jpg"
    if [ "$kind" = v ]; then
        vf="scale=$W:$H:force_original_aspect_ratio=increase:flags=bicubic,crop=$W:$H"
        nice -n 19 ionice -c 3 ffmpeg -nostdin -v error -threads 1 -ss 1 -i "$src" -frames:v 1 -vf "$vf" -q:v 3 -update 1 -y "$tmp" </dev/null
        [ -s "$tmp" ] || nice -n 19 ionice -c 3 ffmpeg -nostdin -v error -threads 1 -i "$src" -frames:v 1 -vf "$vf" -q:v 3 -update 1 -y "$tmp" </dev/null
    else
        nice -n 19 ionice -c 3 magick -limit thread 1 -define jpeg:size=$((W * 2))x$((H * 2)) "$src[0]" -auto-orient -thumbnail "\${W}x\${H}^" -gravity center -extent "\${W}x\${H}" -quality 88 "$tmp"
    fi
    if [ -s "$tmp" ]; then mv -f "$tmp" "$dst" && echo "new $dst"; else rm -f "$tmp"; echo "fail $src"; fi
done`

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: if (root.rescan) {
            root.rescan = false;
            root.scan();
        }
    }

    Process {
        id: thumbJob
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("new ") || line.startsWith("have ")) {
                    root.readyBuf[line.slice(line.indexOf(" ") + 1)] = true;
                    publish.restart();
                } else if (line.startsWith("fail "))
                    console.info(`luxshell: no thumbnail for ${line.slice(5)}`);
            }
        }
        onExited: root.startThumbs()
    }

    // batch the job's lines into one model change
    Timer {
        id: publish
        interval: 30
        onTriggered: {
            root.ready = Object.assign({}, root.ready, root.readyBuf);
            root.readyBuf = {};
        }
    }
}
