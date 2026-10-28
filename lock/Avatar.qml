import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.config
import qs.services

// Avatar disc of ref/11: translucent grey disc with a fine lighter ring and the filled
// person glyph (head 16 px, shoulders 30 x 15 at an 80 px disc). With Settings.lockAvatar
// the user's picture (~/.face, AccountsService) fills the disc instead.
Item {
    id: root

    property real size: 80
    readonly property QtObject g: Theme.lock
    readonly property real u: size / 80 // glyph measured at 80 px
    readonly property real c: size / 2
    readonly property bool picture: Lock.avatar !== "" && photo.status === Image.Ready

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, root.g.avatarFill)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, root.g.avatarRing)
    }

    Shape {
        id: glyph
        visible: !root.picture
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.g.fg(1)
            // head
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2 - 8 * root.u
                radiusX: 8 * root.u
                radiusY: 8 * root.u
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.g.fg(1)
            // shoulders: dome 30 wide from y +2 to +16, softly rounded bottom corners
            startX: root.c - 15 * root.u
            startY: root.c + 14.5 * root.u
            PathCubic {
                x: root.c
                y: root.c + 2 * root.u
                control1X: root.c - 15 * root.u
                control1Y: root.c + 6 * root.u
                control2X: root.c - 8.5 * root.u
                control2Y: root.c + 2 * root.u
            }
            PathCubic {
                x: root.c + 15 * root.u
                y: root.c + 14.5 * root.u
                control1X: root.c + 8.5 * root.u
                control1Y: root.c + 2 * root.u
                control2X: root.c + 15 * root.u
                control2Y: root.c + 6 * root.u
            }
            PathQuad {
                x: root.c + 13.5 * root.u
                y: root.c + 16 * root.u
                controlX: root.c + 15 * root.u
                controlY: root.c + 16 * root.u
            }
            PathLine {
                x: root.c - 13.5 * root.u
                y: root.c + 16 * root.u
            }
            PathQuad {
                x: root.c - 15 * root.u
                y: root.c + 14.5 * root.u
                controlX: root.c - 15 * root.u
                controlY: root.c + 16 * root.u
            }
        }
    }

    Image {
        id: photo
        anchors.fill: parent
        visible: false
        source: Lock.avatar !== "" ? "file://" + Lock.avatar : ""
        sourceSize.width: Math.round(root.size * 2)
        sourceSize.height: Math.round(root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.picture
        source: photo
        maskEnabled: true
        maskSource: mask
    }
}
