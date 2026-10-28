import QtQuick
import qs.config
import qs.core

// Wallpaper: picker and the folders it searches. Keys: wallpaper* (wallpaper, wallpaperDirs exist).
SettingsPage {
    pageId: "wallpaper"
    title: "Wallpaper"
    subtitle: "Where wallpapers come from."
    icon: 0xF0E09
    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "wallpaperPick",
                    "kind": "link",
                    "label": "Wallpaper",
                    "keywords": "background image video choose",
                    "value": () => Settings.wallpaper === "" ? "Choose..." : Settings.wallpaper.split("/").pop(),
                    "run": () => Ui.open("wallpaper")
                }
            ]
        },
        {
            "title": "Folders",
            "options": [
                {
                    "id": "wallpaperDirs",
                    "kind": "paths",
                    "key": "wallpaperDirs",
                    "mode": "folder",
                    "label": "Wallpaper folders (searched 4 levels deep)",
                    "keywords": "wallpaper directories path pictures folder",
                    "addLabel": "Add folder"
                }
            ]
        }
    ]
}
