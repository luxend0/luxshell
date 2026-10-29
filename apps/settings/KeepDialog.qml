import QtQuick
import qs.config
import qs.widgets

// "Keep these settings?" over the settings window (SettingsApp.askKeep): the change is
// already live, a line drains over the countdown (default 15 s), then it is reverted.
// Keep / Revert buttons; keys: Left/Right/Tab pick a button, Enter/Space press it, Esc
// reverts. The keyboard starts on Revert, so a stray Enter on a broken screen undoes.
// The window dims behind it and takes no clicks until it is answered.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.settingsSys
    readonly property var req: SettingsApp.keepRequest
    readonly property bool shown: req !== null
    property bool kb: false
    property int focusButton: 0 // 0 = Revert, 1 = Keep
    property real progress: 1   // 1 -> 0 over req.seconds
    property var last: null     // the request shown while fading out

    visible: shown || card.opacity > 0.01

    function restart(): void {
        if (SettingsApp.keepRequest) {
            last = SettingsApp.keepRequest;
            focusButton = 0;
            count.stop();
            progress = 1;
            count.duration = Math.max(1, req.seconds) * 1000;
            count.start();
        } else {
            count.stop();
        }
    }
    Connections {
        target: SettingsApp
        function onKeepSeqChanged() {
            root.restart();
        }
    }
    // asked while the window was closed: the request came before this item
    Component.onCompleted: restart()

    // real seconds: no Motion slow-motion factor on a safety countdown
    NumberAnimation {
        id: count
        target: root
        property: "progress"
        from: 1
        to: 0
        onFinished: if (root.shown)
            SettingsApp.settleKeep(false)
    }

    readonly property var view: req ?? last ?? ({})
    readonly property int secondsLeft: Math.max(0, Math.ceil(progress * (view.seconds ?? 15) - 0.001))

    function key(event): void {
        switch (event.key) {
        case Qt.Key_Escape:
            return SettingsApp.settleKeep(false);
        case Qt.Key_Left:
            focusButton = 0;
            return;
        case Qt.Key_Right:
            focusButton = 1;
            return;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            focusButton = 1 - focusButton;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            return SettingsApp.settleKeep(focusButton === 1);
        }
    }

    // dim the window, swallow every click and wheel turn behind the card
    Rectangle {
        anchors.fill: parent
        radius: root.g.radius
        color: root.s.scrim
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: 200
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.shown
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.s.keepWidth
        height: col.height + 2 * root.s.keepPad
        radius: root.s.keepRadius
        color: root.s.keepCard
        border.width: 1
        border.color: root.g.separator
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
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

        Column {
            id: col
            x: root.s.keepPad
            y: root.s.keepPad
            width: card.width - 2 * root.s.keepPad
            spacing: 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.s.keepDisc
                height: width
                radius: width / 2
                color: root.g.selected
                MdIcon {
                    anchors.centerIn: parent
                    glyph: typeof root.view.icon === "number" ? String.fromCodePoint(root.view.icon) : (root.view.icon ?? "")
                    size: root.s.keepIconSize
                    color: root.g.icon
                }
            }
            Item {
                width: 1
                height: 16
            }
            SText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                size: root.s.keepTitleSize
                font.weight: Font.DemiBold
                text: root.view.title ?? ""
                color: root.g.label
            }
            Item {
                width: 1
                height: 8
            }
            SText {
                visible: text !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                size: 15
                lineHeight: 1.1
                text: root.view.text ?? ""
                color: root.g.value
            }
            Item {
                visible: (root.view.text ?? "") !== ""
                width: 1
                height: 6
            }
            SText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                size: 15
                text: root.secondsLeft === 1 ? "Reverting in 1 second" : `Reverting in ${root.secondsLeft} seconds`
                color: root.g.value
                font.features: {
                    "tnum": 1
                }
            }
            Item {
                width: 1
                height: 18
            }

            // countdown line
            Rectangle {
                width: parent.width
                height: root.s.keepTrack
                radius: height / 2
                color: root.s.keepTrackColor
                Rectangle {
                    width: Math.max(parent.height, parent.width * root.progress)
                    height: parent.height
                    radius: height / 2
                    color: root.s.keepFill
                    opacity: root.progress > 0 ? 1 : 0
                }
            }
            Item {
                width: 1
                height: 22
            }

            Row {
                anchors.right: parent.right
                spacing: root.s.keepButtonGap

                Pill {
                    text: root.view.revertLabel ?? "Revert"
                    ring: root.kb && root.focusButton === 0
                    onClicked: SettingsApp.settleKeep(false)
                }
                Pill {
                    text: root.view.keepLabel ?? "Keep"
                    primary: true
                    ring: root.kb && root.focusButton === 1
                    onClicked: SettingsApp.settleKeep(true)
                }
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        property string text: ""
        property bool primary: false
        property bool ring: false
        signal clicked

        width: Math.max(96, label.implicitWidth + 36)
        height: root.s.keepButtonHeight
        radius: height / 2
        color: primary ? (area.containsMouse ? Theme.mix(Theme.accent, Theme.text, 0.2) : Theme.accent) : Theme.mix(root.s.keepCard, Theme.text, area.containsMouse ? 0.14 : 0.08)
        Behavior on color {
            ColorAnim {
                ms: Theme.fadeOut
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: root.g.ring
            visible: pill.ring
        }
        SText {
            id: label
            anchors.centerIn: parent
            size: 15
            font.weight: pill.primary ? Font.DemiBold : Font.Medium
            text: pill.text
            color: pill.primary ? Theme.island : root.g.label
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.shown
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }
}
