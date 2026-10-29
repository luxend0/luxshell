import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Power & Idle: the idle stages of services/Idle (dim, lock, screen off, sleep), what
// pauses them, lock before sleep, and the power profile (power-profiles-daemon). Keys: idle*.
// The times are sliders over fixed steps (15 s .. 3 h); a value set by hand (IPC, file) that
// is no step shows as itself until the slider moves.
SettingsPage {
    id: page

    pageId: "idle"
    group: "system"
    title: "Power & Idle"
    subtitle: "What happens when you step away, and the power profile."
    icon: 0xF0904 // md-power-sleep

    // the profile can change outside luxshell (powerprofilesctl, the bar): read it while the page shows
    Timer {
        running: SettingsApp.open && SettingsApp.page === page.pageId
        repeat: true
        triggeredOnStart: true
        interval: 5000
        onTriggered: PowerProfile.refresh()
    }

    Component {
        id: status
        IdleStatus {}
    }
    Component {
        id: note
        Note {}
    }

    readonly property var steps: [15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 330, 360, 420, 480, 600, 720, 900, 1200, 1500, 1800, 2700, 3600, 5400, 7200, 10800]
    function stepOf(s: real): int {
        let best = 0;
        for (let i = 1; i < steps.length; i++)
            if (Math.abs(steps[i] - s) < Math.abs(steps[best] - s))
                best = i;
        return best;
    }
    function timeRow(id: string, key: string, onKey: string, label: string, words: string): var {
        return {
            "id": id,
            "kind": "slider",
            "key": key,
            "label": label,
            "keywords": `idle time timeout after minutes seconds ${words}`,
            "min": 0,
            "max": page.steps.length - 1,
            "step": 1,
            "enabled": () => Settings.idleEnabled && Settings[onKey],
            "value": () => page.stepOf(Settings[key]),
            "set": i => Settings.set(key, page.steps[Math.round(i)]),
            "defaultValue": () => page.stepOf(Settings.defaultOf(key)),
            "format": i => Idle.duration(Math.round(i) === page.stepOf(Settings[key]) ? Settings[key] : page.steps[Math.round(i)])
        };
    }
    function stageRow(id: string, key: string, label: string, words: string): var {
        return {
            "id": id,
            "kind": "switch",
            "key": key,
            "label": label,
            "keywords": `idle stage ${words}`,
            "enabled": () => Settings.idleEnabled
        };
    }

    readonly property var profileOptions: [
        {
            "value": "power-saver",
            "label": "Power Saver",
            "detail": "quieter, slower"
        },
        {
            "value": "balanced",
            "label": "Balanced",
            "detail": "default"
        },
        {
            "value": "performance",
            "label": "Performance",
            "detail": "fastest, louder"
        }
    ]

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "idleEnabled",
                    "kind": "switch",
                    "key": "idleEnabled",
                    "label": "Act when idle",
                    "keywords": "idle daemon dim lock screen off sleep suspend hypridle ambxst inactivity away"
                },
                {
                    "id": "idleStatus",
                    "kind": "custom",
                    "label": "",
                    "title": "Status",
                    "component": status,
                    "keywords": "idle status caffeine paused media playing"
                },
                {
                    "id": "idleMediaPause",
                    "kind": "switch",
                    "key": "idleMediaPause",
                    "label": "Pause while media plays",
                    "keywords": "idle media music video player mpris playing pause inhibit",
                    "enabled": () => Settings.idleEnabled
                },
                {
                    "id": "idleNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "caffeine inhibit fullscreen video",
                    "text": "Every stage counts from the last key press or mouse move. Caffeine (control center, bar) pauses them all, and so does a video that keeps the screen awake by itself. Turn idle off here while another idle daemon (hypridle, Ambxst) does the job."
                }
            ]
        },
        {
            "title": "Dim",
            "options": [stageRow("idleDim", "idleDim", "Dim the screen", "dim brightness darker"), timeRow("idleDimAfter", "idleDimAfter", "idleDim", "After", "dim brightness darker"),
                {
                    "id": "idleDimLevel",
                    "kind": "slider",
                    "key": "idleDimLevel",
                    "label": "Dimmed brightness",
                    "keywords": "idle dim brightness level percent darker",
                    "min": 0,
                    "max": 50,
                    "step": 5,
                    "enabled": () => Settings.idleEnabled && Settings.idleDim,
                    "format": v => `${Math.round(v)} %`
                }
            ]
        },
        {
            "title": "Lock",
            "options": [stageRow("idleLock", "idleLock", "Lock the screen", "lock screen password"), timeRow("idleLockAfter", "idleLockAfter", "idleLock", "After", "lock screen password")]
        },
        {
            "title": "Screen off",
            "options": [stageRow("idleScreenOff", "idleScreenOff", "Turn the screen off", "screen display monitor off dpms blank"), timeRow("idleScreenOffAfter", "idleScreenOffAfter", "idleScreenOff", "After", "screen display monitor off dpms blank")]
        },
        {
            "title": "Sleep",
            "options": [stageRow("idleSuspend", "idleSuspend", "Put the computer to sleep", "sleep suspend standby"), timeRow("idleSuspendAfter", "idleSuspendAfter", "idleSuspend", "After", "sleep suspend standby"),
                {
                    "id": "idleLockBeforeSleep",
                    "kind": "switch",
                    "key": "idleLockBeforeSleep",
                    "label": "Lock before sleep",
                    "keywords": "lock sleep suspend lid power menu systemctl resume wake",
                    "enabled": () => Settings.idleEnabled
                }
            ]
        },
        {
            "title": "Power",
            "options": [
                {
                    "id": "powerProfile",
                    "kind": "choice",
                    "label": "Power profile",
                    "keywords": "power profile mode performance balanced power saver energy powerprofilesctl",
                    "resettable": false,
                    "enabled": () => PowerProfile.available,
                    "value": () => PowerProfile.available ? PowerProfile.profile : "",
                    "set": v => PowerProfile.set(v),
                    "options": () => PowerProfile.available ? page.profileOptions.filter(o => PowerProfile.profiles.includes(o.value)) : [
                            {
                                "value": "",
                                "label": "Not available",
                                "detail": "power-profiles-daemon"
                            }
                        ]
                }
            ]
        }
    ]
}
