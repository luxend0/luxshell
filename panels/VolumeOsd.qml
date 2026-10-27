import QtQuick
import qs.config
import qs.services
import qs.widgets

// Overlay placeholder (registry kind "overlay"): shown via Ui.flash("osd"),
// outranks hover, never takes focus. Module 5 will flash it on volume changes.
PanelBase {
    id: root

    preferredWidth: 380
    preferredHeight: 60
    cornerRadius: 26

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        spacing: 14

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.icon
            size: 20
            color: Theme.text
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            height: 6
            radius: 3
            color: Theme.surfaceHigh
            Rectangle {
                width: parent.width * Audio.volume
                height: parent.height
                radius: 3
                color: Theme.accent
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            text: Math.round(Audio.volume * 100)
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignRight
        }
    }
}
