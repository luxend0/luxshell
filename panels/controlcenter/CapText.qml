import QtQuick
import qs.config

// Text placed by the vertical centre of its capitals (capY, parent coordinates),
// which is what the reference measurements give. Inter cap height = 0.727 em.
Text {
    property real capY: 0

    y: Math.round(capY - (baselineOffset - font.pixelSize * 0.727 / 2))
    font.family: Theme.fontFamily
    color: Theme.text
    elide: Text.ElideRight
}
