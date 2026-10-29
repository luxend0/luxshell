import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content (Displays > Resolution): every resolution of the picked display as a
// chip, biggest first, four per line: "2560 × 1440" over "16:9 · 180 Hz" (the fastest rate
// it has; the EDID's preferred one says "native"). A click asks "Keep?" (the page keeps the
// refresh rate when the new resolution has it and the scale when Hyprland takes it there).
// Keys: Left/Right and Up/Down walk the chips, Enter/Space takes the one under the ring.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject d: Theme.displays
    property var ctl: null
    property var opt: null
    property var row: null
    readonly property var v: ctl ? ctl.cur : null
    readonly property var modes: ctl ? ctl.modesOf(v) : []
    readonly property bool active: row ? row.active : true
    readonly property int cols: d.chipColumns
    readonly property real cw: (width - (cols - 1) * d.chipGap) / cols
    readonly property int currentIndex: v ? modes.findIndex(m => m.w === v.w && m.h === v.h) : -1
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb ? cur : -1
    onKbChanged: if (kb)
        cur = Math.max(0, currentIndex)

    implicitHeight: modes.length === 0 ? 0 : Math.ceil(modes.length / cols) * (d.chipHeight + d.chipGap) - d.chipGap
    opacity: active ? 1 : 0.45

    function enter(dir: int): void {
        cur = Math.max(0, currentIndex);
    }
    function adjust(dd: int): bool {
        const c = cur + dd;
        if (c < 0)
            return false;
        if (c < modes.length)
            cur = c;
        return true;
    }
    function navigate(dd: int, mods: int): bool {
        const c = cur + dd * cols;
        if (c < 0 || c >= modes.length)
            return false;
        cur = c;
        return true;
    }
    function activate(): bool {
        const m = modes[cur];
        if (active && m)
            ctl.setResolution(m.w, m.h);
        return true;
    }
    function focusRect(): var {
        return {
            "y": Math.floor(Math.max(0, cur) / cols) * (d.chipHeight + d.chipGap),
            "h": d.chipHeight
        };
    }

    Repeater {
        model: root.modes

        Rectangle {
            id: chip
            required property var modelData
            required property int index
            readonly property bool on: index === root.currentIndex
            readonly property bool hot: area.containsMouse && root.active
            readonly property bool isNative: root.v !== null && root.v.native === `${modelData.w}x${modelData.h}`

            x: (index % root.cols) * (root.cw + root.d.chipGap)
            y: Math.floor(index / root.cols) * (root.d.chipHeight + root.d.chipGap)
            width: root.cw
            height: root.d.chipHeight
            radius: root.d.chipRadius
            color: on ? root.d.plate : hot ? Theme.mix(root.g.field, Theme.text, 0.06) : root.g.field
            border.width: root.cursor === index ? 2 : 0
            border.color: root.g.ring
            Behavior on color {
                ColorAnim {
                    ms: Theme.fadeOut
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                width: parent.width - 28
                spacing: 2

                SText {
                    width: parent.width
                    elide: Text.ElideRight
                    size: 15.5
                    text: `${chip.modelData.w} × ${chip.modelData.h}`
                    color: chip.on || chip.hot ? root.g.label : Theme.mix(root.g.label, root.g.value, 0.35)
                }
                SText {
                    width: parent.width
                    elide: Text.ElideRight
                    size: 12.5
                    font.weight: Font.Normal
                    text: {
                        const r = chip.modelData.rates;
                        const parts = [root.ctl.aspect(chip.modelData.w, chip.modelData.h)];
                        if (r.length > 0)
                            parts.push(`${root.ctl.fmtHz(r[r.length - 1])} Hz`);
                        if (chip.isNative)
                            parts.push("native");
                        return parts.join(" · ");
                    }
                    color: root.g.value
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.active
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.row) {
                        root.row.host.focusRoot();
                        root.row.host.focusRow(root.row.flatIndex);
                    }
                    root.cur = chip.index;
                    if (!chip.on)
                        root.ctl.setResolution(chip.modelData.w, chip.modelData.h);
                }
            }
        }
    }
}
