import QtQuick
import QtQuick.Shapes
import qs.config

// The island body: flat top flush with the screen edge, rounded bottom, and two
// small concave fillets ("ears") that blend the top corners into the edge.
// Children go inside the body (default property).
Item {
    id: root

    property real radius: 20
    property real ear: Theme.earRadius
    property bool floating: false // below the edge (Settings.islandMargin): all corners round, no ears
    property color color: Theme.island
    default property alias content: body.data

    Rectangle {
        id: body
        anchors.fill: parent
        color: root.color
        topLeftRadius: root.floating ? bottomLeftRadius : 0
        topRightRadius: root.floating ? bottomLeftRadius : 0
        bottomLeftRadius: Math.min(root.radius, height / 2, width / 2)
        bottomRightRadius: bottomLeftRadius
    }

    // left ear: square minus a quarter disc centred at its bottom-left corner
    Shape {
        x: -root.ear
        width: root.ear
        height: root.ear
        visible: root.ear > 0 && !root.floating
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: root.ear; y: 0 }
            PathLine { x: root.ear; y: root.ear }
            PathArc {
                x: 0
                y: 0
                radiusX: root.ear
                radiusY: root.ear
                direction: PathArc.Counterclockwise
            }
        }
    }

    // right ear: mirror image
    Shape {
        x: root.width
        width: root.ear
        height: root.ear
        visible: root.ear > 0 && !root.floating
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: root.ear; y: 0 }
            PathArc {
                x: 0
                y: root.ear
                radiusX: root.ear
                radiusY: root.ear
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }
}
