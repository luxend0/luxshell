import QtQuick
import Quickshell.Widgets
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content of Settings > System > Startup Apps: one line per autostart entry
// (icon, name, command in the caption colour, then a switch, a remove button or a lock),
// optionally an "Add ..." line that opens the row's dropdown (filterable).
//
// Option fields besides the usual ones:
//   entries()     [{ key, label, detail, icon, glyph, on, toggle, remove, confirm, lock, dim }]
//                 icon: image URL or ""; glyph: Material codepoint shown without an icon;
//                 toggle: has a switch; remove: has a remove button (confirm: the first click
//                 asks, like a button row with `confirm`); lock: read only (lock glyph); dim: name
//                 in the value colour (an entry this desktop skips anyway)
//   setOn(e, on), remove(e)
//   candidates()  [{ value, label, detail }] for the add line (absent: no add line); pick(value)
//   addLabel, emptyText (string or function), summary()
// Keys: Up/Down walk the lines, Enter/Space toggles (on the add line: opens the dropdown),
// Delete removes (asks first where `confirm`).
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null
    property var host: null
    property int cursor: -1
    property string armed: ""    // key of the entry whose remove button asks "Remove?"
    readonly property var entries: opt ? opt.entries() : []
    readonly property bool canAdd: opt !== null && typeof opt.candidates === "function"
    readonly property int lines: entries.length + (canAdd ? 1 : 0)

    function summary(): string {
        if (opt && opt.summary)
            return opt.summary();
        const on = entries.filter(e => e.on).length;
        return entries.length === 0 ? "" : entries.some(e => e.toggle) ? `${on} of ${entries.length} on` : `${entries.length}`;
    }
    function toggle(i: int): void {
        const e = entries[i];
        if (e && e.toggle)
            opt.setOn(e, !e.on);
    }
    function askRemove(i: int): void {
        const e = entries[i];
        if (!e || !e.remove)
            return;
        if (e.confirm && armed !== e.key) {
            armed = e.key;
            disarm.restart();
            return;
        }
        armed = "";
        opt.remove(e);
        cursor = Math.min(cursor, lines - 2);
    }
    function openAdd(): void {
        if (!host || !row || !canAdd)
            return;
        host.openMenu(row, {
            "kind": "choice",
            "searchable": true,
            "options": () => root.opt.candidates(),
            "value": () => "",
            "set": v => root.opt.pick(v)
        });
    }
    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    // keyboard (OptionRow forwards)
    function focusRect(): var {
        return cursor < 0 ? null : {
            "y": Math.max(0, cursor) * g.listRow,
            "h": g.listRow
        };
    }
    function enter(d: int): void {
        cursor = lines === 0 ? -1 : d > 0 ? 0 : lines - 1;
    }
    function navigate(d: int, mods: int): bool {
        const j = cursor + d;
        if (j < 0 || j >= lines)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor === entries.length && canAdd)
            openAdd();
        else if (cursor >= 0)
            toggle(cursor);
        return true;
    }
    function deleteKey(): bool {
        if (cursor >= 0 && cursor < entries.length && entries[cursor].remove) {
            askRemove(cursor);
            return true;
        }
        return false;
    }

    Repeater {
        model: root.entries

        Item {
            id: line
            required property var modelData
            required property int index
            readonly property var e: modelData ?? ({}) // ({}) while the delegate is torn down
            readonly property bool asking: root.armed === e.key
            property bool iconBroken: false
            readonly property bool iconShown: (e.icon ?? "") !== "" && !iconBroken

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
                visible: line.iconShown
                onStatusChanged: line.iconBroken = status === Image.Error
                source: line.e.icon ?? ""
                asynchronous: true
                opacity: line.e.on || !line.e.toggle ? 1 : 0.45
            }
            MdIcon {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: !line.iconShown
                glyph: Catalog.glyph(line.e.glyph ?? 0xF018D) // md-console
                size: 20
                color: root.g.icon
                opacity: line.e.on || !line.e.toggle ? 1 : 0.45
            }
            SText {
                id: name
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                // a long name (a command) leaves the detail at most a third of the room
                width: Math.max(0, Math.min(implicitWidth, controls.x - x - 14 - Math.min(detail.implicitWidth + 12, (controls.x - x) * 0.33)))
                elide: Text.ElideRight
                text: line.e.label
                color: (line.e.on || !line.e.toggle) && !line.e.dim ? root.g.label : root.g.value
            }
            SText {
                id: detail
                x: name.x + name.width + 12
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, controls.x - x - 14)
                elide: Text.ElideMiddle
                size: 14
                text: line.e.detail ?? ""
                color: root.g.caption
            }

            Row {
                id: controls
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                MdIcon {
                    visible: line.e.lock === true
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Catalog.glyph(0xF0341) // md-lock-outline
                    size: 18
                    color: root.g.value
                }
                // remove: an x, or the question while armed
                Rectangle {
                    visible: line.e.remove === true
                    anchors.verticalCenter: parent.verticalCenter
                    width: line.asking ? ask.implicitWidth + 24 : root.g.miniButton
                    height: root.g.miniButton
                    radius: line.asking ? height / 2 : root.g.miniRadius
                    color: line.asking ? root.g.danger : rmArea.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.1) : root.g.field
                    Behavior on width {
                        Anim {
                            ms: Theme.fadeIn
                        }
                    }
                    MdIcon {
                        visible: !line.asking
                        anchors.centerIn: parent
                        glyph: Catalog.glyph(0xF0156) // md-close
                        size: 17
                        color: rmArea.containsMouse ? root.g.label : root.g.value
                    }
                    SText {
                        id: ask
                        visible: line.asking
                        anchors.centerIn: parent
                        size: 14
                        text: "Remove?"
                        color: "white"
                    }
                    MouseArea {
                        id: rmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cursor = line.index;
                            root.askRemove(line.index);
                        }
                    }
                }
                SwitchCtl {
                    visible: line.e.toggle === true
                    anchors.verticalCenter: parent.verticalCenter
                    on: line.e.on
                    hovered: swArea.containsMouse
                    MouseArea {
                        id: swArea
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

    // empty / add line
    Item {
        visible: root.canAdd || root.entries.length === 0
        width: root.width
        height: root.g.listRow + (root.canAdd ? 4 : 0)

        Rectangle {
            visible: root.entries.length > 0
            width: parent.width
            height: 1
            color: root.g.separator
        }
        SText {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.entries.length === 0
            width: (root.canAdd ? add.x : parent.width) - x - 12
            elide: Text.ElideRight
            text: root.opt ? (typeof root.opt.emptyText === "function" ? root.opt.emptyText() : (root.opt.emptyText ?? "Nothing here")) : ""
            color: root.g.value
        }
        MiniButton {
            id: add
            visible: root.canAdd
            x: root.entries.length === 0 ? parent.width - width : 0
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.g.fieldHeight
            text: root.opt?.addLabel ?? "Add"
            border.width: root.row && root.row.focused && root.cursor === root.entries.length ? 2 : 0
            border.color: root.g.ring
            onClicked: root.openAdd()
        }
    }
}
