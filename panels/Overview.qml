import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.overview

// Workspace overview, window centred (Expose). No video frame exists for it; it is drawn
// in the island's picker language (ref/04-06): black panel out of the island, cards with
// radius, unselected cards dimmed, the selected one framed, Inter, monochrome.
//
// Every open window is a live preview card (panels/overview/WindowCard.qml), grouped by
// workspace under a small number and a hairline. Groups sit side by side and wrap into
// rows at Theme.overview.maxCols cards, so the panel grows with the window count; more
// than maxLines lines scroll. Inside a group cards follow the tiling (left -> right).
//
// Typing filters by title and app (fuzzy, as in the launcher) and selects the best match;
// the remaining cards slide together. On open the previously focused window is selected
// (Enter = back to it), the focused one carries a small dot.
//
// Settings (Overview & Pickers page): overviewPreview live | still | icons (WindowCard),
// overviewGroup off = one grid without workspace headings (same order), overviewCardSize
// scales the preview box (label line stays).
//
// Keys: arrows move spatially, Tab/Shift+Tab and Ctrl+N/P step in reading order (wrap),
// Home/End, PgUp/PgDn, Enter focuses (hl.dsp.focus by address), Del or Ctrl+W closes
// the selected window (through services/Exec, so LUXSHELL_DRYRUN only logs), Esc closes
// (PanelHost). Mouse: hover selects, click focuses, middle click or the x disc closes,
// wheel scrolls.
PanelBase {
    id: root

    readonly property var g: Theme.overview
    readonly property var p: Theme.picker

    readonly property real cardScale: Math.max(0.5, Math.min(2, Settings.overviewCardSize))
    readonly property int cardWidth: Math.round(g.cardWidth * cardScale)
    readonly property int thumbHeight: Math.round(g.thumbHeight * cardScale)
    readonly property bool grouped: Settings.overviewGroup
    readonly property int headingHeight: grouped ? g.headingHeight : 0
    readonly property string previewMode: Settings.overviewPreview

    readonly property int cellHeight: thumbHeight + g.labelHeight
    readonly property int maxRowWidth: g.maxCols * cardWidth + (g.maxCols - 1) * g.colGap
    readonly property int maxContentHeight: g.maxLines * (headingHeight + cellHeight) + (g.maxLines - 1) * g.rowGap

    readonly property string query: search.text.trim()
    readonly property var wins: probe ? [] : collect(query)
    readonly property var lay: layout(wins)
    readonly property int viewHeight: lay.count === 0 ? headingHeight + cellHeight : Math.min(lay.h, maxContentHeight)
    // the window that has focus right now; none on an empty workspace
    readonly property string focusedAddress: Hypr.hasWindow ? addressOf(Hypr.toplevel) : ""

    property string selected: ""       // address of the selected window
    readonly property int selIndex: lay.order.indexOf(selected)
    readonly property var sel: lay.slots[selected] ?? null
    property string shownQuery: ""
    property string pendingNext: ""    // where the selection goes when the selected window closes
    property int lastIndex: 0
    property bool userMoved: false     // selection picked by key / pointer
    property bool revealing: true      // first frames: cards stagger in, slots jump
    property point lastPointer: Qt.point(-1, -1)

    preferredWidth: Math.max(g.minWidth, Math.round(lay.w + 2 * g.pad))
    preferredHeight: g.gridTop + viewHeight + g.footerHeight
    maxWidth: Math.max(g.minWidth, maxRowWidth + 2 * g.pad)
    maxHeight: g.gridTop + maxContentHeight + g.footerHeight

    function focusDefault() {
        search.forceActiveFocus();
    }

    // ---- data -------------------------------------------------------------------
    function addressOf(t: var): string {
        const a = t?.address ?? "";
        return a === "" ? "" : a.startsWith("0x") ? a : "0x" + a;
    }

    // matching windows in display order: workspace (special ones last), then the tiling
    function collect(q: string): var {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const addr = addressOf(t);
            if (addr === "")
                continue;
            const ipc = t.lastIpcObject ?? {};
            const ws = t.workspace;
            const wsId = ws?.id ?? ipc.workspace?.id ?? 0;
            const wsName = String(ws?.name ?? ipc.workspace?.name ?? wsId).replace(/^special:/, "");
            const appId = t.wayland?.appId || ipc["class"] || "";
            const app = Apps.entryFor(appId)?.name || appId;
            const title = t.title || app;
            // launcher ranking; a plain substring still counts (the launcher drops "t" inside
            // "btop", which here would empty the grid while typing); a bare workspace name
            // ("3") lists that workspace first
            const lq = q.toLowerCase();
            const score = q === "" ? 1 : wsName === q ? 1000 : Math.max(Apps.fuzzy(title, q), Apps.fuzzy(app, q), Apps.fuzzy(appId, q) * 0.8, (title + " " + app).toLowerCase().includes(lq) ? 0.1 : 0);
            if (score <= 0)
                continue;
            const at = ipc.at ?? [0, 0];
            out.push({
                "addr": addr,
                "toplevel": t,
                "title": title,
                "app": app,
                "icon": Apps.iconFor(appId),
                "wsId": wsId,
                "wsName": wsName,
                "x": at[0],
                "y": at[1],
                "hist": ipc.focusHistoryID ?? 999,
                "score": score
            });
        }
        const key = id => id < 0 ? 100000 - id : id;
        out.sort((a, b) => key(a.wsId) - key(b.wsId) || a.x - b.x || a.y - b.y || a.addr.localeCompare(b.addr));
        return out;
    }

    // Slots in content coordinates. A group = heading line + its cards in up to maxCols
    // columns; groups are packed into rows left to right, a group that does not fit
    // starts the next row.
    function layout(list: var): var {
        const C = cardWidth;
        const H = cellHeight;
        const HH = headingHeight;
        const groups = [];
        for (const w of list) {
            let last = groups[groups.length - 1];
            if (!last || (grouped && last.id !== w.wsId)) {
                last = {
                    "id": w.wsId,
                    "name": w.wsName,
                    "items": []
                };
                groups.push(last);
            }
            last.items.push(w);
        }
        const rows = [];
        let row = null;
        for (const gr of groups) {
            const n = gr.items.length;
            const cols = Math.min(n, g.maxCols);
            const lines = Math.ceil(n / cols);
            const bw = cols * C + (cols - 1) * g.colGap;
            const bh = HH + lines * H + (lines - 1) * g.lineGap;
            if (!row || (row.blocks.length > 0 && row.w + g.groupGap + bw > maxRowWidth)) {
                row = {
                    "w": 0,
                    "h": 0,
                    "blocks": []
                };
                rows.push(row);
            }
            const bx = row.blocks.length > 0 ? row.w + g.groupGap : 0;
            row.blocks.push({
                "gr": gr,
                "x": bx,
                "w": bw,
                "cols": cols
            });
            row.w = bx + bw;
            row.h = Math.max(row.h, bh);
        }
        const slots = {};
        const heads = {};
        const order = [];
        let y = 0;
        let w = 0;
        for (const r of rows) {
            for (const b of r.blocks) {
                if (grouped) // ungrouped: one block without heading
                    heads[b.gr.id] = {
                        "x": b.x,
                        "y": y,
                        "w": b.w,
                        "name": b.gr.name,
                        "count": b.gr.items.length
                    };
                b.gr.items.forEach((it, i) => {
                    slots[it.addr] = Object.assign({}, it, {
                        "x": b.x + (i % b.cols) * (C + g.colGap),
                        "y": y + HH + Math.floor(i / b.cols) * (H + g.lineGap),
                        "order": order.length
                    });
                    order.push(it.addr);
                });
            }
            w = Math.max(w, r.w);
            y += r.h + g.rowGap;
        }
        return {
            "slots": slots,
            "heads": heads,
            "order": order,
            "w": w,
            "h": rows.length > 0 ? y - g.rowGap : 0,
            "count": order.length
        };
    }

    // ---- selection --------------------------------------------------------------
    // the most recently focused window that is not the focused one (Enter = back to it);
    // on an empty workspace the last focused window itself
    function initial(): string {
        let best = "";
        let hist = 1e9;
        for (const w of wins) {
            if (w.addr === focusedAddress)
                continue;
            if (w.hist < hist) {
                hist = w.hist;
                best = w.addr;
            }
        }
        if (best === "")
            best = lay.slots[focusedAddress] ? focusedAddress : (lay.order[0] ?? "");
        return best;
    }

    function bestMatch(): string {
        let best = "";
        let score = -1;
        for (const w of wins)
            if (w.score > score) {
                score = w.score;
                best = w.addr;
            }
        return best;
    }

    function reconcile(): void {
        if (lay.count === 0)
            return;
        Qt.callLater(ensureVisible); // content may have shrunk under the scroll position
        if (query !== shownQuery) {
            shownQuery = query;
            if (query !== "") {
                select(bestMatch(), false);
                return;
            }
        }
        if (!userMoved && revealing) {
            select(initial(), false);
            return;
        }
        if (lay.slots[selected] === undefined) {
            const next = lay.slots[pendingNext] ? pendingNext : lay.order[Math.min(lastIndex, lay.count - 1)];
            select(next, false);
        }
    }

    function select(addr: string, byUser: bool): void {
        if (!lay.slots[addr])
            return;
        if (byUser)
            userMoved = true;
        selected = addr;
        lastIndex = lay.order.indexOf(addr);
        Qt.callLater(ensureVisible);
    }

    function step(delta: int, wrap: bool): void {
        const n = lay.count;
        if (n === 0)
            return;
        const i = selIndex < 0 ? 0 : selIndex + delta;
        select(lay.order[wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i))], true);
    }

    // nearest card on the next card line above / below (by centre x)
    function vertical(dir: int): void {
        const cur = sel;
        if (!cur)
            return;
        let lineY = null;
        for (const a of lay.order) {
            const s = lay.slots[a];
            if (dir > 0 ? s.y > cur.y + 1 : s.y < cur.y - 1)
                if (lineY === null || (dir > 0 ? s.y < lineY : s.y > lineY))
                    lineY = s.y;
        }
        if (lineY === null)
            return;
        let best = "";
        let dist = 1e9;
        for (const a of lay.order) {
            const s = lay.slots[a];
            const d = Math.abs(s.x - cur.x);
            if (s.y === lineY && d < dist) {
                dist = d;
                best = a;
            }
        }
        select(best, true);
    }

    function hoverSelect(addr: string, global: point): void {
        // cards sliding under a resting pointer (filtering, scrolling) must not steal it,
        // neither does a pointer that rests where the panel opens (first event only arms)
        if (global.x === lastPointer.x && global.y === lastPointer.y)
            return;
        const armed = lastPointer.x >= 0;
        lastPointer = global;
        if (!armed)
            return;
        if (addr !== selected)
            select(addr, true);
    }

    function ensureVisible(): void {
        const s = sel;
        if (!s)
            return;
        const top = s.y - root.headingHeight;
        const bottom = s.y + cellHeight;
        let y = flick.contentY;
        if (top < y)
            y = top;
        else if (bottom > y + root.viewHeight)
            y = bottom - root.viewHeight;
        y = Math.max(0, Math.min(Math.max(0, lay.h - root.viewHeight), y));
        if (y !== flick.contentY) {
            scroll.to = y;
            scroll.restart();
        }
    }

    // ---- actions ----------------------------------------------------------------
    function focusWindow(addr: string): void {
        if (!lay.slots[addr])
            return;
        Hyprland.dispatch(`hl.dsp.focus({window="address:${addr}"})`);
        Ui.close();
    }

    function closeWindow(addr: string): void {
        const s = lay.slots[addr];
        if (!s)
            return;
        if (!Exec.allow(`close window ${addr} "${s.title}" (workspace ${s.wsName})`)) {
            cardFor(addr)?.nudge();
            return;
        }
        if (addr === selected) {
            const i = lay.order.indexOf(addr);
            pendingNext = lay.order[i + 1] ?? lay.order[i - 1] ?? "";
        }
        Hyprland.dispatch(`hl.dsp.window.close({window="address:${addr}"})`);
    }

    function cardFor(addr: string): Item {
        for (let i = 0; i < cards.count; i++) {
            const c = cards.itemAt(i);
            if (c && c.addr === addr)
                return c;
        }
        return null;
    }

    onLayChanged: reconcile()

    Component.onCompleted: {
        if (probe)
            return;
        Hyprland.refreshToplevels(); // focus history + positions for the order and the first pick
        reconcile();
    }
    Timer {
        running: !root.probe
        interval: 320 // the IPC refresh lands well before; later changes animate
        onTriggered: root.revealing = false
    }

    // cards, headings and the centred content width glide together, on the island's panel
    // curve, so a filter change is one motion (content shrinks while the island does)
    component Slide: NumberAnimation {
        duration: Motion.ms(root.g.relayout)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.emphasized
    }

    // The panel item takes its new size at once, the island body animates there
    // (Motion.specs.panel). Header, grid window and footer follow the animated edges
    // instead of the instant ones, so nothing jumps inside the still moving island.
    property real halfWidth: preferredWidth / 2
    property real gridHeight: viewHeight
    Behavior on halfWidth {
        enabled: !root.revealing
        Slide {
            duration: Motion.ms(Motion.specs.panel.w[0])
        }
    }
    Behavior on gridHeight {
        enabled: !root.revealing
        Slide {
            duration: Motion.ms(Motion.specs.panel.h[0])
        }
    }
    readonly property real leftEdge: width / 2 - halfWidth
    readonly property real rightEdge: width / 2 + halfWidth
    readonly property real footerLine: g.gridTop + gridHeight + g.footerHeight - g.footerY

    // ---- header -----------------------------------------------------------------
    Glyph {
        x: root.leftEdge + root.g.lensX
        y: root.g.headerY - height / 2
        size: root.p.lensSize
        name: "search"
        color: Theme.textDim
    }

    TextInput {
        id: search
        x: root.leftEdge + root.g.inputX
        y: root.g.headerY - height / 2
        width: counter.x - 16 - x
        focus: true
        clip: true
        color: Theme.text
        selectionColor: Theme.surfaceHigh
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: root.p.inputSize
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.text
            visible: search.cursorVisible
        }

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            switch (event.key) {
            case Qt.Key_Right:
                root.step(1, false);
                break;
            case Qt.Key_Left:
                root.step(-1, false);
                break;
            case Qt.Key_Down:
                root.vertical(1);
                break;
            case Qt.Key_Up:
                root.vertical(-1);
                break;
            case Qt.Key_Tab:
                root.step(event.modifiers & Qt.ShiftModifier ? -1 : 1, true);
                break;
            case Qt.Key_Backtab:
                root.step(-1, true);
                break;
            case Qt.Key_Home:
                root.select(root.lay.order[0] ?? "", true);
                break;
            case Qt.Key_End:
                root.select(root.lay.order[root.lay.count - 1] ?? "", true);
                break;
            case Qt.Key_PageDown:
                for (let k = 0; k < root.g.maxLines; k++)
                    root.vertical(1);
                break;
            case Qt.Key_PageUp:
                for (let k = 0; k < root.g.maxLines; k++)
                    root.vertical(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.focusWindow(root.selected);
                break;
            case Qt.Key_Delete:
                root.closeWindow(root.selected);
                break;
            case Qt.Key_W:
                if (!ctrl)
                    return;
                root.closeWindow(root.selected);
                break;
            case Qt.Key_N:
                if (!ctrl)
                    return;
                root.step(1, true);
                break;
            case Qt.Key_P:
                if (!ctrl)
                    return;
                root.step(-1, true);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Search windows..."
            color: Theme.textDim
            font.pixelSize: root.p.inputSize
        }
    }

    Txt {
        id: counter
        x: root.rightEdge - root.g.pad - width
        y: root.g.headerY - height / 2
        text: root.lay.count > 0 ? `${root.selIndex + 1}/${root.lay.count}` : "0/0"
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
        font.features: {
            "tnum": 1
        }
    }

    // ---- cards ------------------------------------------------------------------
    Flickable {
        id: flick
        y: root.g.gridTop
        width: parent.width
        height: root.gridHeight
        contentWidth: width
        contentHeight: Math.max(height, root.lay.h)
        interactive: false
        clip: true

        NumberAnimation {
            id: scroll
            target: flick
            property: "contentY"
            duration: Motion.ms(Theme.launcher.highlightMove)
            easing.type: Easing.OutCubic
        }

        Item {
            id: content
            // centred on the island axis; the half width animates with the cards, so the
            // screen position of every card is continuous while the layout changes
            property real halfWidth: root.lay.w / 2
            Behavior on halfWidth {
                enabled: !root.revealing
                Slide {}
            }
            x: Math.round(flick.width / 2 - halfWidth)
            width: root.lay.w
            height: root.lay.h

            // workspace headings: keyed by the Hyprland workspace, so they glide like the cards
            Repeater {
                model: root.probe ? null : Hyprland.workspaces

                Item {
                    id: head
                    required property var modelData
                    readonly property var slot: root.lay.heads[modelData.id] ?? null
                    readonly property bool current: root.sel !== null && root.sel.wsId === modelData.id

                    property real tx: 0
                    property real ty: 0
                    property real tw: 0
                    x: tx
                    y: ty
                    width: tw
                    height: root.g.headingHeight
                    opacity: slot ? 1 : 0
                    visible: opacity > 0.002
                    onSlotChanged: if (slot) {
                        tx = slot.x;
                        ty = slot.y;
                        tw = slot.w;
                    }
                    Component.onCompleted: slotChanged()
                    Behavior on tx {
                        enabled: !root.revealing
                        Slide {}
                    }
                    Behavior on ty {
                        enabled: !root.revealing
                        Slide {}
                    }
                    Behavior on tw {
                        enabled: !root.revealing
                        Slide {}
                    }
                    Behavior on opacity {
                        Anim {
                            ms: root.g.select
                        }
                    }

                    Txt {
                        id: num
                        y: root.g.headingY - height / 2
                        text: head.slot?.name ?? head.modelData.name
                        font.pixelSize: root.g.headingSize
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                        color: head.current ? Theme.text : Theme.textDim
                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.ms(root.g.select)
                            }
                        }
                    }
                    Rectangle {
                        x: num.width + root.g.ruleGap
                        y: Math.round(root.g.headingY)
                        width: Math.max(0, head.width - x)
                        height: 1
                        color: root.g.rule
                    }
                }
            }

            Repeater {
                id: cards
                model: root.probe ? null : Hyprland.toplevels

                WindowCard {
                    id: wc
                    required property var modelData
                    readonly property string addr: root.addressOf(modelData)
                    readonly property var slot: root.lay.slots[addr] ?? null

                    toplevel: modelData
                    cardWidth: root.cardWidth
                    thumbHeight: root.thumbHeight
                    previewMode: root.previewMode
                    title: slot?.title ?? modelData.title
                    icon: slot?.icon ?? ""
                    selected: root.selected === addr && slot !== null
                    focusedWindow: root.focusedAddress === addr
                    z: selected ? 2 : 0

                    property real tx: 0
                    property real ty: 0
                    x: tx
                    y: ty
                    onSlotChanged: if (slot) {
                        tx = slot.x;
                        ty = slot.y;
                    }
                    Behavior on tx {
                        enabled: !root.revealing
                        Slide {}
                    }
                    Behavior on ty {
                        enabled: !root.revealing
                        Slide {}
                    }

                    // filter: matching cards in, the rest fade out where they were
                    property real vis: slot ? 1 : 0
                    Behavior on vis {
                        Anim {
                            ms: root.g.select
                        }
                    }
                    // opening: staggered rise in reading order
                    property real appear: 0
                    opacity: vis * appear
                    visible: opacity > 0.002
                    enabled: slot !== null
                    transform: Translate {
                        y: (1 - wc.appear) * root.g.revealShift
                    }
                    SequentialAnimation {
                        id: appearAnim
                        PauseAnimation {
                            duration: root.revealing ? Motion.ms(60 + (wc.slot?.order ?? 0) * root.g.stagger) : 0
                        }
                        Anim {
                            target: wc
                            property: "appear"
                            to: 1
                            ms: root.g.reveal
                        }
                    }
                    Component.onCompleted: {
                        slotChanged();
                        appearAnim.start();
                    }

                    onEntered: global => root.hoverSelect(addr, global)
                    onClicked: root.focusWindow(addr)
                    onCloseRequested: root.closeWindow(addr)
                }
            }
        }
    }

    // more cards above / below: the grid edge fades into the panel
    component EdgeFade: Rectangle {
        id: fade
        property bool atTop: false
        property bool shown: false
        x: flick.x
        width: flick.width
        height: root.g.edgeFade
        opacity: shown ? 1 : 0
        visible: opacity > 0.002
        Behavior on opacity {
            Anim {
                ms: root.g.select
            }
        }
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.mix(Theme.island, "transparent", fade.atTop ? 0 : 1)
            }
            GradientStop {
                position: 1
                color: Theme.mix(Theme.island, "transparent", fade.atTop ? 1 : 0)
            }
        }
    }
    EdgeFade {
        atTop: true
        y: flick.y
        shown: flick.contentY > 1
    }
    EdgeFade {
        y: flick.y + flick.height - height
        shown: flick.contentY < root.lay.h - root.viewHeight - 1
    }

    // one card line per wheel notch (touchpads accumulate)
    MouseArea {
        property real acc: 0

        anchors.fill: flick
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            acc += wheel.angleDelta.y / 120;
            const steps = Math.trunc(acc);
            if (steps === 0)
                return;
            acc -= steps;
            const line = root.cellHeight + root.g.lineGap;
            const max = Math.max(0, root.lay.h - root.viewHeight);
            scroll.stop();
            flick.contentY = Math.max(0, Math.min(max, flick.contentY - steps * line));
        }
    }

    Txt {
        anchors.horizontalCenter: flick.horizontalCenter
        y: flick.y + flick.height / 2 - height / 2
        visible: root.lay.count === 0
        text: root.query !== "" ? "No matching window" : "No open windows"
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    // ---- footer -----------------------------------------------------------------
    Txt {
        x: root.leftEdge + root.g.pad
        y: root.footerLine - height / 2
        width: meta.x - 24 - x
        text: root.sel ? `${root.sel.app}  ·  Workspace ${root.sel.wsName}` : ""
        elide: Text.ElideRight
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    Row {
        id: meta
        x: root.rightEdge - root.g.pad - width
        y: root.footerLine - height / 2
        spacing: root.p.metaGap

        Txt {
            text: "Enter to focus"
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
        }
        Txt {
            text: "·"
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
        }
        Txt {
            text: "Del to close"
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
        }
    }
}
