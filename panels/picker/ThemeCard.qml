import QtQuick
import qs.config
import qs.widgets

// One theme card (ref/05, ref/15): the theme's own surface, six swatch dots, its name.
// Everything follows d (signed distance to the carousel position, Carousel.qml):
// the centred card rises and gets the frame, neighbours shrink a little and darken.
// The frame takes Theme.accent, which is the previewed theme's accent while browsing.
Item {
    id: card

    property int index: 0
    property real d: 0
    property string name: ""
    property var pal: Themes.palettes.noir
    property bool applied: false

    readonly property var g: Theme.themePicker
    readonly property real a: Math.abs(d)
    readonly property real near: Math.max(0, 1 - a)      // 1 centred .. 0 one step out

    width: g.cardWidth
    height: g.cardHeight
    y: g.cardTop - g.lift * near
    scale: 1 - g.shrink * Math.min(2, a)

    Rectangle {
        anchors.fill: parent
        radius: card.g.cardRadius
        color: card.pal.surfaceHigh
    }

    Row {
        x: (parent.width - width) / 2
        y: card.g.dotsY - card.g.dotSize / 2
        spacing: card.g.dotStep - card.g.dotSize

        Repeater {
            model: card.pal.swatches

            Rectangle {
                required property string modelData
                width: card.g.dotSize
                height: width
                radius: width / 2
                color: modelData
            }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.g.labelY - height / 2
        text: card.name
        font.pixelSize: Theme.picker.metaSize
        font.weight: Font.Medium
        color: Theme.mix(Theme.textDim, Theme.text, card.near)
    }

    // "applied" dot (ref/15: the current theme carries a small light dot top right)
    Rectangle {
        visible: card.applied
        x: parent.width - card.g.appliedX - width / 2
        y: card.g.appliedY - height / 2
        width: card.g.appliedSize
        height: width
        radius: width / 2
        color: Theme.text
    }

    // depth: neighbours sit back
    Rectangle {
        anchors.fill: parent
        radius: card.g.cardRadius
        color: "black"
        opacity: card.g.dim * Math.min(1.5, card.a)
        visible: opacity > 0.002
    }

    // selection frame, fades with the distance so it slides between cards
    Rectangle {
        anchors.fill: parent
        radius: card.g.cardRadius
        color: "transparent"
        border.width: Theme.picker.frame
        border.color: Theme.accent
        opacity: Math.max(0, 1 - 2 * card.a)
        visible: opacity > 0.002
        Behavior on border.color {
            ColorAnimation {
                duration: Motion.ms(Theme.picker.tint)
            }
        }
    }
}
