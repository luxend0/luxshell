import QtQuick
import qs.config
import qs.apps.settings

// "Option types": one row of every kind added after the video, as a living reference
// for page authors. Hidden unless LUXSHELL_SETTINGS_DEMO=1. The rows write into a
// local store with the Settings API (`store: page`), so nothing reaches settings.json.
SettingsPage {
    id: page

    pageId: "demo"
    title: "Option types"
    subtitle: "Every option kind a page can use (LUXSHELL_SETTINGS_DEMO=1)."
    icon: 0xF0EB4
    hidden: !Env.settingsDemo

    // ---- local store (same API as config/Settings for plain keys) ----------------------
    readonly property var defaults: ({
            "highlight": "",
            "tint": "#3b82f6",
            "font": "Inter",
            "mono": "JetBrains Mono",
            "tiles": ["wifi", "bluetooth", "focus", "night"],
            "quietAt": "22:00",
            "focus": {
                "from": "22:00",
                "to": "07:00"
            },
            "days": [1, 2, 3, 4, 5],
            "dirs": ["~/Pictures/Wallpapers"],
            "notes": "~/notes.md",
            "zones": ["clock", "media", "status"]
        })
    property var store: JSON.parse(JSON.stringify(defaults))

    function get(k: string): var {
        return store[k];
    }
    function set(k: string, v: var): bool {
        const s = Object.assign({}, store);
        s[k] = JSON.parse(JSON.stringify(v));
        store = s;
        return true;
    }
    function defaultOf(k: string): var {
        return JSON.parse(JSON.stringify(defaults[k]));
    }
    function isDefault(k: string): bool {
        return JSON.stringify(store[k]) === JSON.stringify(defaults[k]);
    }
    function reset(k: string): void {
        set(k, defaultOf(k));
    }

    readonly property var tiles: [
        {
            "value": "wifi",
            "label": "Wi-Fi",
            "icon": glyph(0xF05A9)
        },
        {
            "value": "bluetooth",
            "label": "Bluetooth",
            "icon": glyph(0xF00AF)
        },
        {
            "value": "focus",
            "label": "Focus",
            "icon": glyph(0xF0594)
        },
        {
            "value": "night",
            "label": "Night light",
            "icon": glyph(0xF0335)
        },
        {
            "value": "game",
            "label": "Game mode",
            "icon": glyph(0xF0297)
        },
        {
            "value": "mic",
            "label": "Microphone",
            "icon": glyph(0xF036C)
        }
    ]

    // "Keep these settings?" (SettingsApp.askKeep): changes the tint above, then asks
    property string keepAnswer: "Not tried yet"
    readonly property var keepTints: ["#3b82f6", "#e5484d", "#30a46c", "#f5a524", "#8e8e93"]
    function tryKeep(): void {
        const old = store.tint;
        const next = keepTints[(keepTints.indexOf(old) + 1) % keepTints.length];
        set("tint", next);
        keepAnswer = "Waiting...";
        SettingsApp.askKeep({
            "title": "Keep this tint?",
            "text": `The Tint row above is now ${next}. Without an answer it goes back to ${old}.`,
            "keep": () => page.keepAnswer = `Kept ${next}`,
            "revert": () => {
                page.set("tint", old);
                page.keepAnswer = `Reverted to ${old}`;
            }
        });
    }

    // "custom" rows embed any QML: here a tiny zone editor (drag the chips)
    Component {
        id: zoneEditor
        DemoZones {}
    }

    sections: [
        {
            "title": "Colour",
            "options": [
                {
                    "id": "demoHighlight",
                    "kind": "color",
                    "store": page,
                    "key": "highlight",
                    "label": "Highlight (empty = theme accent)",
                    "keywords": "demo colour color picker",
                    "allowEmpty": true,
                    "emptyLabel": "Theme",
                    "fallback": () => Theme.accent
                },
                {
                    "id": "demoTint",
                    "kind": "color",
                    "store": page,
                    "key": "tint",
                    "label": "Tint",
                    "keywords": "demo colour color hex swatches"
                }
            ]
        },
        {
            "title": "Font",
            "options": [
                {
                    "id": "demoFont",
                    "kind": "font",
                    "store": page,
                    "key": "font",
                    "label": "Interface font (every installed family)",
                    "keywords": "demo typeface family"
                },
                {
                    "id": "demoMono",
                    "kind": "font",
                    "store": page,
                    "key": "mono",
                    "mono": true,
                    "label": "Monospace font",
                    "keywords": "demo typeface mono terminal"
                }
            ]
        },
        {
            "title": "Ordered list",
            "options": [
                {
                    "id": "demoTiles",
                    "kind": "list",
                    "store": page,
                    "key": "tiles",
                    "label": "Tiles",
                    "keywords": "demo order reorder enable control center",
                    "items": () => page.tiles
                }
            ]
        },
        {
            "title": "Time",
            "options": [
                {
                    "id": "demoQuiet",
                    "kind": "time",
                    "store": page,
                    "key": "quietAt",
                    "label": "Quiet from",
                    "keywords": "demo clock hour",
                    "step": 15
                },
                {
                    "id": "demoFocus",
                    "kind": "timerange",
                    "store": page,
                    "key": "focus",
                    "label": "Focus schedule",
                    "keywords": "demo range from to"
                },
                {
                    "id": "demoDays",
                    "kind": "weekdays",
                    "store": page,
                    "key": "days",
                    "label": "On these days",
                    "keywords": "demo week monday"
                }
            ]
        },
        {
            "title": "Files",
            "options": [
                {
                    "id": "demoDirs",
                    "kind": "paths",
                    "store": page,
                    "key": "dirs",
                    "mode": "folder",
                    "label": "Folders",
                    "keywords": "demo directories",
                    "addLabel": "Add folder"
                },
                {
                    "id": "demoNotes",
                    "kind": "path",
                    "store": page,
                    "key": "notes",
                    "mode": "file",
                    "label": "Notes file",
                    "keywords": "demo file path",
                    "placeholder": "~/notes.md"
                }
            ]
        },
        {
            "title": "Keep dialog",
            "options": [
                {
                    "id": "demoKeep",
                    "kind": "button",
                    "label": "Change the tint, then keep or revert",
                    "keywords": "demo keep revert countdown confirm dialog monitor rollback",
                    "value": () => "",
                    "action": "Try",
                    "run": () => page.tryKeep()
                },
                {
                    "id": "demoKeepAnswer",
                    "kind": "info",
                    "label": "Last answer",
                    "keywords": "demo keep revert result",
                    "value": () => page.keepAnswer
                }
            ]
        },
        {
            "title": "Custom",
            "options": [
                {
                    "id": "demoZones",
                    "kind": "custom",
                    "store": page,
                    "key": "zones",
                    "label": "Island zones (drag to reorder)",
                    "keywords": "demo custom editor drag drop",
                    "component": zoneEditor
                }
            ]
        }
    ]
}
