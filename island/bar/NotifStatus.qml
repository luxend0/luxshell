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
Item {
    id: root

    property real textOpacity: 1
    signal openRequested

    readonly property QtObject h: Theme.hover

    implicitWidth: label.implicitWidth + 12 + bell.width
    implicitHeight: h.bellSize

    Rectangle {
        id: highlight
        x: -Theme.media.chipPad
        width: root.width + 2 * Theme.media.chipPad
        height: root.h.bellSize + 14
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
        anchors.verticalCenter: parent.verticalCenter
        text: Notifs.status
        opacity: root.textOpacity
        font.pixelSize: root.h.notifSize
        font.weight: Font.Medium
    }
    Icon {
        id: bell
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        name: Notifs.count > 0 ? "bell-dot" : "bell"
        size: root.h.bellSize
        color: Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: highlight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested()
    }
}
