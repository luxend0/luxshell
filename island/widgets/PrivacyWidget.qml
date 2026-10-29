import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// Privacy indicator: a red dot, with the glyphs of what is in use (screen, camera, microphone)
// unless Settings.islandPrivacyStyle is "dot". Shows only while something is in use
// (services/Privacy, BarRegistry.present). Click: panels/PrivacyPanel (which apps, what).
Item {
    id: root

    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject wm: Theme.widgets
    readonly property QtObject b: Theme.barInfo
    readonly property bool icons: Settings.islandPrivacyStyle !== "dot"
    readonly property var glyphs: icons ? Privacy.glyphs : []
    readonly property int n: glyphs.length
    function mix(a: real, b: real): real {
        return a + (b - a) * t;
    }
    function widthAt(si: int): real {
        const ic = Math.round(wm.iconSize[si] * b.privacyIconScale);
        return b.dotSize[si] + (n > 0 ? b.privacyGap[si] + n * ic + (n - 1) * b.privacyIconGap[si] : 0);
    }
    readonly property real wC: widthAt(0)
    readonly property real wH: widthAt(1)

    implicitWidth: mix(wC, wH)
    implicitHeight: Math.round(mix(wm.iconSize[0], wm.iconSize[1]))

    Rectangle {
        x: -Theme.media.chipPad
        width: root.width + 2 * Theme.media.chipPad
        height: root.height + 14
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.media.chipHover
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
    }

    Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        width: root.mix(root.b.dotSize[0], root.b.dotSize[1])
        height: width
        radius: width / 2
        color: Theme.danger
    }
    Row {
        x: dot.width + root.mix(root.b.privacyGap[0], root.b.privacyGap[1])
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.mix(root.b.privacyIconGap[0], root.b.privacyIconGap[1])
        Repeater {
            model: root.glyphs
            WIcon {
                required property string modelData
                name: modelData
                size: root.mix(root.wm.iconSize[0], root.wm.iconSize[1]) * root.b.privacyIconScale
                color: Theme.text
                opacity: root.textOpacity
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggle("privacy", root.screen ? root.screen.name : undefined)
    }
}
