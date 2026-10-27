pragma Singleton
import QtQuick
import Quickshell
import qs.panels

// Panel registry: id -> component + kind. The island knows nothing else about
// panels; each panel reports its own size/radius at runtime (panels/PanelBase.qml).
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
            "launcher": {
                "component": launcher,
                "kind": "panel"
            },
            "osd": {
                "component": volumeOsd,
                "kind": "overlay"
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

    Component {
        id: controlCenter
        ControlCenter {}
    }
    Component {
        id: launcher
        Launcher {}
    }
    Component {
        id: volumeOsd
        VolumeOsd {}
    }
}
