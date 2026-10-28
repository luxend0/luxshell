import QtQuick
import Quickshell.Widgets
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content: a list of hidden things (launcher apps, media players), one line each
// with a remove button, then "Add ..." which opens the row's dropdown (filterable) with
// everything that can still be hidden. Value: array of ids (opt.value() / opt.set()).
//
// Option fields besides the usual ones:
//   candidates()  [{ value, label, detail, icon }] that can be hidden (icon: image URL or "")
//   addLabel      text of the add button ("Hide an app")
//   emptyText     line shown while nothing is hidden
//   describe(v)   { label, detail, icon } for a hidden id that is not a candidate right now
// Keys: Up/Down walk the lines, Delete removes the one under the cursor, Enter on the last
// line opens the dropdown.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    property int cursor: -1
    readonly property var value: opt ? Array.from(opt.value() ?? []) : []
    readonly property var candidates: opt && opt.candidates ? opt.candidates() : []

    function info(v: string): var {
        const c = candidates.find(x => x.value === v);
        if (c)
            return c;
        const d = opt && opt.describe ? opt.describe(v) : null;
        return d ?? {
            "label": v,
            "detail": "",
            "icon": ""
        };
    }
    function summary(): string {
        return value.length === 0 ? "None" : `${value.length} hidden`;
    }
    function add(v: string): void {
        if (v === "" || value.includes(v))
            return;
        const n = value.length;
        opt.set([...value, v]);
        cursor = n + 1; // stay on the add line
    }
    function remove(i: int): void {
        opt.set(value.filter((_, j) => j !== i));
        cursor = Math.min(cursor, value.length - 1);
    }
    function openAdd(): void {
        if (!host || !row)
            return;
        const taken = value;
        host.openMenu(row, {
            "kind": "choice",
            "searchable": true,
            "options": () => root.candidates.filter(c => !taken.includes(c.value)).map(c => ({
                        "value": c.value,
                        "label": c.label,
                        "detail": c.detail ?? ""
                    })),
            "value": () => "",
            "set": v => root.add(v)
        });
    }

    // keyboard (OptionRow forwards)
    function focusRect(): var {
        return cursor < 0 ? null : {
            "y": Math.max(0, cursor) * g.listRow,
            "h": g.listRow
        };
    }
    function enter(d: int): void {
        cursor = d > 0 ? 0 : value.length;
    }
    function navigate(d: int, mods: int): bool {
        const j = cursor + d;
        if (j < 0 || j > value.length)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor === value.length || cursor < 0)
            openAdd();
        return true;
    }
    function deleteKey(): bool {
        if (cursor >= 0 && cursor < value.length) {
            remove(cursor);
            return true;
        }
        return false;
    }

    Repeater {
        model: root.value

        Item {
            id: line
            required property string modelData
            required property int index
            readonly property var it: root.info(modelData)

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
                visible: root.row && root.row.focused && root.cursor === line.index
            }
            IconImage {
                id: icon
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                visible: (line.it.icon ?? "") !== ""
                source: line.it.icon ?? ""
                asynchronous: true
            }
            MdIcon {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: !icon.visible
                glyph: Catalog.glyph(0xF06D1) // md-eye-off-outline
                size: 20
                color: root.g.icon
            }
            SText {
                id: name
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, rm.x - x - 12)
                elide: Text.ElideRight
                text: line.it.label
            }
            SText {
                x: name.x + name.width + 12
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, rm.x - x - 12)
                elide: Text.ElideMiddle
                size: 14
                text: line.it.detail ?? ""
                color: root.g.caption
            }
            MiniButton {
                id: rm
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(0xF0156) // md-close
                onClicked: root.remove(line.index)
            }
        }
    }

    // add line
    Item {
        width: root.width
        height: root.g.listRow + 4

        Rectangle {
            visible: root.value.length > 0
            width: parent.width
            height: 1
            color: root.g.separator
        }
        SText {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value.length === 0
            width: add.x - x - 12
            elide: Text.ElideRight
            text: root.opt?.emptyText ?? "Nothing hidden"
            color: root.g.value
        }
        MiniButton {
            id: add
            x: root.value.length === 0 ? parent.width - width : 0
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.g.fieldHeight
            text: root.opt?.addLabel ?? "Add"
            active: root.candidates.some(c => !root.value.includes(c.value))
            border.width: root.row && root.row.focused && root.cursor === root.value.length ? 2 : 0
            border.color: root.g.ring
            onClicked: root.openAdd()
        }
    }
}
