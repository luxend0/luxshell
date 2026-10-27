import QtQuick
import qs.config

// Round, borderless icon button; the hover disc is the only chrome.
Item {
    id: root

    property string icon: ""
    property real size: 18
    property color color: Theme.text
    property real restOpacity: 1
    signal clicked

    implicitWidth: size + 10
    implicitHeight: size + 10

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.surfaceHigh
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity {
            Anim {
                duration: Theme.fadeOut
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.size
        color: root.color
        opacity: area.containsMouse ? 1 : root.restOpacity
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
