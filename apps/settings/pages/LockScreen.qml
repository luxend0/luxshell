import QtQuick
import Quickshell.Io
import qs.config

// Lock Screen (lock/*, services/Lock). Keys: lock* (lockAvatar, lockPam from before).
// Idle times (lock after N minutes, screen off) belong to the idle daemon (Ambxst / hypridle).
SettingsPage {
    id: page

    pageId: "lockscreen"
    title: "Lock Screen"
    subtitle: "What the lock screen shows and how it unlocks."
    icon: 0xF033E

    Component {
        id: noteRow
        NoteRow {}
    }

    // PAM services that make sense for a screen locker, as far as they exist here
    readonly property var pamCandidates: ["login", "system-local-login", "system-login", "hyprlock", "swaylock", "kde"]
    property var pamFound: ["login"]
    Process {
        running: true
        command: ["sh", "-c", 'for f in "$@"; do [ -f "/etc/pam.d/$f" ] && echo "$f"; done', "luxshell-pam", ...page.pamCandidates]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l !== "");
                if (list.length > 0)
                    page.pamFound = list;
            }
        }
    }
    function pamOptions(): var {
        const out = page.pamFound.map(s => ({
                    "value": s,
                    "label": s,
                    "detail": s === "login" ? "with faillock" : ""
                }));
        const cur = Settings.lockPam;
        if (cur !== "" && !page.pamFound.includes(cur))
            out.push({
                "value": cur,
                "label": cur,
                "detail": "not found"
            });
        out.push({
            "value": "",
            "label": "luxshell-lock",
            "detail": "no faillock"
        });
        return out;
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "lockAvatar",
                    "kind": "switch",
                    "key": "lockAvatar",
                    "label": "User picture (~/.face) instead of the glyph",
                    "keywords": "avatar face photo user picture"
                },
                {
                    "id": "lockClockFormat",
                    "kind": "choice",
                    "key": "lockClockFormat",
                    "label": "Clock",
                    "keywords": "time format 24h 12h am pm",
                    "options": () => [
                        {
                            "value": "",
                            "label": "Like the island",
                            "detail": Settings.clockFormat
                        },
                        {
                            "value": "24h",
                            "label": "24-hour",
                            "detail": "21:06"
                        },
                        {
                            "value": "12h",
                            "label": "12-hour",
                            "detail": "9:06"
                        },
                        {
                            "value": "12h-ampm",
                            "label": "12-hour with AM/PM",
                            "detail": "9:06 PM"
                        }
                    ]
                },
                {
                    "id": "lockDate",
                    "kind": "switch",
                    "key": "lockDate",
                    "label": "Date above the clock",
                    "keywords": "date day weekday"
                },
                {
                    "id": "lockHint",
                    "kind": "text",
                    "key": "lockHint",
                    "label": "Hint",
                    "keywords": "text message press any key password hint",
                    "placeholder": "No hint"
                }
            ]
        },
        {
            "title": "Background",
            "options": [
                {
                    "id": "lockBlur",
                    "kind": "slider",
                    "key": "lockBlur",
                    "label": "Blur",
                    "keywords": "blur background wallpaper strength",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "format": v => v === 0 ? "Off" : `${Math.round(v * 100)} %`
                },
                {
                    "id": "lockDim",
                    "kind": "slider",
                    "key": "lockDim",
                    "label": "Darken",
                    "keywords": "dim dark darken background brightness",
                    "min": 0,
                    "max": 0.9,
                    "step": 0.05,
                    "format": v => v === 0 ? "Off" : `${Math.round(v * 100)} %`
                }
            ]
        },
        {
            "title": "Unlocking",
            "options": [
                {
                    "id": "lockPam",
                    "kind": "choice",
                    "key": "lockPam",
                    "label": "PAM service",
                    "keywords": "pam authentication password faillock security",
                    "options": () => page.pamOptions()
                },
                {
                    "id": "lockPamNote",
                    "kind": "custom",
                    "label": "",
                    "title": "Wrong passwords",
                    "keywords": "faillock lockout attempts security brute force wrong passwords",
                    "component": noteRow,
                    "warn": () => Settings.lockPam === "",
                    "note": () => Settings.lockPam === "" ? "Unlimited guesses: no faillock" : Settings.lockPam === "login" ? "Lockout after 3 misses (faillock)" : `As /etc/pam.d/${Settings.lockPam} says`
                },
                {
                    "id": "lockIdle",
                    "kind": "info",
                    "label": "Lock and screen off when idle",
                    "keywords": "idle timeout minutes hypridle ambxst screen off dpms suspend",
                    "value": () => "Set in Ambxst"
                }
            ]
        }
    ]
}
