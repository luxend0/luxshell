pragma Singleton
import QtQuick
import Quickshell

// Theme data only. A theme is a flat palette; Theme.qml maps it to semantic roles.
// The island itself stays black in every theme (video), themes tint accent,
// text and the swatches the theme picker shows. Red (#e5484d) is not themable,
// it belongs to the power button only (Theme.danger).
//
// Keys every palette must define:
//   island surface surfaceHigh text textSecondary textDim muted
//   accent onAccent wsOccupied wsEmpty swatches[6]
Singleton {
    id: root

    readonly property var palettes: ({
            "noir": {
                "island": "#000000",
                "surface": "#0b0b0b",
                "surfaceHigh": "#232323",
                "text": "#ececec",
                "textSecondary": "#a8a8a8",
                "textDim": "#8a8a8a",
                "muted": "#4a4a4a",
                "accent": "#e8e8e8",
                "onAccent": "#0a0a0a",
                "wsOccupied": "#636363",
                "wsEmpty": "#282828",
                "swatches": ["#d9d9d9", "#bdbdbd", "#a3a3a3", "#8c8c8c", "#737373", "#ececec"]
            },
            "nord": {
                "island": "#000000",
                "surface": "#0d1016",
                "surfaceHigh": "#1d222c",
                "text": "#eceff4",
                "textSecondary": "#aeb6c6",
                "textDim": "#8790a2",
                "muted": "#434c5e",
                "accent": "#88c0d0",
                "onAccent": "#0d1016",
                "wsOccupied": "#5d6880",
                "wsEmpty": "#262c38",
                "swatches": ["#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0"]
            },
            "kanagawa": {
                "island": "#000000",
                "surface": "#0f0f14",
                "surfaceHigh": "#1f1f28",
                "text": "#dcd7ba",
                "textSecondary": "#b5b09a",
                "textDim": "#8a8678",
                "muted": "#4a4a5a",
                "accent": "#7e9cd8",
                "onAccent": "#0f0f14",
                "wsOccupied": "#5c5c74",
                "wsEmpty": "#26262f",
                "swatches": ["#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589"]
            }
        })

    readonly property var names: Object.keys(palettes)

    function resolve(name: string): string {
        return palettes.hasOwnProperty(name) ? name : "noir";
    }
}
