import QtQuick
import qs.config

// Bar & Island: workspaces, collapse delay. Keys: island* (config/Settings.qml).
SettingsPage {
    pageId: "bar"
    title: "Bar & Island"
    subtitle: "Workspaces and how the island collapses."
    icon: 0xF1513
    sections: [
        {
            "title": "",
            "options": [
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
                }
            ]
        }
    ]
}
