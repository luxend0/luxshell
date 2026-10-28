import QtQuick
import Quickshell.Widgets
import qs.config

// Icon of a notification / app: a themed icon or image URL, rounded when it is a
// picture (avatars, covers), a Lucide glyph when nothing resolves or loading fails.
Item {
    id: root

    property string source: ""
    property real size: 22
    property bool picture: false // photo-like source: fill + round the corners
    property string fallback: "message-square"
    property color fallbackColor: Theme.textSecondary
    readonly property bool failed: source === "" || (picture ? img.status === Image.Error : icon.status === Image.Error)

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: icon
        anchors.fill: parent
        visible: !root.picture && !root.failed
        source: root.picture ? "" : root.source
        asynchronous: true
        mipmap: true
    }

    ClippingRectangle {
        anchors.fill: parent
        visible: root.picture && !root.failed
        radius: width * 0.28
        color: "transparent"

        Image {
            id: img
            anchors.fill: parent
            source: root.picture ? root.source : ""
            sourceSize.width: Math.round(root.size * 2)
            sourceSize.height: Math.round(root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            mipmap: true
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.failed
        name: root.fallback
        size: root.size * 0.86
        color: root.fallbackColor
    }
}
