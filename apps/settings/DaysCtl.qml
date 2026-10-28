import QtQuick
import qs.config
import qs.widgets
import qs.services

// Weekday discs in the system's week order (English names like the clock). value: ISO days, 1 = Monday ... 7 = Sunday.
// Keys (row): Left/Right walk the days, Enter/Space switch one.
Row {
    id: root

    readonly property QtObject g: Theme.settings
    property var value: []
    property var owner: null   // the OptionRow
    property int cursor: 0
    signal changed(var days)

    // ISO numbers in display order
    readonly property var order: {
        const first = Qt.locale().firstDayOfWeek; // 0 = Sunday
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = (first + i) % 7;
            out.push(d === 0 ? 7 : d);
        }
        return out;
    }

    spacing: g.dayGap

    function toggle(i: int): void {
        const d = order[i];
        const v = value.includes(d) ? value.filter(x => x !== d) : [...value, d];
        changed(v.sort((a, b) => a - b));
    }
    function adjust(d: int): bool {
        const j = cursor + d;
        if (j < 0)
            return false;
        cursor = Math.min(6, j);
        return true;
    }
    function activate(): bool {
        toggle(cursor);
        return true;
    }

    Repeater {
        model: root.order

        Rectangle {
            id: day
            required property int modelData
            required property int index
            readonly property bool on: root.value.includes(modelData)

            width: root.g.day
            height: width
            radius: width / 2
            color: on ? Theme.accent : area.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.08) : root.g.field
            border.width: root.owner && root.owner.focused && root.cursor === index ? 2 : 0
            border.color: root.g.ring
            Behavior on color {
                ColorAnim {}
            }

            SText {
                anchors.centerIn: parent
                size: 14
                text: Clock.locale.dayName(day.modelData % 7, Locale.NarrowFormat)
                color: day.on ? Theme.onAccent : root.g.value
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.cursor = day.index;
                    root.toggle(day.index);
                }
            }
        }
    }
}
