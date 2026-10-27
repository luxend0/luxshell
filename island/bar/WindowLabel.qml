import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// App icon + title of the focused window; "Desktop" with a dot on an empty workspace.
Item {
    id: root

    readonly property QtObject h: Theme.hover
    readonly property string iconSource: Hypr.hasWindow ? Apps.iconFor(Hypr.appId) : ""

    implicitWidth: h.appIconSize + h.appIconGap + title.width
    implicitHeight: h.appIconSize

    Item {
        id: glyph
        width: root.h.appIconSize
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
        anchors.left: glyph.right
        anchors.leftMargin: root.h.appIconGap
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.h.titleMaxWidth)
        text: Hypr.hasWindow ? Hypr.title : "Desktop"
        elide: Text.ElideRight
        font.pixelSize: root.h.titleSize
        font.weight: Font.DemiBold
    }
}
