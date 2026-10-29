pragma Singleton
import QtQuick
import qs.config
import Quickshell
import qs.panels
import qs.services
import qs.apps.settings

// Panel registry: id -> component + kind. The island knows nothing else about
// panels; each panel reports its own size/radius at runtime (panels/PanelBase.qml).
// The registry also knows the largest size any panel can ask for (maxWidth/maxHeight):
// every component is probed once at start (PanelBase.maxWidth/maxHeight), live panels
// raise it further via report(). The island's layer surface is sized from it, so a
// taller panel added later is never clipped.
//
//   kind "panel"    modal: focus grab + exclusive keyboard, Esc / click outside closes
//   kind "overlay"  transient (OSD): no focus, auto-hides, outranks hover but not panels
//   kind "window"   own toplevel outside the island (settings app): { window: singleton
//                   with show(page) / toggle() }, never shown by the island
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
            "overview": {
                "component": overview,
                "kind": "panel"
            },
            // notification history (services/Notifs), opened from "All caught up" / the bell of
            // the hover island or ipc toggle notifications
            "notifications": {
                "component": notificationCenter,
                "kind": "panel"
            },
            // now playing (services/Media), opened from the media chip of the hover island
            "media": {
                "component": mediaPanel,
                "kind": "panel"
            },
            // power menu (services/Power), opened from the red power button of the hover island
            // or ipc toggle power (Super+Esc)
            "power": {
                "component": powerMenu,
                "kind": "panel"
            },
            // apps using the microphone / camera / screen (services/Privacy), opened from the
            // island's privacy dot
            "privacy": {
                "component": privacyPanel,
                "kind": "panel"
            },
            // own window (FloatingWindow), Ui.open/toggle hand it to window.show()/toggle()
            "settings": {
                "window": SettingsApp,
                "kind": "window"
            },
            // bar menus (panels/SheetMenu): one control-center sheet as its own island panel,
            // opened by the bar widgets (click; microphone: right click = sound on its input part)
            "sheet-bluetooth": {
                "component": sheetBluetooth,
                "kind": "panel"
            },
            "sheet-sound": {
                "component": sheetSound,
                "kind": "panel"
            },
            "sheet-sound-input": {
                "component": sheetSoundInput,
                "kind": "panel"
            },
            "sheet-network": {
                "component": sheetNetwork,
                "kind": "panel"
            },
            "sheet-display": {
                "component": sheetDisplay,
                "kind": "panel"
            },
            // small menus of the bar switches (right click on power mode / caffeine)
            "menu-powerprofile": {
                "component": menuPowerProfile,
                "kind": "panel"
            },
            "menu-caffeine": {
                "component": menuCaffeine,
                "kind": "panel"
            },
            // polkit authentication prompt (services/Polkit opens it per request); "exclusive":
            // the island window holds the keyboard exclusively while it is open (IslandWindow)
            "polkit": {
                "component": polkitPrompt,
                "kind": "panel",
                "exclusive": true
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

    // Probe only after Settings is read: probing with the default theme and then switching
    // to the saved one re-ran bindings of already destroyed probes (TypeErrors at start).
    property bool probed: false
    function probeAll(): void {
        if (probed)
            return;
        probed = true;
        for (const id of ids) {
            if (!entries[id].component)
                continue; // windows have no island size
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

    Component.onCompleted: if (Settings.ready)
        probeAll()
    Connections {
        target: Settings
        function onReadyChanged() {
            if (Settings.ready)
                Qt.callLater(root.probeAll);
        }
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
        id: overview
        Overview {}
    }
    Component {
        id: mediaPanel
        MediaPanel {}
    }
    Component {
        id: notificationCenter
        NotificationCenter {}
    }
    Component {
        id: powerMenu
        PowerMenu {}
    }
    Component {
        id: privacyPanel
        PrivacyPanel {}
    }
    Component {
        id: sheetBluetooth
        SheetMenu {
            sheet: "bluetooth"
        }
    }
    Component {
        id: sheetSound
        SheetMenu {
            sheet: "sound"
        }
    }
    Component {
        id: sheetSoundInput // sound menu scrolled to the microphone
        SheetMenu {
            sheet: "sound"
            section: "input"
        }
    }
    Component {
        id: sheetNetwork
        SheetMenu {
            sheet: "network"
        }
    }
    Component {
        id: sheetDisplay
        SheetMenu {
            sheet: "display"
        }
    }
    Component {
        id: menuPowerProfile
        SheetMenu {
            sheet: "powerprofile"
        }
    }
    Component {
        id: menuCaffeine
        SheetMenu {
            sheet: "caffeine"
        }
    }
    Component {
        id: polkitPrompt
        PolkitPrompt {}
    }
}
