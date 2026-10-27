import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.widgets
import qs.island.bar

// Morph container for one screen. It only decides WHAT is shown (Ui priorities)
// and HOW BIG the body is; content comes from BarContent (collapsed/hover) or
// from PanelHost (whatever panel the registry provides, size reported by it).
Item {
    id: island

    required property var screen
    readonly property string screenName: screen?.name ?? ""
    readonly property alias body: shape

    // ---- what is shown ------------------------------------------------------
    readonly property string panelId: Ui.panelFor(screenName)
    readonly property string overlayId: panelId === "" ? Ui.overlayFor(screenName) : ""
    readonly property string shownId: panelId !== "" ? panelId : overlayId
    readonly property bool modal: panelId !== ""
    // focus grab + exclusive keyboard only where the panel was opened; a preview
    // shown on every screen must not fight over the grab
    readonly property bool grabs: modal && Ui.panelScreen === screenName
    readonly property Item panel: shownId !== "" ? host.current : null

    property bool pointerInside: false
    readonly property bool expanded: Ui.forced === "hover" || (Ui.forced !== "collapsed" && (pointerInside || bar.holdOpen))

    property real hoverProgress: expanded ? 1 : 0
    Behavior on hoverProgress {
        Anim {}
    }

    // ---- how big --------------------------------------------------------------
    readonly property real targetWidth: panel ? panel.preferredWidth : expanded ? Theme.hover.width : Theme.collapsed.width
    readonly property real targetHeight: panel ? panel.preferredHeight : expanded ? Theme.hover.height : Theme.collapsed.height
    readonly property real targetRadius: panel ? panel.cornerRadius : expanded ? Theme.hover.radius : Theme.collapsed.radius

    Timer {
        id: leaveHold
        interval: Theme.hoverHold
        onTriggered: island.pointerInside = false
    }

    IslandShape {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: island.targetWidth
        height: island.targetHeight
        radius: island.targetRadius
        Behavior on width {
            Anim {}
        }
        Behavior on height {
            Anim {}
        }
        Behavior on radius {
            Anim {}
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leaveHold.stop();
                    island.pointerInside = true;
                } else {
                    leaveHold.restart();
                }
            }
        }

        // click on the bar = control center (children with own handlers win)
        MouseArea {
            anchors.fill: parent
            enabled: !island.modal
            onClicked: Ui.toggle("controlcenter", island.screenName)
        }

        Item {
            anchors.fill: parent
            clip: true

            BarContent {
                id: bar
                width: parent.width
                height: parent.height
                p: island.hoverProgress
                screen: island.screen
                opacity: island.shownId === "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    Anim {
                        duration: Theme.fadeOut
                    }
                }
            }

            PanelHost {
                id: host
                anchors.fill: parent
                panelId: island.shownId
            }
        }
    }
}
