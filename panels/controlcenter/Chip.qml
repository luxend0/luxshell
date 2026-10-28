import QtQuick
import qs.config
import qs.widgets

// Small round icon button (the chevron at the top right of a slider card).
Rectangle {
    id: chip

    property string icon: "chevron-right"
    property real iconSize: 16
    signal clicked

    width: Theme.cc.chip
    height: width
    radius: width / 2
    color: area.containsMouse ? Theme.mix(Theme.cc.chipColor, Theme.text, 0.08) : Theme.cc.chipColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    Glyph {
        anchors.centerIn: parent
        name: chip.icon
        size: chip.iconSize
        stroke: 2.2
        color: area.containsMouse ? Theme.text : Theme.textDim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
