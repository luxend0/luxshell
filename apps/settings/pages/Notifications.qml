import QtQuick
import qs.config
import qs.services

// Notifications: focus (manual + schedule), peeks, sound, per-app rules, history.
// Keys: notif* (dnd, notifTimeout* from before the prefixes). Consumers: services/Notifs
// (peek, sound, rules, limit), services/Focus (schedule).
SettingsPage {
    id: page

    pageId: "notifications"
    title: "Notifications"
    subtitle: "Popups in the island, Focus and the history."
    icon: 0xF009A

    Component {
        id: rulesEditor
        NotifRules {}
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "dnd",
                    "kind": "switch",
                    "key": "dnd",
                    "label": "Focus (only critical ones pop up)",
                    "keywords": "do not disturb silence quiet dnd"
                },
                {
                    "id": "notifPeek",
                    "kind": "switch",
                    "key": "notifPeek",
                    "label": "Show new notifications in the island",
                    "keywords": "peek popup banner live activity"
                }
            ]
        },
        {
            "title": "Focus schedule",
            "options": [
                {
                    "id": "notifFocusSchedule",
                    "kind": "switch",
                    "key": "notifFocusSchedule",
                    "label": "Turn Focus on automatically",
                    "keywords": "schedule dnd do not disturb night automatic timer"
                },
                {
                    "id": "notifFocusDays",
                    "kind": "weekdays",
                    "key": "notifFocusDays",
                    "label": "Starts on",
                    "keywords": "schedule focus days week",
                    "enabled": () => Settings.notifFocusSchedule
                },
                {
                    "id": "notifFocusTime",
                    "kind": "timerange",
                    "key": "notifFocusTime",
                    "label": "From – to",
                    "keywords": "schedule focus time hours night",
                    "step": 15,
                    "enabled": () => Settings.notifFocusSchedule
                },
                {
                    "id": "notifFocusState",
                    "kind": "info",
                    "label": "Schedule",
                    "keywords": "schedule focus next status",
                    "value": () => Focus.describe()
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
                    "format": v => `${page.trim(v)} s`,
                    "enabled": () => Settings.notifPeek
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
                    "format": v => `${page.trim(v)} s`,
                    "enabled": () => Settings.notifPeek
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
            "title": "Sound",
            "options": [
                {
                    "id": "notifSound",
                    "kind": "switch",
                    "key": "notifSound",
                    "label": "Play a sound (not during Focus)",
                    "keywords": "sound audio chime ding pw-play"
                },
                {
                    "id": "notifSoundFile",
                    "kind": "path",
                    "key": "notifSoundFile",
                    "mode": "file",
                    "label": "Sound file",
                    "keywords": "sound audio file oga wav",
                    "placeholder": "message.oga (system)",
                    "enabled": () => Settings.notifSound
                },
                {
                    "id": "notifSoundTest",
                    "kind": "button",
                    "label": "Try the sound",
                    "keywords": "sound test play",
                    "value": () => Notifs.soundFile.split("/").pop(),
                    "action": "Play",
                    "run": () => Notifs.playSound()
                }
            ]
        },
        {
            "title": "Apps",
            "options": [
                {
                    "id": "notifRules",
                    "kind": "custom",
                    "key": "notifRules",
                    "label": "Rules per app",
                    "keywords": "app exceptions mute silence block always focus history keep rules",
                    "component": rulesEditor
                }
            ]
        },
        {
            "title": "History",
            "options": [
                {
                    "id": "notifHistoryLimit",
                    "kind": "slider",
                    "key": "notifHistoryLimit",
                    "label": "Keep at most",
                    "keywords": "history limit maximum count oldest",
                    "min": 0,
                    "max": 200,
                    "step": 10,
                    "format": v => v === 0 ? "Unlimited" : `${v} notifications`
                },
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
        },
        {
            "title": "Notification center",
            "options": [
                {
                    "id": "notifCenterGroup",
                    "kind": "switch",
                    "key": "notifCenterGroup",
                    "label": "Group per app (off: newest first)",
                    "keywords": "group stack fold app notification center history list"
                },
                {
                    "id": "notifCenterMaxHeight",
                    "kind": "slider",
                    "key": "notifCenterMaxHeight",
                    "label": "Maximum height (then it scrolls)",
                    "keywords": "notification center height size scroll tall",
                    "min": 400,
                    "max": 1100,
                    "step": 20,
                    "format": v => `${Math.round(v)} px`
                }
            ]
        }
    ]
}
