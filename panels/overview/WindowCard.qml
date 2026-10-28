import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// One window of the overview: preview box (live screencopy of the toplevel, fitted
// into a 16:10 box like the picker cards), app icon + title below.
//
// Selection like the pickers: the selected card keeps full size and gets the light
// frame, every other card is a little smaller and darkened. The focused window carries
// the small dot of the applied wallpaper (ref/06), the hovered one a close disc.
//
// Capture: only while the overview exists (the panel is destroyed on close). The
// selected / hovered card is live, the others keep the frame captured on open, so a
// big overview does not stream every window.
Item {
    id: card

    property var toplevel: null
    property string title: ""
    property string icon: ""
    property bool selected: false
    property bool focusedWindow: false

    readonly property var g: Theme.overview
    readonly property bool hovered: hover.hovered

    signal entered(point global)
    signal clicked
    signal closeRequested

    width: g.cardWidth
    height: g.thumbHeight + g.labelHeight

    // 0 = unselected look, 1 = selected look; one value drives frame, dim, scale, text
    property real sel: selected ? 1 : 0
    Behavior on sel {
        Anim {
            ms: card.g.select
        }
    }

    HoverHandler {
        id: hover
        onPointChanged: card.entered(point.scenePosition)
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: if (!closeHover.hovered) // the close disc has its own tap
            card.clicked()
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: card.closeRequested()
    }

    Item {
        id: thumb
        width: card.g.cardWidth
        height: card.g.thumbHeight
        scale: 1 - card.g.shrink * (1 - card.sel)

        ClippingRectangle {
            id: box
            anchors.fill: parent
            radius: card.g.cardRadius
            color: card.g.box

            ScreencopyView {
                id: view
                readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 10
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * ar)
                height: width / ar
                captureSource: card.toplevel?.wayland ?? null
                live: card.selected || card.hovered
                opacity: hasContent ? 1 : 0
                Behavior on opacity {
                    Anim {
                        ms: 180
                    }
                }
            }

            AppIcon {
                anchors.centerIn: parent
                size: card.g.placeholderIcon
                visible: !view.hasContent
                source: card.icon
                fallback: "app-window"
                fallbackColor: Theme.textDim
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: card.g.dim * (1 - card.sel)
                visible: opacity > 0.002
            }
        }

        // selection frame (picker frame)
        Rectangle {
            anchors.fill: parent
            radius: card.g.cardRadius
            color: "transparent"
            border.width: card.g.frame
            border.color: Theme.text
            opacity: card.sel
            visible: opacity > 0.002
        }

        // focused window: small light dot top right (as the applied wallpaper in ref/06)
        Rectangle {
            visible: card.focusedWindow && !closeBtn.visible
            x: parent.width - card.g.dotInset - width / 2
            y: card.g.dotInset - height / 2
            width: card.g.dotSize
            height: width
            radius: width / 2
            color: Theme.accent
            border.width: 1.5
            border.color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            id: closeBtn
            visible: card.hovered
            x: parent.width - card.g.closeInset - width
            y: card.g.closeInset
            width: card.g.closeSize
            height: width
            radius: width / 2
            color: closeTap.pressed ? Theme.surfaceHigh : card.g.closeDisc
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, closeHover.hovered ? 0.18 : 0.08)

            Glyph {
                anchors.centerIn: parent
                name: "x"
                size: 14
                stroke: 2.2
                color: closeHover.hovered ? Theme.text : Theme.textSecondary
            }
            HoverHandler {
                id: closeHover
            }
            TapHandler {
                id: closeTap
                onTapped: card.closeRequested()
            }
        }
    }

    Row {
        id: label
        x: Math.max(0, (card.width - width) / 2)
        y: card.g.thumbHeight + card.g.labelY - height / 2
        spacing: 8

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: card.g.iconSize
            source: card.icon
            fallback: "app-window"
            fallbackColor: Theme.textDim
            opacity: 0.55 + 0.45 * card.sel
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, card.width - card.g.iconSize - label.spacing)
            text: card.title
            elide: Text.ElideRight
            font.pixelSize: card.g.titleSize
            font.weight: Font.Medium
            color: Theme.mix(Theme.textDim, Theme.text, card.sel)
        }
    }

    // dry run: a short shake instead of the window going away
    SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: thumb; property: "x"; to: -6; duration: Motion.ms(50) }
        NumberAnimation { target: thumb; property: "x"; to: 5; duration: Motion.ms(70) }
        NumberAnimation { target: thumb; property: "x"; to: -3; duration: Motion.ms(60) }
        NumberAnimation { target: thumb; property: "x"; to: 0; duration: Motion.ms(60) }
    }
    function nudge(): void {
        shake.restart();
    }
}
