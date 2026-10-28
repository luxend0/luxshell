pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import "layout.js" as L

// Widgets of the island and the layout they sit in (Settings.islandLayout).
//
//   widgets           every widget: id, name, icon (chip), states it may sit in, class (gaps),
//                     option keys + the option rows the settings editor shows for it
//   layout            Settings.islandLayout, validated (unknown ids dropped, one per state)
//   width/height/radius(layout, state)   island size of a state for a layout
//   env(widthFn)      environment for island/bar/layout.js plans (live widths from BarContent)
//   peek(ms)          show the hover island on every screen for a moment (editor feedback)
//
// Island width = default width + (content of this layout - content of the default layout),
// both measured with stable sizes (longest title, "All caught up", a fixed date): the default
// layout with default options is exactly the video's 316 / 958 px, every change grows or
// shrinks the island by what it adds or removes.
Singleton {
    id: root

    // ---- widgets ---------------------------------------------------------------------------
    // reveal: how a hover-only widget fades in (Motion.reveal): "top" icon early + text late
    // (row 1 of ref/02), "extras" last (gear, power, tray), "date" with the clock's growth
    readonly property var widgets: [
        {
            "id": "workspaces",
            "name": "Workspaces",
            "icon": "layout-grid",
            "states": ["collapsed", "hover"],
            "cls": "ws",
            "fills": true,
            "reveal": "extras",
            "desc": "Workspaces 1 to n. Click one in the hover island to switch.",
            "options": [
                {
                    "key": "workspaceCount",
                    "label": "Count",
                    "kind": "slider",
                    "min": 2,
                    "max": 6,
                    "step": 1,
                    "unit": ""
                },
                {
                    "key": "islandWorkspaceStyle",
                    "label": "Style",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "capsules",
                            "label": "Capsules"
                        },
                        {
                            "value": "dots",
                            "label": "Dots"
                        },
                        {
                            "value": "numbers",
                            "label": "Numbers"
                        }
                    ]
                }
            ]
        },
        {
            "id": "clock",
            "name": "Clock",
            "icon": "clock",
            "states": ["collapsed", "hover"],
            "cls": "time",
            "reveal": "date",
            "desc": "Time; grows in the hover island.",
            "options": [
                {
                    "key": "clockFormat",
                    "label": "Format",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "24h",
                            "label": "24 h"
                        },
                        {
                            "value": "12h",
                            "label": "12 h"
                        },
                        {
                            "value": "12h-ampm",
                            "label": "AM/PM"
                        }
                    ]
                },
                {
                    "key": "islandClockSeconds",
                    "label": "Seconds",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "date",
            "name": "Date",
            "icon": "calendar",
            "states": ["collapsed", "hover"],
            "cls": "time",
            "reveal": "date",
            "desc": "Date, dimmed. Next to the clock it shrinks and grows with it.",
            "options": [
                {
                    "key": "dateFormat",
                    "label": "Format",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "ddd, MMM d",
                            "label": "Sun, Oct 25"
                        },
                        {
                            "value": "ddd d",
                            "label": "Sun 25"
                        },
                        {
                            "value": "d MMM",
                            "label": "25 Oct"
                        },
                        {
                            "value": "dddd",
                            "label": "Sunday"
                        }
                    ]
                }
            ]
        },
        {
            "id": "window",
            "name": "Window",
            "icon": "app-window",
            "states": ["collapsed", "hover"],
            "cls": "label",
            "reveal": "top",
            "desc": "Icon and title of the focused window, \"Desktop\" on an empty workspace.",
            "options": [
                {
                    "key": "islandWindowTitle",
                    "label": "Title",
                    "kind": "switch"
                },
                {
                    "key": "islandWindowMaxWidth",
                    "label": "Longest title",
                    "kind": "slider",
                    "min": 120,
                    "max": 480,
                    "step": 20,
                    "unit": " px"
                },
                {
                    "key": "islandWindowYield",
                    "label": "Make room for media",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "media",
            "name": "Media",
            "icon": "music",
            "states": ["collapsed", "hover"],
            "cls": "label",
            "reveal": "top",
            "desc": "Cover, title and play/pause while a player has a track. Click opens the media panel.",
            "options": []
        },
        {
            "id": "notifications",
            "name": "Notifications",
            "icon": "bell",
            "states": ["collapsed", "hover"],
            "cls": "label",
            "reveal": "top",
            "desc": "\"All caught up\" or the count, with the bell. Click opens the notification center.",
            "options": [
                {
                    "key": "islandNotifLabel",
                    "label": "Status text",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "network",
            "name": "Network",
            "icon": "signal",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Ethernet = all bars, Wi-Fi by strength, offline = none.",
            "options": [
                {
                    "key": "islandNetworkStyle",
                    "label": "Style",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "bars",
                            "label": "Bars"
                        },
                        {
                            "value": "icon",
                            "label": "Icon"
                        }
                    ]
                }
            ]
        },
        {
            "id": "volume",
            "name": "Volume",
            "icon": "volume-2",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Output volume. Scroll on it to change the volume.",
            "options": [
                {
                    "key": "islandVolumePercent",
                    "label": "Percentage",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "tray",
            "name": "Tray",
            "icon": "ellipsis",
            "states": ["hover"],
            "cls": "tray",
            "reveal": "extras",
            "desc": "Tray icons of running apps. Hover island only (menus need it open).",
            "options": []
        },
        {
            "id": "settings",
            "name": "Settings",
            "icon": "settings",
            "states": ["collapsed", "hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "Gear, opens this window.",
            "options": []
        },
        {
            "id": "power",
            "name": "Power",
            "icon": "power",
            "states": ["hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "Opens the power menu. Hover island only, out of reach of stray clicks.",
            "options": []
        },
        {
            "id": "battery",
            "name": "Battery",
            "icon": "battery-medium",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Charge, only shown on machines with a battery.",
            "options": [
                {
                    "key": "islandBatteryPercent",
                    "label": "Percentage",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "weather",
            "name": "Weather",
            "icon": "cloud-sun",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Current weather from wttr.in, fetched every 30 minutes and cached.",
            "options": [
                {
                    "key": "islandWeatherLocation",
                    "label": "Location",
                    "kind": "text",
                    "placeholder": "By IP"
                },
                {
                    "key": "islandWeatherUnit",
                    "label": "Unit",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "c",
                            "label": "°C"
                        },
                        {
                            "value": "f",
                            "label": "°F"
                        }
                    ]
                }
            ]
        },
        {
            "id": "cpu",
            "name": "CPU",
            "icon": "cpu",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Processor load from /proc/stat.",
            "options": [
                {
                    "key": "islandSysmonInterval",
                    "label": "Every",
                    "kind": "slider",
                    "min": 2,
                    "max": 10,
                    "step": 1,
                    "unit": " s"
                }
            ]
        },
        {
            "id": "ram",
            "name": "Memory",
            "icon": "memory-stick",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Memory in use from /proc/meminfo.",
            "options": [
                {
                    "key": "islandSysmonInterval",
                    "label": "Every",
                    "kind": "slider",
                    "min": 2,
                    "max": 10,
                    "step": 1,
                    "unit": " s"
                }
            ]
        },
        {
            "id": "keyboard",
            "name": "Keyboard",
            "icon": "keyboard",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Active keyboard layout (Hyprland).",
            "options": [
                {
                    "key": "islandKeyboardStyle",
                    "label": "Show",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "code",
                            "label": "DE"
                        },
                        {
                            "value": "name",
                            "label": "German"
                        }
                    ]
                }
            ]
        },
        {
            "id": "spacer",
            "name": "Spacer",
            "icon": "move-horizontal",
            "states": ["collapsed", "hover"],
            "cls": "spacer",
            "repeat": true,
            "desc": "Empty space between widgets. Can be used more than once.",
            "options": [
                {
                    "key": "islandSpacerWidth",
                    "label": "Width",
                    "kind": "slider",
                    "min": 8,
                    "max": 120,
                    "step": 4,
                    "unit": " px"
                }
            ]
        }
    ]

    readonly property var ids: widgets.map(w => w.id)
    readonly property var byId: {
        const m = {};
        for (const w of widgets)
            m[w.id] = w;
        return m;
    }
    function def(id: string): var {
        return byId[id] ?? null;
    }
    function allowed(id: string, state: string): bool {
        const d = byId[id];
        return !!d && d.states.includes(state);
    }
    // option keys of a widget (reset, undo)
    function optionKeys(id: string): var {
        return (byId[id]?.options ?? []).map(o => o.key);
    }
    readonly property var allOptionKeys: {
        const out = [];
        for (const w of widgets)
            for (const o of w.options)
                if (!out.includes(o.key))
                    out.push(o.key);
        return out;
    }

    // ---- layout ----------------------------------------------------------------------------
    readonly property var defaultLayout: Settings.defaultOf("islandLayout")
    readonly property var layout: normalize(Settings.islandLayout)

    function normalize(obj: var): var {
        return L.normalize(obj, ids, (id, s) => root.allowed(id, s), defaultLayout);
    }
    function contains(lay: var, state: string, id: string): bool {
        return L.contains(lay, state, id);
    }
    function find(lay: var, state: string, id: string): var {
        return L.find(lay, state, id);
    }
    function list(lay: var, state: string, row: string, col: string): var {
        return L.listAt(lay, state, row, col);
    }
    function slots(state: string): var {
        return L.slots(state);
    }
    function lib(): var {
        return L;
    }

    // ---- presence --------------------------------------------------------------------------
    function hasBattery(): bool {
        const d = UPower.displayDevice;
        return !!d && d.isLaptopBattery && d.isPresent;
    }
    function trayCount(): int {
        return (Tray.items?.values ?? []).length;
    }
    // can it ever show here (keeps a hover row open)
    function available(id: string): bool {
        return id === "battery" ? hasBattery() : true;
    }
    // shows right now; ids = the slot it sits in (the window title yields to a media chip
    // in the same slot while a track plays, like the video's row 1)
    function present(id: string, slotIds: var): bool {
        switch (id) {
        case "battery":
            return hasBattery();
        case "media":
            return Media.hasTrack;
        case "window":
            return !(Settings.islandWindowYield && Media.hasTrack && (slotIds ?? []).includes("media"));
        case "tray":
            return trayCount() > 0;
        }
        return true;
    }

    // ---- measures ----------------------------------------------------------------------------
    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property QtObject w: Theme.widgets
    readonly property var mC: ({
            "padLeft": c.padLeft,
            "padRight": c.padRight,
            "centerY": c.centerY
        })
    readonly property var mH: ({
            "padLeft": h.padLeft,
            "padRight": h.padRight,
            "row1Y": h.row1Y,
            "row2Y": h.row2Y,
            "oneRowY": w.oneRowY,
            "spanY": w.spanY
        })

    function cls(id: string): string {
        return byId[id]?.cls ?? "other";
    }
    function gap(a: string, b: string, state: string): real {
        if (a === "spacer" || b === "spacer")
            return 0;
        const i = state === "collapsed" ? 0 : 1;
        const g = w.gaps;
        const ca = cls(a), cb = cls(b);
        if (ca === cb)
            return (g[ca] ?? g.other)[i];
        return (g[ca + "|" + cb] ?? g[cb + "|" + ca] ?? g.other)[i];
    }
    // optical line offset: signal + volume sit 1 px below row 2 in ref/02 (statusY vs row2Y)
    function dy(id: string, state: string): real {
        if (id !== "network" && id !== "volume")
            return 0;
        return state === "collapsed" ? c.statusY - c.centerY : h.statusY - h.row2Y;
    }

    // option values: current ones or the defaults (the default layout is measured with these)
    function opts(defaults: bool): var {
        const o = {};
        for (const k of allOptionKeys.concat(["clockFormat", "dateFormat"]))
            o[k] = defaults ? Settings.defaultOf(k) : Settings[k];
        return o;
    }

    FontMetrics {
        id: fmClockC
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.c.clockSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmClockH
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.h.clockSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmDateC
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.w.dateSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmDateH
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.h.dateSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmNotifC
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.w.notifSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmNotifH
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.h.notifSize)
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmTextC
        font.family: Theme.fontFamily
        font.pixelSize: root.w.textSize[0]
        font.weight: Font.Medium
    }
    FontMetrics {
        id: fmTextH
        font.family: Theme.fontFamily
        font.pixelSize: root.w.textSize[1]
        font.weight: Font.Medium
    }

    function timeSample(o: var): string {
        let t = o.clockFormat === "24h" ? "00:00" : "10:00";
        if (o.islandClockSeconds)
            t += ":00";
        if (o.clockFormat === "12h-ampm")
            t += " PM";
        return t;
    }
    function glyphText(si: int, text: string): real {
        return w.iconSize[si] + w.iconGap[si] + (si === 0 ? fmTextC : fmTextH).advanceWidth(text);
    }

    // width a widget reserves in the island width (stable: longest title, sample texts)
    function reserve(id: string, state: string, o: var): real {
        const hv = state === "hover";
        const si = hv ? 1 : 0;
        const g = hv ? h : c;
        switch (id) {
        case "workspaces":
            {
                const n = Math.max(2, Math.min(6, o.workspaceCount || 5));
                if (o.islandWorkspaceStyle === "dots")
                    return (n - 1) * w.dotStep[si] + w.dotActive[si];
                if (o.islandWorkspaceStyle === "numbers")
                    return (n - 1) * w.numberStep[si] + w.numberSize[si];
                return (n - 1) * g.pillStep + g.pillWidth;
            }
        case "clock":
            {
                const fm = hv ? fmClockH : fmClockC;
                return fm.advanceWidth(timeSample(o)) * g.clockSize / fm.font.pixelSize;
            }
        case "date":
            return (hv ? fmDateH : fmDateC).advanceWidth(new Date(2026, 8, 30).toLocaleDateString(Clock.locale, o.dateFormat || "ddd, MMM d"));
        case "window":
            {
                const title = o.islandWindowTitle ? (hv ? o.islandWindowMaxWidth : Math.round(o.islandWindowMaxWidth * w.titleShare)) : 0;
                return (hv ? h.appIconSize : w.appIconSize) + (title > 0 ? (hv ? h.appIconGap : w.appIconGap) + title : 0);
            }
        case "media":
            return hv ? Theme.media.chipMaxWidth : w.chipMaxWidth;
        case "notifications":
            {
                const label = o.islandNotifLabel ? (hv ? fmNotifH : fmNotifC).advanceWidth("All caught up") + (hv ? 12 : w.notifGap) : 0;
                return label + (hv ? h.bellSize : w.bellSize);
            }
        case "network":
            return o.islandNetworkStyle === "icon" ? w.iconSize[si] : 4 * g.barWidth + 3 * g.barGap;
        case "volume":
            return g.volumeSize + (o.islandVolumePercent ? w.iconGap[si] + (hv ? fmTextH : fmTextC).advanceWidth("100%") : 0);
        case "tray":
            {
                const n = trayCount();
                return n === 0 ? 0 : n * h.trayIconSize + (n - 1) * 10;
            }
        case "settings":
        case "power":
            return (hv ? h.systemIconSize : w.systemIconSize) + 10;
        case "battery":
            return o.islandBatteryPercent ? glyphText(si, "100%") : w.iconSize[si];
        case "weather":
            return glyphText(si, "-10°");
        case "cpu":
        case "ram":
            return glyphText(si, "100%");
        case "keyboard":
            return glyphText(si, o.islandKeyboardStyle === "name" ? KbLayout.name || "English (US)" : "WW");
        case "spacer":
            return o.islandSpacerWidth;
        }
        return 0;
    }

    function measureEnv(o: var): var {
        return {
            "m": s => s === "collapsed" ? root.mC : root.mH,
            "available": id => root.available(id),
            "present": (id, ids, s) => root.present(id, ids),
            "width": (id, s) => root.reserve(id, s, o),
            "gap": (a, b, s) => root.gap(a, b, s),
            "dy": (id, s) => root.dy(id, s),
            "reserve": (id, s) => root.reserve(id, s, o),
            "yieldOn": o.islandWindowYield,
            "mediaPresent": Media.hasTrack
        };
    }
    // live environment for plans: widthFn(id, state) from the widgets on screen
    function env(widthFn: var): var {
        const e = measureEnv(opts(false));
        e.width = widthFn;
        return e;
    }

    // ---- island size per state -------------------------------------------------------------
    readonly property real defaultCoreC: L.core(defaultLayout, "collapsed", measureEnv(opts(true)))
    readonly property real defaultCoreH: L.core(defaultLayout, "hover", measureEnv(opts(true)))

    function isDefaultLayout(lay: var): bool {
        return JSON.stringify(lay) === JSON.stringify(defaultLayout);
    }
    // content width of a state measured on the live widths (widthFn), plus the minimum air
    function liveMinWidth(lay: var, state: string, widthFn: var): real {
        const e = measureEnv(opts(false));
        e.reserve = (id, s) => id === "media" && !Media.hasTrack ? 0 : widthFn(id, s);
        return L.core(lay, state, e) + 2 * w.minGap[state === "collapsed" ? 0 : 1];
    }
    function hoverRows(lay: var): int {
        return L.rowsUsed(lay, "hover", measureEnv(opts(false))).length;
    }
    function width(lay: var, state: string): real {
        const g = state === "collapsed" ? c : h;
        if (state === "hover" && hoverRows(lay) === 0)
            return h.width; // nothing to expand to; the drop zones of the editor keep their size
        const core = L.core(lay, state, measureEnv(opts(false)));
        const base = state === "collapsed" ? defaultCoreC : defaultCoreH;
        return Math.max(w.minWidth, Math.min(w.maxWidth, Math.round((g.width + core - base) * 100) / 100));
    }
    function height(lay: var, state: string): real {
        if (state === "collapsed")
            return c.height;
        const n = hoverRows(lay);
        return n >= 2 ? h.height : n === 1 ? w.oneRowHeight : c.height;
    }
    function radius(lay: var, state: string): real {
        if (state === "collapsed")
            return c.radius;
        const n = hoverRows(lay);
        return n >= 2 ? h.radius : n === 1 ? w.oneRowRadius : c.radius;
    }

    // ---- peek: the hover island on screen for a moment (editor) --------------------------------
    property bool peeking: false
    function peek(ms: int): void {
        peeking = true;
        peekTimer.interval = ms > 0 ? ms : 1600;
        peekTimer.restart();
    }
    Timer {
        id: peekTimer
        onTriggered: root.peeking = false
    }
}
