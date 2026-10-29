import QtQuick
import qs.config
import qs.apps.settings

// Custom row content without the row's own label (option `label: ""`): one line like a
// switch row, label (option `title`) left with an optional grey note under it (`note()`),
// its reset arrow, and a segment bar on the right (VRR, colour, mirror). Option fields:
// title, note(), items(), value(), set(v), modified(), reset(), enabled().
// Keys: Left/Right walk the segments (Left on the first: sidebar), Enter/Space takes it.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    readonly property var items: opt && opt.items ? opt.items() : []
    readonly property var value: opt ? opt.value() : undefined
    readonly property bool active: row ? row.active : true
    readonly property string note: opt && opt.note ? opt.note() : ""
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && items.length > 1 ? cur : -1
    onKbChanged: if (kb)
        cur = Math.max(0, seg.current)

    implicitHeight: note !== "" ? 68 : g.rowHeight

    function enter(d: int): void {
        cur = Math.max(0, seg.current);
    }
    function adjust(d: int): bool {
        const c = cur + d;
        if (c < 0)
            return false;
        if (c < items.length)
            cur = c;
        return true;
    }
    function activate(): bool {
        const it = items[cur];
        if (active && it && it.value !== value)
            opt.set(it.value);
        return true;
    }

    Column {
        x: root.g.rowInset
        anchors.verticalCenter: parent.verticalCenter
        width: reset.x - x - 12
        spacing: 3

        SText {
            width: parent.width
            elide: Text.ElideRight
            text: root.opt?.title ?? ""
            color: root.active ? root.g.label : root.g.value
        }
        SText {
            visible: root.note !== ""
            width: parent.width
            elide: Text.ElideRight
            size: 13.5
            font.weight: Font.Normal
            text: root.note
            color: root.g.value
        }
    }

    ResetButton {
        id: reset
        shown: root.active && root.opt !== null && root.opt.modified()
        host: root.host
        tip: "Back to the rule before luxshell"
        x: seg.x - (shown ? width + root.g.resetGap : 0)
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            if (root.row) {
                root.host.focusRoot();
                root.host.focusRow(root.row.flatIndex);
            }
            root.opt.reset();
        }
    }

    // one value only (nothing else to pick): plain text instead of a bar
    SText {
        visible: root.items.length === 1
        x: root.width - root.g.rowInset - width - 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.items[0]?.label ?? ""
        color: root.g.value
    }

    Seg {
        id: seg
        visible: root.items.length > 1
        x: root.width - root.g.rowInset - width
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        items: root.items
        value: root.value
        cursor: root.cursor
        active: root.active
        textSize: 14.5
        onPicked: v => {
            if (root.row) {
                root.host.focusRoot();
                root.host.focusRow(root.row.flatIndex);
            }
            root.cur = root.items.findIndex(i => i.value === v);
            if (v !== root.value)
                root.opt.set(v);
        }
    }
}
