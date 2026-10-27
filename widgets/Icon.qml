import QtQuick

// Lucide glyph in any colour. size may animate; the SVG is rasterised at the
// rounded size, so it is pixel exact at rest.
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
        source: root.name !== "" ? Icons.url(root.name, root.color, root.stroke, root.filled) : ""
        sourceSize.width: Math.max(1, Math.round(root.size))
        sourceSize.height: Math.max(1, Math.round(root.size))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
