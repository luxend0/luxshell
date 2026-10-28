import QtQuick
import qs.config
import qs.services
import qs.widgets

// Thin progress track with the elapsed and total time under its ends. Grows on hover
// when the player can seek; click or drag seeks on release (while dragging the time
// follows the pointer). Without seek support it is a plain progress line.
Item {
    id: root

    property var player: null
    readonly property QtObject m: Theme.media
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property bool seekable: Media.canSeek(player)
    readonly property real shownPos: area.pressed ? area.dragPos : position
    readonly property real frac: length > 0 ? Math.max(0, Math.min(1, shownPos / length)) : 0
    readonly property bool hot: seekable && (area.containsMouse || area.pressed)

    implicitHeight: 28

    Rectangle {
        id: track
        width: parent.width
        height: root.hot ? root.m.trackHover : root.m.trackHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: root.m.track
        Behavior on height {
            Anim {
                ms: 180
            }
        }

        Rectangle {
            width: Math.max(parent.height, parent.width * root.frac)
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: root.length > 0 ? (root.player?.isPlaying || area.pressed ? 1 : 0.7) : 0
            Behavior on opacity {
                Anim {
                    ms: Theme.fadeIn
                }
            }
        }
    }

    MouseArea {
        id: area
        property real dragPos: 0
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, x / width)) * root.length;
        }
        onPressed: m => dragPos = at(m.x)
        onPositionChanged: m => {
            if (pressed)
                dragPos = at(m.x);
        }
        onReleased: Media.seekTo(root.player, dragPos)
    }

    component Time: Txt {
        // cap centre at Theme.media.timeY (track centre at trackY)
        y: Math.round(root.height / 2 + root.m.timeY - root.m.trackY - (baselineOffset - font.pixelSize * 0.727 / 2))
        font.pixelSize: root.m.timeSize
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
        color: Theme.textDim
    }
    Time {
        text: Media.time(root.shownPos)
        color: area.pressed ? Theme.text : Theme.textDim
    }
    Time {
        anchors.right: parent.right
        text: root.length > 0 ? Media.time(root.length) : "--:--"
    }
}
