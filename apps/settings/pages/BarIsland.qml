import QtQuick
import qs.config
import qs.island.bar
import qs.apps.settings.island

// Bar & Island: the layout editor (drag and drop on a live preview), the island's size and
// distance from the edge, how it expands and what clicks and the wheel do.
// Keys: islandLayout + island* widget options (editor), island* (config/Settings.qml).
SettingsPage {
    pageId: "bar"
    title: "Bar & Island"
    subtitle: "Layout, size and what the island does."
    icon: 0xF1513

    Component {
        id: editor
        IslandEditor {}
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "islandLayout",
                    "kind": "custom",
                    "key": "islandLayout",
                    // the reset arrow restores the layout and every widget option
                    "keys": IslandEditing.keys,
                    "reset": () => {
                        IslandEditing.remember();
                        Settings.resetMany(IslandEditing.keys);
                    },
                    "label": "Layout",
                    "keywords": "island widgets drag drop arrange order slots collapsed hover clock date window title network signal volume tray media notifications bell settings gear power battery weather cpu memory ram keyboard layout spacer workspaces",
                    "summary": () => Settings.isDefault("islandLayout") ? "Default" : "Custom",
                    "component": editor
                }
            ]
        },
        {
            "title": "Island",
            "options": [
                {
                    "id": "islandScale",
                    "kind": "slider",
                    "key": "islandScale",
                    "label": "Island size",
                    "keywords": "scale zoom bigger smaller",
                    "min": 0.7,
                    "max": 1.5,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "islandMargin",
                    "kind": "slider",
                    "key": "islandMargin",
                    "label": "Distance from the top edge",
                    "keywords": "margin gap flush floating pill offset",
                    "min": 0,
                    "max": 24,
                    "step": 1,
                    "format": v => v === 0 ? "Flush" : `${v} px`
                },
                {
                    "id": "workspaces",
                    "kind": "slider",
                    "key": "workspaceCount",
                    "label": "Workspaces",
                    "keywords": "capsules count island bar",
                    "min": 2,
                    "max": 6,
                    "step": 1,
                    "format": v => `${v}`
                }
            ]
        },
        {
            "title": "Behaviour",
            "options": [
                {
                    "id": "islandHoverExpand",
                    "kind": "switch",
                    "key": "islandHoverExpand",
                    "label": "Expand on hover (off: click to expand)",
                    "keywords": "hover open click expand"
                },
                {
                    "id": "islandHoverDelay",
                    "kind": "slider",
                    "key": "islandHoverDelay",
                    "label": "Hover delay (before the island expands)",
                    "keywords": "hover open delay wait",
                    "enabled": () => Settings.islandHoverExpand,
                    "min": 0,
                    "max": 800,
                    "step": 20,
                    "format": v => v === 0 ? "None" : `${v} ms`
                },
                {
                    "id": "hoverHold",
                    "kind": "slider",
                    "key": "hoverHold",
                    "label": "Collapse delay (after the pointer leaves the island)",
                    "keywords": "hover hold close",
                    "min": 0,
                    "max": 600,
                    "step": 20,
                    "format": v => `${v} ms`
                },
                {
                    "id": "islandClickAction",
                    "kind": "choice",
                    "key": "islandClickAction",
                    "label": "Click",
                    "keywords": "click action open control center notifications launcher",
                    "options": () => [
                        {
                            "value": "controlcenter",
                            "label": "Control Center"
                        },
                        {
                            "value": "notifications",
                            "label": "Notifications"
                        },
                        {
                            "value": "launcher",
                            "label": "Launcher"
                        },
                        {
                            "value": "none",
                            "label": "Nothing"
                        }
                    ]
                },
                {
                    "id": "islandMiddleClick",
                    "kind": "choice",
                    "key": "islandMiddleClick",
                    "label": "Middle click",
                    "keywords": "middle click action mute play pause overview",
                    "options": () => [
                        {
                            "value": "none",
                            "label": "Nothing"
                        },
                        {
                            "value": "controlcenter",
                            "label": "Control Center"
                        },
                        {
                            "value": "notifications",
                            "label": "Notifications"
                        },
                        {
                            "value": "launcher",
                            "label": "Launcher"
                        },
                        {
                            "value": "overview",
                            "label": "Overview"
                        },
                        {
                            "value": "playpause",
                            "label": "Play / pause"
                        },
                        {
                            "value": "mute",
                            "label": "Mute"
                        }
                    ]
                },
                {
                    "id": "islandScrollAction",
                    "kind": "choice",
                    "key": "islandScrollAction",
                    "label": "Scroll",
                    "keywords": "wheel scroll volume workspaces",
                    "options": () => [
                        {
                            "value": "volume",
                            "label": "Volume"
                        },
                        {
                            "value": "workspaces",
                            "label": "Workspaces"
                        },
                        {
                            "value": "none",
                            "label": "Nothing (volume glyph only)"
                        }
                    ]
                }
            ]
        }
    ]
}
