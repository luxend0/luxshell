import QtQuick
import qs.config
import qs.widgets

// Dropdown of a "choice" / "font" row, inside the window above everything else. Opens
// under the row's right edge (above it when there is no room). Click outside or Esc closes.
// Long lists (more than menuMaxRows, every font list, or searchable: true) scroll and
// get a filter line: typing filters, Backspace edits it.
// Keys (from the window): Up/Down, PgUp/PgDn, Home/End, Enter/Space picks, Esc clears the
// filter, then closes.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property bool shown: false
    property var opt: null
    property var items: []
    property string filter: ""
    property bool searchable: false
    property int highlighted: 0
    property real anchorRight: 0
    property real anchorTop: 0
    property real anchorBottom: 0
    signal closed

    readonly property var shownItems: {
        const f = filter.trim().toLowerCase();
        if (f === "")
            return items;
        const starts = [], has = [];
        for (const it of items) {
            const l = String(it.label).toLowerCase();
            if (l.startsWith(f))
                starts.push(it);
            else if (l.includes(f) || String(it.detail ?? "").toLowerCase().includes(f))
                has.push(it);
        }
        return starts.concat(has);
    }
    readonly property bool isFont: opt?.kind === "font"

    visible: shown || box.opacity > 0.01

    FontMetrics {
        id: fm
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.g.textSize * Theme.fontScale)
        font.weight: Font.Medium
    }
    // widest label (in its own font where it has one) and detail
    readonly property real contentWidth: {
        if (isFont)
            return g.fontMenuWidth - 2 * g.menuPad;
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
        filter = "";
        searchable = o.searchable === true || o.kind === "font" || items.length > g.menuMaxRows;
        highlighted = Math.max(0, items.findIndex(i => i.value === o.value()));
        const p = row.mapToItem(root, row.width - g.rowInset + 6, 0);
        anchorRight = p.x;
        anchorTop = p.y + row.height - 6;
        anchorBottom = p.y + 6;
        shown = true;
        list.positionViewAtIndex(highlighted, ListView.Center);
    }
    function close(): void {
        if (!shown)
            return;
        shown = false;
        closed();
    }
    function pick(i: int): void {
        const it = shownItems[i];
        if (it && opt && it.value !== opt.value())
            opt.set(it.value);
        close();
    }
    function hilite(i: int): void {
        highlighted = Math.max(0, Math.min(shownItems.length - 1, i));
        list.positionViewAtIndex(highlighted, ListView.Contain);
    }
    onFilterChanged: {
        highlighted = 0;
        list.positionViewAtBeginning();
    }

    function key(event): void {
        const page = Math.max(1, g.menuMaxRows - 1);
        switch (event.key) {
        case Qt.Key_Up:
            return hilite(highlighted - 1);
        case Qt.Key_Down:
        case Qt.Key_Tab:
            return hilite(highlighted + 1);
        case Qt.Key_PageUp:
            return hilite(highlighted - page);
        case Qt.Key_PageDown:
            return hilite(highlighted + page);
        case Qt.Key_Home:
            return hilite(0);
        case Qt.Key_End:
            return hilite(shownItems.length - 1);
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return pick(highlighted);
        case Qt.Key_Space:
            if (!searchable || filter === "")
                return pick(highlighted);
            filter += " ";
            return;
        case Qt.Key_Backspace:
            if (searchable)
                filter = filter.slice(0, -1);
            return;
        case Qt.Key_Escape:
            if (filter !== "")
                filter = "";
            else
                close();
            return;
        case Qt.Key_Left:
            if (filter === "")
                close();
            return;
        }
        if (searchable && event.text.length === 1 && event.text > " ")
            filter += event.text;
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
        readonly property real head: root.searchable ? root.g.menuFilterHeight : 0
        // a filtered list keeps its size while typing
        readonly property int rows: root.searchable ? root.g.menuMaxRows : Math.max(1, root.shownItems.length)
        readonly property real wanted: head + rows * root.g.menuRow + 2 * root.g.menuPad
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

        // filter line (long lists)
        Item {
            visible: root.searchable
            x: root.g.menuPad
            y: root.g.menuPad
            width: box.width - 2 * root.g.menuPad
            height: box.head

            MdIcon {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(0xF0349) // md-magnify
                size: 18
                color: root.g.placeholder
            }
            SText {
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 60
                elide: Text.ElideLeft
                text: root.filter === "" ? "Type to filter" : root.filter
                color: root.filter === "" ? root.g.placeholder : root.g.label
            }
            SText {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                text: `${root.shownItems.length}`
                color: root.g.caption
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.g.separator
            }
        }

        ListView {
            id: list
            x: root.g.menuPad
            y: root.g.menuPad + box.head
            width: box.width - 2 * root.g.menuPad
            height: box.height - y - root.g.menuPad
            clip: true
            model: root.shownItems
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            highlightMoveDuration: 0

            delegate: Rectangle {
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
                    width: Math.min(implicitWidth, parent.width - x - (detail.text !== "" ? detail.implicitWidth + 28 : 12))
                    elide: Text.ElideRight
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

            SText {
                visible: root.shownItems.length === 0
                anchors.centerIn: parent
                text: "Nothing matches"
                color: root.g.value
            }
        }

        // thin scroll handle
        Rectangle {
            visible: list.interactive
            x: box.width - 6
            y: list.y + list.visibleArea.yPosition * list.height
            width: 3
            height: Math.max(24, list.visibleArea.heightRatio * list.height)
            radius: 1.5
            color: root.g.scrollbar
        }
    }
}
