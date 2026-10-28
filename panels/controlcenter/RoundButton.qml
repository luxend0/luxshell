import QtQuick
import qs.config
import qs.widgets

// Round 80px button of ref/08 (lock: dark, light mode toggle: white when on).
Rectangle {
    id: btn

    property string icon
    property bool on: false
    property real iconSize: Theme.cc.iconSize
    property bool iconFilled: false
    property real iconStroke: 2

    signal clicked

    width: Theme.cc.row
    height: width
    radius: width / 2
    color: on ? Theme.accent : area.containsMouse ? Theme.cc.hover : Theme.surface
    border.width: on ? 0 : 1
    border.color: Theme.cc.stroke
    Behavior on color {
        ColorAnim {}
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
        anchors.verticalCenterOffset: 1
        name: btn.icon
        size: btn.iconSize
        filled: btn.iconFilled
        stroke: btn.iconStroke
        color: btn.on ? Theme.onAccent : Theme.mix(Theme.textSecondary, Theme.text, 0.5)
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
