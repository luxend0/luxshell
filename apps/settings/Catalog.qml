pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core
import qs.services
import qs.widgets

// Every page and option of the settings app, as data. Pages without options are
// left out of the sidebar (Media, Lock Screen: their modules bring options later;
// the video's Dock does not exist here). Every option reads and writes real state:
// config/Settings keys or the service that owns it (consumer noted per option).
//
// option = {
//   id, kind, label, keywords (search only), enabled() (optional)
//   kind "link"     value() text + arrow, run()
//   kind "choice"   value() current id, options() [{ value, label, detail }], set(v)
//   kind "switch"   value() bool, set(b)
//   kind "slider"   value() number, set(n), min, max, step, format(n)
//   kind "swatches" value() current colour ("" = theme accent), colours(), set(c)
//   kind "text"     value() text, placeholder, valid(t), apply(t)
//   kind "button"   value() text, action label, run()
//   kind "info"     value() text
// }
// Functions are called inside bindings, so everything they read stays live.
Singleton {
    id: root

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    // ---- installed terminals and fonts (choices only offer what exists) ------------
    readonly property var terminalCandidates: ["kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "xterm"]
    property var terminals: [Settings.terminal]
    readonly property var fontCandidates: ["Inter", "Inter Display", "Geist", "SF Pro Display", "SF Pro Text", "Roboto", "Noto Sans", "IBM Plex Sans", "Cantarell", "Ubuntu", "Fira Sans", "JetBrains Mono"]
    readonly property var fonts: {
        const all = Qt.fontFamilies();
        const list = fontCandidates.filter(f => all.includes(f));
        return list.includes(Settings.fontFamily) ? list : [Settings.fontFamily, ...list];
    }

    Process {
        running: true
        command: ["sh", "-c", 'for t in "$@"; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done', "sh", ...root.terminalCandidates]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(s => s !== "");
                root.terminals = found.includes(Settings.terminal) ? found : [Settings.terminal, ...found];
            }
        }
    }

    // ---- helpers -----------------------------------------------------------------
    function hex(c: color): string {
        return Icons.hex(c).toUpperCase();
    }
    function trim(n: real): string {
        return String(Math.round(n * 100) / 100);
    }
    readonly property var dateFormats: ["ddd, MMM d", "ddd d MMM", "ddd d.M.", "d.M.yyyy", "yyyy-MM-dd"]
    readonly property var timeFormats: [
        {
            "value": "24h",
            "label": "24-hour"
        },
        {
            "value": "12h",
            "label": "12-hour"
        },
        {
            "value": "12h-ampm",
            "label": "12-hour, AM/PM"
        }
    ]

    // island hover open + close once (Motion page preview)
    Timer {
        id: previewTimer
        interval: Motion.ms(1300)
        onTriggered: Ui.preview("")
    }
    function playPreview(): void {
        Ui.preview("hover");
        previewTimer.restart();
    }

    // ---- pages ---------------------------------------------------------------------
    readonly property var pages: [
        {
            "id": "bar",
            "title": "Bar & Island",
            "subtitle": "Workspaces and how the island collapses.",
            "icon": glyph(0xF1513),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "workspaces",
                            "kind": "slider",
                            "label": "Workspaces",
                            "keywords": "capsules count island bar",
                            "min": 2,
                            "max": 6,
                            "step": 1,
                            "value": () => Settings.workspaceCount,
                            "set": v => Settings.set("workspaceCount", v),
                            "format": v => `${v}`
                        },
                        {
                            "id": "hoverHold",
                            "kind": "slider",
                            "label": "Collapse delay (after the pointer leaves the island)",
                            "keywords": "hover hold close",
                            "min": 0,
                            "max": 600,
                            "step": 20,
                            "value": () => Settings.hoverHold,
                            "set": v => Settings.set("hoverHold", v),
                            "format": v => `${v} ms`
                        }
                    ]
                }
            ]
        },
        {
            "id": "media",
            "title": "Media",
            "subtitle": "Now playing in the island.",
            "icon": glyph(0xF0387),
            "sections": []
        },
        {
            "id": "clock",
            "title": "Clock & Date",
            "subtitle": "Time and date format of the island.",
            "icon": glyph(0xF1442),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "clockFormat",
                            "kind": "choice",
                            "label": "Time format",
                            "keywords": "12 24 hour am pm clock",
                            "value": () => Settings.clockFormat,
                            "options": () => root.timeFormats.map(f => ({
                                        "value": f.value,
                                        "label": f.label,
                                        "detail": Clock.formatTime(Clock.now, f.value)
                                    })),
                            "set": v => Settings.set("clockFormat", v)
                        },
                        {
                            "id": "dateFormat",
                            "kind": "choice",
                            "label": "Date format",
                            "keywords": "day month weekday",
                            "value": () => Settings.dateFormat,
                            "options": () => root.dateFormats.map(f => ({
                                        "value": f,
                                        "label": Clock.now.toLocaleDateString(Clock.locale, f),
                                        "detail": ""
                                    })),
                            "set": v => Settings.set("dateFormat", v)
                        }
                    ]
                },
                {
                    "title": "Preview",
                    "options": [
                        {
                            "id": "clockPreview",
                            "kind": "info",
                            "label": "Island",
                            "keywords": "clock date example",
                            "value": () => `${Clock.time}   ${Clock.date}`
                        }
                    ]
                }
            ]
        },
        {
            "id": "appearance",
            "title": "Appearance",
            "subtitle": "Theme, wallpaper, accent colour and fonts.",
            "icon": glyph(0xF03D8),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "theme",
                            "kind": "link",
                            "label": "Theme",
                            "keywords": "palette colours colors dark",
                            "value": () => Theme.name,
                            "run": () => Ui.open("themes")
                        },
                        {
                            "id": "wallpaper",
                            "kind": "link",
                            "label": "Wallpaper",
                            "keywords": "background image video",
                            "value": () => "Choose...",
                            "run": () => Ui.open("wallpaper")
                        }
                    ]
                },
                {
                    "title": "Accent",
                    "options": [
                        {
                            "id": "accent",
                            "kind": "swatches",
                            "label": "Accent colour",
                            "keywords": "color highlight tint",
                            "value": () => Settings.accent,
                            "colours": () => [Theme.pal.accent, ...Theme.swatches],
                            "set": c => Settings.set("accent", c)
                        },
                        {
                            "id": "accentCustom",
                            "kind": "text",
                            "label": "Custom (#rrggbb)",
                            "keywords": "accent colour color hex",
                            "value": () => root.hex(Theme.accent),
                            "placeholder": "#rrggbb",
                            "valid": t => /^#?[0-9a-fA-F]{6}$/.test(t.trim()) || t.trim() === "",
                            "apply": t => {
                                const v = t.trim();
                                Settings.set("accent", v === "" ? "" : (v.startsWith("#") ? v : "#" + v).toLowerCase());
                            }
                        },
                        {
                            "id": "themeExport",
                            "kind": "switch",
                            "label": "Export colours (kitty, GTK and palette.json)",
                            "keywords": "theme export cache terminal gtk",
                            "value": () => Settings.themeExport,
                            "set": v => Settings.set("themeExport", v)
                        }
                    ]
                },
                {
                    "title": "Type",
                    "options": [
                        {
                            "id": "fontSize",
                            "kind": "slider",
                            "label": "Font size",
                            "keywords": "text scale",
                            "min": 12,
                            "max": 20,
                            "step": 1,
                            "value": () => Settings.fontSize,
                            "set": v => Settings.set("fontSize", v),
                            "format": v => `${v} px`
                        },
                        {
                            "id": "fontFamily",
                            "kind": "choice",
                            "label": "Font",
                            "keywords": "typeface family inter",
                            "value": () => Settings.fontFamily,
                            "options": () => root.fonts.map(f => ({
                                        "value": f,
                                        "label": f,
                                        "detail": "",
                                        "font": f
                                    })),
                            "set": v => Settings.set("fontFamily", v)
                        }
                    ]
                },
                {
                    "title": "Wallpaper",
                    "options": [
                        {
                            "id": "wallpaperDirs",
                            "kind": "text",
                            "label": "Folders",
                            "keywords": "wallpaper directories path pictures",
                            "value": () => Settings.wallpaperDirs.join(", "),
                            "placeholder": "~/Pictures/Wallpapers",
                            "valid": t => true,
                            "apply": t => Settings.set("wallpaperDirs", t.split(",").map(s => s.trim()).filter(s => s !== ""))
                        }
                    ]
                }
            ]
        },
        {
            "id": "motion",
            "title": "Motion",
            "subtitle": "How fast the island and panels animate.",
            "icon": glyph(0xF0DAF),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "animationSpeed",
                            "kind": "slider",
                            "label": "Animation speed",
                            "keywords": "animations duration fast slow reduce motion",
                            "min": 0.5,
                            "max": 3,
                            "step": 0.25,
                            "value": () => Settings.animationSpeed,
                            "set": v => Settings.set("animationSpeed", v),
                            "format": v => `${root.trim(v)}×`
                        },
                        {
                            "id": "motionPreview",
                            "kind": "button",
                            "label": "Preview on the island",
                            "keywords": "try test animation hover",
                            "value": () => "",
                            "action": "Play",
                            "run": () => root.playPreview()
                        }
                    ]
                }
            ]
        },
        {
            "id": "launcher",
            "title": "Launcher",
            "subtitle": "Terminal for commands and the web search row.",
            "icon": glyph(0xF0349),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "terminal",
                            "kind": "choice",
                            "label": "Terminal",
                            "keywords": "kitty foot shell command console",
                            "value": () => Settings.terminal,
                            "options": () => root.terminals.map(t => ({
                                        "value": t,
                                        "label": t,
                                        "detail": ""
                                    })),
                            "set": v => Settings.set("terminal", v)
                        },
                        {
                            "id": "searchEngine",
                            "kind": "choice",
                            "label": "Search engine",
                            "keywords": "web google duckduckgo browser",
                            "value": () => Settings.searchEngine,
                            "options": () => SearchEngines.list.map(e => ({
                                        "value": e.id,
                                        "label": e.name,
                                        "detail": ""
                                    })),
                            "set": v => Settings.set("searchEngine", v)
                        },
                        {
                            "id": "webResults",
                            "kind": "switch",
                            "label": "Web search row (under every query)",
                            "keywords": "internet results",
                            "value": () => Settings.webResults,
                            "set": v => Settings.set("webResults", v)
                        }
                    ]
                }
            ]
        },
        {
            "id": "notifications",
            "title": "Notifications",
            "subtitle": "Popups in the island and the history.",
            "icon": glyph(0xF009A),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "dnd",
                            "kind": "switch",
                            "label": "Do not disturb (only critical ones pop up)",
                            "keywords": "focus silence quiet dnd",
                            "value": () => Settings.dnd,
                            "set": v => Settings.set("dnd", v)
                        }
                    ]
                },
                {
                    "title": "Popup duration",
                    "options": [
                        {
                            "id": "notifTimeout",
                            "kind": "slider",
                            "label": "Normal",
                            "keywords": "timeout notification popup peek seconds",
                            "min": 2,
                            "max": 20,
                            "step": 0.5,
                            "value": () => Settings.notifTimeout,
                            "set": v => Settings.set("notifTimeout", v),
                            "format": v => `${root.trim(v)} s`
                        },
                        {
                            "id": "notifTimeoutLow",
                            "kind": "slider",
                            "label": "Low priority",
                            "keywords": "timeout notification transient seconds",
                            "min": 1,
                            "max": 20,
                            "step": 0.5,
                            "value": () => Settings.notifTimeoutLow,
                            "set": v => Settings.set("notifTimeoutLow", v),
                            "format": v => `${root.trim(v)} s`
                        },
                        {
                            "id": "notifTimeoutCritical",
                            "kind": "slider",
                            "label": "Critical",
                            "keywords": "timeout notification urgent seconds",
                            "min": 3,
                            "max": 60,
                            "step": 1,
                            "value": () => Settings.notifTimeoutCritical,
                            "set": v => Settings.set("notifTimeoutCritical", v),
                            "format": v => `${root.trim(v)} s`
                        }
                    ]
                },
                {
                    "title": "History",
                    "options": [
                        {
                            "id": "notifClear",
                            "kind": "button",
                            "label": "Notifications",
                            "keywords": "clear history dismiss",
                            "value": () => Notifs.count === 0 ? "None" : `${Notifs.count}`,
                            "action": "Clear all",
                            "enabled": () => Notifs.count > 0,
                            "run": () => Notifs.clear()
                        }
                    ]
                }
            ]
        },
        {
            "id": "controlcenter",
            "title": "Control Center",
            "subtitle": "The control center's switches.",
            "icon": glyph(0xF062E),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "ccFocus",
                            "kind": "switch",
                            "label": "Focus (silences notifications)",
                            "keywords": "dnd do not disturb",
                            "value": () => Settings.dnd,
                            "set": v => Settings.set("dnd", v)
                        },
                        {
                            "id": "gameMode",
                            "kind": "switch",
                            "label": "Game Mode (animations, blur and gaps off)",
                            "keywords": "gaming performance hyprland",
                            "value": () => GameMode.active,
                            "enabled": () => !GameMode.busy,
                            "set": v => GameMode.set(v)
                        }
                    ]
                }
            ]
        },
        {
            "id": "lockscreen",
            "title": "Lock Screen",
            "subtitle": "",
            "icon": glyph(0xF033E),
            "sections": []
        },
        {
            "id": "system",
            "title": "System",
            "subtitle": "How luxshell shares the desktop.",
            "icon": glyph(0xF0493),
            "sections": [
                {
                    "title": "",
                    "options": [
                        {
                            "id": "wallpaperLayer",
                            "kind": "switch",
                            "label": "Paint the wallpaper (off: another shell draws it)",
                            "keywords": "background layer ambxst",
                            "value": () => Settings.wallpaperLayer,
                            "set": v => Settings.set("wallpaperLayer", v)
                        }
                    ]
                },
                {
                    "title": "Files",
                    "options": [
                        {
                            "id": "settingsFile",
                            "kind": "button",
                            "label": "Settings",
                            "keywords": "config json file folder path",
                            "value": () => Settings.path.replace(Env.get("HOME"), "~"),
                            "action": "Open folder",
                            "run": () => Exec.run(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", Env.configDir], "open settings folder")
                        }
                    ]
                }
            ]
        }
    ]

    readonly property var visiblePages: pages.filter(p => p.sections.some(s => s.options.length > 0))

    function visible(id: string): bool {
        return visiblePages.some(p => p.id === id);
    }
    function pageById(id: string): var {
        return visiblePages.find(p => p.id === id) ?? visiblePages[0];
    }

    // ---- search across pages --------------------------------------------------------
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
