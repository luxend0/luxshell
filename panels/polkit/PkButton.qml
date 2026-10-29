import QtQuick
import qs.config
import qs.widgets

// Quiet pill button of the polkit prompt (Cancel, Details): the lock screen's translucent
// fill, a step lighter under the pointer. `flat`: no fill until hovered. Optional chevron
// after the label (Details), turned by `turn` (0 .. 1 = down .. up).
Item {
    id: root

    property string text: ""
    property bool flat: false
    property string chevron: ""
    property real turn: 0
    readonly property QtObject g: Theme.lock
    readonly property QtObject p: Theme.polkit

    signal clicked

    implicitWidth: row.width + 2 * p.buttonPadX
    implicitHeight: p.buttonHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, area.containsMouse ? root.p.buttonHover : root.flat ? 0 : root.p.buttonFill)
        Behavior on color {
            ColorAnimation {
                duration: Motion.ms(120)
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.g.fg(area.containsMouse || !root.flat ? 0.92 : 0.62)
            font.family: Theme.fontFamily
            font.pixelSize: root.p.buttonSize
            font.weight: Font.Medium
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.chevron !== ""
            name: root.chevron !== "" ? root.chevron : "chevron-down"
            size: 15
            stroke: 2.2
            color: root.g.fg(area.containsMouse ? 0.92 : 0.62)
            rotation: 180 * root.turn
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
