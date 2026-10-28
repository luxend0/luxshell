import QtQuick
import qs.config
import qs.widgets
import qs.island.bar
import qs.island.widgets
import qs.apps.settings

// Island layout editor (custom row "Layout" of the Bar & Island page), direction A: a live
// preview to grab. The collapsed and the hover island are drawn by the island's own
// BarContent at preview scale (EditorStrip); below them the palette of every widget, the
// picked widget's options next to it (WidgetOptions).
//
//   drag a chip into a strip     adds it there (a widget sits at most once per state; the
//                                spacer may repeat), the slots light up, a caret marks the
//                                spot, neighbours move aside, the widget already shows
//   drag a widget in a strip     moves it (also into the other state)
//   drag it out of the strips    removes it ("Remove" chip; the toast offers Undo)
//   click a widget / a chip      shows its options;  Delete removes the picked widget
//   Ctrl+Z, Ctrl+Shift+Z / Ctrl+Y   undo / redo every edit made here (IslandEditing; the
//                                settings window hands the keys to undoKey())
// Every drop writes Settings.islandLayout at once: the island on screen follows, an edit of
// the hover layout shows the hover island on screen for a moment (BarRegistry.peek).
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject e: Theme.islandEditor
    property var opt: null
    property var row: null
    property var host: null

    readonly property var lib: BarRegistry.lib()
    readonly property var committed: BarRegistry.layout

    // ---- drag state --------------------------------------------------------------------------
    property bool pressed: false
    property point pressPos: Qt.point(0, 0)
    property var pressHit: null       // { kind: "chip" | "item", id, state?, row?, col?, idx? }
    property bool dragging: false
    property string dragId: ""
    property var dragFrom: null       // { state, row, col, idx } for a widget taken from a strip
    property point pointer: Qt.point(0, 0)
    property var dropAt: null         // { state, row, col, idx } or null (outside: remove / cancel)
    property string hoverChip: ""

    // committed layout without the dragged entry
    readonly property var baseLayout: dragging && dragFrom ? lib.removeAt(committed, dragFrom.state, dragFrom) : committed
    function baseFor(state: string): var {
        return dragId === "spacer" ? baseLayout : lib.removeId(baseLayout, state, dragId);
    }
    readonly property var viewLayout: {
        if (!dragging)
            return committed;
        if (!dropAt)
            return baseLayout;
        return lib.insertAt(baseFor(dropAt.state), dropAt.state, dropAt.row, dropAt.col, dropAt.idx, dragId);
    }
    readonly property bool removing: dragging && !dropAt && dragFrom !== null

    // preview scale, shared by both strips: the islands as drawn always fit (they grow while a
    // widget is dragged in, the scale follows); drops are measured at the scale of the layout
    // without the dragged widget, which holds still for the whole drag (no feedback)
    function fit(lay: var): real {
        return Math.min(e.maxScale, (width - 28) / Math.max(600, BarRegistry.width(lay, "hover"), BarRegistry.width(lay, "collapsed")));
    }
    readonly property real previewScale: fit(viewLayout)
    readonly property real hitScale: fit(baseLayout)

    implicitHeight: column.height + 4

    // ---- pointer -----------------------------------------------------------------------------
    function chipAt(x: real, y: real): string {
        for (let i = 0; i < chips.count; i++) {
            const c = chips.itemAt(i);
            const p = c.mapFromItem(root, x, y);
            if (p.x >= 0 && p.y >= 0 && p.x <= c.width && p.y <= c.height)
                return c.def.id;
        }
        return "";
    }
    // strip under a point; with a margin, the nearest strip within it (a strip the point is
    // really on always wins over a neighbour's margin)
    function stripAt(x: real, y: real, margin: real): var {
        let best = null, bestD = margin + 1;
        for (const s of [stripC, stripH]) {
            if (!s.visible)
                continue;
            const p = s.mapFromItem(root, x, y);
            const dx = Math.max(0, -p.x, p.x - s.width);
            const dy = Math.max(0, -p.y, p.y - s.height);
            const d = Math.max(dx, dy);
            if (d <= margin && d < bestD) {
                best = s;
                bestD = d;
            }
        }
        return best;
    }
    function hitAt(x: real, y: real): var {
        const id = chipAt(x, y);
        if (id !== "")
            return {
                "kind": "chip",
                "id": id
            };
        const s = stripAt(x, y, 0);
        if (!s)
            return null;
        const p = s.mapFromItem(root, x, y);
        const h = s.hit(p.x, p.y);
        return h ? {
            "kind": "item",
            "id": h.id,
            "state": s.mode,
            "row": h.row,
            "col": h.col,
            "idx": h.idx
        } : null;
    }
    function computeDrop(x: real, y: real): var {
        const s = stripAt(x, y, e.dropOut);
        if (!s || !BarRegistry.allowed(dragId, s.mode))
            return null;
        const p = s.mapFromItem(root, x, y);
        return s.dropTarget(p.x, p.y, baseFor(s.mode), root.hitScale);
    }
    function startDrag(): void {
        const h = pressHit;
        if (!h)
            return;
        dragId = h.id;
        dragFrom = h.kind === "item" ? {
            "state": h.state,
            "row": h.row,
            "col": h.col,
            "idx": h.idx
        } : null;
        dragging = true;
        dropAt = computeDrop(pointer.x, pointer.y);
    }
    function finishDrag(): void {
        const id = dragId, from = dragFrom, at = dropAt;
        const lay = at ? viewLayout : baseLayout;
        dragging = false;
        dropAt = null;
        dragFrom = null;
        dragId = "";
        if (at) {
            IslandEditing.setLayout(lay, at.state === "hover" || (from && from.state === "hover"));
            IslandEditing.selected = id;
        } else if (from) {
            IslandEditing.setLayout(lay, from.state === "hover");
            SettingsApp.toast(`Removed ${BarRegistry.def(id)?.name ?? id} from the ${from.state} island`, () => IslandEditing.undo());
        }
    }

    // ---- edits from the options panel and keys --------------------------------------------------
    // where "Add to ..." puts a widget: the slot its kind sits in by default
    function defaultSlot(id: string, state: string): var {
        const cls = BarRegistry.cls(id);
        if (state === "collapsed") {
            if (cls === "ws" || cls === "label")
                return {
                    "row": "",
                    "col": "left",
                    "end": true
                };
            if (cls === "time" || cls === "spacer")
                return {
                    "row": "",
                    "col": "center",
                    "end": true
                };
            return {
                "row": "",
                "col": "right",
                "end": false
            };
        }
        if (cls === "ws")
            return {
                "row": "bottom",
                "col": "left",
                "end": true
            };
        if (cls === "label")
            return {
                "row": "top",
                "col": "left",
                "end": true
            };
        if (cls === "time" || cls === "spacer")
            return {
                "row": "top",
                "col": "center",
                "end": true
            };
        if (cls === "system")
            return {
                "row": "top",
                "col": "right",
                "end": false
            };
        return {
            "row": "bottom",
            "col": "right",
            "end": false
        };
    }
    function add(id: string, state: string): void {
        const at = defaultSlot(id, state);
        const base = id === "spacer" ? committed : lib.removeId(committed, state, id);
        const n = BarRegistry.list(base, state, at.row, at.col).length;
        IslandEditing.setLayout(lib.insertAt(base, state, at.row, at.col, at.end ? n : 0, id), state === "hover");
    }
    function remove(id: string): void {
        if (!BarRegistry.contains(committed, "collapsed", id) && !BarRegistry.contains(committed, "hover", id))
            return;
        IslandEditing.setLayout(lib.removeId(lib.removeId(committed, "collapsed", id), "hover", id), false);
        SettingsApp.toast(`Removed ${BarRegistry.def(id)?.name ?? id}`, () => IslandEditing.undo());
    }

    // row contract (keys forwarded by the settings window)
    // Left/Right: pick the previous / next widget of the palette; Left on the first one goes
    // back to the sidebar
    function adjust(d: int): bool {
        const ids = BarRegistry.ids;
        const i = ids.indexOf(IslandEditing.selected);
        if (i <= 0 && d < 0)
            return false;
        IslandEditing.selected = ids[Math.max(0, Math.min(ids.length - 1, i < 0 ? 0 : i + d))];
        return true;
    }
    function deleteKey(): bool {
        const id = IslandEditing.selected;
        if (id === "" || (!BarRegistry.contains(committed, "collapsed", id) && !BarRegistry.contains(committed, "hover", id)))
            return false;
        remove(id);
        return true;
    }

    // Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y from the settings window (a text field with the keyboard
    // keeps them for its own text)
    function undoKey(redo: bool): bool {
        return redo ? IslandEditing.redo() : IslandEditing.undo();
    }

    // one area for every drag and click on strips and chips (controls on top keep theirs)
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : root.hoverChip !== "" ? Qt.OpenHandCursor : Qt.ArrowCursor
        onPressed: m => {
            if (root.host && root.row) {
                root.host.focusRoot();
                root.host.focusRow(root.row.flatIndex);
            }
            root.pressed = true;
            root.pressPos = Qt.point(m.x, m.y);
            root.pointer = Qt.point(m.x, m.y);
            root.pressHit = root.hitAt(m.x, m.y);
        }
        onPositionChanged: m => {
            root.pointer = Qt.point(m.x, m.y);
            if (!root.pressed) {
                const h = root.hitAt(m.x, m.y);
                root.hoverChip = h ? h.id : "";
                return;
            }
            if (!root.dragging && root.pressHit && Math.hypot(m.x - root.pressPos.x, m.y - root.pressPos.y) > root.e.dragThreshold)
                root.startDrag();
            if (root.dragging) {
                const d = root.computeDrop(m.x, m.y);
                if (JSON.stringify(d) !== JSON.stringify(root.dropAt))
                    root.dropAt = d;
            }
        }
        onReleased: m => {
            root.pressed = false;
            if (root.dragging) {
                root.finishDrag();
                return;
            }
            IslandEditing.selected = root.pressHit ? root.pressHit.id : "";
        }
        onCanceled: {
            root.pressed = false;
            root.dragging = false;
            root.dropAt = null;
            root.dragFrom = null;
            root.dragId = "";
        }
        onExited: if (!root.pressed)
            root.hoverChip = ""
    }

    Column {
        id: column
        width: parent.width
        spacing: 12

        // ---- toolbar ----
        Item {
            width: parent.width
            height: root.e.segHeight

            Segmented {
                items: [
                    {
                        "value": "collapsed",
                        "label": "Collapsed"
                    },
                    {
                        "value": "hover",
                        "label": "Hover"
                    },
                    {
                        "value": "both",
                        "label": "Both"
                    }
                ]
                value: IslandEditing.view
                onPicked: v => IslandEditing.view = v
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                MiniButton {
                    glyph: Catalog.glyph(0xF054C) // undo
                    active: IslandEditing.canUndo
                    onClicked: IslandEditing.undo()
                }
                MiniButton {
                    glyph: Catalog.glyph(0xF044E) // redo
                    active: IslandEditing.canRedo
                    onClicked: IslandEditing.redo()
                }
            }
        }

        // ---- previews ----
        EditorStrip {
            id: stripC
            visible: IslandEditing.view !== "hover"
            width: parent.width
            mode: "collapsed"
            s: root.previewScale
            hs: root.hitScale
            layout: root.viewLayout
            ghostId: root.dragging && root.dropAt && root.dropAt.state === "collapsed" ? root.dragId : ""
            caretKey: ghostId === "" ? "" : root.dragId === "spacer" ? `spacer@.${root.dropAt.col}.${root.dropAt.idx}` : root.dragId
            selectedId: root.dragging ? "" : IslandEditing.selected
            zones: root.dragging && BarRegistry.allowed(root.dragId, "collapsed")
            blocked: root.dragging && !BarRegistry.allowed(root.dragId, "collapsed")
            hot: root.dragging && root.dropAt && root.dropAt.state === "collapsed" ? root.dropAt : null
        }
        EditorStrip {
            id: stripH
            visible: IslandEditing.view !== "collapsed"
            width: parent.width
            mode: "hover"
            s: root.previewScale
            hs: root.hitScale
            layout: root.viewLayout
            ghostId: root.dragging && root.dropAt && root.dropAt.state === "hover" ? root.dragId : ""
            caretKey: ghostId === "" ? "" : root.dragId === "spacer" ? `spacer@${root.dropAt.row}.${root.dropAt.col}.${root.dropAt.idx}` : root.dragId
            selectedId: root.dragging ? "" : IslandEditing.selected
            zones: root.dragging && BarRegistry.allowed(root.dragId, "hover")
            blocked: root.dragging && !BarRegistry.allowed(root.dragId, "hover")
            hot: root.dragging && root.dropAt && root.dropAt.state === "hover" ? root.dropAt : null
        }

        // ---- palette + options ----
        Item {
            width: parent.width
            height: Math.max(palette.height, options.height)

            Flow {
                id: palette
                width: parent.width - root.e.optionsWidth - 14
                spacing: root.e.chipGap

                Repeater {
                    id: chips
                    model: BarRegistry.widgets

                    WidgetChip {
                        required property var modelData
                        def: modelData
                        hovered: root.hoverChip === modelData.id && !root.dragging
                        selected: IslandEditing.selected === modelData.id && !root.dragging
                        dimmed: root.dragging && root.dragFrom === null && root.dragId === modelData.id
                        usedC: BarRegistry.contains(root.committed, "collapsed", modelData.id)
                        usedH: BarRegistry.contains(root.committed, "hover", modelData.id)
                        unavailable: modelData.id === "battery" && !BarRegistry.hasBattery()
                    }
                }
            }

            WidgetOptions {
                id: options
                x: palette.width + 14
                width: root.e.optionsWidth
                widgetId: IslandEditing.selected
                onAddRequested: state => root.add(widgetId, state)
                onRemoveRequested: root.remove(widgetId)
            }
        }

        SText {
            width: parent.width
            wrapMode: Text.WordWrap
            size: 13
            color: root.g.caption
            text: "Drag a widget into a slot of the island, drag it out to remove it. Ctrl+Z undoes, Ctrl+Shift+Z redoes."
        }
    }

    // the chip under the pointer while dragging
    WidgetChip {
        z: 10
        visible: root.dragging
        floating: true
        def: BarRegistry.def(root.dragId)
        removing: root.removing
        // below-right of the pointer: the spot it drops on stays in view
        x: root.pointer.x + 14
        y: root.pointer.y + 12
    }
}
