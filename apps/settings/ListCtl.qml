import QtQuick
import qs.config
import qs.widgets

// "list" row content: entries in their order, each with up/down and a switch.
// value() = the enabled values in order (disabled ones follow in items() order);
// toggle: false = order only (value holds every item, no switches).
// Keys: Up/Down walk the entries, Shift+Up/Down move the entry, Enter/Space switch it.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var owner: null   // the OptionRow
    property int cursor: -1
    readonly property bool toggles: opt?.toggle !== false
    readonly property var all: opt ? opt.items() : []
    readonly property var value: opt ? opt.value() : []
    readonly property var entries: {
        const byId = {};
        for (const it of all)
            byId[it.value] = it;
        const on = value.filter(v => byId[v] !== undefined).map(v => Object.assign({ "on": true }, byId[v]));
        const off = toggles ? all.filter(it => !value.includes(it.value)).map(it => Object.assign({ "on": false }, it)) : [];
        return on.concat(off);
    }
    readonly property int onCount: entries.filter(e => e.on).length

    function summary(): string {
        return toggles ? `${onCount} of ${all.length}` : `${all.length}`;
    }
    function toggle(i: int): void {
        const e = entries[i];
        if (!e || !toggles)
            return;
        opt.set(e.on ? value.filter(v => v !== e.value) : [...value.filter(v => entries.some(x => x.on && x.value === v)), e.value]);
    }
    function move(i: int, d: int): bool {
        const e = entries[i];
        const j = i + d;
        if (!e || !e.on || j < 0 || j >= onCount)
            return false;
        const v = entries.filter(x => x.on).map(x => x.value);
        v.splice(j, 0, v.splice(i, 1)[0]);
        opt.set(v);
        cursor = j;
        return true;
    }

    // keyboard (OptionRow forwards)
    function focusRect(): var {
        return cursor < 0 ? null : {
            "y": cursor * g.listRow,
            "h": g.listRow
        };
    }
    function enter(d: int): void {
        cursor = d > 0 ? 0 : entries.length - 1;
    }
    function navigate(d: int, mods: int): bool {
        if (mods & Qt.ShiftModifier) {
            move(cursor, d);
            return true;
        }
        const j = cursor + d;
        if (j < 0 || j >= entries.length)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor < 0)
            cursor = 0;
        toggle(cursor);
        return true;
    }

    Repeater {
        model: root.entries

        Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: root.owner && root.owner.focused && root.cursor === index

            width: root.width
            height: root.g.listRow

            Rectangle {
                visible: line.index > 0
                width: parent.width
                height: 1
                color: root.g.separator
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 10
                color: "transparent"
                border.width: 2
                border.color: root.g.ring
                visible: line.current
            }

            MdIcon {
                id: icon
                visible: (line.modelData.icon ?? "") !== ""
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                glyph: line.modelData.icon ?? ""
                size: 20
                color: line.modelData.on ? root.g.icon : Theme.mix(root.g.icon, root.g.card, 0.5)
            }
            SText {
                x: icon.visible ? 38 : 4
                anchors.verticalCenter: parent.verticalCenter
                width: buttons.x - x - 12
                elide: Text.ElideRight
                text: line.modelData.label
                color: line.modelData.on ? root.g.label : root.g.value
            }

            Row {
                id: buttons
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MiniButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: line.modelData.on
                    glyph: Catalog.glyph(0xF0143) // md-chevron-up
                    active: line.index > 0
                    onClicked: root.move(line.index, -1)
                }
                MiniButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: line.modelData.on
                    glyph: Catalog.glyph(0xF0140) // md-chevron-down
                    active: line.index < root.onCount - 1
                    onClicked: root.move(line.index, 1)
                }
                Item {
                    visible: root.toggles
                    width: 8
                    height: 1
                }
                SwitchCtl {
                    visible: root.toggles
                    anchors.verticalCenter: parent.verticalCenter
                    on: line.modelData.on
                    hovered: sw.containsMouse
                    MouseArea {
                        id: sw
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cursor = line.index;
                            root.toggle(line.index);
                        }
                    }
                }
            }
        }
    }
}
