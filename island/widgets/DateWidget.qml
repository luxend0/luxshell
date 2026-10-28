import QtQuick
import qs.config
import qs.services
import qs.widgets

// Date, dimmed ("Sun, Oct 25", Settings.dateFormat via services/Clock). 15 px collapsed,
// 19 px hover. Riding next to the clock it keeps 19 px and takes the clock's scale (BarWidget).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject wm: Theme.widgets
    readonly property QtObject h: Theme.hover
    readonly property real wC: measureC.implicitWidth
    readonly property real wH: measureH.implicitWidth
    readonly property real anchorY: height / 2
    readonly property real textBase: label.baselineOffset

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Txt {
        id: label
        text: Clock.date
        color: Theme.textDim
        font.pixelSize: Math.round(root.wm.dateSize + (root.h.dateSize - root.wm.dateSize) * root.t)
        font.weight: Font.Medium
    }
    Txt {
        id: measureC
        visible: false
        text: Clock.date
        font.pixelSize: Math.round(root.wm.dateSize)
        font.weight: Font.Medium
    }
    Txt {
        id: measureH
        visible: false
        text: Clock.date
        font.pixelSize: Math.round(root.h.dateSize)
        font.weight: Font.Medium
    }
}
