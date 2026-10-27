import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.core

// One layer surface per screen. The surface is tall enough for any panel but
// transparent; the input mask follows the island body, the exclusive zone is
// the collapsed height only.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Math.min(modelData.height, Theme.windowHeight)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.collapsed.height
    color: "transparent"

    WlrLayershell.namespace: "luxshell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: island.grabs ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: island.body
    }

    Island {
        id: island
        anchors.fill: parent
        screen: win.modelData
    }

    // click outside a modal panel closes it. The grab is armed a moment after the
    // surface took keyboard focus; armed in the same frame Hyprland clears it at once.
    HyprlandFocusGrab {
        id: grab
        windows: [win]
        onCleared: if (island.grabs)
            Ui.close()
    }
    Timer {
        id: armGrab
        interval: 60
        onTriggered: grab.active = island.grabs
    }
    Connections {
        target: island
        function onGrabsChanged() {
            if (island.grabs)
                armGrab.restart();
            else
                grab.active = false;
        }
    }
}
