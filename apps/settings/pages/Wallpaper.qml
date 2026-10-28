import QtQuick
import qs.config
import qs.core
import qs.services

// Wallpaper: picker, luxshell's own wallpaper layer, video pause, cross-fade, shuffle, folders.
// Keys: wallpaper* (wallpaper, wallpaperDirs, wallpaperLayer from before).
// Consumers: background/WallpaperLayer (layer, pause, fade), services/Wallpapers (shuffle).
SettingsPage {
    id: page

    pageId: "wallpaper"
    title: "Wallpaper"
    subtitle: "Where wallpapers come from and how they change."
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
                },
                {
                    "id": "wallpaperLayer",
                    "kind": "switch",
                    "key": "wallpaperLayer",
                    "label": "luxshell paints the wallpaper (off: Ambxst)",
                    "keywords": "layer background ambxst own draw render"
                },
                {
                    "id": "wallpaperPauseCovered",
                    "kind": "switch",
                    "key": "wallpaperPauseCovered",
                    "label": "Pause video wallpapers behind windows",
                    "keywords": "video pause covered fullscreen window battery gpu",
                    "enabled": () => Wallpapers.layerEnabled
                },
                {
                    "id": "wallpaperFade",
                    "kind": "slider",
                    "key": "wallpaperFade",
                    "label": "Cross-fade",
                    "keywords": "fade transition duration change blend",
                    "min": 0,
                    "max": 3000,
                    "step": 100,
                    "format": v => v === 0 ? "Off" : `${page.trim(v / 1000)} s`,
                    "enabled": () => Wallpapers.layerEnabled
                }
            ]
        },
        {
            "title": "Shuffle",
            "options": [
                {
                    "id": "wallpaperShuffle",
                    "kind": "switch",
                    "key": "wallpaperShuffle",
                    "label": "Change the wallpaper automatically",
                    "keywords": "shuffle random rotate slideshow cycle timer"
                },
                {
                    "id": "wallpaperShuffleMinutes",
                    "kind": "slider",
                    "key": "wallpaperShuffleMinutes",
                    "label": "Every",
                    "keywords": "shuffle interval minutes random",
                    "min": 5,
                    "max": 240,
                    "step": 5,
                    "format": v => v < 60 ? `${v} min` : v % 60 === 0 ? `${v / 60} h` : `${Math.floor(v / 60)} h ${v % 60} min`,
                    "enabled": () => Settings.wallpaperShuffle
                },
                {
                    "id": "wallpaperShuffleNow",
                    "kind": "button",
                    "label": "Random wallpaper",
                    "keywords": "shuffle random next now",
                    "value": () => "",
                    "action": "Next",
                    "run": () => Wallpapers.shuffleNow()
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
