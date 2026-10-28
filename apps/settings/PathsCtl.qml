import QtQuick
import Quickshell.Io
import qs.config
import qs.widgets

// "paths" row content: one line per path (missing ones marked) with remove, then a field
// to add one (Enter) and Browse (zenity, when installed). Paths under $HOME are kept as ~/...
// Keys: Up/Down walk the lines, Delete removes the path under the cursor, Enter on the
// last line edits the field.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var owner: null   // the OptionRow
    property var host: null
    property int cursor: -1
    readonly property var value: opt ? Array.from(opt.value()) : []
    readonly property string mode: opt?.mode ?? "folder"
    property var exists: ({})

    function summary(): string {
        const n = value.length;
        const what = mode === "folder" ? "folder" : "file";
        return n === 0 ? `No ${what}s` : `${n} ${what}${n === 1 ? "" : "s"}`;
    }
    function add(p: string): void {
        const v = Catalog.tilde(Catalog.expand(p.trim()).replace(/\/+$/, "") || "/");
        if (p.trim() === "" || value.includes(v))
            return;
        opt.set([...value, v]);
        cursor = value.length; // stay on the add line
    }
    function remove(i: int): void {
        opt.set(value.filter((_, j) => j !== i));
        cursor = Math.min(cursor, value.length - 1);
    }

    // which paths exist (re-checked whenever the list changes)
    onValueChanged: check()
    Component.onCompleted: check()
    function check(): void {
        if (value.length === 0)
            return;
        probe.command = ["sh", "-c", 'for p in "$@"; do [ -e "$p" ] && echo 1 || echo 0; done', "sh", ...value.map(p => Catalog.expand(p))];
        probe.running = true;
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                const flags = text.split("\n");
                const e = {};
                root.value.forEach((p, i) => e[p] = flags[i] === "1");
                root.exists = e;
            }
        }
    }

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
        const j = cursor + d;
        if (j < 0 || j > value.length)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor === value.length || cursor < 0)
            field.edit();
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
            readonly property bool missing: root.exists[modelData] === false

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
                visible: root.owner && root.owner.focused && root.cursor === line.index
            }
            MdIcon {
                id: icon
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(root.mode === "folder" ? 0xF024B : 0xF0214) // md-folder / md-file
                size: 20
                color: root.g.icon
            }
            SText {
                x: 38
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, tag.x - x - 10)
                elide: Text.ElideMiddle
                text: line.modelData
                color: line.missing ? root.g.value : root.g.label
            }
            SText {
                id: tag
                x: rm.x - (visible ? width + 12 : 0)
                anchors.verticalCenter: parent.verticalCenter
                visible: line.missing
                size: 14
                text: "missing"
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
        FieldCtl {
            id: field
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (browse.visible ? browse.width + 8 : 0)
            host: root.host
            flatIndex: root.owner ? root.owner.flatIndex : -1
            text: ""
            placeholder: root.opt?.placeholder ?? (root.mode === "folder" ? "Add a folder: type a path, Enter" : "Add a file: type a path, Enter")
            border.width: input.activeFocus || (root.owner && root.owner.focused && root.cursor === root.value.length) ? (root.owner && root.owner.focused && root.cursor === root.value.length && !input.activeFocus ? 2 : 1) : 0
            border.color: input.activeFocus ? Theme.mix(root.g.field, Theme.text, 0.25) : root.g.ring
            onApplied: t => root.add(t)
        }
        MiniButton {
            id: browse
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.g.fieldHeight
            visible: Catalog.hasChooser
            text: root.opt?.addLabel ?? "Browse"
            onClicked: Catalog.choosePath(root.mode, root.opt?.label ?? "Choose", root.value[root.value.length - 1] ?? "~", p => root.add(p))
        }
    }
}
