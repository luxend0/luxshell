import QtQuick
import qs.config

// "Sound" / "Display" card of ref/08: label, chevron chip (sub page), slider.
// Keyboard: Left/Right step 5 %, Enter opens the sub page.
Rectangle {
    id: card

    property string label
    property string icon
    property real iconSize: 18
    property real iconStroke: 2.25
    property real value: 0
    property bool hasPage: true
    property bool sliderEnabled: true
    signal moved(real v)
    signal opened

    width: parent ? parent.width : Theme.cc.width - 2 * Theme.cc.pad
    height: Theme.cc.row
    radius: Theme.cc.cardRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.cc.stroke

    readonly property bool ccControl: true
    function key(k: int): bool {
        if ((k === Qt.Key_Left || k === Qt.Key_Right) && sliderEnabled)
            moved(Math.max(0, Math.min(1, value + (k === Qt.Key_Right ? 0.05 : -0.05))));
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && hasPage)
            opened();
        else
            return false;
        return true;
    }

    CapText {
        x: Theme.cc.labelX
        width: card.width - x - (card.hasPage ? 60 : 20)
        capY: Theme.cc.labelY
        text: card.label
        font.pixelSize: Theme.cc.labelSize
        font.weight: Font.DemiBold
    }

    Chip {
        x: card.width - Theme.cc.trackX - width
        y: Theme.cc.chipY
        visible: card.hasPage
        onClicked: card.opened()
    }

    SliderTrack {
        x: Theme.cc.trackX
        y: Theme.cc.trackY
        width: card.width - 2 * Theme.cc.trackX
        value: card.value
        icon: card.icon
        iconSize: card.iconSize
        iconStroke: card.iconStroke
        enabled: card.sliderEnabled
        onMoved: v => card.moved(v)
    }

    FocusRing {}
}
