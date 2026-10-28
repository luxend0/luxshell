import QtQuick
import qs.config
import qs.services

// Control Center: its switches. Keys: cc* (tiles, order).
SettingsPage {
    pageId: "controlcenter"
    title: "Control Center"
    subtitle: "The control center's switches."
    icon: 0xF062E
    sections: [
        {
            "title": "",
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
