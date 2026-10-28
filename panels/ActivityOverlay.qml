import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// The one building block for short status messages (registry kind "overlay"):
// volume, brightness, microphone, output device, keyboard layout, Caps Lock ...
// Renders an activity object (services/Activities.qml): with a value it is the bar of
// ref/10 (icon, slider, percentage), without one the same bar carries a label and a
// detail. The overlay id picks the data: "activity" = Activities.current,
// "osd" / "brightness" = live presets (aliases, also for `ipc call luxshell flash ...`).
//
// Same key: values update in place (slider glides). Another key: the content dips
// out, swaps and comes back while the island morphs to the new width.
PanelBase {
    id: root

    readonly property QtObject o: Theme.osd
    readonly property var act: probe ? null : Activities.live(panelId)

    // what is drawn; swapped at the bottom of the dip when the key changes
    property var shown: null
    property real alpha: 1

    onActChanged: {
        if (!act)
            return;
        if (!shown || shown.key === act.key) {
            shown = act;
            return;
        }
        swap.restart();
    }
    Component.onCompleted: shown = act

    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: root
            property: "alpha"
            to: 0
            duration: Motion.ms(root.o.swapOut)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: root.shown = root.act
        }
        NumberAnimation {
            target: root
            property: "alpha"
            to: 1
            duration: Motion.ms(root.o.swapIn)
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool hasValue: shown !== null && shown.value !== null
    // width follows the incoming activity at once, so the island morphs during the dip
    readonly property var sizing: act ?? shown
    readonly property real needed: !sizing || (sizing.value !== null && sizing.value !== undefined) ? o.width : o.sliderX + labelMetrics.advanceWidth + o.gap + detailMetrics.advanceWidth + o.padRight

    preferredWidth: Math.round(Math.max(o.width, Math.min(o.maxWidth, needed)))
    preferredHeight: o.height
    maxWidth: o.maxWidth
    cornerRadius: o.radius

    TextMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.o.labelSize
        font.weight: Font.Medium
        text: root.sizing?.label ?? ""
    }
    TextMetrics {
        id: detailMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.o.valueSize
        font.weight: Font.Medium
        text: root.sizing?.detail ?? ""
    }

    Item {
        anchors.fill: parent
        opacity: root.alpha
        visible: root.shown !== null

        Icon {
            id: icon
            x: root.o.padLeft
            y: root.o.centerY - height / 2
            name: root.shown?.icon ?? ""
            size: root.o.iconSize
            color: Theme.text
        }

        // value: slider (ref/10)
        Rectangle {
            id: track
            visible: root.hasValue
            x: root.o.sliderX
            y: root.o.centerY - height / 2
            width: root.width - root.o.sliderX - root.o.gap - valueText.width - root.o.padRight
            height: root.o.sliderHeight
            radius: height / 2
            color: root.o.track

            property real v: root.hasValue ? root.shown.value : 0
            Behavior on v {
                Anim {
                    ms: root.o.valueMove
                }
            }

            Rectangle {
                width: Math.max(parent.height, parent.width * parent.v)
                height: parent.height
                radius: parent.radius
                visible: parent.v > 0.001
                color: root.shown?.dim ? root.o.dimFill : Theme.accent
                Behavior on color {
                    ColorAnimation {
                        duration: Motion.ms(Theme.fadeIn)
                    }
                }
            }
        }
        Txt {
            id: valueText
            visible: root.hasValue
            // fixed slot ("100%"), so the slider does not jump while the value changes
            width: Math.max(implicitWidth, slot.implicitWidth)
            x: root.width - root.o.padRight - width
            y: root.o.centerY - height / 2
            text: root.shown?.detail ?? ""
            horizontalAlignment: Text.AlignRight
            font.pixelSize: root.o.valueSize
            font.weight: Font.Medium
            color: root.o.valueColor
            Txt {
                id: slot
                visible: false
                text: "100%"
                font: valueText.font
            }
        }

        // no value: label + detail on the same bar
        Txt {
            visible: !root.hasValue
            x: root.o.sliderX
            y: root.o.centerY - height / 2
            width: detail.x - root.o.gap - x
            text: root.shown?.label ?? ""
            elide: Text.ElideRight
            font.pixelSize: root.o.labelSize
            font.weight: Font.Medium
            color: Theme.text
        }
        Txt {
            id: detail
            visible: !root.hasValue
            x: root.width - root.o.padRight - width
            y: root.o.centerY - height / 2
            text: root.shown?.detail ?? ""
            font.pixelSize: root.o.valueSize
            font.weight: Font.Medium
            color: root.o.valueColor
        }
    }

    // scrolling over the volume bar sets the volume (an explicit user action, Audio.step)
    WheelHandler {
        enabled: root.shown?.key === "volume"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => Audio.step(e.angleDelta.y > 0 ? 0.05 : -0.05)
    }
}
