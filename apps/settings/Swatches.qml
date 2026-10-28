import QtQuick
import qs.config
import qs.widgets

// Accent colour discs (ref/12): theme accent first, then the palette's six swatches.
// The applied one carries a black centre dot.
Row {
    id: root

    readonly property QtObject g: Theme.settings
    property var colours: []
    property int current: -1
    signal picked(int index)

    spacing: g.swatchStep - g.swatch
    layoutDirection: Qt.LeftToRight

    Repeater {
        model: root.colours

        Item {
            id: cell
            required property var modelData
            required property int index

            width: root.g.swatch
            height: root.g.swatch

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: cell.modelData
                scale: tap.containsMouse ? 1.1 : 1
                Behavior on scale {
                    Anim {
                        ms: Theme.fadeOut
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.g.swatchDot
                    height: width
                    radius: width / 2
                    color: Theme.island
                    opacity: cell.index === root.current ? 1 : 0
                    Behavior on opacity {
                        Anim {
                            ms: Theme.fadeIn
                        }
                    }
                }
            }

            MouseArea {
                id: tap
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(cell.index)
            }
        }
    }
}
