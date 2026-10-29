import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Input: mouse (global), per-device values, keyboard layouts. Every row writes
// Hyprland through services/HyprSystem (live via hyprctl eval, kept in luxshell-system.lua);
// a reset gives the value back to the rest of the Hyprland config. Key repeat is not offered
// on purpose (it stays off: repeat_rate 0 + xset r off).
SettingsPage {
    id: page

    pageId: "input"
    group: "system"
    title: "Input"
    subtitle: "Mouse, touchpad and keyboard. Changes apply at once."
    icon: 0xF037D // md-mouse

    // the device list changes outside luxshell (plugging in): re-read it while the page shows
    Timer {
        running: SettingsApp.open && SettingsApp.page === page.pageId
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: HyprSystem.refreshDevices()
    }

    Component.onCompleted: Xkb.load() // layout and switch-key names

    Component {
        id: layoutList
        LayoutList {}
    }
    Component {
        id: note
        Note {}
    }

    function speed(v: real): string {
        const r = Math.round(v * 100) / 100;
        return r === 0 ? "0" : (r > 0 ? "+" : "−") + String(Math.abs(r));
    }
    function factor(v: real): string {
        return `${String(Math.round(v * 100) / 100)}×`;
    }
    readonly property var accelOptions: [
        {
            "value": "",
            "label": "Device default",
            "detail": "libinput decides"
        },
        {
            "value": "adaptive",
            "label": "Adaptive",
            "detail": "fast moves go further"
        },
        {
            "value": "flat",
            "label": "Flat",
            "detail": "no acceleration"
        }
    ]

    // ---- keyboard: layouts + switch key as one store each (reset and undo move both paths) ----
    function parseLayouts(layouts: string, variants: string): var {
        const v = String(variants).split(",");
        return String(layouts).split(",").map((l, i) => ({
                    "layout": l.trim(),
                    "variant": (v[i] ?? "").trim()
                })).filter(x => x.layout !== "");
    }
    function grpOf(options: string): string {
        return String(options).split(",").map(o => o.trim()).find(o => o.startsWith("grp:")) ?? "";
    }
    function withGrp(options: string, grp: string): string {
        const rest = String(options).split(",").map(o => o.trim()).filter(o => o !== "" && !o.startsWith("grp:"));
        if (grp !== "")
            rest.push(grp);
        return rest.join(",");
    }
    readonly property QtObject keyboard: QtObject {
        function paths(k: string): var {
            return k === "layouts" ? ["input.kb_layout", "input.kb_variant"] : ["input.kb_options"];
        }
        function get(k: string): var {
            if (k === "layouts")
                return page.parseLayouts(HyprSystem.current("input.kb_layout"), HyprSystem.current("input.kb_variant"));
            return page.grpOf(HyprSystem.current("input.kb_options"));
        }
        function set(k: string, v: var): bool {
            if (k === "layouts") {
                const list = Array.from(v ?? []).filter(x => x && x.layout);
                if (list.length === 0)
                    return false;
                return HyprSystem.setMany({
                    "input.kb_layout": list.map(x => x.layout).join(","),
                    "input.kb_variant": list.some(x => x.variant) ? list.map(x => x.variant ?? "").join(",") : ""
                });
            }
            // the switch key is one "grp:" option among the others the config may have
            return HyprSystem.setMany({
                "input.kb_options": page.withGrp(HyprSystem.baseOf("input.kb_options"), String(v))
            });
        }
        function isDefault(k: string): bool {
            return !paths(k).some(p => HyprSystem.isSet(p));
        }
        function reset(k: string): void {
            HyprSystem.resetMany(paths(k));
        }
        function defaultOf(k: string): var {
            if (k === "layouts")
                return page.parseLayouts(HyprSystem.baseOf("input.kb_layout"), HyprSystem.baseOf("input.kb_variant"));
            return page.grpOf(HyprSystem.baseOf("input.kb_options"));
        }
    }

    // ---- sections ------------------------------------------------------------------------------
    readonly property var mouseSection: ({
            "title": "Mouse",
            "options": [
                {
                    "id": "inputSensitivity",
                    "kind": "slider",
                    "store": HyprSystem,
                    "key": "input.sensitivity",
                    "label": "Pointer speed",
                    "keywords": "mouse sensitivity speed cursor pointer touchpad",
                    "min": -1,
                    "max": 1,
                    "step": 0.05,
                    "format": v => page.speed(v)
                },
                {
                    "id": "inputAccel",
                    "kind": "choice",
                    "store": HyprSystem,
                    "key": "input.accel_profile",
                    "label": "Acceleration",
                    "keywords": "mouse accel acceleration profile flat adaptive raw",
                    "options": () => page.accelOptions
                },
                {
                    "id": "inputNatural",
                    "kind": "switch",
                    "store": HyprSystem,
                    "key": "input.natural_scroll",
                    "label": "Natural scrolling",
                    "keywords": "mouse scroll direction reverse invert wheel"
                },
                {
                    "id": "inputScroll",
                    "kind": "slider",
                    "store": HyprSystem,
                    "key": "input.scroll_factor",
                    "label": "Scroll speed",
                    "keywords": "mouse scroll factor wheel speed multiplier",
                    "min": 0.1,
                    "max": 3,
                    "step": 0.1,
                    "format": v => page.factor(v)
                },
                {
                    "id": "inputLeftHanded",
                    "kind": "switch",
                    "store": HyprSystem,
                    "key": "input.left_handed",
                    "label": "Left-handed (swap the buttons)",
                    "keywords": "mouse left handed swap buttons primary"
                },
                {
                    "id": "inputMouseNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "device own value",
                    "text": "Every mouse and touchpad below follows these values until it gets its own: change a row of a device, its reset arrow hands it back."
                }
            ]
        })

    function deviceSection(d: var): var {
        const n = d.name;
        const key = f => `device:${n}:${f}`;
        const words = `${d.label} ${n} device own`;
        return {
            "title": d.label,
            "options": [
                {
                    "id": `dev-${n}-name`,
                    "kind": "info",
                    "label": d.touchpad ? "Touchpad" : "Mouse",
                    "keywords": words,
                    "value": () => n
                },
                {
                    "id": `dev-${n}-sensitivity`,
                    "kind": "slider",
                    "store": HyprSystem,
                    "key": key("sensitivity"),
                    "label": "Pointer speed",
                    "keywords": `sensitivity speed cursor ${words}`,
                    "min": -1,
                    "max": 1,
                    "step": 0.05,
                    "format": v => page.speed(v)
                },
                {
                    "id": `dev-${n}-accel`,
                    "kind": "choice",
                    "store": HyprSystem,
                    "key": key("accel_profile"),
                    "label": "Acceleration",
                    "keywords": `accel acceleration profile flat adaptive ${words}`,
                    "options": () => page.accelOptions
                },
                {
                    "id": `dev-${n}-natural`,
                    "kind": "switch",
                    "store": HyprSystem,
                    "key": key("natural_scroll"),
                    "label": "Natural scrolling",
                    "keywords": `scroll direction reverse ${words}`
                },
                {
                    "id": `dev-${n}-scroll`,
                    "kind": "slider",
                    "store": HyprSystem,
                    "key": key("scroll_factor"),
                    "label": "Scroll speed",
                    "keywords": `scroll factor wheel ${words}`,
                    "min": 0.1,
                    "max": 3,
                    "step": 0.1,
                    "format": v => page.factor(v)
                },
                {
                    "id": `dev-${n}-left`,
                    "kind": "switch",
                    "store": HyprSystem,
                    "key": key("left_handed"),
                    "label": "Left-handed",
                    "keywords": `left handed swap buttons ${words}`
                }
            ]
        };
    }
    readonly property var noDevices: ({
            "title": "Devices",
            "options": [
                {
                    "id": "inputNoDevices",
                    "kind": "info",
                    "label": "Mice and touchpads",
                    "keywords": "device mouse touchpad",
                    "value": () => HyprSystem.ready ? "None found" : "Reading..."
                }
            ]
        })

    readonly property var keyboardSection: ({
            "title": "Keyboard",
            "options": [
                {
                    "id": "inputLayouts",
                    "kind": "custom",
                    "store": page.keyboard,
                    "key": "layouts",
                    "label": "Layouts",
                    "keywords": "keyboard layout language variant xkb kb_layout de us",
                    "component": layoutList
                },
                {
                    "id": "inputSwitch",
                    "kind": "choice",
                    "store": page.keyboard,
                    "key": "switch",
                    "label": "Switch layouts with",
                    "keywords": "keyboard layout switch toggle shortcut grp kb_options",
                    "searchable": true,
                    "enabled": () => page.keyboard.get("layouts").length > 1,
                    "options": () => [
                        {
                            "value": "",
                            "label": "No key",
                            "detail": ""
                        }
                    ].concat(Xkb.switches.map(s => ({
                                "value": s.value,
                                "label": s.label,
                                "detail": ""
                            })))
                },
                {
                    "id": "inputNumlock",
                    "kind": "switch",
                    "store": HyprSystem,
                    "key": "input.numlock_by_default",
                    "label": "Num Lock on at start",
                    "keywords": "keyboard numlock num lock numpad keypad"
                }
            ]
        })

    // rebuilt when the device list changes (rare: plugging in), otherwise static
    sections: [mouseSection].concat(HyprSystem.mice.length > 0 ? HyprSystem.mice.map(d => deviceSection(d)) : [noDevices]).concat([keyboardSection])
}
