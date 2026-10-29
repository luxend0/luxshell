import QtQuick
import qs.config
import qs.widgets

// GlyphLabel for live numbers (gpu, temps, netspeed, updates): glyph + text in a slot as wide
// as `sample` (tabular figures), so a changing value never moves its neighbours or the
// island width. Sizes like GlyphLabel: Theme.widgets.iconSize / iconGap / textSize,
// t mixes collapsed (0) -> hover (1). iconScale shrinks the glyph (netspeed arrows).
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string sample: ""         // widest text the slot must hold ("" = the text itself)
    property real iconScale: 1
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null
    property color color: Theme.text

    readonly property QtObject wm: Theme.widgets
    readonly property bool hasText: text !== "" || sample !== ""
    readonly property real iconC: Math.round(wm.iconSize[0] * iconScale)
    readonly property real iconH: Math.round(wm.iconSize[1] * iconScale)
    readonly property real slotC: hasText ? Math.ceil(Math.max(measureC.advanceWidth, sampleC.advanceWidth)) : 0
    readonly property real slotH: hasText ? Math.ceil(Math.max(measureH.advanceWidth, sampleH.advanceWidth)) : 0
    readonly property real wC: iconC + (hasText ? wm.iconGap[0] + slotC : 0)
    readonly property real wH: iconH + (hasText ? wm.iconGap[1] + slotH : 0)

    function mix(a: real, b: real): real {
        return a + (b - a) * t;
    }

    implicitWidth: mix(wC, wH)
    implicitHeight: Math.max(glyph.height, label.implicitHeight)

    WIcon {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: root.mix(root.wm.iconSize[0], root.wm.iconSize[1]) * root.iconScale
        color: root.color
    }
    Txt {
        id: label
        visible: root.hasText
        x: glyph.width + root.mix(root.wm.iconGap[0], root.wm.iconGap[1])
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.color
        opacity: root.textOpacity
        font.pixelSize: Math.round(root.mix(root.wm.textSize[0], root.wm.textSize[1]))
        font.weight: Font.Medium
        font.features: ({
                "tnum": 1
            })
    }
    TextMetrics {
        id: measureC
        font.family: Theme.fontFamily
        font.pixelSize: root.wm.textSize[0]
        font.weight: Font.Medium
        font.features: ({
                "tnum": 1
            })
        text: root.text
    }
    TextMetrics {
        id: measureH
        font.family: Theme.fontFamily
        font.pixelSize: root.wm.textSize[1]
        font.weight: Font.Medium
        font.features: ({
                "tnum": 1
            })
        text: root.text
    }
    TextMetrics {
        id: sampleC
        font: measureC.font
        text: root.sample
    }
    TextMetrics {
        id: sampleH
        font: measureH.font
        text: root.sample
    }
}
