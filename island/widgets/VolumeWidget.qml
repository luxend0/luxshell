import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.core

// Output volume glyph (20 px collapsed, 24 px hover), optional percentage after it.
// Scrolling on it always changes the volume (BarContent asks wantsVolumeScroll). Click: sound menu.
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null
    readonly property bool wantsVolumeScroll: true

    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    readonly property bool percent: Settings.islandVolumePercent
    readonly property string pctText: `${Math.round(Audio.volume * 100)}%`
    readonly property real wC: c.volumeSize + (percent ? wm.iconGap[0] + measureC.implicitWidth : 0)
    readonly property real wH: h.volumeSize + (percent ? wm.iconGap[1] + measureH.implicitWidth : 0)

    implicitWidth: icon.width + (percent ? wm.iconGap[0] + (wm.iconGap[1] - wm.iconGap[0]) * t + pct.implicitWidth : 0)
    implicitHeight: icon.height

    Icon {
        id: icon
        name: Audio.icon
        size: root.c.volumeSize + (root.h.volumeSize - root.c.volumeSize) * root.t
        color: Theme.text
    }
    Txt {
        id: pct
        visible: root.percent
        anchors.right: parent.right
        anchors.verticalCenter: icon.verticalCenter
        text: root.pctText
        font.pixelSize: Math.round(root.wm.textSize[0] + (root.wm.textSize[1] - root.wm.textSize[0]) * root.t)
        font.weight: Font.Medium
    }
    Txt {
        id: measureC
        visible: false
        text: root.pctText
        font.pixelSize: root.wm.textSize[0]
        font.weight: Font.Medium
    }
    Txt {
        id: measureH
        visible: false
        text: root.pctText
        font.pixelSize: root.wm.textSize[1]
        font.weight: Font.Medium
    }

    // click opens the sound menu (panel "sheet-sound", Settings.islandVolumeMenu; off: the click falls
    // through to the island); same highlight as the bar menus' widgets (island/widgets/BarToggle)
    Rectangle {
        id: menuHit
        z: -1 // behind the glyph
        x: -Theme.menus.hitPad
        width: root.width + 2 * Theme.menus.hitPad
        height: root.wm.iconSize[0] + (root.wm.iconSize[1] - root.wm.iconSize[0]) * root.t + Theme.menus.hitGrow
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.menus.hit
        opacity: menuArea.containsMouse && menuArea.enabled ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
    }
    MouseArea {
        id: menuArea
        anchors.fill: menuHit
        enabled: root.interactive && Settings.islandVolumeMenu
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.open("sheet-sound", root.screen ? root.screen.name : undefined)
    }
}
