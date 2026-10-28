import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// One wallpaper card (ref/06). Driven by d like ThemeCard: the centred thumbnail is
// full size with a light frame, every step outward is 10 % smaller and darker
// (ref/06: 1, .9, .8 at a constant pitch). The thumbnail comes from the cache
// (services/Wallpapers); until the background job reports it, the card shows the theme
// surface (no load attempt on a missing file, so no warnings).
Item {
    id: thumb

    property int index: 0
    property real d: 0
    property var entry: null
    property bool current: false

    readonly property var g: Theme.wallpaperPicker
    readonly property real a: Math.abs(d)
    readonly property string file: entry?.thumb ?? ""

    width: g.thumbWidth
    height: g.thumbHeight
    y: (g.stripHeight - g.thumbHeight) / 2
    scale: Math.max(0.5, 1 - g.shrink * a)

    ClippingRectangle {
        anchors.fill: parent
        radius: thumb.g.radius
        color: Theme.surfaceHigh

        Image {
            id: img
            anchors.fill: parent
            source: Wallpapers.ready[thumb.file] ? Wallpapers.url(thumb.file) : ""
            sourceSize.width: thumb.g.thumbW
            sourceSize.height: thumb.g.thumbH
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.ms(180)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Math.min(thumb.g.maxDim, thumb.g.dim * thumb.a)
            visible: opacity > 0.002
        }
    }

    // selection frame
    Rectangle {
        anchors.fill: parent
        radius: thumb.g.radius
        color: "transparent"
        border.width: Theme.picker.frame
        border.color: Theme.text
        opacity: Math.max(0, 1 - 2 * thumb.a)
        visible: opacity > 0.002
    }

    // applied wallpaper (ref/06: small light dot in the top right corner)
    Rectangle {
        visible: thumb.current
        x: parent.width - thumb.g.currentInset - width / 2
        y: thumb.g.currentInset - height / 2
        width: thumb.g.currentSize
        height: width
        radius: width / 2
        color: Theme.text
        border.width: 1.5
        border.color: Qt.rgba(0, 0, 0, 0.35)
    }
}
