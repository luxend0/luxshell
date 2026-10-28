import QtQuick
import qs.config
import qs.widgets

// Round transport button: primary = filled accent disc (play/pause), otherwise a bare
// glyph with a hover disc (previous/next). Press dips it a little.
Rectangle {
    id: root

    property string icon
    property bool primary: false
    property real glyphSize: Theme.media.skipGlyph
    property real glyphOffset: 0
    signal clicked

    width: primary ? Theme.media.playDisc : Theme.media.skipDisc
    height: width
    radius: width / 2
    color: primary ? Theme.accent : area.containsMouse ? Theme.media.skipHover : "transparent"
    opacity: enabled ? 1 : 0.35
    scale: area.pressed ? 0.92 : 1
    Behavior on scale {
        Anim {
            ms: 160
        }
    }
    Behavior on color {
        ColorAnim {}
    }

    Glyph {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.glyphOffset
        name: root.icon
        size: root.glyphSize
        filled: true
        stroke: 1.5
        color: root.primary ? Theme.onAccent : Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
