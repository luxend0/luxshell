import QtQuick
import qs.widgets

// Icon.qml over all three icon sets: WIcons (island widgets, editor), Glyphs, Icons.
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 20
    property real stroke: 2
    property bool filled: false

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        source: root.name === "" ? "" : WIcons.has(root.name) ? WIcons.url(root.name, root.color, root.stroke, root.filled) : Glyphs.has(root.name) ? Glyphs.url(root.name, root.color, root.stroke, root.filled) : Icons.url(root.name, root.color, root.stroke, root.filled)
        sourceSize.width: Math.max(1, Math.round(root.size))
        sourceSize.height: Math.max(1, Math.round(root.size))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
