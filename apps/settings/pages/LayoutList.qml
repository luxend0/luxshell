import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.apps.settings

// Custom row content (Settings > Input > Layouts): the keyboard layouts in their order, one
// line each with a keycap of its code, the layout name, its variant (dropdown), up / down /
// remove; "Add layout" opens a filterable dropdown of every XKB layout (services/Xkb).
// Value: [{ layout: "de", variant: "" }, { layout: "us", variant: "intl" }] (opt.value / opt.set);
// at least one layout stays, XKB takes at most four.
// Keys: Up/Down walk the lines, Shift+Up/Down move a layout, Enter opens the variant list
// (on the last line: add), Delete removes the layout under the cursor.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    property int cursor: -1
    readonly property int maxLayouts: 4
    readonly property var value: opt ? Array.from(opt.value() ?? []) : []

    function summary(): string {
        return value.map(v => v.layout + (v.variant ? `(${v.variant})` : "")).join(", ");
    }
    function put(list: var): void {
        if (list.length > 0)
            opt.set(list);
    }
    function add(layout: string): void {
        if (layout === "" || value.length >= maxLayouts)
            return;
        put([...value, {
                "layout": layout,
                "variant": ""
            }]);
        cursor = value.length + 1;
    }
    function remove(i: int): void {
        if (value.length <= 1)
            return;
        put(value.filter((_, j) => j !== i));
        cursor = Math.min(cursor, value.length - 2);
    }
    function move(i: int, d: int): bool {
        const j = i + d;
        if (i < 0 || i >= value.length || j < 0 || j >= value.length)
            return false;
        const v = value.slice();
        v.splice(j, 0, v.splice(i, 1)[0]);
        put(v);
        cursor = j;
        return true;
    }
    function setVariant(i: int, variant: string): void {
        const v = value.map(x => Object.assign({}, x));
        v[i].variant = variant;
        put(v);
    }
    function variantLabel(layout: string, variant: string): string {
        if (variant === "")
            return "Standard";
        const it = Xkb.variants(layout).find(x => x.value === variant);
        if (!it)
            return variant;
        // "English (US, intl., with dead keys)" -> "intl., with dead keys" (the layout's own words dropped)
        const own = (/\((.*)\)$/.exec(Xkb.layoutName(layout)) ?? [])[1] ?? "";
        let inner = (/\((.*)\)$/.exec(it.label) ?? [])[1] ?? it.label;
        if (own !== "" && inner.startsWith(own + ", "))
            inner = inner.slice(own.length + 2);
        return inner;
    }
    function openVariants(i: int): void {
        const it = value[i];
        if (!it || !host || !row)
            return;
        const list = [{
                "value": "",
                "label": "Standard",
                "detail": ""
            }].concat(Xkb.variants(it.layout).map(x => ({
                    "value": x.value,
                    "label": x.label,
                    "detail": x.value
                })));
        host.openMenu(row, {
            "kind": "choice",
            "options": () => list,
            "value": () => it.variant,
            "set": v => root.setVariant(i, v)
        });
    }
    function openAdd(): void {
        if (!host || !row || value.length >= maxLayouts)
            return;
        const taken = value.map(v => v.layout);
        host.openMenu(row, {
            "kind": "choice",
            "searchable": true,
            "options": () => Xkb.layouts.filter(l => !taken.includes(l.value)).map(l => ({
                        "value": l.value,
                        "label": l.label,
                        "detail": l.value
                    })),
            "value": () => "",
            "set": v => root.add(v)
        });
    }

    Component.onCompleted: Xkb.load()

    // keyboard (OptionRow forwards)
    function focusRect(): var {
        return cursor < 0 ? null : {
            "y": cursor * g.listRow,
            "h": g.listRow
        };
    }
    function enter(d: int): void {
        cursor = d > 0 ? 0 : value.length;
    }
    function navigate(d: int, mods: int): bool {
        if ((mods & Qt.ShiftModifier) && cursor < value.length) {
            move(cursor, d);
            return true;
        }
        const j = cursor + d;
        if (j < 0 || j > value.length)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor < 0 || cursor >= value.length)
            openAdd();
        else
            openVariants(cursor);
        return true;
    }
    function deleteKey(): bool {
        if (cursor >= 0 && cursor < value.length && value.length > 1) {
            remove(cursor);
            return true;
        }
        return false;
    }

    Repeater {
        model: root.value

        Item {
            id: line
            required property var modelData
            required property int index

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

            // keycap with the layout code
            Rectangle {
                id: cap
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(38, code.implicitWidth + 16)
                height: 28
                radius: 7
                color: root.g.field
                border.width: 1
                border.color: root.g.separator
                SText {
                    id: code
                    anchors.centerIn: parent
                    size: 13
                    font.weight: Font.DemiBold
                    text: line.modelData.layout.toUpperCase()
                    color: root.g.label
                }
            }
            SText {
                id: name
                x: cap.x + cap.width + 14
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, variant.x - x - 16)
                elide: Text.ElideRight
                text: Xkb.layoutName(line.modelData.layout)
            }

            // variant (dropdown)
            Item {
                id: variant
                x: buttons.x - width - 14
                anchors.verticalCenter: parent.verticalCenter
                width: vRow.implicitWidth
                height: vRow.implicitHeight

                Row {
                    id: vRow
                    spacing: 4
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 200)
                        elide: Text.ElideRight
                        size: 15
                        text: root.variantLabel(line.modelData.layout, line.modelData.variant)
                        color: vArea.containsMouse ? root.g.label : root.g.value
                    }
                    MdIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Catalog.glyph(0xF0140) // md-chevron-down
                        size: root.g.arrowSize + 3
                        color: root.g.value
                    }
                }
                MouseArea {
                    id: vArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cursor = line.index;
                        root.openVariants(line.index);
                    }
                }
            }

            Row {
                id: buttons
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                MiniButton {
                    glyph: Catalog.glyph(0xF0143) // md-chevron-up
                    active: line.index > 0
                    onClicked: root.move(line.index, -1)
                }
                MiniButton {
                    glyph: Catalog.glyph(0xF0140) // md-chevron-down
                    active: line.index < root.value.length - 1
                    onClicked: root.move(line.index, 1)
                }
                MiniButton {
                    glyph: Catalog.glyph(0xF0156) // md-close
                    active: root.value.length > 1
                    onClicked: root.remove(line.index)
                }
            }
        }
    }

    // add line
    Item {
        width: root.width
        height: root.g.listRow + 4

        Rectangle {
            width: parent.width
            height: 1
            color: root.g.separator
        }
        MiniButton {
            id: addButton
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.g.fieldHeight
            text: "Add layout"
            active: root.value.length < root.maxLayouts
            border.width: root.row && root.row.focused && root.cursor === root.value.length ? 2 : 0
            border.color: root.g.ring
            onClicked: root.openAdd()
        }
        SText {
            x: addButton.width + 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            elide: Text.ElideRight
            size: 14
            text: root.value.length >= root.maxLayouts ? "XKB takes four layouts at most" : root.value.length > 1 ? "The first one is used at start" : ""
            color: root.g.caption
        }
    }
}
