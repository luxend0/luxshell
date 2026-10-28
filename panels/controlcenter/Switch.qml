import QtQuick
import qs.config
import qs.widgets

// Toggle switch of the sheet header (ref/09): white track with a black knob on
// the right when on, dark track with a grey knob on the left when off.
// Space / Enter / click toggle.
Rectangle {
    id: sw

    readonly property QtObject sh: Theme.cc.sheet
    property bool on: false
    signal toggled

    width: sh.switchWidth
    height: sh.switchHeight
    radius: height / 2
    color: on ? Theme.accent : area.containsMouse ? Theme.mix(sh.discColor, Theme.text, 0.08) : sh.discColor
    Behavior on color {
        ColorAnim {}
    }

    readonly property bool ccControl: true
    function key(k: int): bool {
        if (k !== Qt.Key_Space && k !== Qt.Key_Return && k !== Qt.Key_Enter)
            return false;
        toggled();
        return true;
    }

    Rectangle {
        readonly property real inset: (sw.height - height) / 2
        x: sw.on ? sw.width - width - inset : inset
        anchors.verticalCenter: parent.verticalCenter
        width: sw.sh.knob
        height: width
        radius: width / 2
        color: sw.on ? Theme.island : Theme.textDim
        Behavior on x {
            Anim {
                ms: Theme.fadeIn
            }
        }
        Behavior on color {
            ColorAnim {}
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }

    FocusRing {}
}
