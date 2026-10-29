import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content (Displays > Scale): a slider that stops only at the scales Hyprland
// keeps for this resolution (page.scalesFor: 100 %, 107 %, 125 %, 133 %, 160 % ... at
// 2560 × 1440), one tick each, evenly spaced. The label line shows the value and what the
// desktop then looks like ("125 % · looks like 2048 × 1152"), live while dragging or while
// the keyboard ring walks the ticks; the stage on top follows. Release / Enter asks "Keep?".
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject d: Theme.displays
    property var ctl: null
    property var opt: null
    property var row: null
    readonly property var v: ctl ? ctl.cur : null
    readonly property var steps: v && v.w > 0 ? ctl.scalesFor(v.w, v.h) : [1]
    readonly property int index: v ? steps.reduce((best, s, i) => Math.abs(s - v.scale) < Math.abs(steps[best] - v.scale) ? i : best, 0) : 0
    readonly property bool active: row ? row.active : true
    property int dragIndex: -1
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb ? cur : -1
    readonly property int shown: dragIndex >= 0 ? dragIndex : kb ? cur : index
    readonly property real knob: g.sliderKnob
    readonly property real span: width - knob
    onKbChanged: if (kb)
        cur = index

    // the stage previews the value under the knob
    readonly property var previewValue: root.v && root.shown !== root.index ? {
        "name": root.v.name,
        "scale": root.steps[root.shown]
    } : null
    onPreviewValueChanged: if (ctl)
        ctl.preview = previewValue
    Component.onDestruction: if (ctl && ctl.preview && previewValue)
        ctl.preview = null

    implicitHeight: 54
    opacity: active ? 1 : 0.45

    function xOf(i: int): real {
        return knob / 2 + (steps.length > 1 ? i / (steps.length - 1) * span : span / 2);
    }
    function indexAt(x: real): int {
        if (steps.length < 2)
            return 0;
        return Math.max(0, Math.min(steps.length - 1, Math.round((x - knob / 2) / span * (steps.length - 1))));
    }
    function summary(): string {
        if (!v || !ctl)
            return "";
        const s = steps[shown];
        const l = ctl.logical(v.w, v.h, s, v.transform);
        return `${ctl.pct(s)} · looks like ${l.w} × ${l.h}`;
    }
    function enter(dir: int): void {
        cur = index;
    }
    function adjust(dd: int): bool {
        const c = cur + dd;
        if (c < 0)
            return false;
        if (c < steps.length)
            cur = c;
        return true;
    }
    function activate(): bool {
        if (active && cur !== index)
            ctl.setScale(steps[cur]);
        return true;
    }
    // every tick label that has room (the current one always)
    function labelled(i: int): bool {
        if (i === shown || i === 0 || i === steps.length - 1)
            return true;
        const gap = steps.length > 1 ? span / (steps.length - 1) : span;
        const every = Math.max(1, Math.ceil(d.tickLabelGap / gap));
        if (Math.abs(xOf(i) - xOf(shown)) < d.tickLabelGap)
            return false;
        if (i !== steps.length - 1 && xOf(steps.length - 1) - xOf(i) < d.tickLabelGap)
            return false;
        return i % every === 0;
    }

    Item {
        id: rail
        width: parent.width
        height: 24

        Rectangle {
            id: track
            x: root.knob / 2
            width: root.span
            anchors.verticalCenter: parent.verticalCenter
            height: root.d.tickTrack
            radius: height / 2
            color: root.g.switchOff

            Rectangle {
                width: Math.max(parent.height, knobItem.x + root.knob / 2 - track.x)
                height: parent.height
                radius: height / 2
                color: root.active ? Theme.accent : Theme.muted
            }
        }

        Repeater {
            model: root.steps.length

            Rectangle {
                required property int index
                x: root.xOf(index) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: root.d.tickHeight
                radius: 1
                color: index <= root.shown ? Theme.mix(Theme.accent, Theme.text, 0.2) : Theme.mix(root.g.switchOff, Theme.text, 0.22)
                visible: index !== root.shown
            }
        }

        Rectangle {
            id: knobItem
            width: root.knob
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.xOf(root.shown) - width / 2
            color: Theme.text
            border.width: root.cursor >= 0 ? 2 : 0
            border.color: root.g.ring
            scale: area.pressed ? 1.12 : area.containsMouse ? 1.06 : 1
            Behavior on x {
                enabled: root.dragIndex < 0
                Anim {
                    ms: 160
                }
            }
            Behavior on scale {
                Anim {
                    ms: Theme.fadeOut
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -26
            hoverEnabled: true
            enabled: root.active
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                if (root.row) {
                    root.row.host.focusRoot();
                    root.row.host.focusRow(root.row.flatIndex);
                }
                root.dragIndex = root.indexAt(mouse.x);
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.dragIndex = root.indexAt(mouse.x);
            }
            onReleased: {
                const i = root.dragIndex;
                root.dragIndex = -1;
                root.cur = i;
                if (i >= 0 && i !== root.index)
                    root.ctl.setScale(root.steps[i]);
            }
            onCanceled: root.dragIndex = -1
        }
    }

    Repeater {
        model: root.steps.length

        SText {
            required property int index
            y: rail.height + 6
            x: Math.max(0, Math.min(root.width - width, root.xOf(index) - width / 2))
            visible: root.labelled(index)
            size: 12.5
            font.weight: index === root.shown ? Font.DemiBold : Font.Normal
            text: String(Math.round(root.steps[index] * 100))
            color: index === root.shown ? root.g.label : root.g.value
        }
    }
}
