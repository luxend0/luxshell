import QtQuick
import qs.config
import qs.services

// Four rising bars: Ethernet = all lit, Wi-Fi = by strength, offline = none.
Item {
    id: root

    property real p: 0
    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    function mix(a: real, b: real): real {
        return a + (b - a) * p;
    }
    readonly property real barW: mix(c.barWidth, h.barWidth)
    readonly property real gap: mix(c.barGap, h.barGap)
    readonly property real maxH: mix(c.barHeight, h.barHeight)
    readonly property var ratios: [0.38, 0.58, 0.79, 1.0]

    implicitWidth: 4 * barW + 3 * gap
    implicitHeight: maxH

    Repeater {
        model: 4

        Rectangle {
            required property int index
            x: index * (root.barW + root.gap)
            width: root.barW
            height: root.maxH * root.ratios[index]
            y: root.maxH - height
            radius: 1.2
            color: index < Net.bars ? Theme.text : Theme.muted
        }
    }
}
