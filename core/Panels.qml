pragma Singleton
import QtQuick
import Quickshell
import qs.panels
import qs.services

// Panel registry: id -> component + kind. The island knows nothing else about
// panels; each panel reports its own size/radius at runtime (panels/PanelBase.qml).
// The registry also knows the largest size any panel can ask for (maxWidth/maxHeight):
// every component is probed once at start (PanelBase.maxWidth/maxHeight), live panels
// raise it further via report(). The island's layer surface is sized from it, so a
// taller panel added later is never clipped.
//
//   kind "panel"    modal: focus grab + exclusive keyboard, Esc / click outside closes
//   kind "overlay"  transient (OSD): no focus, auto-hides, outranks hover but not panels
//
// Adding a panel = new file in panels/ (root: PanelBase) + an entry and a Component here.
// Components are compiled with the shell (typos fail at start) and instantiated
// only while the panel is shown.
Singleton {
    id: root

    readonly property var entries: ({
            "controlcenter": {
                "component": controlCenter,
                "kind": "panel"
            },
            "bluetooth": {
                "component": controlCenterBluetooth,
                "kind": "panel"
            },
            "launcher": {
                "component": launcher,
                "kind": "panel"
            },
            // live activities (services/Activities.qml): one component, the id picks the
            // data ("activity" = Activities.current, "osd" / "brightness" = live presets,
            // also flashable over IPC); "notif" = notification peek/card (services/Notifs.qml)
            "osd": {
                "component": activity,
                "kind": "overlay"
            },
            "brightness": {
                "component": activity,
                "kind": "overlay"
            },
            "activity": {
                "component": activity,
                "kind": "overlay"
            },
            "notif": {
                "component": notif,
                "kind": "overlay"
            },
            "themes": {
                "component": themePicker,
                "kind": "panel"
            },
            "wallpaper": {
                "component": wallpaperPicker,
                "kind": "panel"
            },
            // now playing (services/Media), opened from the media chip of the hover island
            "media": {
                "component": mediaPanel,
                "kind": "panel"
            }
        })

    readonly property var ids: Object.keys(entries)

    function has(id: string): bool {
        return entries.hasOwnProperty(id);
    }
    function component(id: string): Component {
        return has(id) ? entries[id].component : null;
    }
    function kind(id: string): string {
        return has(id) ? (entries[id].kind ?? "panel") : "";
    }

    // only ever grows; write through report()
    property int maxWidth: 0
    property int maxHeight: 0

    function report(w: int, h: int): void {
        if (w > maxWidth)
            maxWidth = w;
        if (h > maxHeight)
            maxHeight = h;
    }

    Component.onCompleted: {
        for (const id of ids) {
            const probe = entries[id].component.createObject(null, {
                "probe": true
            });
            if (!probe) {
                console.warn(`luxshell: panel "${id}" failed to load`);
                continue;
            }
            report(probe.maxWidth, probe.maxHeight);
            probe.destroy();
        }
        // the overlay drivers flash on their own (Pipewire, Hyprland, D-Bus events): touch
        // them once so they live from the start, after the registry itself is complete
        void Activities.current;
        void Notifs.count;
    }

    Component {
        id: controlCenter
        ControlCenter {}
    }
    Component {
        id: controlCenterBluetooth // control center opened on its Bluetooth page
        ControlCenter {
            startPage: "bluetooth"
        }
    }
    Component {
        id: launcher
        Launcher {}
    }
    Component {
        id: activity
        ActivityOverlay {}
    }
    Component {
        id: notif
        NotifOverlay {}
    }
    Component {
        id: themePicker
        ThemePicker {}
    }
    Component {
        id: wallpaperPicker
        WallpaperPicker {}
    }
    Component {
        id: mediaPanel
        MediaPanel {}
    }
}
