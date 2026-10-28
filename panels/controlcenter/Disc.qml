import QtQuick
import qs.config
import qs.widgets

// Round icon disc: white (accent) when on, raised grey when off.
Rectangle {
    id: disc

    property string icon
    property bool on: false
    property bool hovered: false
    property real iconSize: Theme.cc.iconSize
    property real stroke: 2
    property bool filledIcon: false
    property color offIconColor: Theme.textSecondary
    property color offColor: Theme.surfaceHigh

    width: Theme.cc.disc
    height: width
    radius: width / 2
    color: on ? Theme.accent : hovered ? Theme.mix(offColor, Theme.text, 0.08) : offColor
    Behavior on color {
        ColorAnim {}
    }

    Glyph {
        anchors.centerIn: parent
        name: disc.icon
        size: disc.iconSize
        stroke: disc.stroke
        filled: disc.filledIcon
        color: disc.on ? Theme.onAccent : disc.offIconColor
    }
}
