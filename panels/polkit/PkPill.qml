import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.island.widgets

// Password pill of the polkit prompt: the lock screen's pill (lock/PasswordPill.qml) on the
// island. One dot per character (they pop in), the prompt as placeholder while empty, the
// Caps Lock glyph and a round submit disc at the right end once something is typed.
// Checking: the dots breathe. Wrong password: the damped shake of the lock screen.
// Success: the dots give way to a check. A visible-echo prompt (rare PAM steps) shows text.
Item {
    id: root

    readonly property QtObject g: Theme.lock
    readonly property QtObject p: Theme.polkit
    readonly property bool checking: Polkit.phase === "checking"
    readonly property bool success: Polkit.phase === "success"
    readonly property bool typed: Polkit.buffer !== ""
    readonly property real goRoom: typed && !success ? p.goSize + p.goInset : 0
    readonly property real capsRoom: Polkit.caps ? g.capsSize + 8 : 0
    readonly property real sideRoom: Math.max(goRoom + capsRoom, 0)
    readonly property int maxDots: Math.max(0, Math.floor((width - 2 * 22 - 2 * sideRoom + g.dotGap) / (g.dotSize + g.dotGap)))
    // "Password: " / "Passwort: " -> the lock screen's line; other prompts as polkit sends them
    readonly property string placeholder: {
        const t = Polkit.inputPrompt.trim().replace(/:$/, "").trim();
        return t === "" || /pass/i.test(t) ? "Enter Password" : t;
    }
    property real shake: 0

    signal submitClicked

    width: p.pillWidth
    height: p.pillHeight
    transform: Translate {
        x: root.shake
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
        width: parent.width - 2 * 20
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.placeholder
        color: root.g.fg(root.g.hintAlpha)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.pillTextSize
        font.weight: Font.Medium
        opacity: !root.typed && !root.checking && !root.success ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: 120
            }
        }
    }

    // visible echo (a non-secret PAM question): the text itself
    Text {
        anchors.centerIn: parent
        width: parent.width - 2 * 20 - 2 * root.sideRoom
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideLeft
        visible: Polkit.echo
        text: Polkit.buffer
        color: root.g.fg(0.95)
        font.family: Theme.fontFamily
        font.pixelSize: root.g.pillTextSize
        font.weight: Font.Medium
    }

    // dots: a ListModel synced to the buffer length, as on the lock screen (existing dots stay,
    // new ones pop in, deleted ones shrink away, the row glides to stay centred)
    ListModel {
        id: dotModel
    }
    function syncDots(): void {
        const n = Polkit.echo ? 0 : Math.min(Polkit.buffer.length, maxDots);
        while (dotModel.count < n)
            dotModel.append({});
        while (dotModel.count > n)
            dotModel.remove(dotModel.count - 1);
    }
    Connections {
        target: Polkit
        function onBufferChanged() {
            root.syncDots();
        }
        function onFailed() {
            shakeAnim.restart();
        }
    }
    onMaxDotsChanged: syncDots()
    Component.onCompleted: syncDots()

    ListView {
        id: dots
        readonly property real fullWidth: count > 0 ? count * root.g.dotSize + (count - 1) * root.g.dotGap : 0
        x: (parent.width - fullWidth) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, fullWidth)
        height: root.g.dotSize
        orientation: ListView.Horizontal
        spacing: root.g.dotGap
        interactive: false
        clip: false
        model: dotModel
        opacity: root.success ? 0 : 1
        Behavior on x {
            NumberAnimation {
                duration: Motion.ms(170)
                easing.type: Easing.OutCubic
            }
        }

        delegate: Rectangle {
            width: root.g.dotSize
            height: width
            radius: width / 2
            color: root.g.fg(0.95)
        }
        add: Transition {
            NumberAnimation {
                property: "scale"
                from: 0.2
                to: 1
                duration: Motion.ms(150)
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.ms(110)
            }
        }
        remove: Transition {
            NumberAnimation {
                properties: "scale,opacity"
                to: 0
                duration: Motion.ms(120)
                easing.type: Easing.InCubic
            }
        }

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
                dots.opacity = Qt.binding(() => root.success ? 0 : 1)
        }
    }

    // authorised
    Icon {
        anchors.centerIn: parent
        name: "check"
        size: 22
        stroke: 2.4
        color: root.g.fg(0.95)
        opacity: root.success ? 1 : 0
        scale: root.success ? 1 : 0.6
        Behavior on opacity {
            Anim {
                ms: 160
            }
        }
        Behavior on scale {
            Anim {
                ms: 220
            }
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: 14 + root.goRoom
        anchors.verticalCenter: parent.verticalCenter
        name: "arrow-big-up"
        size: root.g.capsSize
        stroke: 2
        color: root.g.fg(0.8)
        opacity: Polkit.caps && !root.success ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: 160
            }
        }
    }

    // submit disc
    Rectangle {
        id: go
        anchors.right: parent.right
        anchors.rightMargin: root.p.goInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.p.goSize
        height: width
        radius: width / 2
        color: goArea.containsMouse && !root.checking ? root.g.fg(0.3) : root.g.fg(0.18)
        opacity: root.typed && !root.success ? 1 : 0
        scale: root.typed ? 1 : 0.7
        visible: opacity > 0.01
        Behavior on opacity {
            Anim {
                ms: 160
            }
        }
        Behavior on scale {
            Anim {
                ms: 200
            }
        }

        WIcon {
            anchors.centerIn: parent
            name: "arrow-right"
            size: 16
            stroke: 2.4
            color: root.g.fg(0.95)
        }
        MouseArea {
            id: goArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submitClicked()
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
}
