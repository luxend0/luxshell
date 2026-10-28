import QtQuick
import qs.config
import qs.core

// Overview & Pickers: the workspace overview (previews, grouping, card size) and the theme /
// wallpaper pickers. Keys: overview*, picker*, wallpaperVideos (+ wallpaperDirs, also on the
// Wallpaper page).
SettingsPage {
    id: page

    pageId: "overview"
    title: "Overview & Pickers"
    subtitle: "Window overview, theme and wallpaper picker."
    icon: 0xF11D9 // md-view-grid-outline

    sections: [
        {
            "title": "Overview",
            "options": [
                {
                    "id": "overviewPreview",
                    "kind": "choice",
                    "key": "overviewPreview",
                    "label": "Window previews",
                    "keywords": "live preview screencopy thumbnail capture expose",
                    "options": () => [
                        {
                            "value": "live",
                            "label": "Live",
                            "detail": "selected card streams"
                        },
                        {
                            "value": "still",
                            "label": "Still",
                            "detail": "frame from opening"
                        },
                        {
                            "value": "icons",
                            "label": "App icons",
                            "detail": "no capture"
                        }
                    ]
                },
                {
                    "id": "overviewGroup",
                    "kind": "switch",
                    "key": "overviewGroup",
                    "label": "Group windows by workspace",
                    "keywords": "workspace heading group grid expose"
                },
                {
                    "id": "overviewCardSize",
                    "kind": "slider",
                    "key": "overviewCardSize",
                    "label": "Card size",
                    "keywords": "card size scale preview thumbnail bigger smaller",
                    "min": 0.7,
                    "max": 1.4,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "overviewOpen",
                    "kind": "link",
                    "label": "Open the overview",
                    "keywords": "try show expose",
                    "value": () => "",
                    "run": () => Ui.open("overview")
                }
            ]
        },
        {
            "title": "Theme picker",
            "options": [
                {
                    "id": "pickerThemePreview",
                    "kind": "switch",
                    "key": "pickerThemePreview",
                    "label": "Live preview on the island while browsing",
                    "keywords": "theme picker preview live tint"
                }
            ]
        },
        {
            "title": "Wallpaper picker",
            "options": [
                {
                    "id": "wallpaperVideos",
                    "kind": "switch",
                    "key": "wallpaperVideos",
                    "label": "List video wallpapers (mp4, webm, mkv)",
                    "keywords": "video animated wallpaper picker mp4 webm"
                },
                {
                    "id": "pickerWallpaperDirs",
                    "kind": "paths",
                    "key": "wallpaperDirs",
                    "mode": "folder",
                    "label": "Wallpaper folders (searched 4 levels deep)",
                    "keywords": "wallpaper directories path pictures folder picker",
                    "addLabel": "Add folder"
                }
            ]
        }
    ]
}
