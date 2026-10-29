pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Default applications per kind of link / file (Settings > System > Default Apps), the XDG way.
//
//   read   `xdg-mime query default <type>` for every type of every category (one sh, nice), and
//          the MimeType= lines of every .desktop file under $XDG_DATA_HOME + $XDG_DATA_DIRS (which
//          app can open what; the first file of an id wins, like the XDG lookup). Names and icons
//          come from services/Apps (the launcher's list) and DesktopEntries.
//   write  `xdg-mime default <app>.desktop <types...>` through Exec.callUser, i.e. into
//          $XDG_CONFIG_HOME/mimeapps.list: the category's types the app lists (browser and file
//          manager: all of them, like xdg-settings), the first type when it lists none.
//   refresh() while the page shows; set(categoryId, desktopId).
// The terminal is no MIME type: luxshell's own Settings.terminal (Launcher page) is the one.
Singleton {
    id: root

    // types: what is set; need: an app is offered when it lists one of these; all: set every
    // type whether the app lists it or not
    readonly property var categories: [
        {
            "id": "browser",
            "label": "Web browser",
            "words": "browser web internet http https html links",
            "types": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml", "x-scheme-handler/about", "x-scheme-handler/unknown"],
            "need": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"],
            "all": true
        },
        {
            "id": "files",
            "label": "File manager",
            "words": "files folder directory file manager explorer thunar nautilus dolphin",
            "types": ["inode/directory"],
            "need": ["inode/directory"],
            "all": true
        },
        {
            "id": "editor",
            "label": "Text editor",
            "words": "text editor notepad plain txt code markdown",
            "types": ["text/plain", "text/markdown", "text/x-log", "application/x-shellscript", "text/x-python", "text/x-csrc", "text/x-chdr", "text/x-c++src", "application/json", "application/x-yaml", "application/toml", "text/css"],
            "need": ["text/plain"]
        },
        {
            "id": "images",
            "label": "Images",
            "words": "image picture photo viewer png jpeg gif webp svg",
            "types": ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff", "image/svg+xml", "image/avif", "image/heif"],
            "need": ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff", "image/svg+xml", "image/avif", "image/heif"]
        },
        {
            "id": "video",
            "label": "Video",
            "words": "video movie player mp4 mkv webm film",
            "types": ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg", "video/x-flv", "video/3gpp"],
            "need": ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg", "video/x-flv", "video/3gpp"]
        },
        {
            "id": "music",
            "label": "Music",
            "words": "music audio player song mp3 flac ogg",
            "types": ["audio/mpeg", "audio/flac", "audio/x-flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/opus", "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/x-m4a"],
            "need": ["audio/mpeg", "audio/flac", "audio/x-flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/opus", "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/x-m4a"]
        },
        {
            "id": "pdf",
            "label": "PDF documents",
            "words": "pdf document reader viewer",
            "types": ["application/pdf"],
            "need": ["application/pdf"]
        },
        {
            "id": "mail",
            "label": "Mail",
            "words": "mail email e-mail mailto client thunderbird",
            "types": ["x-scheme-handler/mailto", "message/rfc822"],
            "need": ["x-scheme-handler/mailto"]
        }
    ]
    readonly property var allTypes: categories.reduce((a, c) => a.concat(c.types), [])

    property var current: ({})   // type -> "app.desktop" ("" = none set)
    property var handlers: ({})  // "app.desktop" -> { "type": true }
    property bool typesRead: false
    property bool handlersRead: false
    readonly property bool ready: typesRead && handlersRead
    property string busy: ""     // category id being set
    property string error: ""    // last failed change, shown on the page until dismissed
    signal notice(string text)   // a change went through (the page shows it as a toast)

    function category(id: string): var {
        return categories.find(c => c.id === id) ?? null;
    }
    function norm(id: string): string {
        const s = String(id ?? "");
        return s === "" || s.endsWith(".desktop") ? s : s + ".desktop";
    }
    function entryOf(id: string): var {
        if (id === "")
            return null;
        const bare = id.replace(/\.desktop$/, "");
        return DesktopEntries.byId(bare) ?? DesktopEntries.byId(id) ?? null;
    }
    function nameOf(id: string): string {
        if (id === "")
            return "None";
        const e = entryOf(id);
        return e && e.name !== "" ? e.name : id.replace(/\.desktop$/, "");
    }

    // the category's default: the app of its first type
    function value(catId: string): string {
        const c = category(catId);
        return c ? (current[c.types[0]] ?? "") : "";
    }
    // types of the category the app would get, and how many point to it now
    function typesFor(c: var, id: string): var {
        if (c.all)
            return c.types;
        const h = handlers[norm(id)] ?? {};
        const own = c.types.filter(t => h[t]);
        return own.length > 0 ? own : [c.types[0]];
    }
    function coverage(catId: string, id: string): var {
        const c = category(catId);
        if (!c || id === "")
            return {
                "of": 0,
                "set": 0
            };
        const ts = typesFor(c, id);
        return {
            "of": ts.length,
            "set": ts.filter(t => current[t] === id).length
        };
    }

    // [{ value, label, detail }] of the dropdown: launcher apps that list one of `need`, A-Z,
    // plus the current default when it is none of them (NoDisplay helpers like kitty-open)
    function candidates(catId: string): var {
        const c = category(catId);
        if (!c)
            return [];
        const out = [];
        for (const e of Apps.all) {
            const id = norm(e.id);
            const h = handlers[id];
            if (h && c.need.some(t => h[t]))
                out.push({
                    "value": id,
                    "label": e.name
                });
        }
        const cur = value(catId);
        if (cur !== "" && !out.some(o => o.value === cur))
            out.push({
                "value": cur,
                "label": nameOf(cur)
            });
        out.sort((a, b) => a.label.localeCompare(b.label));
        const seen = {};
        for (const o of out)
            seen[o.label] = (seen[o.label] ?? 0) + 1;
        return out.map(o => {
            let detail = seen[o.label] > 1 ? o.value.replace(/\.desktop$/, "") : "";
            if (o.value === cur) {
                const k = coverage(catId, cur);
                detail = k.set < k.of ? `${k.set} of ${k.of} types` : (detail || "current");
            }
            return {
                "value": o.value,
                "label": o.label,
                "detail": detail
            };
        }).concat(cur === "" ? [
                {
                    "value": "",
                    "label": "None",
                    "detail": "nothing set"
                }
            ] : []);
    }

    function set(catId: string, id: string): void {
        const c = category(catId);
        if (!c || id === "" || busy !== "")
            return;
        const app = norm(id);
        const types = typesFor(c, app);
        busy = catId;
        Exec.callUser(["xdg-mime", "default", app, ...types], `default ${c.label.toLowerCase()} ${app}`, (ok, text) => {
            root.busy = "";
            if (!ok) {
                root.error = `${c.label}: ${text || "xdg-mime failed"}`;
                return;
            }
            root.error = "";
            if (text === "dry run") { // nothing written: keep showing what is there
                root.notice(`Dry run: ${c.label.toLowerCase()} ${root.nameOf(app)} (xdg-mime not run)`);
                return;
            }
            root.notice(`${c.label}: ${root.nameOf(app)}`);
            const cur = Object.assign({}, root.current);
            for (const t of types)
                cur[t] = app;
            root.current = cur;
            root.refresh(); // what the XDG lookup says now (another mimeapps.list may win)
        });
    }

    function refresh(): void {
        if (!reader.running)
            reader.running = true;
        if (!scanner.running)
            scanner.running = true;
    }

    // current defaults: "type<TAB>app.desktop" per line
    Process {
        id: reader
        command: ["nice", "-n", "19", "sh", "-c", 'for t in "$@"; do printf "%s\\t%s\\n" "$t" "$(xdg-mime query default "$t" 2>/dev/null)"; done', "sh", ...root.allTypes]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t");
                    if (i > 0)
                        cur[line.slice(0, i)] = line.slice(i + 1).trim().split(";")[0];
                }
                root.current = cur;
                root.typesRead = true;
            }
        }
    }

    // which app lists which type: "rel/path.desktop:MimeType=a;b;" per file, data dirs in XDG order
    Process {
        id: scanner
        command: ["nice", "-n", "19", "sh", "-c", 'IFS=:; for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do [ -d "$d/applications" ] && (cd "$d/applications" && grep -rs --include="*.desktop" "^MimeType=" . | sed "s|^\\./||"); done; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":MimeType=");
                    if (i <= 0)
                        continue;
                    const id = line.slice(0, i).replace(/\//g, "-");
                    if (h[id])
                        continue; // shadowed by a file earlier in the search path
                    const types = {};
                    for (const t of line.slice(i + 10).split(";"))
                        if (t.trim() !== "")
                            types[t.trim()] = true;
                    h[id] = types;
                }
                root.handlers = h;
                root.handlersRead = true;
            }
        }
    }
}
