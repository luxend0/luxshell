import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.config
import qs.services

// Tray icons, dimmed until pointed at. openMenus > 0 keeps the island expanded.
Row {
    id: root

    property int openMenus: 0
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null
    readonly property real iconSize: Theme.hover.trayIconSize
    // BarWidget contract (hover island only)
    readonly property real wC: implicitWidth
    readonly property real wH: implicitWidth

    spacing: 10

    Repeater {
        model: Tray.items

        Item {
            id: entry
            required property SystemTrayItem modelData
            width: root.iconSize
            height: root.iconSize

            IconImage {
                anchors.fill: parent
                source: entry.modelData.icon
                opacity: area.containsMouse ? 1 : 0.75
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -4
                enabled: root.interactive
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    if (m.button === Qt.RightButton && entry.modelData.hasMenu)
                        menu.open();
                    else if (m.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (entry.modelData.onlyMenu && entry.modelData.hasMenu)
                        menu.open();
                    else
                        entry.modelData.activate();
                }
                onWheel: w => entry.modelData.scroll(w.angleDelta.y / 120, false)
            }

            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                onVisibleChanged: root.openMenus += visible ? 1 : -1
            }
        }
    }
}
