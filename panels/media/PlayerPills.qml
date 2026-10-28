import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Player switch: one pill per player (app icon + name), the shown one filled. With a
// single player it is a plain label. Click = Media.select (luxshell-local, the player
// keeps playing); Tab in the panel cycles.
Row {
    id: root

    readonly property QtObject m: Theme.media
    readonly property var players: Media.players.slice(0, 3)
    readonly property bool multi: players.length > 1

    spacing: 6

    Repeater {
        model: root.players

        Rectangle {
            id: pill
            required property var modelData
            readonly property bool current: modelData === Media.active

            width: content.width + 2 * root.m.pillPad
            height: root.m.pillHeight
            radius: height / 2
            color: current && root.multi ? root.m.pill : area.containsMouse && root.multi ? root.m.chipHover : "transparent"
            Behavior on color {
                ColorAnim {}
            }

            Row {
                id: content
                x: root.m.pillPad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Item {
                    width: root.m.pillIcon
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property string path: Media.icon(pill.modelData)
                    IconImage {
                        anchors.fill: parent
                        visible: parent.path !== ""
                        source: parent.path
                        asynchronous: true
                    }
                    Glyph {
                        anchors.fill: parent
                        visible: parent.path === ""
                        name: "music"
                        size: parent.width
                        color: Theme.textSecondary
                    }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.name(pill.modelData)
                    font.pixelSize: root.m.pillSize
                    font.weight: Font.Medium
                    color: pill.current ? Theme.text : Theme.textDim
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                enabled: root.multi
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.select(pill.modelData)
            }
        }
    }
}
