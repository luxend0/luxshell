import QtQuick

// Material Design glyph from the Nerd Font (filled icons like the video's sidebar),
// centred in a size x size box. glyph: Catalog.glyph(0xF03D8) etc.
Item {
    id: root

    property string glyph: ""
    property real size: 20
    property color color: "white"

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.color
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(root.size)
        renderType: Text.QtRendering
    }
}
