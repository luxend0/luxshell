import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// App icon + title of the focused window; "Desktop" with a dot on an empty workspace.
// textOpacity: the title fades in after the icon while the island opens.
// t: 1 = hover sizes (video), 0 = collapsed sizes (Theme.widgets) when the layout puts it
// into the collapsed island. Title on/off and its longest width: Settings.islandWindow*.
Item {
    id: root

    property real textOpacity: 1
    property real t: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    readonly property string iconSource: Hypr.hasWindow ? Apps.iconFor(Hypr.appId) : ""
    function mix(a: real, b: real): real {
        return a + (b - a) * t;
    }
    readonly property bool showTitle: Settings.islandWindowTitle
    readonly property real maxH: Settings.islandWindowMaxWidth
    readonly property real maxC: Math.round(Settings.islandWindowMaxWidth * wm.titleShare)
    readonly property real iconSize: mix(wm.appIconSize, h.appIconSize)
    readonly property string titleText: Hypr.hasWindow ? Hypr.title : "Desktop"
    // BarWidget contract: width at collapsed / hover sizes
    readonly property real wC: wm.appIconSize + (showTitle ? wm.appIconGap + Math.min(measureC.implicitWidth, maxC) : 0)
    readonly property real wH: h.appIconSize + (showTitle ? h.appIconGap + Math.min(measureH.implicitWidth, maxH) : 0)

    implicitWidth: iconSize + (showTitle ? mix(wm.appIconGap, h.appIconGap) + title.width : 0)
    implicitHeight: iconSize

    Item {
        id: glyph
        width: root.iconSize
        height: width
        anchors.verticalCenter: parent.verticalCenter

        IconImage {
            anchors.fill: parent
            visible: Hypr.hasWindow && root.iconSource !== ""
            source: root.iconSource
        }
        Icon {
            anchors.fill: parent
            visible: Hypr.hasWindow && root.iconSource === ""
            name: "app-window"
            size: parent.width
            color: Theme.textSecondary
        }
        Rectangle {
            anchors.centerIn: parent
            visible: !Hypr.hasWindow
            width: 6
            height: 6
            radius: 3
            color: Theme.textDim
        }
    }

    Txt {
        id: title
        visible: root.showTitle
        anchors.left: glyph.right
        anchors.leftMargin: root.mix(root.wm.appIconGap, root.h.appIconGap)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.mix(root.maxC, root.maxH))
        text: root.titleText
        opacity: root.textOpacity
        elide: Text.ElideRight
        font.pixelSize: Math.round(root.mix(root.wm.titleSize, root.h.titleSize))
        font.weight: Font.DemiBold
    }
    Txt {
        id: measureC
        visible: false
        text: root.titleText
        font.pixelSize: Math.round(root.wm.titleSize)
        font.weight: Font.DemiBold
    }
    Txt {
        id: measureH
        visible: false
        text: root.titleText
        font.pixelSize: Math.round(root.h.titleSize)
        font.weight: Font.DemiBold
    }
}
