import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.apps.settings

// Custom row content (Displays > Brightness): one slider per display that speaks DDC/CI (or a
// backlight), services/Brightness: read when the page opens (at most every 30 s), writes
// debounced, one ddcutil at a time. Each line names the model and its connector.
// Keys: Up/Down walk the displays, Left/Right change the one under the ring by 5 %.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var ctl: null
    property var opt: null
    property var row: null
    readonly property var list: Brightness.displays
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb && list.length > 0 ? cur : -1

    function navigate(dd: int, mods: int): bool {
        const c = cur + dd;
        if (c < 0 || c >= list.length)
            return false;
        cur = c;
        return true;
    }
    function enter(dir: int): void {
        cur = dir > 0 ? 0 : Math.max(0, list.length - 1);
    }
    function adjust(dd: int): bool {
        const d = list[cur];
        if (!d)
            return false;
        Brightness.set(cur, Math.round((d.value + dd * 0.05) * 20) / 20);
        return true;
    }
    function focusRect(): var {
        return {
            "y": cur * 76,
            "h": 76
        };
    }
    function connectorOf(d: var): string {
        return String(d.connector ?? "").replace(/^card\d+-/, "");
    }

    Item {
        visible: root.list.length === 0
        width: root.width
        height: root.g.rowHeight

        SText {
            x: root.g.rowInset
            anchors.verticalCenter: parent.verticalCenter
            text: "Brightness"
        }
        SText {
            x: parent.width - root.g.rowInset - width
            anchors.verticalCenter: parent.verticalCenter
            text: Brightness.loading ? "Looking for DDC/CI displays…" : "No DDC/CI display or backlight"
            color: root.g.value
        }
    }

    Repeater {
        model: root.list

        Item {
            id: line
            required property var modelData
            required property int index
            readonly property string conn: root.connectorOf(modelData)
            width: root.width
            height: 76

            Rectangle {
                visible: line.index > 0
                x: root.g.rowInset
                width: parent.width - 2 * root.g.rowInset
                height: 1
                color: root.g.separator
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 13
                color: "transparent"
                border.width: 2
                border.color: root.g.ring
                visible: root.cursor === line.index
            }

            SText {
                id: name
                x: root.g.rowInset
                y: 26 - height / 2
                width: parent.width - 2 * root.g.rowInset - pctText.width - 12
                elide: Text.ElideRight
                text: (line.modelData.model || "Display") + (line.conn !== "" && line.conn !== "-" ? `  ·  ${line.conn}` : "")
            }
            SText {
                id: pctText
                x: parent.width - 22 - width
                y: name.y
                text: `${Math.round((slider.shown ?? line.modelData.value) * 100)} %`
                color: root.g.value
            }
            SliderCtl {
                id: slider
                x: root.g.rowInset
                y: 56 - height / 2
                width: parent.width - 2 * root.g.rowInset
                value: line.modelData.value
                min: 0
                max: 1
                step: 0.01
                onCommit: v => {
                    if (root.row) {
                        root.row.host.focusRoot();
                        root.row.host.focusRow(root.row.flatIndex);
                    }
                    root.cur = line.index;
                    Brightness.set(line.index, v);
                }
            }
        }
    }
}
