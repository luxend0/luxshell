import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Segment bar of the Displays page (refresh rate, VRR, colour, mirror): mutually exclusive
// values in one plate with a sliding highlight, the look of the island editor's Segmented.
// stretch: the segments share the whole width; when the labels do not fit, the values wrap
// as separate plates. `cursor` rings one segment (keyboard), `hoverValue` tells what the
// mouse is over (live previews), `picked(value)` is a click.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject d: Theme.displays
    property var items: []            // [{ value, label }]
    property var value: undefined
    property int cursor: -1
    property bool stretch: false
    property bool active: true
    property real textSize: 15
    signal picked(var value)

    readonly property int current: items.findIndex(i => i.value === value)
    readonly property var hoverValue: {
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it && it.hot)
                return root.items[i]?.value;
        }
        for (let i = 0; i < flowRep.count; i++) {
            const it = flowRep.itemAt(i);
            if (it && it.hot)
                return root.items[i]?.value;
        }
        return undefined;
    }

    // natural width of one line: every label plus its padding
    readonly property real natural: {
        let w = 6;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it)
                w += it.need;
        }
        return w;
    }
    readonly property bool wraps: stretch ? natural > width + 0.5 : false

    implicitWidth: stretch ? 0 : natural
    implicitHeight: wraps ? flow.implicitHeight : d.segHeight
    opacity: active ? 1 : 0.45

    // ---- one plate ----
    Rectangle {
        id: plateBg
        visible: !root.wraps
        width: root.stretch ? root.width : root.natural
        height: root.d.segHeight
        radius: root.d.segRadius
        color: root.g.field

        Rectangle {
            id: plate
            visible: root.current >= 0
            readonly property Item target: root.current >= 0 ? rep.itemAt(root.current) : null
            x: target ? line.x + target.x : 0
            y: 3
            width: target ? target.width : 0
            height: parent.height - 6
            radius: plateBg.radius - 3
            color: root.d.plate
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
            id: line
            x: 3
            height: parent.height

            Repeater {
                id: rep
                model: root.items

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property real need: label.implicitWidth + 2 * root.d.segPad
                    readonly property bool hot: area.containsMouse && root.active
                    width: root.stretch ? (plateBg.width - 6) / Math.max(1, root.items.length) : need
                    height: line.height

                    SText {
                        id: label
                        anchors.centerIn: parent
                        size: root.textSize
                        text: seg.modelData.label
                        color: seg.index === root.current || seg.hot ? root.g.label : root.g.value
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: root.d.segRadius - 2
                        color: "transparent"
                        border.width: 2
                        border.color: root.g.ring
                        visible: root.cursor === seg.index
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.active
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(seg.modelData.value)
                    }
                }
            }
        }
    }

    // ---- wrapping plates (more values than fit in one line) ----
    Flow {
        id: flow
        visible: root.wraps
        width: root.width
        spacing: 6

        Repeater {
            id: flowRep
            model: root.wraps ? root.items : []

            Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool on: index === root.current
                readonly property bool hot: chipArea.containsMouse && root.active
                width: chipLabel.implicitWidth + 2 * root.d.segPad
                height: root.d.segHeight - 2
                radius: root.d.segRadius
                color: on ? root.d.plate : hot ? Theme.mix(root.g.field, Theme.text, 0.07) : root.g.field
                border.width: root.cursor === index ? 2 : 0
                border.color: root.g.ring

                SText {
                    id: chipLabel
                    anchors.centerIn: parent
                    size: root.textSize
                    text: chip.modelData.label
                    color: chip.on || chip.hot ? root.g.label : root.g.value
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(chip.modelData.value)
                }
            }
        }
    }
}
