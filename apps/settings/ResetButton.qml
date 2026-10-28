import QtQuick
import qs.config
import qs.widgets

// Per-option reset (only while the option differs from its default): a quiet
// circular arrow, brighter on hover, with a "Default: ..." tip. Takes no room when
// hidden (width 0), so unchanged rows keep the video's layout.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property bool shown: false
    property string tip: "Reset to default"
    property var host: null
    signal clicked

    width: shown ? g.resetSize : 0
    height: g.resetSize
    visible: shown

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: area.containsMouse ? root.g.field : "transparent"
        Behavior on color {
            ColorAnim {
                ms: Theme.fadeOut
            }
        }
    }

    MdIcon {
        anchors.centerIn: parent
        glyph: String.fromCodePoint(0xF0450) // md-refresh: back to the default
        size: root.g.resetIconSize
        color: area.containsMouse ? root.g.label : root.g.value
        transform: Scale {
            origin.x: root.g.resetIconSize / 2
            xScale: -1 // counter-clockwise reads as "undo"
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.host)
                root.host.untip(root);
            root.clicked();
        }
        onContainsMouseChanged: if (root.host) {
            if (containsMouse)
                root.host.tip(root, root.tip);
            else
                root.host.untip(root);
        }
    }
}
