import QtQuick
import qs.config
import qs.widgets

// Toggle tile of ref/08: pill, disc on the left, title + state.
// The disc toggles. The body toggles too, unless the tile has a sub page
// (hasPage): then the body (or right click / Enter) opens it, Space toggles.
Rectangle {
    id: tile

    property string icon
    property string label
    property string sub
    property bool on: false
    property bool hasPage: false
    property real iconSize: Theme.cc.iconSize
    property real iconStroke: 2
    property bool iconFilled: false

    signal toggled
    signal opened

    width: Theme.cc.tileWidth
    height: Theme.cc.row
    radius: height / 2
    color: body.containsMouse || discArea.containsMouse ? Theme.cc.hover : Theme.surface
    border.width: 1
    border.color: Theme.cc.stroke
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    readonly property bool ccControl: true
    function key(k: int): bool {
        if (k === Qt.Key_Space)
            toggled();
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            hasPage ? opened() : toggled();
        else
            return false;
        return true;
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (tile.hasPage)
                tile.opened();
            else if (mouse.button === Qt.LeftButton)
                tile.toggled();
        }
    }

    Disc {
        id: disc
        x: (tile.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        icon: tile.icon
        on: tile.on
        iconSize: tile.iconSize
        stroke: tile.iconStroke
        filledIcon: tile.iconFilled
        hovered: discArea.containsMouse

        MouseArea {
            id: discArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }

    CapText {
        x: Theme.cc.textX
        width: tile.width - x - 18
        capY: Theme.cc.titleY
        text: tile.label
        font.pixelSize: Theme.cc.titleSize
        font.weight: Font.Medium
    }
    CapText {
        x: Theme.cc.textX
        width: tile.width - x - 18
        capY: Theme.cc.subY
        text: tile.sub
        font.pixelSize: Theme.cc.subSize
        color: Theme.textDim
    }

    FocusRing {}
}
