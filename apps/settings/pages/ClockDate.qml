import QtQuick
import qs.config
import qs.services

// Clock & Date (sidebar entry of the video): time and date format of the island.
SettingsPage {
    id: page

    readonly property var dateFormats: ["ddd, MMM d", "ddd d MMM", "ddd d.M.", "d.M.yyyy", "yyyy-MM-dd"]
    readonly property var timeFormats: [
        {
            "value": "24h",
            "label": "24-hour"
        },
        {
            "value": "12h",
            "label": "12-hour"
        },
        {
            "value": "12h-ampm",
            "label": "12-hour, AM/PM"
        }
    ]

    pageId: "clock"
    title: "Clock & Date"
    subtitle: "Time and date format of the island."
    icon: 0xF1442
    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "clockFormat",
                    "kind": "choice",
                    "key": "clockFormat",
                    "label": "Time format",
                    "keywords": "12 24 hour am pm clock",
                    "options": () => page.timeFormats.map(f => ({
                                "value": f.value,
                                "label": f.label,
                                "detail": Clock.formatTime(Clock.now, f.value)
                            }))
                },
                {
                    "id": "dateFormat",
                    "kind": "choice",
                    "key": "dateFormat",
                    "label": "Date format",
                    "keywords": "day month weekday",
                    "options": () => page.dateFormats.map(f => ({
                                "value": f,
                                "label": Clock.now.toLocaleDateString(Clock.locale, f),
                                "detail": ""
                            }))
                }
            ]
        },
        {
            "title": "Preview",
            "options": [
                {
                    "id": "clockPreview",
                    "kind": "info",
                    "label": "Island",
                    "keywords": "clock date example",
                    "value": () => `${Clock.time}   ${Clock.date}`
                }
            ]
        }
    ]
}
