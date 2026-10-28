import QtQuick
import qs.config
import qs.core

// Motion: interface scale, animation speed, preview. Keys: motion* (animationSpeed, uiScale exist).
SettingsPage {
    id: page

    pageId: "motion"
    title: "Motion"
    subtitle: "How fast the island and panels animate."
    icon: 0xF0DAF

    // island hover open + close once
    function playPreview(): void {
        Ui.preview("hover");
        previewTimer.restart();
    }
    Timer {
        id: previewTimer
        interval: Motion.ms(1300)
        onTriggered: Ui.preview("")
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "uiScale",
                    "kind": "slider",
                    "key": "uiScale",
                    "label": "Interface scale (restart)",
                    "keywords": "size scale zoom bigger smaller dpi interface",
                    "min": 0.6,
                    "max": 1.2,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "animationSpeed",
                    "kind": "slider",
                    "key": "animationSpeed",
                    "label": "Animation speed",
                    "keywords": "animations duration fast slow reduce motion",
                    "min": 0.5,
                    "max": 3,
                    "step": 0.25,
                    "format": v => `${page.trim(v)}×`
                },
                {
                    "id": "motionPreview",
                    "kind": "button",
                    "label": "Preview on the island",
                    "keywords": "try test animation hover",
                    "value": () => "",
                    "action": "Play",
                    "run": () => page.playPreview()
                }
            ]
        }
    ]
}
