import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content (System > Sound: output and input volume): a mute disc, then the slider.
// The range runs to opt.max() (the volume limit, 1 = 100 %); above 100 % a thin mark shows
// where 100 % is. The percentage stands on the row's label line (summary()).
// Option fields: value(), set(v), max(), muted(), toggleMute(), glyph(muted) -> codepoint,
// enabled(). Keys: Left/Right 1 % steps (OptionRow: adjust), Enter/Space mute.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject s: Theme.sysnet
    property var opt: null
    property var row: null
    property var host: null
    readonly property bool active: row ? row.active : true
    readonly property real max: opt ? opt.max() : 1
    readonly property bool muted: opt ? opt.muted() : false
    readonly property real value: opt ? opt.value() : 0

    implicitHeight: s.volumeButton

    function summary(): string {
        if (!active)
            return "";
        const v = slider.shown;
        return muted ? `Muted · ${Math.round(v * 100)} %` : `${Math.round(v * 100)} %`;
    }
    function adjust(d: int): bool {
        if (!active)
            return false;
        opt.set(Math.max(0, Math.min(max, Math.round((value + d * 0.01) * 100) / 100)));
        return true;
    }
    function activate(): bool {
        if (active)
            opt.toggleMute();
        return true;
    }

    Rectangle {
        id: muteDisc
        width: root.s.volumeButton
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.muted ? root.g.danger : muteArea.containsMouse && root.active ? Theme.mix(root.g.field, Theme.text, 0.1) : root.g.field
        opacity: root.active ? 1 : 0.4
        Behavior on color {
            ColorAnim {
                ms: Theme.fadeOut
            }
        }
        MdIcon {
            anchors.centerIn: parent
            glyph: root.opt ? Catalog.glyph(root.opt.glyph(root.muted)) : ""
            size: 18
            color: root.muted ? "white" : root.g.label
        }
        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.active
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.row && root.host) {
                    root.host.focusRoot();
                    root.host.focusRow(root.row.flatIndex);
                }
                root.opt.toggleMute();
            }
        }
    }

    SliderCtl {
        id: slider
        x: muteDisc.width + root.s.sliderGap
        width: parent.width - x
        anchors.verticalCenter: parent.verticalCenter
        value: Math.min(root.value, root.max)
        min: 0
        max: root.max
        step: 0.01
        enabled: root.active
        opacity: root.muted ? 0.55 : 1
        onCommit: v => {
            if (root.row && root.host) {
                root.host.focusRoot();
                root.host.focusRow(root.row.flatIndex);
            }
            if (Math.abs(v - root.value) > 0.0005)
                root.opt.set(v);
        }

        // 100 % mark while the limit is higher
        Rectangle {
            visible: root.max > 1.001
            x: (1 / root.max) * (slider.width - root.g.sliderKnob) + root.g.sliderKnob / 2 - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 14
            radius: 1
            color: root.g.value
            z: -1
        }
    }
}
