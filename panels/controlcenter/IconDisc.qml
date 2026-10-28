import QtQuick
import qs.config
import qs.widgets

// Small round icon button of the sheet header (back chevron, refresh).
Rectangle {
    id: btn

    readonly property QtObject sh: Theme.cc.sheet
    property string icon: "chevron-left"
    property real iconSize: 15
    property real stroke: 2.2
    signal clicked

    width: sh.backSize
    height: width
    radius: width / 2
    color: area.containsMouse ? sh.rowHover : sh.rowColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    readonly property bool ccControl: true
    function key(k: int): bool {
        if (k !== Qt.Key_Space && k !== Qt.Key_Return && k !== Qt.Key_Enter)
            return false;
        clicked();
        return true;
    }

    Glyph {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: btn.icon === "chevron-left" ? -1 : 0
        name: btn.icon
        size: btn.iconSize
        stroke: btn.stroke
        color: area.containsMouse ? Theme.textSecondary : Theme.textDim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    FocusRing {}
}
