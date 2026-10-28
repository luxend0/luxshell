import QtQuick
import qs.config
import qs.widgets

// Sidebar entry (ref/12): icon disc + page name. The current page's disc turns
// light (accent) with a black glyph; the row background is the window's highlight.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    required property var page
    property bool current: false
    property bool ring: false
    signal clicked

    width: g.sideWidth
    height: g.sideRowHeight

    Rectangle {
        anchors.fill: parent
        radius: root.g.sideRadius
        color: Theme.mix(root.g.sidebar, root.g.selected, 0.5)
        opacity: area.containsMouse && !root.current ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: root.g.sideRadius + 3
        color: "transparent"
        border.width: 2
        border.color: root.g.ring
        visible: root.ring
    }

    Rectangle {
        id: disc
        x: root.g.sideDiscX
        anchors.verticalCenter: parent.verticalCenter
        width: root.g.sideDisc
        height: width
        radius: width / 2
        color: root.current ? root.g.discOn : root.g.disc
        Behavior on color {
            ColorAnim {}
        }

        MdIcon {
            anchors.centerIn: parent
            glyph: root.page.icon
            size: root.g.sideIconSize
            color: root.current ? Theme.island : root.g.icon
        }
    }

    SText {
        x: root.g.sideTextX
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 8
        elide: Text.ElideRight
        text: root.page.title
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
