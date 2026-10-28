import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// Keybinds: Hyprland binds for luxshell's actions. Outside luxshell, so opt-in (keysEnabled
// default off). Keys: keys* (keysEnabled, keysBinds.<action>). services/Keybinds writes
// luxshell-keys.lua, loads it live and finds conflicts (hyprctl binds -j).
SettingsPage {
    id: page

    pageId: "keybinds"
    title: "Keybinds"
    subtitle: "Click a shortcut, then press the keys. Esc cancels, Backspace clears."
    icon: 0xF030C

    Component {
        id: keyRow
        KeyRow {}
    }

    // Hyprland's binds change outside luxshell: re-read them while this page is on screen
    Timer {
        running: SettingsApp.open && SettingsApp.page === page.pageId
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: Keybinds.refresh()
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "keysEnabled",
                    "kind": "switch",
                    "key": "keysEnabled",
                    "label": "Bind these keys in Hyprland",
                    "keywords": "keybinds shortcuts hyprland integration enable lua"
                },
                {
                    "id": "keysFile",
                    "kind": "info",
                    "label": "File",
                    "keywords": "keybinds lua file path dofile",
                    "value": () => Catalog.tilde(Keybinds.file)
                },
                {
                    "id": "keysStatus",
                    "kind": "info",
                    "label": "Status",
                    "keywords": "keybinds loaded status",
                    "value": () => Settings.keysEnabled ? (Keybinds.status || "Loading...") : Keybinds.status === "" ? "Off" : Keybinds.status
                },
                {
                    "id": "keysReload",
                    "kind": "button",
                    "label": "Restore replaced Hyprland binds",
                    "keywords": "hyprland reload config restore original binds",
                    "value": () => "",
                    "action": "Reload Hyprland",
                    "confirm": "Reloads the whole Hyprland config",
                    "run": () => Keybinds.reloadHyprland()
                }
            ]
        },
        {
            "title": "Shortcuts",
            "options": Keybinds.actions.map(a => ({
                        "id": "keys-" + a.id,
                        "kind": "custom",
                        "label": "",
                        "key": "keysBinds." + a.id,
                        "action": a,
                        "keywords": `${a.label} keybind shortcut hotkey keys ${a.id}`,
                        "component": keyRow
                    }))
        }
    ]
}
