import QtQuick
import qs.config

// Text of the sheets, placed by the centre of its capitals (capY, parent
// coordinates) like CapText; px = pixel size (Inter cap height 0.727 em).
Text {
    property real capY: 0
    property int px: 15

    y: Math.round(capY - (baselineOffset - px * 0.727 / 2))
    font.family: Theme.fontFamily
    font.pixelSize: px
    color: Theme.text
    elide: Text.ElideRight
}
