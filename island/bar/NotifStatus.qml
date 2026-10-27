import QtQuick
import qs.config
import qs.services
import qs.widgets

// "All caught up" + bell, or the unread count with a dotted bell.
Item {
    id: root

    readonly property QtObject h: Theme.hover

    implicitWidth: label.implicitWidth + 12 + bell.width
    implicitHeight: h.bellSize

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Notifs.status
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
}
