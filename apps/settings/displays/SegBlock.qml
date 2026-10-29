import QtQuick
import qs.config
import qs.apps.settings

// Custom row content (Displays > Refresh rate): a full-width segment bar under the row's
// label line. Option fields: items() -> [{ value, label }], value(), set(v).
// Keys: Left/Right walk the segments (Left on the first: back to the sidebar), Enter/Space
// takes the one under the ring (a display change asks "Keep?", so arrows never apply alone).
Item {
    id: root

    property var opt: null
    property var row: null
    readonly property var items: opt && opt.items ? opt.items() : []
    readonly property var value: opt ? opt.value() : undefined
    readonly property bool active: row ? row.active : true
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb ? cur : -1
    onKbChanged: if (kb)
        cur = Math.max(0, seg.current)

    implicitHeight: seg.implicitHeight

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

    Seg {
        id: seg
        width: root.width
        stretch: true
        items: root.items
        value: root.value
        cursor: root.cursor
        active: root.active
        onPicked: v => {
            if (root.row) {
                root.row.host.focusRoot();
                root.row.host.focusRow(root.row.flatIndex);
            }
            root.cur = root.items.findIndex(i => i.value === v);
            if (v !== root.value)
                root.opt.set(v);
        }
    }
}
