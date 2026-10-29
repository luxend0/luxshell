pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.services as Services // PowerProfile: Quickshell.Services.UPower has an enum of that name
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
            "desc": "Ethernet = all bars, Wi-Fi by strength, offline = none. Click opens the network menu.",
            "options": [
                {
                    "key": "islandNetworkMenu",
                    "label": "Click opens menu",
                    "kind": "switch"
                },
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
            "desc": "Output volume. Scroll on it to change the volume, click opens the sound menu.",
            "options": [
                {
                    "key": "islandVolumeMenu",
                    "label": "Click opens menu",
                    "kind": "switch"
                },
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
        // ---- bar info + tools (palette only; island/widgets: Gpu, Temp, NetSpeed, Updates,
        // Tool, Privacy) ----
        {
            "id": "gpu",
            "name": "GPU",
            "icon": "gpu",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "GPU load and VRAM in use (amdgpu sysfs, the card with the most VRAM).",
            "options": [
                {
                    "key": "islandGpuShow",
                    "label": "Show",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "load",
                            "label": "Load"
                        },
                        {
                            "value": "vram",
                            "label": "VRAM"
                        },
                        {
                            "value": "both",
                            "label": "Both"
                        }
                    ]
                },
                {
                    "key": "islandGpuVram",
                    "label": "VRAM as",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "gb",
                            "label": "GB"
                        },
                        {
                            "value": "pct",
                            "label": "%"
                        }
                    ]
                },
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
            "id": "temps",
            "name": "Temperatures",
            "icon": "thermometer",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "CPU and GPU temperature (hwmon: k10temp or zenpower, the card's amdgpu sensor).",
            "options": [
                {
                    "key": "islandTempShow",
                    "label": "Show",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "cpu",
                            "label": "CPU"
                        },
                        {
                            "value": "gpu",
                            "label": "GPU"
                        },
                        {
                            "value": "both",
                            "label": "Both"
                        }
                    ]
                },
                {
                    "key": "islandTempCpuSensor",
                    "label": "CPU sensor",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "tctl",
                            "label": "Tctl"
                        },
                        {
                            "value": "ccd",
                            "label": "Hottest CCD"
                        }
                    ]
                },
                {
                    "key": "islandTempGpuSensor",
                    "label": "GPU sensor",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "edge",
                            "label": "Edge"
                        },
                        {
                            "value": "junction",
                            "label": "Junction"
                        },
                        {
                            "value": "mem",
                            "label": "Memory"
                        }
                    ]
                },
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
            "id": "netspeed",
            "name": "Network speed",
            "icon": "arrow-down-up",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Download and upload rate of the default-route interface (/proc/net/dev), the unit picked automatically.",
            "options": [
                {
                    "key": "islandNetSpeedShow",
                    "label": "Show",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "both",
                            "label": "Both"
                        },
                        {
                            "value": "down",
                            "label": "Down"
                        },
                        {
                            "value": "up",
                            "label": "Up"
                        }
                    ]
                },
                {
                    "key": "islandNetSpeedBits",
                    "label": "Bits per second",
                    "kind": "switch"
                },
                {
                    "key": "islandNetSpeedIface",
                    "label": "Interface",
                    "kind": "text",
                    "placeholder": "Default route"
                },
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
            "id": "updates",
            "name": "Updates",
            "icon": "package",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Pending updates (checkupdates + paru -Qua), checked in the background at low priority. Click: paru -Syu in the terminal, right click: check now.",
            "options": [
                {
                    "key": "islandUpdatesHideZero",
                    "label": "Only when there are updates",
                    "kind": "switch"
                },
                {
                    "key": "islandUpdatesAur",
                    "label": "Count AUR updates",
                    "kind": "switch"
                },
                {
                    "key": "islandUpdatesInterval",
                    "label": "Check every",
                    "kind": "slider",
                    "min": 15,
                    "max": 240,
                    "step": 15,
                    "unit": " min"
                }
            ]
        },
        {
            "id": "screenshot",
            "name": "Screenshot",
            "icon": "camera",
            "states": ["collapsed", "hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "Click: a region (slurp), right click: the whole screen. Saved and copied like the control center's button.",
            "options": []
        },
        {
            "id": "colorpicker",
            "name": "Color picker",
            "icon": "pipette",
            "states": ["collapsed", "hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "hyprpicker: click a pixel, the value is copied and shown in the island.",
            "options": [
                {
                    "key": "islandPickerFormat",
                    "label": "Format",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "hex",
                            "label": "HEX"
                        },
                        {
                            "value": "rgb",
                            "label": "RGB"
                        },
                        {
                            "value": "hsl",
                            "label": "HSL"
                        }
                    ]
                }
            ]
        },
        {
            "id": "launcher",
            "name": "Launcher",
            "icon": "search",
            "states": ["collapsed", "hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "Opens the launcher.",
            "options": []
        },
        {
            "id": "overview",
            "name": "Overview",
            "icon": "layout-dashboard",
            "states": ["collapsed", "hover"],
            "cls": "system",
            "reveal": "extras",
            "desc": "Opens the workspace overview.",
            "options": []
        },
        {
            "id": "privacy",
            "name": "Privacy",
            "icon": "circle-dot",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "desc": "Red dot while an app shares or records the screen, uses the camera or the microphone; hidden otherwise. Click: which apps.",
            "options": [
                {
                    "key": "islandPrivacyStyle",
                    "label": "Style",
                    "kind": "segment",
                    "items": [
                        {
                            "value": "icons",
                            "label": "Dot + glyphs"
                        },
                        {
                            "value": "dot",
                            "label": "Dot"
                        }
                    ]
                }
            ]
        },
        // ---- bar menus + switches (island/widgets/BarToggle; menus = panels/SheetMenu) ----
        {
            "id": "bluetooth",
            "name": "Bluetooth",
            "icon": "bluetooth",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Off, on or connected. Click opens the Bluetooth menu.",
            "options": [
                {
                    "key": "islandBluetoothBattery",
                    "label": "Device battery",
                    "kind": "switch"
                },
                {
                    "key": "islandBluetoothName",
                    "label": "Device name",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "display",
            "name": "Display",
            "icon": "sun",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Brightness of this screen (DDC/CI or backlight). Scroll on it to change it, click opens the display menu with the night light.",
            "options": [
                {
                    "key": "islandDisplayPercent",
                    "label": "Percentage",
                    "kind": "switch"
                },
                {
                    "key": "islandDisplayStep",
                    "label": "Scroll step",
                    "kind": "slider",
                    "min": 1,
                    "max": 20,
                    "step": 1,
                    "unit": " %"
                }
            ]
        },
        {
            "id": "mic",
            "name": "Microphone",
            "icon": "mic",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Click mutes or unmutes the microphone. Right click opens the sound menu at the input.",
            "options": [
                {
                    "key": "islandMicRecording",
                    "label": "Red while an app records",
                    "kind": "switch"
                },
                {
                    "key": "islandMicPercent",
                    "label": "Input level",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "nightlight",
            "name": "Night Light",
            "icon": "moon",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Warm screen (wlsunset). Click turns it on or off, scroll sets the temperature, right click opens the display menu.",
            "options": [
                {
                    "key": "islandNightLightTemp",
                    "label": "Temperature",
                    "kind": "switch"
                },
                {
                    "key": "islandNightLightStep",
                    "label": "Scroll step",
                    "kind": "slider",
                    "min": 50,
                    "max": 500,
                    "step": 50,
                    "unit": " K"
                }
            ]
        },
        {
            "id": "powerprofile",
            "name": "Power Mode",
            "icon": "gauge",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "power-profiles-daemon. Click switches to the next profile, right click picks one.",
            "options": [
                {
                    "key": "islandPowerProfileLabel",
                    "label": "Name",
                    "kind": "switch"
                }
            ]
        },
        {
            "id": "caffeine",
            "name": "Caffeine",
            "icon": "coffee",
            "states": ["collapsed", "hover"],
            "cls": "status",
            "reveal": "extras",
            "dim": true,
            "desc": "Keeps the session awake. Click turns it on or off, right click picks 30 min, 1 h, 2 h or until off.",
            "options": [
                {
                    "key": "islandCaffeineTime",
                    "label": "Time left",
                    "kind": "switch"
                },
                {
                    "key": "islandCaffeineClick",
                    "label": "Click keeps awake",
                    "kind": "segment",
                    "items": [
                        {
                            "value": 0,
                            "label": "Until off"
                        },
                        {
                            "value": 30,
                            "label": "30 min"
                        },
                        {
                            "value": 60,
                            "label": "1 h"
                        },
                        {
                            "value": 120,
                            "label": "2 h"
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
        if (id === "nightlight")
            return NightLight.available;
        if (id === "powerprofile")
            return Services.PowerProfile.available;
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
        case "updates":
            return updatesShown();
        case "privacy":
            return Privacy.active;
        case "nightlight":
            return NightLight.available;
        case "powerprofile":
            return Services.PowerProfile.available;
        }
        return true;
    }
    function updatesShown(): bool {
        return !Settings.islandUpdatesHideZero || Updates.count > 0;
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
        case "gpu":
            {
                const vram = o.islandGpuVram === "pct" ? "100%" : "88.8G";
                return infoText(si, 1, o.islandGpuShow === "vram" ? vram : o.islandGpuShow === "both" ? `100% · ${vram}` : "100%");
            }
        case "temps":
            return o.islandTempShow === "both" ? 2 * infoText(si, 1, "100°") + w.gaps.status[si] : infoText(si, 1, "100°");
        case "netspeed":
            {
                const one = infoText(si, Theme.barInfo.arrowScale, o.islandNetSpeedBits ? "88.8 Mb/s" : "88.8 MB/s");
                return o.islandNetSpeedShow === "both" ? 2 * one + w.gaps.status[si] : one;
            }
        case "updates":
            return updatesShown() ? infoText(si, 1, Updates.ready ? String(Updates.count) : "–") : 0;
        case "screenshot":
        case "colorpicker":
        case "launcher":
        case "overview":
            return (hv ? h.systemIconSize : w.systemIconSize) + 10;
        case "privacy":
            {
                if (!Privacy.active)
                    return 0;
                const b = Theme.barInfo;
                const n = o.islandPrivacyStyle === "dot" ? 0 : Privacy.glyphs.length;
                return b.dotSize[si] + (n > 0 ? b.privacyGap[si] + n * Math.round(w.iconSize[si] * b.privacyIconScale) + (n - 1) * b.privacyIconGap[si] : 0);
            }
        case "bluetooth":
            return o.islandBluetoothName || o.islandBluetoothBattery ? glyphText(si, (o.islandBluetoothName ? "Bluetooth device " : "") + (o.islandBluetoothBattery ? "100%" : "")) : w.iconSize[si];
        case "display":
            return o.islandDisplayPercent ? glyphText(si, "100%") : w.iconSize[si];
        case "mic":
            return o.islandMicPercent ? glyphText(si, "100%") : w.iconSize[si];
        case "nightlight":
            return o.islandNightLightTemp ? glyphText(si, "6000 K") : w.iconSize[si];
        case "powerprofile":
            return o.islandPowerProfileLabel ? glyphText(si, "Performance") : w.iconSize[si];
        case "caffeine":
            return o.islandCaffeineTime ? glyphText(si, "1h 59m") : w.iconSize[si];
        }
        return 0;
    }
    // InfoLabel (island/widgets): glyph (scaled) + gap + a text slot as wide as the sample
    function infoText(si: int, iconScale: real, sample: string): real {
        return Math.round(w.iconSize[si] * iconScale) + w.iconGap[si] + Math.ceil((si === 0 ? fmTextC : fmTextH).advanceWidth(sample));
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
