import QtQuick
import qs.config
import qs.widgets

// Toggle of a settings row (ref/12 "Color burst"): off = dark track, grey knob left;
// on = accent track, black knob right. The row handles clicks and keys.
Rectangle {
    id: sw

    readonly property QtObject g: Theme.settings
    property bool on: false
    property bool hovered: false

    implicitWidth: g.switchWidth
    implicitHeight: g.switchHeight
    radius: height / 2
    color: on ? Theme.accent : hovered ? Theme.mix(g.switchOff, Theme.text, 0.06) : g.switchOff
    Behavior on color {
        ColorAnim {}
    }

    Rectangle {
        readonly property real inset: (sw.height - height) / 2
        x: sw.on ? sw.width - width - inset : inset
        anchors.verticalCenter: parent.verticalCenter
        width: sw.g.knob
        height: width
        radius: width / 2
        color: sw.on ? Theme.onAccent : sw.g.knobOff
        Behavior on x {
            Anim {
                ms: Theme.fadeIn
            }
        }
        Behavior on color {
            ColorAnim {}
        }
    }
}
