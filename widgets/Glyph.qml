import QtQuick

// Icon.qml with the extra Glyphs set: same API (name, color, size, stroke, filled),
// looks the name up in Glyphs first, then in Icons.
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
        source: root.name === "" ? "" : Glyphs.has(root.name) ? Glyphs.url(root.name, root.color, root.stroke, root.filled) : Icons.url(root.name, root.color, root.stroke, root.filled)
        sourceSize.width: Math.max(1, Math.round(root.size))
        sourceSize.height: Math.max(1, Math.round(root.size))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
