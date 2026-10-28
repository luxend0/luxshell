import QtQuick
import qs.config
import qs.widgets
import qs.island
import qs.island.bar
import qs.apps.settings

// One state of the island in the editor: a strip of "screen" with the real island hanging
// from its top edge, rendered by the island's own BarContent at preview scale (same widgets,
// same layout engine, same live data; read only). While a widget is dragged the strip shows
// its slots as zones, the zone under the pointer lit, an insertion caret where the widget
// would land, and the widget itself already there (translucent) with its neighbours moved
// aside. Spacers, invisible on screen, show as outlines here.
//
// Coordinates: bar = unscaled island coordinates (layout.js), strip = this item.
Item {
    id: strip

    readonly property QtObject g: Theme.settings
    readonly property QtObject e: Theme.islandEditor
    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover

    property string mode: "collapsed"     // collapsed | hover
    property var layout: BarRegistry.layout
    property real s: 0.6
    property real hs: s                   // scale the strip height follows (stable while dragging)
    property string ghostId: ""           // dragged widget drawn translucent
    property string selectedId: ""
    property bool zones: false            // dragging a widget that may go here
    property bool blocked: false          // dragging a widget that may not go here
    property var hot: null                // { row, col } under the pointer
    property string caretKey: ""          // plan key of the dragged widget in this strip

    readonly property bool hoverMode: mode === "hover"
    // hover layout without anything: the island never expands, the strip shows it collapsed
    readonly property bool asHover: hoverMode && !bar.hoverEmpty
    readonly property real islandW: hoverMode && !bar.hoverEmpty ? bar.wH : bar.wC
    readonly property real islandH: hoverMode && !bar.hoverEmpty ? bar.hH : bar.hC
    readonly property real islandR: hoverMode && !bar.hoverEmpty ? bar.rH : bar.rC
    readonly property var plan: hoverMode ? bar.planH : bar.planC
    // full two-row height in the hover strip, so a second row has room to be dropped into
    readonly property real fullH: hoverMode ? h.height : c.height

    implicitHeight: Math.round(fullH * hs) + e.stripPadBottom
    clip: true
    Behavior on s {
        Anim {
            ms: Theme.widgets.reflow
        }
    }

    function toStrip(bx: real, by: real): point {
        return Qt.point(shape.x + bx * s, by * s);
    }
    function toBar(px: real, py: real): point {
        return Qt.point((px - shape.x) / s, py / s);
    }
    function planOf(lay: var): var {
        return bar.planFor(lay, mode);
    }

    // zone columns of a row in bar coordinates: centre zone around the centre slot
    function columns(p: var, row: string): var {
        const W = p.width;
        const cs = p.slots.find(x => x.row === row && x.col === "center");
        const hw = Math.max(64, cs ? (cs.x1 - cs.x0) / 2 + 22 : 64);
        return {
            "left": [0, W / 2 - hw],
            "center": [W / 2 - hw, W / 2 + hw],
            "right": [W / 2 + hw, W]
        };
    }
    function rowBand(row: string): var {
        if (!hoverMode)
            return [0, c.height];
        const mid = (h.row1Y + h.row2Y) / 2;
        return row === "top" ? [0, mid] : [mid, h.height];
    }
    // where a drop at strip point (px, py) lands in layout `base` (the dragged widget already
    // taken out): { state, row, col, idx }. Measured on the island as `base` lays it out, not
    // on the one on screen (that one already grows around the dragged widget: feedback)
    function dropTarget(px: real, py: real, base: var, sHit: real): var {
        const p = planOf(base);
        const bx = (px - (width - p.width * sHit) / 2) / sHit;
        const by = py / sHit;
        const row = hoverMode ? (by < (h.row1Y + h.row2Y) / 2 ? "top" : "bottom") : "";
        const cols = columns(p, row);
        const col = bx < cols.left[1] ? "left" : bx > cols.right[0] ? "right" : "center";
        const list = BarRegistry.list(base, mode, row, col);
        const slot = p.slots.find(x => x.row === row && x.col === col);
        let idx = list.length;
        for (const key of slot ? slot.keys : []) {
            const it = p.items[key];
            if (bx < it.x + it.w / 2) {
                idx = it.idx;
                break;
            }
        }
        return {
            "state": mode,
            "row": row,
            "col": col,
            "idx": idx
        };
    }
    // widget (or spacer) under strip point (px, py): { id, key, row, col, idx } or null
    function hit(px: real, py: real): var {
        const b = toBar(px, py);
        const tol = 4 / s;
        for (const key in plan.items) {
            const it = plan.items[key];
            let r;
            if (it.id === "spacer") {
                r = {
                    "x": it.x,
                    "y": it.y - 12,
                    "w": it.w,
                    "h": 24
                };
            } else {
                const wdg = bar.items[it.id];
                if (!wdg || !wdg.shown)
                    continue;
                r = {
                    "x": wdg.hitX,
                    "y": wdg.hitY,
                    "w": wdg.hitW,
                    "h": wdg.hitH
                };
            }
            if (b.x >= r.x - tol && b.x <= r.x + r.w + tol && b.y >= r.y - tol && b.y <= r.y + r.h + tol)
                return {
                    "id": it.id,
                    "key": key,
                    "row": it.row,
                    "col": it.col,
                    "idx": it.idx
                };
        }
        return null;
    }
    // strip rect of a planned key (live widget geometry when it has one)
    function rectOf(key: string): var {
        const it = plan.items[key];
        if (!it)
            return null;
        const wdg = it.id !== "spacer" ? bar.items[it.id] : null;
        const r = wdg && wdg.shown ? {
            "x": wdg.hitX,
            "y": wdg.hitY,
            "w": wdg.hitW,
            "h": wdg.hitH
        } : {
            "x": it.x,
            "y": it.y - 12,
            "w": it.w,
            "h": 24
        };
        const p = toStrip(r.x, r.y);
        return {
            "x": p.x,
            "y": p.y,
            "w": r.w * s,
            "h": r.h * s
        };
    }

    // ---- the strip -----------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: strip.e.stripRadius
        color: strip.e.strip
    }

    IslandShape {
        id: shape
        x: (strip.width - width) / 2
        width: strip.islandW * strip.s
        height: strip.islandH * strip.s
        radius: strip.islandR * strip.s
        ear: Theme.earRadius * strip.s
        Behavior on width {
            Anim {
                ms: Theme.widgets.reflow
            }
        }
        Behavior on height {
            Anim {
                ms: Theme.widgets.reflow
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            BarContent {
                id: bar
                width: parent.width / strip.s
                height: parent.height / strip.s
                scale: strip.s
                transformOrigin: Item.TopLeft
                preview: true
                layout: strip.layout
                ghostId: strip.ghostId
                pw: strip.asHover ? 1 : 0
                ph: strip.asHover ? 1 : 0
                pr: strip.asHover ? 1 : 0
                topAlpha: strip.asHover ? 1 : 0
            }
        }
    }

    // ---- overlay ------------------------------------------------------------------------------
    // slot zones while dragging
    Repeater {
        model: strip.zones ? BarRegistry.slots(strip.mode) : []

        Rectangle {
            id: zone
            required property var modelData
            readonly property var cols: strip.columns(strip.plan, modelData.row)
            readonly property var span: cols[modelData.col]
            readonly property var band: strip.rowBand(modelData.row)
            readonly property bool lit: !!strip.hot && strip.hot.row === modelData.row && strip.hot.col === modelData.col
            readonly property point tl: strip.toStrip(Math.max(span[0], 0) + 5, band[0] + 3)
            readonly property point br: strip.toStrip(Math.min(span[1], strip.plan.width) - 5, band[1] - 3)
            x: tl.x
            y: tl.y
            width: Math.max(0, br.x - tl.x)
            height: Math.max(0, br.y - tl.y)
            radius: 8 * strip.s
            color: Qt.alpha(lit ? strip.e.slotHot : strip.e.slot, lit ? 0.32 : 0.13)
            border.width: lit ? 1 : 0
            border.color: strip.e.slotHot
            Behavior on color {
                ColorAnim {
                    ms: 120
                }
            }
        }
    }

    // spacers (invisible on screen)
    Repeater {
        model: Object.keys(strip.plan.items).filter(k => strip.plan.items[k].id === "spacer")

        Rectangle {
            required property var modelData
            readonly property var r: strip.rectOf(modelData)
            visible: !!r
            x: r ? r.x : 0
            y: r ? r.y + r.h * 0.2 : 0
            width: r ? r.w : 0
            height: r ? r.h * 0.6 : 0
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: strip.e.slot
            opacity: strip.ghostId === "spacer" && strip.caretKey === modelData ? 0.5 : 1
        }
    }

    // selection ring
    Repeater {
        model: strip.selectedId === "" || strip.zones ? [] : Object.keys(strip.plan.items).filter(k => strip.plan.items[k].id === strip.selectedId)

        Rectangle {
            required property var modelData
            readonly property var r: strip.rectOf(modelData)
            readonly property real pad: strip.e.selectPad
            visible: !!r
            x: r ? r.x - pad : 0
            y: r ? r.y - pad : 0
            width: r ? r.w + 2 * pad : 0
            height: r ? r.h + 2 * pad : 0
            radius: 8
            color: "transparent"
            border.width: 1.5
            border.color: strip.e.ring
        }
    }

    // insertion caret left of the widget's new place
    Rectangle {
        id: caret
        readonly property var it: strip.caretKey !== "" ? strip.plan.items[strip.caretKey] ?? null : null
        readonly property real bx: it ? it.x - Math.max(3, it.lead / 2) : 0
        readonly property point p: strip.toStrip(bx, it ? it.y - 15 : 0)
        visible: !!it
        x: p.x - width / 2
        y: p.y
        width: strip.e.caret
        height: 30 * strip.s
        radius: width / 2
        color: strip.e.caretColor
        Behavior on x {
            enabled: caret.visible
            Anim {
                ms: Theme.widgets.reflow
            }
        }
    }

    // a widget that may not go here
    Rectangle {
        anchors.fill: parent
        radius: strip.e.stripRadius
        color: Qt.alpha(strip.g.window, 0.6)
        visible: strip.blocked
        SText {
            anchors.centerIn: parent
            size: 13
            text: strip.hoverMode ? "Collapsed island only" : "Hover island only"
            color: strip.g.value
        }
    }

    SText {
        x: 12
        y: parent.height - height - 5
        size: strip.e.captionSize
        text: strip.hoverMode ? (strip.asHover ? "Hover" : "Hover: empty, the island does not expand") : "Collapsed"
        color: strip.g.caption
    }
    SText {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: parent.height - height - 5
        size: strip.e.captionSize
        text: `${Math.round(strip.islandW)} x ${Math.round(strip.islandH)}`
        color: strip.g.caption
    }
}
