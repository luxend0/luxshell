import QtQuick
import qs.config
import qs.widgets

// Small round icon button of the notification center (fold chevron, dismiss x): the
// control center's chevron chip, a size smaller.
Rectangle {
    id: chip

    property string icon: "x"
    property real iconSize: Theme.nc.chipIcon
    property bool hot: false          // drawn as hovered (keyboard selection)
    readonly property bool hovered: area.containsMouse
    signal clicked

    width: Theme.nc.chip
    height: width
    radius: width / 2
    color: area.containsMouse || hot ? Theme.mix(Theme.nc.chipColor, Theme.text, 0.1) : Theme.nc.chipColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    Glyph {
        anchors.centerIn: parent
        name: chip.icon
        size: chip.iconSize
        stroke: 2.3
        color: area.containsMouse || chip.hot ? Theme.text : Theme.textSecondary
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
