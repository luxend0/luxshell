import QtQuick
import qs.config
import qs.services
import qs.panels.controlcenter

// Control Center: which tiles and sliders, in which order (packed by
// panels/controlcenter/CcLayout with the video's metrics), options of single tiles and the
// switches themselves. Keys: cc* (+ dnd).
SettingsPage {
    id: page

    pageId: "controlcenter"
    title: "Control Center"
    subtitle: "Tiles, sliders and their order."
    icon: 0xF062E

    Component {
        id: preview
        CcPreview {}
    }

    function themeOptions(): var {
        return Themes.names.map(n => ({
                    "value": n,
                    "label": n.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" "),
                    "detail": ""
                }));
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "ccPreview",
                    "kind": "custom",
                    "label": "",
                    "keywords": "preview layout grid control center",
                    "component": preview
                },
                {
                    "id": "ccTiles",
                    "kind": "list",
                    "key": "ccTiles",
                    "label": "Tiles (two per row, round buttons join a row)",
                    "keywords": "order reorder wifi network focus lock bluetooth game mode night light caffeine microphone power screenshot theme dark",
                    "items": () => CcLayout.catalog.filter(c => c.available).map(c => ({
                                "value": c.id,
                                "label": c.label,
                                "icon": page.glyph(c.glyph)
                            }))
                },
                {
                    "id": "ccSliders",
                    "kind": "list",
                    "key": "ccSliders",
                    "label": "Sliders (below the tiles)",
                    "keywords": "order sound volume display brightness microphone input",
                    "items": () => CcLayout.sliderCatalog.map(s => ({
                                "value": s.id,
                                "label": s.label,
                                "icon": page.glyph(s.glyph)
                            }))
                }
            ]
        },
        {
            "title": "Tile options",
            "options": [
                {
                    "id": "ccNightTemp",
                    "kind": "slider",
                    "key": "ccNightTemp",
                    "label": "Night light temperature (wlsunset)",
                    "keywords": "night light warm kelvin wlsunset blue",
                    "enabled": () => NightLight.available,
                    "min": 2500,
                    "max": 6000,
                    "step": 100,
                    "format": v => `${Math.round(v)} K`
                },
                {
                    "id": "ccScreenshotMode",
                    "kind": "choice",
                    "key": "ccScreenshotMode",
                    "label": "Screenshot button takes",
                    "keywords": "screenshot grim slurp region screen capture",
                    "options": () => [
                        {
                            "value": "region",
                            "label": "A region",
                            "detail": "drag with slurp"
                        },
                        {
                            "value": "screen",
                            "label": "All screens",
                            "detail": ""
                        }
                    ]
                },
                {
                    "id": "ccScreenshotDir",
                    "kind": "path",
                    "key": "ccScreenshotDir",
                    "mode": "folder",
                    "label": "Screenshot folder",
                    "keywords": "screenshot save directory pictures",
                    "placeholder": "~/Pictures/Screenshots"
                },
                {
                    "id": "ccThemeA",
                    "kind": "choice",
                    "key": "ccThemeA",
                    "label": "Theme button: off",
                    "keywords": "theme switch dark light toggle round button",
                    "options": () => page.themeOptions()
                },
                {
                    "id": "ccThemeB",
                    "kind": "choice",
                    "key": "ccThemeB",
                    "label": "Theme button: on (right click opens the picker)",
                    "keywords": "theme switch dark light toggle round button",
                    "options": () => page.themeOptions()
                }
            ]
        },
        {
            "title": "Switches",
            "options": [
                {
                    "id": "ccFocus",
                    "kind": "switch",
                    "key": "dnd",
                    "label": "Focus (silences notifications)",
                    "keywords": "dnd do not disturb"
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
}
