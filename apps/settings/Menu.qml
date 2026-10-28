import QtQuick
import qs.config
import qs.widgets

// Dropdown of a "choice" row, inside the window above everything else. Opens under
// the row's right edge (above it when there is no room). Click outside or Esc closes.
// Keys (from the window): Up/Down, Home/End, Enter/Space picks, Esc closes.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property bool shown: false
    property var opt: null
    property var items: []
    property int highlighted: 0
    property real anchorRight: 0
    property real anchorTop: 0
    property real anchorBottom: 0
    signal closed

    visible: shown || box.opacity > 0.01

    FontMetrics {
        id: fm
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.g.textSize * Theme.fontScale)
        font.weight: Font.Medium
    }
    // widest label (in its own font where it has one) and detail
    readonly property real contentWidth: {
        let l = 0, d = 0;
        for (const it of items) {
            l = Math.max(l, fm.advanceWidth(it.label) * (it.font ? 1.15 : 1));
            if (it.detail)
                d = Math.max(d, fm.advanceWidth(it.detail));
        }
        return 34 + l + (d > 0 ? d + 32 : 0) + 18;
    }

    function show(row: Item, o: var): void {
        opt = o;
        items = o.options();
        highlighted = Math.max(0, items.findIndex(i => i.value === o.value()));
        const p = row.mapToItem(root, row.width - g.rowInset + 6, 0);
        anchorRight = p.x;
        anchorTop = p.y + row.height - 6;
        anchorBottom = p.y + 6;
        shown = true;
    }
    function close(): void {
        if (!shown)
            return;
        shown = false;
        closed();
    }
    function pick(i: int): void {
        const it = items[i];
        if (it && opt && it.value !== opt.value())
            opt.set(it.value);
        close();
    }

    function key(event): void {
        switch (event.key) {
        case Qt.Key_Up:
            highlighted = Math.max(0, highlighted - 1);
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            highlighted = Math.min(items.length - 1, highlighted + 1);
            break;
        case Qt.Key_Home:
            highlighted = 0;
            break;
        case Qt.Key_End:
            highlighted = items.length - 1;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            pick(highlighted);
            break;
        case Qt.Key_Escape:
        case Qt.Key_Left:
            close();
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: box
        readonly property real wanted: root.items.length * root.g.menuRow + 2 * root.g.menuPad
        readonly property bool below: root.anchorTop + wanted <= root.height - 12
        width: Math.min(root.width - 24, Math.max(root.g.menuMinWidth, root.contentWidth + 2 * root.g.menuPad))
        height: Math.min(wanted, root.height - 24)
        x: Math.max(12, root.anchorRight - width)
        y: below ? root.anchorTop : Math.max(12, root.anchorBottom - height)
        radius: root.g.menuRadius
        color: root.g.menu
        border.width: 1
        border.color: root.g.separator
        clip: true
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: below ? Item.TopRight : Item.BottomRight
        Behavior on opacity {
            Anim {
                ms: 140
            }
        }
        Behavior on scale {
            Anim {
                ms: 180
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true // swallow clicks between rows
        }

        Column {
            id: list
            x: root.g.menuPad
            y: root.g.menuPad
            width: box.width - 2 * root.g.menuPad

            Repeater {
                model: root.items

                Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.opt && modelData.value === root.opt.value()

                    width: list.width
                    height: root.g.menuRow
                    radius: root.g.menuRadius - root.g.menuPad
                    color: index === root.highlighted ? root.g.menuHover : "transparent"

                    MdIcon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Catalog.glyph(0xF012C) // md-check
                        size: 18
                        color: Theme.text
                        visible: item.selected
                    }
                    SText {
                        id: name
                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.modelData.label
                        font.family: item.modelData.font ?? Theme.fontFamily
                    }
                    SText {
                        id: detail
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.modelData.detail ?? ""
                        color: root.g.value
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.highlighted = item.index
                        onClicked: root.pick(item.index)
                    }
                }
            }
        }
    }
}
