import QtQuick
import qs.config
import qs.services

// Notifications: focus, popup durations, history. Keys: notif* (dnd, notifTimeout* exist).
SettingsPage {
    id: page

    pageId: "notifications"
    title: "Notifications"
    subtitle: "Popups in the island and the history."
    icon: 0xF009A
    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "dnd",
                    "kind": "switch",
                    "key": "dnd",
                    "label": "Do not disturb (only critical ones pop up)",
                    "keywords": "focus silence quiet dnd"
                }
            ]
        },
        {
            "title": "Popup duration",
            "options": [
                {
                    "id": "notifTimeout",
                    "kind": "slider",
                    "key": "notifTimeout",
                    "label": "Normal",
                    "keywords": "timeout notification popup peek seconds",
                    "min": 2,
                    "max": 20,
                    "step": 0.5,
                    "format": v => `${page.trim(v)} s`
                },
                {
                    "id": "notifTimeoutLow",
                    "kind": "slider",
                    "key": "notifTimeoutLow",
                    "label": "Low priority",
                    "keywords": "timeout notification transient seconds",
                    "min": 1,
                    "max": 20,
                    "step": 0.5,
                    "format": v => `${page.trim(v)} s`
                },
                {
                    "id": "notifTimeoutCritical",
                    "kind": "slider",
                    "key": "notifTimeoutCritical",
                    "label": "Critical",
                    "keywords": "timeout notification urgent seconds",
                    "min": 3,
                    "max": 60,
                    "step": 1,
                    "format": v => `${page.trim(v)} s`
                }
            ]
        },
        {
            "title": "History",
            "options": [
                {
                    "id": "notifClear",
                    "kind": "button",
                    "label": "Notifications",
                    "keywords": "clear history dismiss",
                    "value": () => Notifs.count === 0 ? "None" : `${Notifs.count}`,
                    "action": "Clear all",
                    "enabled": () => Notifs.count > 0,
                    "run": () => Notifs.clear()
                }
            ]
        }
    ]
}
