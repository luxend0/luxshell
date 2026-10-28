import QtQuick
import qs.config
import qs.core

// Motion: animation speed, motion style, preview. Keys: motion* (animationSpeed from before the
// prefixes, motionStyle -> config/Motion.qml; the interface scale moved to Appearance).
SettingsPage {
    id: page

    pageId: "motion"
    title: "Motion"
    subtitle: "How the island and panels move."
    icon: 0xF0DAF

    // island hover open + close once, or a panel open + close (uses the current style)
    property string previewing: ""
    function playPreview(what: string): void {
        previewing = what;
        Ui.preview(what);
        previewTimer.interval = Motion.ms(Motion.style === "spring" ? 1500 : 1300);
        previewTimer.restart();
    }
    Timer {
        id: previewTimer
        onTriggered: {
            page.previewing = "";
            Ui.preview("");
        }
    }

    readonly property var styleOptions: [
        {
            "value": "video",
            "label": "Video",
            "detail": "fitted to the original"
        },
        {
            "value": "spring",
            "label": "Spring",
            "detail": "slight overshoot"
        },
        {
            "value": "fast",
            "label": "Fast",
            "detail": "same curves, quicker"
        },
        {
            "value": "reduced",
            "label": "Reduced",
            "detail": "cross-fades only"
        }
    ]

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "animationSpeed",
                    "kind": "slider",
                    "key": "animationSpeed",
                    "label": "Animation speed",
                    "keywords": "animations duration fast slow tempo",
                    "min": 0.5,
                    "max": 3,
                    "step": 0.25,
                    "format": v => `${page.trim(v)}×`
                },
                {
                    "id": "motionStyle",
                    "kind": "choice",
                    "key": "motionStyle",
                    "label": "Motion style",
                    "keywords": "animation curve spring bounce overshoot fast reduce motion accessibility fade video",
                    "options": () => page.styleOptions
                }
            ]
        },
        {
            "title": "Preview",
            "options": [
                {
                    "id": "motionPreview",
                    "kind": "button",
                    "label": "Island hover",
                    "keywords": "try test animation hover preview",
                    "value": () => page.previewing === "hover" ? "Playing" : "",
                    "action": "Play",
                    "run": () => page.playPreview("hover")
                },
                {
                    "id": "motionPreviewPanel",
                    "kind": "button",
                    "label": "Panel open and close",
                    "keywords": "try test animation panel control center preview",
                    "value": () => page.previewing === "controlcenter" ? "Playing" : "",
                    "action": "Play",
                    "run": () => page.playPreview("controlcenter")
                }
            ]
        }
    ]
}
