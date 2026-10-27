import QtQuick
import qs.config

// Text whose size animates smoothly: integer font size + residual scale, so it is
// crisp at rest (scale 1) and has no 1px steps while morphing.
// Position it through anchorY (vertical centre of digits/caps, item coordinates).
Text {
    id: root

    property real size: 16
    readonly property real s: size / font.pixelSize
    readonly property real capHeight: font.pixelSize * 0.727 // Inter cap/figure height
    readonly property real anchorY: baselineOffset - capHeight / 2
    readonly property real visualWidth: width * s
    readonly property real visualCapHeight: capHeight * s

    font.family: Theme.fontFamily
    font.pixelSize: Math.max(1, Math.round(size))
    color: Theme.text

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.anchorY
        xScale: root.s
        yScale: root.s
    }
}
