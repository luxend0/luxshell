import QtQuick
import qs.config
import qs.widgets

// Pill slider of ref/08: dark track, white fill that never gets shorter than a
// circle, icon riding inside the fill. Emits moved(v) on drag, click and wheel;
// while the pointer is down it shows the drag position, not `value`.
Rectangle {
    id: track

    property real value: 0
    property string icon
    property real iconSize: 18
    property real iconStroke: 2
    signal moved(real v)

    readonly property real shown: area.pressed ? area.dragValue : value
    // values that arrive right after opening (DDC read) jump instead of sliding in
    property bool settled: false
    Timer {
        running: true
        interval: 600
        onTriggered: track.settled = true
    }

    height: Theme.cc.trackHeight
    radius: height / 2
    color: Theme.cc.track

    Rectangle {
        id: fill
        width: Math.max(track.height, track.width * Math.max(0, Math.min(1, track.shown)))
        height: parent.height
        radius: parent.radius
        color: Theme.accent
        // no data yet (DDC still reading) or nothing to control: empty track, the fill fades in later
        opacity: track.enabled ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
        Behavior on width {
            enabled: track.settled && !area.pressed
            Anim {
                ms: Theme.fadeIn
            }
        }
    }

    Glyph {
        x: Math.max(track.height / 2, Math.min(Theme.cc.trackIconX, fill.width / 2)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: track.icon
        size: track.iconSize
        stroke: track.iconStroke
        color: track.enabled ? Theme.onAccent : Theme.textDim
    }

    MouseArea {
        id: area
        property real dragValue: 0
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: mouse => {
            dragValue = at(mouse.x);
            track.moved(dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            dragValue = at(mouse.x);
            track.moved(dragValue);
        }
        onWheel: wheel => track.moved(Math.max(0, Math.min(1, track.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
