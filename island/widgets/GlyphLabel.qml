import QtQuick
import qs.config
import qs.widgets

// Glyph + short text (battery, weather, cpu, memory, keyboard): 17/20 px glyph, 15/17 px
// text (Theme.widgets, t mixes collapsed -> hover). Text optional.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null
    property color color: Theme.text

    readonly property QtObject wm: Theme.widgets
    readonly property bool hasText: text !== ""
    readonly property real wC: wm.iconSize[0] + (hasText ? wm.iconGap[0] + measureC.implicitWidth : 0)
    readonly property real wH: wm.iconSize[1] + (hasText ? wm.iconGap[1] + measureH.implicitWidth : 0)

    implicitWidth: glyph.width + (hasText ? wm.iconGap[0] + (wm.iconGap[1] - wm.iconGap[0]) * t + label.implicitWidth : 0)
    implicitHeight: Math.max(glyph.height, label.implicitHeight)

    WIcon {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: root.wm.iconSize[0] + (root.wm.iconSize[1] - root.wm.iconSize[0]) * root.t
        color: root.color
    }
    Txt {
        id: label
        visible: root.hasText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.color
        opacity: root.textOpacity
        font.pixelSize: Math.round(root.wm.textSize[0] + (root.wm.textSize[1] - root.wm.textSize[0]) * root.t)
        font.weight: Font.Medium
    }
    Txt {
        id: measureC
        visible: false
        text: root.text
        font.pixelSize: root.wm.textSize[0]
        font.weight: Font.Medium
    }
    Txt {
        id: measureH
        visible: false
        text: root.text
        font.pixelSize: root.wm.textSize[1]
        font.weight: Font.Medium
    }
}
