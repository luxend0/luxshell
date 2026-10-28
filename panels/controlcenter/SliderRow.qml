import QtQuick
import qs.config
import qs.widgets

// Slider card of a sheet (output volume, one app, one display): optional app
// icon, label and value on the first line, the pill slider of ref/08 below.
// Keyboard: Left/Right step 5 %, Space / Enter = secondary (mute).
Rectangle {
    id: card

    readonly property QtObject sh: Theme.cc.sheet

    property string label
    property string valueText
    property string iconSource: ""    // app icon path
    property string glyph: ""         // fallback glyph in a small disc when there is no icon
    property real value: 0
    property string trackIcon: "volume-2"
    property real trackIconSize: 18
    property bool sliderEnabled: true
    signal moved(real v)
    signal secondary

    readonly property bool hasIcon: iconSource !== "" || glyph !== ""

    width: parent ? parent.width : 300
    height: sh.sliderRow
    radius: sh.rowRadius
    color: sh.rowColor

    readonly property bool ccControl: true
    function key(k: int): bool {
        if ((k === Qt.Key_Left || k === Qt.Key_Right) && sliderEnabled)
            moved(Math.max(0, Math.min(1, value + (k === Qt.Key_Right ? 0.05 : -0.05))));
        else if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            secondary();
        else
            return false;
        return true;
    }

    Item {
        id: iconBox
        x: 16
        y: 9
        width: 24
        height: 24
        visible: card.hasIcon
        Image {
            id: img
            anchors.fill: parent
            source: card.iconSource
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
        Disc {
            anchors.fill: parent
            visible: !img.visible
            icon: card.glyph || "music"
            iconSize: 13
            offColor: card.sh.discColor
        }
    }

    SheetText {
        x: card.hasIcon ? 50 : 20
        width: valueLabel.x - x - 12
        capY: 21
        px: 16
        text: card.label
        color: card.sh.textColor
        font.weight: Font.Medium
    }
    SheetText {
        id: valueLabel
        x: card.width - 20 - implicitWidth
        capY: 21
        px: 15
        text: card.valueText
        color: Theme.textDim
    }

    SliderTrack {
        x: 12
        y: 36
        width: card.width - 24
        value: card.value
        icon: card.trackIcon
        iconSize: card.trackIconSize
        iconStroke: 2.25
        enabled: card.sliderEnabled
        onMoved: v => card.moved(v)
    }

    FocusRing {
        gap: 2
    }
}
