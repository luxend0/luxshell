import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.core

// One layer surface per screen, anchored to the top edge only (centred by the
// compositor) and only as large as needed: hover size or the largest registered
// panel (Panels.maxWidth/maxHeight), plus the ears. Transparent; the input mask
// follows the island body, the exclusive zone is the collapsed height only.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    anchors.top: true
    // * (1 + Motion.overshoot): room for the spring's swing (0 unless motionStyle "spring")
    implicitWidth: Math.min(modelData.width, Math.max(Theme.hover.width, Panels.maxWidth) * (1 + Motion.overshoot) + 2 * Theme.earRadius + 2 * Theme.look.shadowMargin)
    implicitHeight: Math.min(modelData.height, Math.max(Theme.hover.height, Panels.maxHeight) * (1 + Motion.overshoot) + 2 + Theme.look.shadowMargin)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.collapsed.height
    color: "transparent"

    WlrLayershell.namespace: "luxshell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: island.grabs ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
    // Keyboard focus must be OnDemand, not Exclusive: with Exclusive Hyprland never clears
    // the grab on an outside click (tested 2026-10-28 with a virtual pointer); the active
    // grab still hands the panel the keyboard, so typing in the launcher works.
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
