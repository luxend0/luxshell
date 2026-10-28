import QtQuick
import qs.config
import qs.services
import qs.widgets

// One widget of the island bar, placed from the layout plans (island/bar/layout.js) of both
// states and moved by the island's content progress like the video's elements:
//
//   shared       in the collapsed AND the hover layout: moves and scales between its two rest
//                places (anchored by the edge of its slot: left / centre / right), each axis
//                with its own lag (Motion.lag; in a right slot the element further from the
//                edge leads, which reproduces signal before volume of ref/14)
//   hover only   fades in late (Motion.reveal); rides its neighbour toward the slot's edge
//                (tray on the signal bars, gear on power on "All caught up"; the date rides
//                the clock and takes its scale) or, first in its slot, the island edge (row 1)
//   collapsed only  the mirror: stays with its neighbour / edge and fades out early
//
// A widget that stops showing (media chip without a track, window title yielding to it)
// keeps its last place and fades (Theme.media.swap). Rest places glide when the layout
// changes (Theme.widgets.reflow): neighbours make room in the editor preview.
//
// This item only computes; the content item is created as a direct child of the bar and gets
// x/y/scale/opacity (px, py, fsc), so the scene graph holds the same nodes as the video
// layout had with its widgets as direct children (a deeper tree moves text by 1/255 in the
// middle of the morph through float32 batch transforms).
Item {
    id: root

    required property var modelData
    property Item bar: null

    readonly property string wid: modelData.id
    readonly property bool fills: modelData.fills === true
    readonly property QtObject c: Theme.collapsed
    readonly property QtObject h: Theme.hover

    // ---- membership, presence ------------------------------------------------------------
    readonly property bool member: BarRegistry.contains(bar.layout, "collapsed", wid) || BarRegistry.contains(bar.layout, "hover", wid)
    readonly property var nowC: bar.planC.items[wid] ?? null
    readonly property var nowH: bar.planH.items[wid] ?? null
    property var lastC: null
    property var lastH: null
    onNowCChanged: if (nowC)
        lastC = nowC
    onNowHChanged: if (nowH)
        lastH = nowH
    readonly property var pC: nowC ?? lastC
    readonly property var pH: nowH ?? lastH
    readonly property string kindNow: nowC && nowH ? "shared" : nowH ? "hover" : nowC ? "collapsed" : ""
    property string kind: ""
    onKindNowChanged: if (kindNow !== "")
        kind = kindNow
    Component.onCompleted: {
        if (nowC)
            lastC = nowC;
        if (nowH)
            lastH = nowH;
        if (kindNow !== "")
            kind = kindNow;
        bar.register(wid, root);
        build();
    }
    Component.onDestruction: {
        if (bar)
            bar.unregister(wid, root);
        if (w)
            w.destroy();
    }
    onMemberChanged: build()

    property real presence: kindNow !== "" ? 1 : 0
    Behavior on presence {
        enabled: root.bar.animate
        Anim {
            ms: Theme.media.swap
        }
    }

    // ---- content -----------------------------------------------------------------------------
    property Item w: null
    readonly property real cw: w ? w.width : 0
    readonly property real ch: w ? w.height : 0
    readonly property real cAnchorY: w ? (w.anchorY ?? ch / 2) : 0
    // visible width (a MorphText scales around its centre: visualWidth < width while small)
    readonly property real vw: w ? (w.visualWidth ?? cw) : 0
    readonly property var widths: w ? [w.wC ?? cw, w.wH ?? cw] : null
    onWidthsChanged: if (widths)
        bar.report(wid, widths[0], widths[1])

    // visual extents for widgets riding this one
    readonly property bool centred: kind === "shared" && aC === 0.5 && aH === 0.5
    readonly property real vLeft: fills ? (w ? w.groupLeft : 0) : centred ? anchorX - vw / 2 : px + (cw - vw) / 2
    readonly property real vRight: fills ? (w ? w.groupRight : 0) : centred ? anchorX + vw / 2 : px + (cw + vw) / 2
    readonly property real vCy: fills ? (w ? w.cy : 0) : py + cAnchorY
    readonly property real vBase: w && w.textBase !== undefined ? py + w.textBase : vCy

    function frac(align: string): real {
        return align === "r" ? 1 : align === "c" ? 0.5 : 0;
    }
    function mix(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    // ---- rest places (glide on layout changes) ----------------------------------------------
    readonly property real aC: frac(pC?.align ?? "l")
    readonly property real aH: frac(pH?.align ?? "l")
    // anchor point relative to the island centre
    property real restC: pC ? pC.rel : 0
    property real restH: pH ? pH.rel : 0
    // left edge relative to the island centre (Workspaces places its capsules from it)
    property real restLC: pC ? pC.x - bar.wC / 2 : 0
    property real restLH: pH ? pH.x - bar.wH / 2 : 0
    property real yC: pC ? pC.y : c.centerY
    property real yH: pH ? pH.y : h.row1Y
    // distance to the island edge (riders) or to the neighbour (followers)
    readonly property var followH: kind === "hover" ? bar.followTarget("hover", wid) : null
    readonly property var followC: kind === "collapsed" ? bar.followTarget("collapsed", wid) : null
    property real edgeOff: {
        const p = kind === "hover" ? pH : kind === "collapsed" ? pC : null;
        const f = kind === "hover" ? followH : followC;
        if (!p)
            return 0;
        if (f)
            return f.offset;
        if (p.col === "left")
            return kind === "hover" ? p.before : p.x;
        if (p.col === "right")
            return kind === "hover" ? p.after : bar.wC - (p.x + p.w);
        return p.x - (kind === "hover" ? bar.wH : bar.wC) / 2;
    }
    readonly property bool glide: bar.animate && presence > 0.99
    Behavior on restC {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on restH {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on restLC {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on restLH {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on yC {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on yH {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }
    Behavior on edgeOff {
        enabled: root.glide
        Anim {
            ms: Theme.widgets.reflow
        }
    }

    // ---- lags (shared widgets) ---------------------------------------------------------------
    // fitted pairs from ref/14: volume (edge-most in its slot) and signal (one further in);
    // further widgets continue the line, centre widgets move like the clock
    readonly property int edgeIndex: !pC ? 0 : pC.col === "right" ? pC.count - 1 - pC.pos : pC.col === "left" ? pC.pos : 0
    readonly property var lagNow: {
        const L = Motion.lag;
        if (wid === "clock" || (pC && pC.col === "center"))
            return [1, L.clockY];
        if (pC && pC.col === "right")
            return [L.volumeX + edgeIndex * (L.signalX - L.volumeX), L.volumeY + edgeIndex * (L.signalY - L.volumeY)];
        return [1 + 0.25 * edgeIndex, L.volumeY];
    }
    readonly property real qx: Motion.lagged(bar.pw, lagNow[0])
    readonly property real qy: Motion.lagged(bar.ph, lagNow[1])
    // collapsed (0) -> hover (1) sizes of the content
    // (centre column like the clock: with the horizontal progress)
    readonly property real t: kind === "shared" ? (wid === "clock" || (pC && pC.col === "center") ? bar.pw : bar.ph) : kind === "collapsed" ? 0 : 1

    // ---- followers ---------------------------------------------------------------------------
    readonly property var follow: kind === "hover" ? followH : kind === "collapsed" ? followC : null
    readonly property Item nb: follow ? (bar.items[follow.key] ?? null) : null
    readonly property bool carry: !!nb && !!nb.w && nb.w.carryScale === true
    readonly property real fsc: carry ? nb.w.sc : 1

    // left x of a hover-only / collapsed-only widget (cwNow: its width now)
    function soloX(cwNow: real): real {
        if (nb)
            return follow.side === "after" ? nb.vRight + edgeOff * fsc : nb.vLeft - edgeOff * fsc - cwNow;
        if (kind === "hover") {
            if (pH.col === "left")
                return mix(h.topStartLeft, h.padLeft, bar.pw) + edgeOff;
            if (pH.col === "right")
                return bar.width - mix(h.topStartRight, h.padRight, bar.pw) - edgeOff - cwNow;
            return bar.width / 2 + edgeOff;
        }
        if (pC.col === "left")
            return edgeOff;
        if (pC.col === "right")
            return bar.width - edgeOff - cwNow;
        return bar.width / 2 + edgeOff;
    }
    // centre line of a hover-only / collapsed-only widget
    function soloCy(): real {
        if (nb)
            return nb.vCy;
        if (kind === "hover")
            return mix(yH * Theme.widgets.startShare, yH, Motion.lagged(bar.ph, Motion.lag.topY));
        return yC;
    }

    // ---- geometry ----------------------------------------------------------------------------
    readonly property real fillsLeft: {
        if (!fills || kind === "" || !pC && !pH)
            return 0;
        if (kind === "shared")
            return 0; // Workspaces moves each capsule itself
        return soloX((kind === "hover" ? pH : pC).w);
    }
    // anchor point of a shared widget now (left edge / centre / right edge, mixed)
    readonly property real anchorX: bar.width / 2 + mix(restC, restH, qx)
    readonly property real px: {
        if (fills || kind === "" || (!pC && !pH))
            return 0;
        if (kind === "shared")
            return centred ? anchorX - cw / 2 : anchorX - mix(aC, aH, qx) * vw - (cw - vw) / 2;
        return soloX(cw);
    }
    readonly property real py: {
        if (fills || kind === "" || (!pC && !pH))
            return 0;
        if (kind === "shared")
            return mix(yC, yH, qy) - cAnchorY;
        if (carry && w && w.textBase !== undefined)
            return nb.vBase - ch / 2 - (w.textBase - ch / 2) * fsc;
        return soloCy() - cAnchorY;
    }
    // hit box in bar coordinates (editor, scroll target)
    readonly property real hitX: fills ? vLeft : px
    readonly property real hitW: fills ? vRight - vLeft : cw * fsc
    readonly property real hitY: fills ? vCy - (w ? w.pillH ?? 20 : 20) / 2 : py
    readonly property real hitH: fills ? (w ? w.activeH ?? 20 : 20) : ch

    // ---- fades -------------------------------------------------------------------------------
    readonly property var rv: Motion.reveal
    readonly property real revealOpacity: {
        if (kind === "shared" || kind === "")
            return 1;
        if (kind === "collapsed")
            return 1 - Motion.smooth(bar.pw, [0, 0.3]);
        switch (modelData.reveal) {
        case "top":
            return bar.topAlpha * Motion.smooth(bar.pw, rv.topIcon);
        case "date":
            return Motion.smooth(bar.pw, rv.date);
        }
        return bar.topAlpha * Motion.smooth(bar.pw, rv.extras);
    }
    readonly property real textOpacity: kind === "hover" && modelData.reveal === "top" ? Motion.smooth(bar.pw, rv.topText) : 1
    readonly property real dimOpacity: !modelData.dim ? 1 : kind === "shared" ? mix(c.statusOpacity, h.statusOpacity, bar.pw) : kind === "hover" ? h.statusOpacity : c.statusOpacity
    readonly property real alpha: presence * revealOpacity * dimOpacity * (bar.ghostId === wid ? 0.4 : 1)
    readonly property bool shown: member && alpha > 0.001
    readonly property bool interactive: !bar.preview && presence > 0.5

    // content: created while the widget is in the layout, parented to the bar
    function build(): void {
        if (member && !w) {
            const comp = bar.components[wid];
            if (!comp)
                return;
            const it = comp.createObject(bar);
            if (!it) {
                console.warn(`luxshell: island widget "${wid}" failed to load`);
                return;
            }
            bindContent(it);
            w = it;
        } else if (!member && w) {
            const old = w;
            w = null;
            old.destroy();
        }
    }
    function bindContent(it: Item): void {
        it.opacity = Qt.binding(() => root.alpha);
        it.visible = Qt.binding(() => root.shown);
        {
            if (root.fills) {
                it.width = Qt.binding(() => root.bar.width);
                it.height = Qt.binding(() => root.bar.height);
            } else {
                it.x = Qt.binding(() => root.px);
                it.y = Qt.binding(() => root.py);
                it.scale = Qt.binding(() => root.fsc);
                it.transformOrigin = Qt.binding(() => root.follow && root.follow.side === "before" ? Item.Right : Item.Left);
            }
            it.t = Qt.binding(() => root.t);
            it.textOpacity = Qt.binding(() => root.textOpacity);
            it.interactive = Qt.binding(() => root.interactive);
            it.screen = Qt.binding(() => root.bar.screen);
            if (!root.fills)
                return;
            it.pw = Qt.binding(() => root.kind === "shared" ? root.bar.pw : 0);
            it.ps = Qt.binding(() => root.kind === "shared" ? Motion.lagged(root.bar.pr, Motion.lag.workspacesSize) : root.kind === "hover" ? 1 : 0);
            it.cy = Qt.binding(() => root.kind === "shared" ? root.mix(root.yC, root.yH, root.bar.pr) : root.kind === "hover" ? root.soloCy() : root.yC);
            it.relLeftC = Qt.binding(() => root.kind === "shared" ? root.restLC : root.fillsLeft - root.bar.width / 2);
            it.relLeftH = Qt.binding(() => root.kind === "shared" ? root.restLH : root.fillsLeft - root.bar.width / 2);
        }
    }
}
