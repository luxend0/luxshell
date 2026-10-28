import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content of the "Option types" page: chips you drag into another order.
// Contract of "custom" rows (OptionRow sets opt and row; keys are forwarded when
// the functions exist): activate() Enter/Space, adjust(d) Left/Right, navigate(d, mods)
// Up/Down inside the row (false = leave it), enter(d) focus arrives from above (1) / below (-1).
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    readonly property var zones: opt ? opt.value() : []
    readonly property var names: ({
            "clock": "Clock",
            "media": "Media",
            "status": "Status"
        })
    readonly property real chipWidth: 132
    readonly property real step: chipWidth + 10
    property int dragFrom: -1
    property int dragTo: -1
    property int cursor: 0

    implicitHeight: 48

    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || to >= zones.length)
            return;
        const z = zones.slice();
        z.splice(to, 0, z.splice(from, 1)[0]);
        opt.set(z);
    }
    function activate(): bool {
        cursor = (cursor + 1) % Math.max(1, zones.length);
        return true;
    }
    function adjust(d: int): bool {
        const to = cursor + d;
        if (to < 0 || to >= zones.length)
            return d > 0; // Left at the start: back to the sidebar
        move(cursor, to);
        cursor = to;
        return true;
    }

    Repeater {
        model: root.zones

        Rectangle {
            id: chip
            required property var modelData
            required property int index
            readonly property bool dragged: root.dragFrom === index
            // slot while another chip is dragged over this one
            readonly property int slot: {
                if (root.dragFrom < 0 || dragged)
                    return index;
                if (root.dragFrom < index && root.dragTo >= index)
                    return index - 1;
                if (root.dragFrom > index && root.dragTo <= index)
                    return index + 1;
                return index;
            }

            width: root.chipWidth
            height: 44
            radius: 12
            y: 2
            z: dragged ? 2 : 1
            color: dragged ? Theme.mix(root.g.field, Theme.text, 0.12) : root.g.field
            border.width: root.row && root.row.focused && root.cursor === index ? 2 : 0
            border.color: root.g.ring
            Binding on x {
                when: !chip.dragged
                value: chip.slot * root.step
            }
            Behavior on x {
                enabled: !chip.dragged
                Anim {
                    ms: 180
                }
            }

            SText {
                anchors.centerIn: parent
                text: root.names[chip.modelData] ?? chip.modelData
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: chip
                drag.axis: Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: (root.zones.length - 1) * root.step
                onPressed: {
                    root.cursor = chip.index;
                    root.dragFrom = chip.index;
                    root.dragTo = chip.index;
                }
                onPositionChanged: if (pressed)
                    root.dragTo = Math.max(0, Math.min(root.zones.length - 1, Math.round(chip.x / root.step)))
                onReleased: {
                    const from = root.dragFrom, to = root.dragTo;
                    root.dragFrom = -1;
                    root.dragTo = -1;
                    root.cursor = to;
                    root.move(from, to);
                }
            }
        }
    }
}
