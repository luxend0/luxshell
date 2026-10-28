import QtQuick
import qs.config
import qs.services
import qs.widgets

// Password field: a quiet translucent pill in place of the hint line. One dot per
// character (they pop in), "Enter Password" while empty, ⇧ glyph at the right end while
// Caps Lock is on. Checking: the dots breathe. Wrong password: a short damped shake
// (services/Lock already emptied the buffer).
Item {
    id: root

    property bool shown: false
    readonly property QtObject g: Theme.lock
    readonly property bool checking: Lock.phase === "checking" || Lock.phase === "unlocking"
    readonly property real capsRoom: Lock.caps ? g.capsSize + 10 : 0
    readonly property int maxDots: Math.max(0, Math.floor((g.pillWidth - 2 * 22 - capsRoom + g.dotGap) / (g.dotSize + g.dotGap)))
    property real shake: 0

    width: g.pillWidth
    height: g.pillHeight
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    visible: opacity > 0
    transform: Translate {
        x: root.shake
    }

    Behavior on opacity {
        Anim {
            ms: root.g.pillIn
        }
    }
    Behavior on scale {
        Anim {
            ms: root.g.pillIn
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, root.g.pillFill)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, root.g.pillStroke)
    }

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.capsRoom / 2
        text: "Enter Password"
        color: root.g.fg(root.g.hintAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.pillTextSize
        font.weight: Font.Medium
        opacity: Lock.buffer === "" && !root.checking ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: 120
            }
        }
    }

    Row {
        id: dots
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.capsRoom / 2
        spacing: root.g.dotGap

        Repeater {
            model: Math.min(Lock.buffer.length, root.maxDots)

            Rectangle {
                id: dot
                width: root.g.dotSize
                height: width
                radius: width / 2
                color: root.g.fg(0.95)
                scale: 0
                Component.onCompleted: pop.start()
                Anim {
                    id: pop
                    target: dot
                    property: "scale"
                    to: 1
                    ms: 140
                }
            }
        }

        // checking: breathe
        SequentialAnimation on opacity {
            running: root.checking
            loops: Animation.Infinite
            alwaysRunToEnd: false
            NumberAnimation {
                to: 0.35
                duration: Motion.ms(380)
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: Motion.ms(380)
                easing.type: Easing.InOutSine
            }
            onRunningChanged: if (!running)
                dots.opacity = 1
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: "arrow-big-up"
        size: root.g.capsSize
        stroke: 2
        color: root.g.fg(0.8)
        opacity: Lock.caps ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: 160
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        readonly property real a: root.g.shake
        NumberAnimation { target: root; property: "shake"; to: -shakeAnim.a; duration: Motion.ms(55); easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "shake"; to: shakeAnim.a * 0.85; duration: Motion.ms(90); easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: -shakeAnim.a * 0.6; duration: Motion.ms(85); easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: shakeAnim.a * 0.35; duration: Motion.ms(80); easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: -shakeAnim.a * 0.12; duration: Motion.ms(70); easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: Motion.ms(60); easing.type: Easing.OutSine }
    }

    Connections {
        target: Lock
        function onFailed(): void {
            shakeAnim.restart();
        }
    }
}
