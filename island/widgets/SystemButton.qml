import QtQuick
import qs.config
import qs.core
import qs.widgets

// Gear (settings app) or power (power menu, red) of the hover island: 18 px glyph with a
// hover disc (IconButton, 28 px item), 16 px in the collapsed island.
Item {
    id: root

    property string kind: "settings"
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    readonly property real wC: wm.systemIconSize + 10
    readonly property real wH: h.systemIconSize + 10

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    IconButton {
        id: button
        enabled: root.interactive
        icon: root.kind === "power" ? "power" : "settings"
        size: root.wm.systemIconSize + (root.h.systemIconSize - root.wm.systemIconSize) * root.t
        color: root.kind === "power" ? Theme.danger : Theme.text
        restOpacity: root.kind === "power" ? 0.85 : 0.6
        onClicked: Ui.toggle(root.kind === "power" ? "power" : "settings") // "power" = panels/PowerMenu (also ipc toggle power)
    }
}
