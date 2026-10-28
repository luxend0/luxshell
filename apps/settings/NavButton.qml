import QtQuick
import qs.config
import qs.widgets

// Back / forward button above the page (ref/12).
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property string glyph: ""
    property bool active: true
    signal clicked

    width: g.navWidth
    height: g.navHeight
    radius: g.navRadius
    color: area.containsMouse && active ? Theme.mix(g.nav, Theme.text, 0.07) : g.nav
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    MdIcon {
        anchors.centerIn: parent
        glyph: root.glyph
        size: root.g.navIconSize
        color: root.active ? root.g.label : Theme.mix(root.g.label, root.g.nav, 0.6)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.active)
            root.clicked()
    }
}
