import QtQuick
import qs.config
import qs.services
import qs.widgets

// Volume of the player itself (MPRIS Volume, not the sink): speaker glyph + short track.
// Click / drag / wheel set it. Hidden by the panel when the player has no volume.
Item {
    id: root

    property var player: null
    readonly property QtObject m: Theme.media
    readonly property real value: area.pressed ? area.dragValue : (player?.volume ?? 0)

    implicitWidth: m.volumeIcon + 10 + m.volumeWidth
    implicitHeight: 28

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: root.value <= 0.001 ? "volume-x" : root.value < 0.34 ? "volume" : root.value < 0.67 ? "volume-1" : "volume-2"
        size: root.m.volumeIcon
        color: Theme.textSecondary
    }

    Rectangle {
        id: track
        x: root.m.volumeIcon + 10
        width: root.m.volumeWidth
        height: area.containsMouse || area.pressed ? root.m.trackHover : root.m.trackHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: root.m.track
        Behavior on height {
            Anim {
                ms: 180
            }
        }
        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
            height: parent.height
            radius: parent.radius
            color: Theme.textSecondary
        }
    }

    MouseArea {
        id: area
        property real dragValue: 0
        x: track.x
        width: track.width
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: m => {
            dragValue = at(m.x);
            Media.setVolume(root.player, dragValue);
        }
        onPositionChanged: m => {
            if (!pressed)
                return;
            dragValue = at(m.x);
            Media.setVolume(root.player, dragValue);
        }
        onWheel: w => Media.setVolume(root.player, (root.player?.volume ?? 0) + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
