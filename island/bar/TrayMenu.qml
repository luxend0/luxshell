import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.widgets

// Context menu of a tray item in the island's look. Reads the dbusmenu through QsMenuOpener,
// so quickshell needs no QApplication (QsMenuAnchor would, and draws a plain Qt menu).
// Submenus open in place with a back row on top. Closes on a click outside or Escape.
PopupWindow {
    id: root

    readonly property real gap: 8 // below the icon
    readonly property real pad: 6
    readonly property real rowH: 32
    readonly property real minW: 180
    readonly property real maxW: 420

    // menu handles from the item's root menu down to the open submenu
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : null

    property real closedAt: 0
    function open(item: Item, menu: var): void {
        // a click on the same icon closed the menu through the grab a moment ago: toggle
        if (anchor.item === item && Date.now() - closedAt < 300)
            return;
        anchor.item = item;
        stack = [menu];
        visible = true;
    }
    function close(): void {
        visible = false;
        stack = [];
        closedAt = Date.now();
    }

    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: body.width
    implicitHeight: body.height + gap

    QsMenuOpener {
        id: opener
        menu: root.current
    }
    // keeps the root menu referenced while a submenu shows (an unreferenced dbusmenu is freed)
    QsMenuOpener {
        menu: root.stack[0] ?? null
    }

    // armed a moment after the popup mapped; armed in the same frame Hyprland drops it and a
    // click outside would never close the menu (same trap as IslandWindow.qml)
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: if (root.visible)
            root.close()
    }
    Timer {
        id: armGrab
        interval: 60
        onTriggered: grab.active = root.visible
    }
    onVisibleChanged: {
        if (visible)
            armGrab.restart();
        else
            grab.active = false;
    }

    // widest label decides the width; rows read it, so no binding loop
    readonly property bool lead: {
        for (const c of col.children)
            if (c.lead)
                return true;
        return false;
    }
    readonly property real menuW: {
        let w = minW;
        for (const c of col.children)
            if (c.natural !== undefined)
                w = Math.max(w, c.natural);
        return Math.min(w, maxW);
    }

    Rectangle {
        id: body
        y: root.gap
        width: root.menuW + 2 * root.pad
        height: col.implicitHeight + 2 * root.pad
        radius: Theme.rad(14)
        color: Theme.island
        border.width: 1
        border.color: Theme.surfaceHigh
        focus: true
        Keys.onEscapePressed: root.close()

        Column {
            id: col
            x: root.pad
            y: root.pad

            MenuRow {
                visible: root.stack.length > 1
                label: root.current?.text ?? ""
                glyph: "chevron-left"
                onActivated: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Item {
                    id: entry
                    required property QsMenuEntry modelData
                    readonly property bool lead: !modelData.isSeparator && (modelData.icon !== "" || modelData.buttonType !== QsMenuButtonType.None)
                    readonly property real natural: modelData.isSeparator ? 0 : row.natural
                    width: root.menuW
                    height: modelData.isSeparator ? 9 : root.rowH

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Theme.surfaceHigh
                    }

                    MenuRow {
                        id: row
                        visible: !entry.modelData.isSeparator
                        label: entry.modelData.text
                        icon: entry.modelData.icon
                        checked: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState === Qt.Checked
                        sub: entry.modelData.hasChildren
                        active: entry.modelData.enabled
                        onActivated: {
                            if (entry.modelData.hasChildren) {
                                root.stack = root.stack.concat([entry.modelData]);
                            } else {
                                entry.modelData.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Item {
        id: mr
        property string label: ""
        property string icon: ""
        property string glyph: ""
        property bool checked: false
        property bool sub: false
        property bool active: true
        signal activated
        readonly property real leadW: root.lead || glyph !== "" ? 24 : 0
        readonly property real natural: 10 + leadW + text.implicitWidth + (sub ? 28 : 10)
        width: root.menuW
        height: root.rowH

        Rectangle {
            anchors.fill: parent
            radius: Theme.rad(8)
            color: Theme.surface
            opacity: area.containsMouse && mr.active ? 1 : 0
        }
        Icon {
            visible: mr.glyph !== "" || mr.checked
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: mr.glyph !== "" ? mr.glyph : "check"
            size: 16
            color: Theme.textSecondary
        }
        IconImage {
            visible: mr.icon !== "" && !mr.checked
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: mr.icon
        }
        Txt {
            id: text
            x: 10 + mr.leadW
            width: parent.width - x - (mr.sub ? 28 : 10)
            anchors.verticalCenter: parent.verticalCenter
            text: mr.label
            elide: Text.ElideRight
            font.pixelSize: Theme.tx(14)
            color: mr.active ? Theme.text : Theme.textDim
        }
        Icon {
            visible: mr.sub
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-right"
            size: 16
            color: Theme.textSecondary
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: mr.active
            onClicked: mr.activated()
        }
    }
}
