import QtQuick
import qs.config
import qs.core
import qs.services
import qs.apps.settings

// Power: the power menu (panels/PowerMenu, services/Power). Which actions in which order,
// the info lines, which actions ask for a second click and how long, own commands.
// Keys: power*. File name PowerPage: "Power" is already the services/Power singleton.
SettingsPage {
    id: page

    pageId: "power"
    title: "Power"
    subtitle: "Power menu: actions, confirmation and commands."
    icon: 0xF0425

    Component {
        id: note
        Note {}
    }

    // Material Design glyphs of the Nerd Font for the list rows
    readonly property var icons: ({
            "lock": 0xF033E,
            "logout": 0xF0343,
            "suspend": 0xF0594,
            "reboot": 0xF0709,
            "poweroff": 0xF0425,
            "firmware": 0xF061A
        })

    function firmwareLabel(): string {
        if (Power.firmwareKnown && !Power.firmwareSupported && Power.command("firmware") === "")
            return "Firmware Setup (not offered by this machine)";
        return "Firmware Setup (BIOS / UEFI)";
    }

    function confirmRow(id: string): var {
        const a = Power.entry(id);
        return {
            "id": "powerConfirm." + id,
            "kind": "switch",
            "key": "powerConfirm." + id,
            "label": a.title,
            "keywords": `confirm second click ask twice ${a.keywords}`
        };
    }

    function commandRow(id: string): var {
        const a = Power.entry(id);
        return {
            "id": "powerCommands." + id,
            "kind": "text",
            "key": "powerCommands." + id,
            "label": a.title,
            "keywords": `command custom shell override ${a.keywords}`,
            "mono": true,
            "placeholder": `Default: ${a.def}`
        };
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "powerActions",
                    "kind": "list",
                    "key": "powerActions",
                    "label": "Actions, in menu order",
                    "keywords": "order show hide lock log out logout sleep suspend restart reboot shut down poweroff firmware bios uefi",
                    "items": () => Power.catalog.map(a => ({
                                "value": a.id,
                                "label": a.id === "firmware" ? page.firmwareLabel() : a.title,
                                "icon": page.glyph(page.icons[a.id])
                            }))
                },
                {
                    "id": "powerDetails",
                    "kind": "switch",
                    "key": "powerDetails",
                    "label": "Info line under each action (keybind, updates, uptime)",
                    "keywords": "details subtitle uptime kernel updates pending pacman keybind windows"
                },
                {
                    "id": "powerOpen",
                    "kind": "link",
                    "label": "Open the power menu",
                    "keywords": "try show powermenu",
                    "value": () => "",
                    "run": () => Ui.open("power")
                }
            ]
        },
        {
            "title": "Confirmation",
            "options": [
                {
                    "id": "powerConfirmNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": "Actions switched on below arm on the first click or Enter: the row turns red and drains back over the time set here. A second click or Enter in that time runs the action, anything else lets it fall back."
                },
                {
                    "id": "powerConfirmTime",
                    "kind": "slider",
                    "key": "powerConfirmTime",
                    "label": "Time for the second click",
                    "keywords": "confirm timeout seconds fall back countdown",
                    "min": 1.5,
                    "max": 8,
                    "step": 0.5,
                    "format": v => `${page.trim(v)} s`
                },
                page.confirmRow("lock"),
                page.confirmRow("logout"),
                page.confirmRow("suspend"),
                page.confirmRow("reboot"),
                page.confirmRow("poweroff"),
                page.confirmRow("firmware")
            ]
        },
        {
            "title": "Commands",
            "options": [
                {
                    "id": "powerCommandsNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": "Empty runs the default. An own command runs with sh -c instead, for example loginctl lock-session, hyprlock, systemctl hibernate or hyprshutdown."
                },
                page.commandRow("lock"),
                page.commandRow("logout"),
                page.commandRow("suspend"),
                page.commandRow("reboot"),
                page.commandRow("poweroff"),
                page.commandRow("firmware")
            ]
        }
    ]
}
