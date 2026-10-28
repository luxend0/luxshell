import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Mutually exclusive choices (the editor's Collapsed | Hover | Both, the widget options).
// In one pill with a sliding plate while they fit maxWidth; otherwise as wrapping pills.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject e: Theme.islandEditor
    property var items: []            // [{ value, label }]
    property var value: ""
    property real textSize: 14
    property real pad: e.segPad
    property real maxWidth: 100000
    signal picked(var value)

    readonly property int current: items.findIndex(i => i.value === value)
    readonly property bool wraps: pill.implicitWidth > maxWidth

    implicitWidth: wraps ? maxWidth : pill.implicitWidth
    implicitHeight: wraps ? flow.implicitHeight : e.segHeight

    // ---- one pill ----
    Rectangle {
        id: pill
        visible: !root.wraps
        implicitWidth: row.width + 6
        width: implicitWidth
        height: root.e.segHeight
        radius: root.e.segRadius
        color: root.g.field

        Rectangle {
            id: plate
            visible: root.current >= 0
            readonly property Item target: root.current >= 0 ? rep.itemAt(root.current) : null
            x: target ? row.x + target.x : 0
            y: 3
            width: target ? target.width : 0
            height: parent.height - 6
            radius: pill.radius - 3
            color: Theme.mix(root.g.field, Theme.text, 0.14)
            Behavior on x {
                Anim {
                    ms: 200
                }
            }
            Behavior on width {
                Anim {
                    ms: 200
                }
            }
        }

        Row {
            id: row
            x: 3
            height: parent.height

            Repeater {
                id: rep
                model: root.items

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    width: label.implicitWidth + 2 * root.pad
                    height: row.height

                    SText {
                        id: label
                        anchors.centerIn: parent
                        size: root.textSize
                        text: seg.modelData.label
                        color: seg.index === root.current || area.containsMouse ? root.g.label : root.g.value
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(seg.modelData.value)
                    }
                }
            }
        }
    }

    // ---- wrapping pills ----
    Flow {
        id: flow
        visible: root.wraps
        width: root.maxWidth
        spacing: 6

        Repeater {
            model: root.wraps ? root.items : []

            Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool on: index === root.current
                width: chipLabel.implicitWidth + 2 * Math.min(root.pad, 10)
                height: root.e.segHeight - 4
                radius: root.e.segRadius - 2
                color: on ? Theme.mix(root.g.field, Theme.text, 0.14) : chipArea.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.07) : root.g.field

                SText {
                    id: chipLabel
                    anchors.centerIn: parent
                    size: root.textSize
                    text: chip.modelData.label
                    color: chip.on || chipArea.containsMouse ? root.g.label : root.g.value
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(chip.modelData.value)
                }
            }
        }
    }
}
