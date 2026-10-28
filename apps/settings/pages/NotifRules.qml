import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.apps.settings

// Custom row content of Notifications > App rules (Settings.notifRules): one line per app
// with its rule, a mode dropdown and remove, then "Add app" (apps seen in the history
// first, then every installed app; the dropdown filters while typing).
//   rule  { "app": "Vesktop", "id": "vesktop", "mode": "mute" | "nopeek" | "always" | "nostore" }
//         matched against a notification's app name and desktop id (services/Notifs.ruleFor)
// Keys (OptionRow forwards): Up/Down walk the lines, Left/Right change the mode, Enter opens
// the mode list (on "Add app": the app list), Delete removes the rule.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null     // the OptionRow (set by it)
    property var host: null    // SettingsWindow controller (set by the row)
    property int cursor: -1
    readonly property var rules: opt ? Array.from(opt.value() ?? []) : []
    readonly property bool focusedRow: !!row && row.focused

    readonly property var modes: [
        {
            "value": "mute",
            "label": "Muted",
            "detail": "no popup, no sound"
        },
        {
            "value": "nopeek",
            "label": "No popup",
            "detail": "keeps the sound"
        },
        {
            "value": "always",
            "label": "Always show",
            "detail": "also during Focus"
        },
        {
            "value": "nostore",
            "label": "Don't keep",
            "detail": "popup, not in the history"
        }
    ]
    function modeLabel(v: string): string {
        return modes.find(m => m.value === v)?.label ?? v;
    }

    function summary(): string {
        return rules.length === 0 ? "None" : rules.length === 1 ? "1 app" : `${rules.length} apps`;
    }

    // ---- edits (whole list replaced: Settings sees the change) ----------------------------
    function setMode(i: int, mode: string): void {
        const r = rules.slice();
        if (!r[i] || r[i].mode === mode)
            return;
        r[i] = Object.assign({}, r[i], {
            "mode": mode
        });
        opt.set(r);
    }
    function remove(i: int): void {
        const r = rules.slice();
        r.splice(i, 1);
        opt.set(r);
        cursor = Math.min(cursor, r.length);
    }
    function add(app: string, id: string): void {
        const key = (app + "|" + id).toLowerCase();
        const at = rules.findIndex(r => (r.app + "|" + (r.id ?? "")).toLowerCase() === key);
        if (at >= 0) {
            cursor = at;
            return;
        }
        opt.set([...rules, {
                "app": app,
                "id": id,
                "mode": "mute"
            }]);
        cursor = rules.length - 1;
    }

    // apps for "Add app": seen in the history first, then the installed ones
    function appChoices(): var {
        const out = [];
        const seen = {};
        const push = (label, id, detail) => {
            const k = (label + "|" + id).toLowerCase();
            if (label === "" || seen[k])
                return;
            seen[k] = true;
            out.push({
                "value": JSON.stringify([label, id]),
                "label": label,
                "detail": detail
            });
        };
        for (const gr of Notifs.groups)
            push(gr.app, gr.group, "recent");
        for (const e of Apps.all)
            push(e.name, e.id, "");
        return out;
    }

    function openModes(i: int, item: Item): void {
        if (!host)
            return;
        cursor = i;
        host.openMenu(item, {
            "kind": "choice",
            "options": () => root.modes,
            "value": () => root.rules[i]?.mode ?? "",
            "set": v => root.setMode(i, v)
        });
    }
    function openAdd(): void {
        if (!host)
            return;
        cursor = rules.length;
        host.openMenu(addBtn, {
            "kind": "choice",
            "searchable": true,
            "options": () => root.appChoices(),
            "value": () => "",
            "set": v => {
                const [app, id] = JSON.parse(v);
                root.add(app, id);
            }
        });
    }

    // ---- keyboard (OptionRow forwards) ----------------------------------------------------
    function focusRect(): var {
        return cursor < 0 ? null : {
            "y": cursor * g.listRow,
            "h": g.listRow
        };
    }
    function enter(d: int): void {
        cursor = d > 0 ? 0 : rules.length;
    }
    function navigate(d: int, mods: int): bool {
        const j = cursor + d;
        if (j < 0 || j > rules.length)
            return false;
        cursor = j;
        return true;
    }
    function activate(): bool {
        if (cursor < 0)
            cursor = 0;
        if (cursor >= rules.length)
            openAdd();
        else
            openModes(cursor, lines.itemAt(cursor)?.chip ?? addBtn);
        return true;
    }
    function adjust(d: int): bool {
        if (cursor < 0 || cursor >= rules.length)
            return false;
        const i = modes.findIndex(m => m.value === rules[cursor].mode);
        const n = modes[Math.max(0, Math.min(modes.length - 1, i + d))];
        setMode(cursor, n.value);
        return true;
    }
    function deleteKey(): bool {
        if (cursor < 0 || cursor >= rules.length)
            return false;
        remove(cursor);
        return true;
    }

    // ---- lines ----------------------------------------------------------------------------
    Repeater {
        id: lines
        model: root.rules

        Item {
            id: line
            required property var modelData
            required property int index
            readonly property alias chip: chip
            readonly property bool current: root.focusedRow && root.cursor === index

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

            AppIcon {
                id: icon
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 24
                source: Apps.iconFor(line.modelData.id ?? "") || Apps.iconFor(line.modelData.app ?? "")
            }
            SText {
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                width: chip.x - x - 12
                elide: Text.ElideRight
                text: line.modelData.app
            }

            Rectangle {
                id: chip
                x: remove.x - width - 8
                anchors.verticalCenter: parent.verticalCenter
                width: chipText.implicitWidth + 44
                height: root.g.miniButton
                radius: root.g.miniRadius
                color: chipArea.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.1) : root.g.field
                SText {
                    id: chipText
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 14
                    text: root.modeLabel(line.modelData.mode)
                }
                MdIcon {
                    x: parent.width - width - 9
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Catalog.glyph(0xF0140) // md-chevron-down
                    size: 17
                    color: root.g.value
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openModes(line.index, chip)
                }
            }
            MiniButton {
                id: remove
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(0xF0156) // md-close
                onClicked: root.remove(line.index)
            }
        }
    }

    // ---- add ------------------------------------------------------------------------------
    Item {
        width: root.width
        height: root.g.listRow
        readonly property bool current: root.focusedRow && root.cursor === root.rules.length

        Rectangle {
            visible: root.rules.length > 0
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
            visible: parent.current
        }
        SText {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: root.rules.length === 0
            text: "No app has a rule"
            color: root.g.value
        }
        MiniButton {
            id: addBtn
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            text: "Add app"
            onClicked: root.openAdd()
        }
    }
}
