import QtQuick
import qs.config
import qs.widgets

// Bottom toast of the settings window ("Reset 3 options  Undo"), from SettingsApp.toast().
// Stays 10 s (longer while hovered); Undo restores the snapshot taken before the change.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property bool shown: false

    Connections {
        target: SettingsApp
        function onToastSeqChanged() {
            root.shown = SettingsApp.toastText !== "";
            if (root.shown)
                life.restart();
        }
    }
    Timer {
        id: life
        interval: 10000
        onTriggered: if (hover.hovered)
            restart();
        else
            root.shown = false
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - root.g.toastBottom : parent.height + 8
        width: content.implicitWidth + 36
        height: root.g.toastHeight
        radius: height / 2
        color: root.g.tip
        border.width: 1
        border.color: root.g.separator
        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on y {
            Anim {
                ms: 260
            }
        }
        Behavior on opacity {
            Anim {
                ms: 200
            }
        }
        HoverHandler {
            id: hover
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 18
            SText {
                anchors.verticalCenter: parent.verticalCenter
                size: 15
                text: SettingsApp.toastText
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                visible: SettingsApp.toastUndo !== null
                size: 15
                font.weight: Font.DemiBold
                text: "Undo"
                color: undo.containsMouse ? Theme.text : Theme.accent
                MouseArea {
                    id: undo
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        SettingsApp.undoToast();
                        root.shown = false;
                    }
                }
            }
        }
    }
}
