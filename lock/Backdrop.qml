import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Lock screen background: blurred, desaturated and darkened.
//
//   source   the applied wallpaper (Settings.wallpaper; a video contributes one cached still,
//            services/Lock), else the screenshot of this screen taken as the lock surface
//            appears (ScreencopyView, one frame), else black
//   strength Settings.lockBlur (0..1 of the blur) and Settings.lockDim (darkening), Lock Screen page
//   level    0 = the plain screenshot (desktop as it was), 1 = full lock look. The wallpaper
//            fades in over the screenshot with the same value, so locking blurs the desktop
//            into the lock screen and unlocking blurs it back out.
Item {
    id: root

    property var screen: null
    property real level: 1
    readonly property QtObject g: Theme.lock

    // what gets blurred
    Item {
        id: stage
        anchors.fill: parent
        visible: false

        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: root.screen
            live: false
            paintCursor: false
        }

        Image {
            id: wall
            anchors.fill: parent
            source: Lock.backdrop !== "" ? Wallpapers.url(Lock.backdrop) : ""
            // blurred anyway: half resolution decodes fast and costs a quarter of the memory
            sourceSize.width: Math.round(width / 2)
            sourceSize.height: Math.round(height / 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            smooth: true
            opacity: root.level
            onStatusChanged: if (status === Image.Error)
                console.warn(`luxshell: lock screen cannot show ${Lock.backdrop}`)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: stage
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: root.g.blurMax
        blur: root.g.blur * Math.max(0, Math.min(1, Settings.lockBlur)) * root.level
        saturation: root.g.saturation * root.level
    }

    Rectangle {
        anchors.fill: parent
        color: root.g.dimColor
        opacity: Math.max(0, Math.min(0.95, Settings.lockDim)) * (shot.hasContent ? root.level : 1)
    }
}
