import QtQuick
import qs.config
import qs.services
import qs.island.widgets

// Network: the video's four rising bars (Ethernet = all lit) or one glyph
// (Settings.islandNetworkStyle "icon": ethernet / wifi / wifi-off).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    readonly property bool asIcon: Settings.islandNetworkStyle === "icon"
    readonly property real wC: asIcon ? wm.iconSize[0] : 4 * c.barWidth + 3 * c.barGap
    readonly property real wH: asIcon ? wm.iconSize[1] : 4 * h.barWidth + 3 * h.barGap

    implicitWidth: asIcon ? glyph.width : bars.implicitWidth
    implicitHeight: asIcon ? glyph.height : bars.implicitHeight

    SignalBars {
        id: bars
        visible: !root.asIcon
        p: root.t
    }
    WIcon {
        id: glyph
        visible: root.asIcon
        name: Net.kind === "ethernet" ? "ethernet" : Net.kind === "wifi" ? "wifi" : "wifi-off"
        size: root.wm.iconSize[0] + (root.wm.iconSize[1] - root.wm.iconSize[0]) * root.t
        color: Theme.text
    }
}
