import QtQuick
import qs.config
import qs.services
import qs.widgets

// Pending updates (services/Updates: checkupdates + paru -Qua every
// Settings.islandUpdatesInterval minutes, nice 19). Hidden at 0 unless
// Settings.islandUpdatesHideZero is off (BarRegistry.present).
// Click: `paru -Syu` in the terminal (counts again after the pacman transaction);
// right click: check now. Hover: the chip highlight of the media chip / notification status.
// Live width (the count changes rarely, a fixed slot would leave a gap).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property alias wC: label.wC
    readonly property alias wH: label.wH

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Rectangle {
        x: -Theme.media.chipPad
        width: root.width + 2 * Theme.media.chipPad
        height: root.height + 14
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

    InfoLabel {
        id: label
        icon: "package"
        text: Updates.ready ? String(Updates.count) : "–"
        t: root.t
        textOpacity: root.textOpacity * (Updates.checking ? 0.5 : 1)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton || Updates.count === 0)
                Updates.check();
            else
                Updates.upgrade();
        }
    }

    Component.onCompleted: Updates.use()
    Component.onDestruction: Updates.release()
}
