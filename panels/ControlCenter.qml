import QtQuick
import qs.config
import qs.services
import qs.widgets

// Placeholder with the geometry of ref/08 (686x686). Display only: nothing
// here changes system state yet, that is module 2.
PanelBase {
    id: root

    preferredWidth: 686
    preferredHeight: 686

    readonly property int pad: 20
    readonly property int gap: 16
    readonly property int rowH: 78
    readonly property int tileW: (preferredWidth - 2 * pad - rowH - 2 * gap) / 2

    component Tile: Rectangle {
        id: tile
        property string icon
        property string label
        property string sub
        property bool on: false
        width: root.tileW
        height: root.rowH
        radius: height / 2
        color: Theme.surface

        Rectangle {
            id: disc
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 54
            height: 54
            radius: 27
            color: tile.on ? Theme.accent : Theme.surfaceHigh
            Icon {
                anchors.centerIn: parent
                name: tile.icon
                size: 20
                color: tile.on ? Theme.onAccent : Theme.textSecondary
            }
        }
        Column {
            anchors.left: disc.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Txt {
                text: tile.label
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Txt {
                text: tile.sub
                font.pixelSize: 14
                color: Theme.textDim
            }
        }
    }

    component Round: Rectangle {
        property string icon
        property bool on: false
        width: root.rowH
        height: root.rowH
        radius: width / 2
        color: on ? Theme.accent : Theme.surface
        Icon {
            anchors.centerIn: parent
            name: parent.icon
            size: 20
            color: parent.on ? Theme.onAccent : Theme.textSecondary
            filled: parent.on
        }
    }

    component SliderCard: Rectangle {
        id: card
        property string label
        property string icon
        property real value: 0
        width: root.preferredWidth - 2 * root.pad
        height: root.rowH
        radius: 24
        color: Theme.surface

        Txt {
            x: 18
            y: 12
            text: card.label
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 8
            width: 30
            height: 30
            radius: 15
            color: Theme.surfaceHigh
            opacity: 0.6
            Icon {
                anchors.centerIn: parent
                name: "chevron-right"
                size: 14
                color: Theme.textSecondary
            }
        }
        Rectangle {
            id: track
            x: 12
            y: 38
            width: parent.width - 24
            height: 32
            radius: 16
            color: Qt.darker(Theme.surface, 2)
            Rectangle {
                width: Math.max(height, track.width * card.value)
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
            Icon {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                name: card.icon
                size: 16
                color: Theme.onAccent
            }
        }
    }

    Column {
        x: root.pad
        y: root.pad
        spacing: root.gap + 1

        Row {
            spacing: root.gap
            Tile {
                icon: Net.kind === "wifi" ? "wifi" : "ethernet"
                label: Net.kind === "wifi" ? "Wi-Fi" : "Network"
                sub: Net.label
                on: Net.kind !== "offline"
            }
            Tile {
                icon: "circle-minus"
                label: "Focus"
                sub: "Off"
            }
            Round {
                icon: "lock"
            }
        }
        Row {
            spacing: root.gap
            Tile {
                icon: "bluetooth"
                label: "Bluetooth"
                sub: "On"
                on: true
            }
            Tile {
                icon: "toggle-left"
                label: "Game Mode"
                sub: "Off"
            }
            Round {
                icon: "moon"
                on: true
            }
        }
        SliderCard {
            label: "Sound"
            icon: Audio.icon
            value: Audio.volume
        }
        SliderCard {
            label: "Display"
            icon: "sun"
            value: 0.5
        }
        Rectangle {
            width: root.preferredWidth - 2 * root.pad
            height: root.preferredHeight - root.pad - y - 18
            radius: 24
            color: Theme.surface
            Column {
                x: 18
                y: 16
                spacing: 12
                Txt {
                    text: "Notifications"
                    font.pixelSize: 14
                    color: Theme.textDim
                }
                Txt {
                    text: Notifs.count === 0 ? "No notifications" : Notifs.status
                    font.pixelSize: 17
                    color: Theme.textDim
                }
            }
        }
    }
}
