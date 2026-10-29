import QtQuick
import qs.config
import qs.widgets

// Row of a sheet with a switch instead of a pill (night light in the display sheet): the
// card, disc, name and status of SheetRow, the header Switch at the right. A click anywhere
// on the row flips it; the keyboard selects the switch (Enter / Space).
Rectangle {
    id: row

    readonly property QtObject sh: Theme.cc.sheet

    property string icon
    property string name
    property string sub
    property bool on: false
    property bool switchEnabled: true
    signal toggled

    width: parent ? parent.width : 300
    height: sh.rowHeight
    radius: sh.rowRadius
    color: area.containsMouse && switchEnabled ? sh.rowHover : sh.rowColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.switchEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.switchEnabled)
            row.toggled()
    }

    Disc {
        x: row.sh.discX
        y: Math.round((row.sh.rowHeight - height) / 2)
        width: row.sh.disc
        icon: row.icon
        on: row.on
        iconSize: row.sh.discIcon
        offColor: row.sh.discColor
    }

    SheetText {
        x: row.sh.nameX
        width: sw.x - x - 14
        capY: row.sh.nameY
        px: row.sh.nameSize
        text: row.name
        color: row.sh.textColor
        font.weight: Font.Medium
    }
    SheetText {
        x: row.sh.subX
        width: sw.x - x - 14
        capY: row.sh.subY
        px: row.sh.subSize
        text: row.sub
        color: row.sh.subColor
    }

    Switch {
        id: sw
        x: row.width - row.sh.pillRight - 6 - width
        y: Math.round((row.sh.rowHeight - height) / 2)
        on: row.on
        enabled: row.switchEnabled
        opacity: row.switchEnabled ? 1 : 0.4
        onToggled: row.toggled()
    }
}
