import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.config

// The island body: flat top flush with the screen edge, rounded bottom, and two
// small concave fillets ("ears") that blend the top corners into the edge.
// Children go inside the body (default property).
//
// Look options (Theme.look, Settings look*): the fill can be translucent (island and
// panel opacity apart, `panel` = a panel or overlay is shown), an outline can follow
// ears + sides + bottom, and a drop shadow can sit under the body. The shadow is cut
// out under a translucent body, so it never darkens what shows through the island.
Item {
    id: root

    property real radius: 20
    property real ear: Theme.earRadius
    property color color: Theme.island
    property bool panel: false
    default property alias content: body.data

    readonly property QtObject look: Theme.look
    readonly property real r: Math.min(radius, height / 2, width / 2)
    property real alpha: panel ? look.panelOpacity : look.islandOpacity
    Behavior on alpha {
        NumberAnimation {
            duration: Motion.ms(root.look.fillMs)
            easing.type: Easing.OutCubic
        }
    }
    readonly property color fill: Qt.rgba(color.r, color.g, color.b, color.a * alpha)

    // ---- shadow (below everything) ---------------------------------------------------
    Loader {
        id: shadowLoader
        active: root.look.shadow
        // the shadow layer covers the body plus a margin on the sides and below
        x: -m
        y: -m
        width: root.width + 2 * m
        height: root.height + 2 * m
        readonly property real m: root.look.shadowMargin
        sourceComponent: Item {
            id: shadowBox

            readonly property bool cut: root.alpha < 0.999

            // the shadow itself; its top runs off the screen edge (flat top, round bottom)
            Item {
                id: shadowSrc
                anchors.fill: parent
                layer.enabled: shadowBox.cut
                visible: !shadowBox.cut

                RectangularShadow {
                    x: shadowLoader.m
                    y: shadowLoader.m - root.r - 2
                    width: root.width
                    height: root.height + root.r + 2
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: root.r
                    bottomRightRadius: root.r
                    blur: root.look.shadowBlur
                    offset.y: root.look.shadowOffset
                    color: Qt.rgba(0, 0, 0, root.look.shadowOpacity)
                }
            }

            // body silhouette: what the shadow must not cover while the body is see-through
            Item {
                id: hole
                anchors.fill: parent
                visible: false
                layer.enabled: shadowBox.cut

                Rectangle {
                    x: shadowLoader.m
                    y: shadowLoader.m - 1
                    width: root.width
                    height: root.height + 1
                    bottomLeftRadius: root.r
                    bottomRightRadius: root.r
                    color: "black"
                }
            }

            Loader {
                anchors.fill: parent
                active: shadowBox.cut
                sourceComponent: MultiEffect {
                    source: shadowSrc
                    maskEnabled: true
                    maskInverted: true
                    maskSource: hole
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 0.2
                }
            }
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: root.fill
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.r
        bottomRightRadius: root.r
    }

    // left ear: square minus a quarter disc centred at its bottom-left corner
    Shape {
        x: -root.ear
        width: root.ear
        height: root.ear
        visible: root.ear > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
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
        visible: root.ear > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
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

    // ---- outline: left ear arc, left side, bottom with its corners, right side, right ear arc.
    // The stroke is centred on the path, so the path runs half a stroke inside the body
    // (ear arcs: radius ear + h around the ear's centre; corners: radius r - h). Without
    // ears both ends start just above the screen edge (zero-length arcs draw nothing).
    Shape {
        id: outline
        visible: root.look.border
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real h: root.look.borderWidth / 2
        readonly property real e: root.ear
        readonly property bool ears: e > 0
        readonly property real er: e + h
        readonly property real cr: Math.max(0, root.r - h)
        readonly property real w: root.width
        readonly property real b: root.height
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.look.borderColor
            strokeWidth: root.look.borderWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: outline.ears ? -outline.e : outline.h
            startY: outline.ears ? -outline.h : -1
            PathArc {
                x: outline.h
                y: outline.ears ? outline.e : -1
                radiusX: outline.er
                radiusY: outline.er
                direction: PathArc.Clockwise
            }
            PathLine { x: outline.h; y: outline.b - outline.h - outline.cr }
            PathArc {
                x: outline.h + outline.cr
                y: outline.b - outline.h
                radiusX: outline.cr
                radiusY: outline.cr
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.w - outline.h - outline.cr; y: outline.b - outline.h }
            PathArc {
                x: outline.w - outline.h
                y: outline.b - outline.h - outline.cr
                radiusX: outline.cr
                radiusY: outline.cr
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.w - outline.h; y: outline.ears ? outline.e : -1 }
            PathArc {
                x: outline.ears ? outline.w + outline.e : outline.w - outline.h
                y: outline.ears ? -outline.h : -1
                radiusX: outline.er
                radiusY: outline.er
                direction: PathArc.Clockwise
            }
        }
    }
}
