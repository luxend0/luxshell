import QtQuick
import qs.config
import qs.services
import qs.widgets

// "All caught up" + bell, or the unread count with a dotted bell.
// textOpacity: the label fades in after the bell while the island opens.
// Click = openRequested (island/bar/BarContent opens the notification center); the soft
// highlight under the pointer is the media chip's (island/bar/MediaLabel), so both
// clickable spots of the hover island look alike. Without it a click here would fall
// through to the island and open the control center.
// t: 1 = hover sizes (video), 0 = collapsed sizes (Theme.widgets). Settings.islandNotifLabel
// off = bell only.
Item {
    id: root

    property real textOpacity: 1
    property real t: 1
    property bool interactive: true
    property var screen: null
    signal openRequested

    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    function mix(a: real, b: real): real {
        return a + (b - a) * t;
    }
    readonly property bool showLabel: Settings.islandNotifLabel
    readonly property real bellSize: mix(wm.bellSize, h.bellSize)
    readonly property real wC: (showLabel ? measureC.implicitWidth + wm.notifGap : 0) + wm.bellSize
    readonly property real wH: (showLabel ? measureH.implicitWidth + 12 : 0) + h.bellSize

    implicitWidth: (showLabel ? label.implicitWidth + mix(wm.notifGap, 12) : 0) + bell.width
    implicitHeight: bellSize

    Rectangle {
        id: highlight
        x: -Theme.media.chipPad
        width: root.width + 2 * Theme.media.chipPad
        height: root.bellSize + 14
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.media.chipHover
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
    }

    Txt {
        id: label
        visible: root.showLabel
        anchors.verticalCenter: parent.verticalCenter
        text: Notifs.status
        opacity: root.textOpacity
        font.pixelSize: Math.round(root.mix(root.wm.notifSize, root.h.notifSize))
        font.weight: Font.Medium
    }
    Txt {
        id: measureC
        visible: false
        text: Notifs.status
        font.pixelSize: Math.round(root.wm.notifSize)
        font.weight: Font.Medium
    }
    Txt {
        id: measureH
        visible: false
        text: Notifs.status
        font.pixelSize: Math.round(root.h.notifSize)
        font.weight: Font.Medium
    }
    Icon {
        id: bell
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        name: Notifs.count > 0 ? "bell-dot" : "bell"
        size: root.bellSize
        color: Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: highlight
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested()
    }
}
