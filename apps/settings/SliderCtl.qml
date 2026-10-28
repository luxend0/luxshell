import QtQuick
import qs.config
import qs.widgets

// Slim slider of a settings row: track, accent fill, knob. Dragging shows the value
// live and commits through a short debounce (every commit writes settings.json).
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property real value: 0
    property real min: 0
    property real max: 1
    property real step: 0.1
    property bool enabled: true
    signal commit(real v)

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    readonly property real ratio: max > min ? Math.max(0, Math.min(1, (shown - min) / (max - min))) : 0

    implicitHeight: g.sliderKnob + 10

    function snap(v: real): real {
        const s = Math.round((v - min) / step) * step + min;
        return Math.max(min, Math.min(max, Math.round(s * 1000) / 1000));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.g.trackHeight
        radius: height / 2
        color: root.g.switchOff

        Rectangle {
            width: Math.max(height, knob.x + knob.width / 2)
            height: parent.height
            radius: height / 2
            color: root.enabled ? Theme.accent : Theme.muted
        }
    }

    Rectangle {
        id: knob
        width: root.g.sliderKnob
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.ratio * (root.width - width)
        color: Theme.text
        scale: area.pressed ? 1.12 : area.containsMouse ? 1.06 : 1
        Behavior on scale {
            Anim {
                ms: Theme.fadeOut
            }
        }
        Behavior on x {
            enabled: !root.dragging
            Anim {
                ms: 160
            }
        }
    }

    Timer {
        id: debounce
        interval: 140
        onTriggered: root.commit(root.dragValue)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function at(mx: real): real {
            const r = (mx - knob.width / 2) / Math.max(1, root.width - knob.width);
            return root.snap(root.min + Math.max(0, Math.min(1, r)) * (root.max - root.min));
        }
        onPressed: mouse => {
            root.dragValue = at(mouse.x);
            root.dragging = true;
            debounce.restart();
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const v = at(mouse.x);
            if (v !== root.dragValue) {
                root.dragValue = v;
                debounce.restart();
            }
        }
        onReleased: {
            debounce.stop();
            root.commit(root.dragValue);
            root.dragging = false;
        }
        onCanceled: {
            debounce.stop();
            root.dragging = false;
        }
    }
}
