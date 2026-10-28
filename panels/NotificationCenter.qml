import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.controlcenter
import qs.panels.notifications

// Notification center (registry id "notifications"): a panel out of the island in the
// control center's language (same width, black, cards with the CC radius, Inter, mono).
// Opened from "All caught up" / the bell of the hover island or `ipc call luxshell toggle
// notifications`.
//
//   header  "Notifications" + count; right the Focus switch (Settings.dnd) and "Clear all"
//   list    services/Notifs grouped per app, newest group and newest card first. A group
//           with several notifications starts folded: the newest card with the others as
//           edges behind it (chevron, a click on the stack or Right unfolds it). Cards:
//           panels/notifications/NcCard.qml, group rows: NcGroupHeader.qml
//   empty   bell + "All caught up"
//
// Rows are one flat list of strings, "g|<group>" (header) and "n|<key>" (card), in a
// ScriptModel: inserts and removals animate (ListView transitions: new rows fade in,
// leaving rows fade out, the rest slide) and delegates keep their state (unfolded text,
// hover) while Notifs replaces its entry objects.
// Height: header + the rows' RESTING heights (not the animated ones) + pad, so the island
// morphs once per change while the rows slide with the same curve; capped at
// Settings.notifCenterMaxHeight (default = Theme.nc.maxHeight), then the list scrolls (edges
// fade while more is off view). Settings.notifCenterGroup off: no per-app groups, the cards
// newest first, a header (no folding) over every run of cards from the same app.
//
// Opening marks everything read (Notifs.markAllRead); what was unread keeps a dot until
// the panel closes. While it is open, peeks stay out of the island (services/Notifs) and
// new notifications land in the list (marked read, with a dot).
//
// Keys: Up/Down rows (the header controls sit above the first row), Tab/Shift+Tab all of
// them in order. Left/Right: group row = fold/unfold, card = step through its action
// buttons (no buttons: fold/unfold the text), header = Focus <-> Clear all. Space: card
// text / group fold / header control. Enter: the selected button, else the default
// action (the panel closes; without one the text unfolds). Delete/Backspace: dismiss the
// card / clear the group, Shift+Delete: clear all. 1-3: card buttons. Esc: PanelHost.
PanelBase {
    id: root

    readonly property QtObject nc: Theme.nc

    preferredWidth: nc.width
    readonly property int maxH: Math.max(nc.emptyHeight, Settings.notifCenterMaxHeight)
    readonly property bool grouped: Settings.notifCenterGroup

    preferredHeight: empty ? nc.emptyHeight : Math.min(maxH, Math.ceil(nc.headerHeight + targetContent + nc.pad))
    maxWidth: nc.width
    maxHeight: maxH
    cornerRadius: nc.radius

    // ---- rows ---------------------------------------------------------------------------
    property var unfolded: ({})       // group -> true
    readonly property var groups: probe ? [] : grouped ? Notifs.groups : runs(Notifs.entries)
    readonly property var rows: {
        const out = [];
        for (const g of groups) {
            out.push("g|" + g.group);
            const all = !grouped || g.entries.length < 2 || unfolded[g.group] === true;
            for (const e of all ? g.entries : g.entries.slice(0, 1))
                out.push("n|" + e.key);
        }
        return out;
    }
    readonly property bool empty: rows.length === 0

    // ungrouped: consecutive cards of one app share a header; its id names the newest card,
    // so two runs of the same app stay apart
    function runs(entries: var): var {
        const out = [];
        let cur = null;
        for (const e of entries) {
            if (!cur || cur.appGroup !== e.group) {
                cur = {
                    "group": e.group + "#" + e.key,
                    "appGroup": e.group,
                    "run": true,
                    "app": e.app,
                    "icon": e.icon,
                    "picture": e.picture,
                    "entries": []
                };
                out.push(cur);
            }
            cur.entries.push(e);
        }
        return out;
    }
    // clear a header's cards: the whole app (grouped) or just that run
    function clearRow(id: string): void {
        const g = groupOf(id);
        if (g && g.run === true)
            g.entries.forEach(e => Notifs.dismiss(e.key));
        else
            Notifs.clearGroup(id);
    }

    function groupOf(name: string): var {
        return groups.find(g => g.group === name) ?? null;
    }
    function setUnfolded(group: string, on: bool): void {
        if (!grouped)
            return;
        if ((unfolded[group] === true) === on)
            return;
        const u = Object.assign({}, unfolded);
        if (on)
            u[group] = true;
        else
            delete u[group];
        unfolded = u;
    }

    ScriptModel {
        id: rowModel
        values: root.rows
    }

    // resting height of everything in the list (rows report targetH, see the delegate)
    readonly property real targetContent: {
        let s = 0;
        for (const c of list.contentItem.children)
            if (c.ncRow === true && !c.removing)
                s += c.targetH;
        return s;
    }

    // ---- read state -----------------------------------------------------------------------
    property var fresh: ({})          // key -> true: unread when it reached the open center
    function markRead(): void {
        if (probe || !active || Notifs.unread === 0)
            return;
        const f = Object.assign({}, fresh);
        for (const e of Notifs.entries)
            if (!e.seen)
                f[e.key] = true;
        fresh = f;
        Notifs.markAllRead();
    }
    Connections {
        target: Notifs
        enabled: !root.probe
        function onEntriesChanged() {
            if (Notifs.unread > 0)
                Qt.callLater(root.markRead);
        }
    }

    property double now: Date.now()
    Timer {
        running: root.active
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }

    // rows stagger in while the panel opens (then new rows use the list's add transition)
    property bool revealing: false
    Timer {
        id: revealEnd
        interval: Motion.ms(Motion.fadeInDelay + 8 * Theme.nc.stagger + Theme.nc.enter)
        onTriggered: root.revealing = false
    }

    Component.onCompleted: {
        if (probe) // registry size probe at shell start: no service side effects
            return;
        now = Date.now();
        revealing = true;
        revealEnd.start();
        sel = rows.length > 0 ? rows[0] : "h|focus";
        Qt.callLater(markRead);
    }
    onActiveChanged: if (active && !probe)
        Qt.callLater(markRead)

    // drop fold state of groups that are gone
    onRowsChanged: {
        fixSel();
        const u = {};
        let pruned = false;
        for (const g of Object.keys(unfolded)) {
            if (groupOf(g))
                u[g] = true;
            else
                pruned = true;
        }
        if (pruned)
            unfolded = u;
    }

    // ---- actions ------------------------------------------------------------------------------
    function defaultAction(e: var, card: Item): void {
        if (!e)
            return;
        if (e.hasDefault && e.alive) {
            Notifs.invoke(e.key, "default");
            Ui.close();
        } else if (card && card.canOpen) {
            card.open = !card.open;
        }
    }

    // ---- keyboard ------------------------------------------------------------------------------
    property string sel: ""           // row id, or "h|focus" / "h|clear"
    property int selIdx: 0
    property int actionSel: -1        // selected action pill of the selected card
    property bool kb: false           // selection visible (after a key, until the pointer moves)

    readonly property var controls: empty ? ["h|focus"] : ["h|focus", "h|clear"]

    onSelChanged: {
        actionSel = -1;
        const i = rows.indexOf(sel);
        if (i >= 0)
            selIdx = i;
        if (kb)
            Qt.callLater(ensureVisible);
    }

    function fixSel(): void {
        if (sel === "")
            return;
        if (sel.startsWith("h|")) {
            if (!controls.includes(sel))
                sel = "h|focus";
            return;
        }
        const i = rows.indexOf(sel);
        if (i >= 0)
            selIdx = i;
        else
            sel = rows.length > 0 ? rows[Math.min(selIdx, rows.length - 1)] : "h|focus";
    }

    function rowItem(id: string): Item {
        const i = rows.indexOf(id);
        return i >= 0 ? list.itemAtIndex(i) : null;
    }

    function scrollTo(y: real): void {
        const lo = list.originY - list.topMargin;
        const hi = Math.max(lo, list.originY + list.contentHeight + list.bottomMargin - viewH);
        scroller.to = Math.max(lo, Math.min(hi, y));
        scroller.restart();
    }
    // visible part of the list (it is as tall as the largest panel, the island cuts it);
    // its bottom stays clear of the panel's round corners (Theme.nc.listInset)
    readonly property real viewH: preferredHeight - list.y - nc.listInset
    function ensureVisible(): void {
        if (!list.scrollable)
            return;
        if (sel.startsWith("h|")) {
            scrollTo(-Infinity);
            return;
        }
        const it = rowItem(sel);
        if (!it)
            return;
        // resting height: a card that is still unfolding is scrolled to its final size;
        // taller than the view: its top
        const top = it.y - 8;
        const bottom = it.y + it.targetH - it.gapAfter + 8;
        if (top < list.contentY + list.topMargin || bottom - top > viewH - list.topMargin - list.bottomMargin)
            scrollTo(top - list.topMargin);
        else if (bottom > list.contentY + viewH - list.bottomMargin)
            scrollTo(bottom - viewH + list.bottomMargin);
    }
    NumberAnimation {
        id: scroller
        target: list
        property: "contentY"
        duration: Motion.ms(240)
        easing.type: Easing.OutCubic
    }

    function activateControl(id: string): void {
        if (id === "h|focus")
            Settings.set("dnd", !Settings.dnd);
        else if (id === "h|clear")
            Notifs.clear();
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            event.accepted = false; // PanelHost closes
            return;
        }
        const wasHidden = !kb;
        kb = true;
        if (sel === "" || (!rows.includes(sel) && !controls.includes(sel)))
            sel = rows.length > 0 ? rows[0] : "h|focus";
        event.accepted = true;

        const i = rows.indexOf(sel);
        const head = sel.startsWith("h|");
        const groupRow = sel.startsWith("g|");
        const it = head ? null : rowItem(sel);
        const card = !head && !groupRow && it ? it.card : null;
        const e = card ? card.entry : null;
        const shift = event.modifiers & Qt.ShiftModifier;

        if (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            if (wasHidden)
                return; // first press only shows where the selection is
            if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                const all = controls.concat(rows);
                const back = k === Qt.Key_Backtab || shift;
                const j = all.indexOf(sel);
                sel = all[(j + (back ? all.length - 1 : 1)) % all.length];
            } else if (k === Qt.Key_Up) {
                if (i > 0)
                    sel = rows[i - 1];
                else if (i === 0)
                    sel = controls[controls.length - 1];
            } else {
                if (head) {
                    if (rows.length > 0)
                        sel = rows[0];
                } else if (i < rows.length - 1) {
                    sel = rows[i + 1];
                }
            }
            return;
        }
        if (k === Qt.Key_Home || k === Qt.Key_End) {
            if (rows.length > 0)
                sel = k === Qt.Key_Home ? rows[0] : rows[rows.length - 1];
            return;
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const right = k === Qt.Key_Right;
            if (head)
                sel = right ? controls[controls.length - 1] : "h|focus";
            else if (groupRow)
                setUnfolded(sel.slice(2), right);
            else if (card && card.actions.length > 0)
                actionSel = Math.max(-1, Math.min(card.actions.length - 1, actionSel + (right ? 1 : -1)));
            else if (card && (card.canOpen || card.open))
                card.open = right;
            Qt.callLater(ensureVisible);
            return;
        }
        if (k === Qt.Key_Space) {
            if (head)
                activateControl(sel);
            else if (groupRow)
                setUnfolded(sel.slice(2), unfolded[sel.slice(2)] !== true);
            else if (card && (card.canOpen || card.open))
                card.open = !card.open;
            Qt.callLater(ensureVisible);
            return;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (head)
                activateControl(sel);
            else if (groupRow)
                setUnfolded(sel.slice(2), unfolded[sel.slice(2)] !== true);
            else if (card && actionSel >= 0 && actionSel < card.actions.length)
                Notifs.invoke(e.key, card.actions[actionSel].id);
            else
                defaultAction(e, card);
            return;
        }
        if (k === Qt.Key_Delete || k === Qt.Key_Backspace) {
            if (shift || sel === "h|clear")
                Notifs.clear();
            else if (groupRow)
                root.clearRow(sel.slice(2));
            else if (card)
                card.flyAway(1);
            return;
        }
        if (k >= Qt.Key_1 && k <= Qt.Key_3 && card) {
            const n = k - Qt.Key_1;
            if (n < card.actions.length)
                Notifs.invoke(e.key, card.actions[n].id);
            return;
        }
        event.accepted = false;
    }

    // pointer use hides the keyboard selection again. Only real motion counts: Qt re-sends
    // hover at the same position whenever the scene changes under a resting pointer (the
    // ring appearing would hide itself again)
    HoverHandler {
        property point last: Qt.point(-1, -1)
        enabled: !root.probe
        onPointChanged: {
            const p = point.position;
            if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2) {
                if (last.x >= 0)
                    root.kb = false;
                last = p;
            }
        }
    }

    // ---- header ------------------------------------------------------------------------------
    CapText {
        id: title
        x: root.nc.titleX
        capY: root.nc.headerY
        text: "Notifications"
        font.pixelSize: root.nc.titleSize
        font.weight: Font.DemiBold
        color: Theme.text
    }
    CapText {
        x: title.x + title.implicitWidth + root.nc.countGap
        capY: root.nc.headerY
        text: Notifs.entries.length
        font.pixelSize: root.nc.titleSize
        font.weight: Font.Medium
        color: Theme.textDim
        opacity: root.empty ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }

    PillButton {
        id: clearPill
        x: root.width - root.nc.pad - width
        y: root.nc.headerY - height / 2
        height: root.nc.pillHeight
        text: "Clear all"
        opacity: root.empty ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
        onClicked: Notifs.clear()

        NcRing {
            shown: root.kb && root.sel === "h|clear"
            gap: 2
        }
    }

    Switch {
        id: focusSwitch
        x: (root.empty ? root.width - root.nc.pad : clearPill.x - root.nc.controlsGap) - width
        y: root.nc.headerY - height / 2
        on: Settings.dnd
        onToggled: Settings.set("dnd", !Settings.dnd)
        Behavior on x {
            enabled: root.active
            Anim {
                ms: Theme.nc.move
            }
        }

        NcRing {
            shown: root.kb && root.sel === "h|focus"
        }
    }
    Txt {
        id: focusLabel
        x: focusSwitch.x - root.nc.labelGap - width
        y: root.nc.headerY - height / 2
        text: "Focus"
        color: Settings.dnd ? Theme.text : Theme.textDim
        font.pixelSize: root.nc.labelSize
        font.weight: Font.Medium
        Behavior on color {
            ColorAnim {}
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: Settings.set("dnd", !Settings.dnd)
        }
    }

    // ---- empty --------------------------------------------------------------------------------
    Item {
        id: emptyBox
        y: root.nc.headerHeight
        width: root.width
        height: root.nc.emptyHeight - root.nc.headerHeight - root.nc.pad
        opacity: root.empty && !root.probe ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: Motion.ms(root.empty ? 120 : 0) // after the last cards faded
                }
                Anim {
                    ms: Theme.nc.enter
                }
            }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            spacing: 14

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: Settings.dnd ? "bell-off" : "bell"
                size: root.nc.emptyIcon
                color: Theme.textDim
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                color: Theme.textSecondary
                font.pixelSize: root.nc.emptySize
                font.weight: Font.Medium
            }
        }
    }

    // ---- list ---------------------------------------------------------------------------------
    ListView {
        id: list

        // from the resting heights, so it does not flicker while rows resize
        readonly property bool scrollable: !root.empty && root.nc.headerHeight + root.targetContent + root.nc.pad > root.maxH + 0.5

        y: root.nc.headerHeight - topMargin
        width: root.width
        // as tall as the largest panel: every row that fits the island exists (their
        // resting heights size the panel), the island body cuts the rest. Scrolled rows
        // end listInset above the panel edge, inside its round corners.
        height: root.maxH - y - root.nc.listInset
        topMargin: 6
        bottomMargin: root.nc.pad - root.nc.listInset
        clip: true
        visible: !root.probe
        model: rowModel
        interactive: scrollable
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600

        // new rows wait until the rows below have mostly made room, then fade in
        add: Transition {
            SequentialAnimation {
                PropertyAction {
                    property: "opacity"
                    value: 0
                }
                PauseAnimation {
                    duration: Motion.ms(Theme.nc.enterDelay)
                }
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: Motion.ms(Theme.nc.enter)
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.97
                        to: 1
                        duration: Motion.ms(Theme.nc.enter)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Motion.ms(Theme.nc.leave)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "x"
                to: 40
                duration: Motion.ms(Theme.nc.leave)
                easing.type: Easing.OutCubic
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Motion.ms(Theme.nc.move)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasized
            }
            // a row that was still fading in when it got displaced ends opaque
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Motion.ms(Theme.nc.enter)
            }
            NumberAnimation {
                property: "scale"
                to: 1
                duration: Motion.ms(Theme.nc.enter)
            }
        }

        delegate: Item {
            id: row

            required property string modelData
            required property int index

            readonly property bool ncRow: true
            readonly property bool isHeader: modelData.startsWith("g|")
            readonly property string ref: modelData.slice(2)
            property bool removing: false
            ListView.onRemove: removing = true

            // the data stays while the row fades out (Notifs no longer has it then)
            readonly property var liveData: isHeader ? root.groupOf(ref) : Notifs.find(parseInt(ref))
            property var info: null
            onLiveDataChanged: if (liveData)
                info = liveData
            Component.onCompleted: {
                if (liveData)
                    info = liveData;
                if (root.revealing) {
                    reveal = 0;
                    revealAnim.start();
                }
            }

            readonly property string group: isHeader ? ref : (info?.group ?? "")
            readonly property bool lastRow: index < 0 || index >= root.rows.length - 1
            readonly property bool lastInGroup: lastRow || root.rows[index + 1].startsWith("g|")
            readonly property real gapAfter: isHeader || lastRow ? 0 : lastInGroup ? root.nc.groupGap : root.nc.cardGap
            readonly property real targetH: (loader.item ? loader.item.targetHeight : 0) + gapAfter
            readonly property bool selected: root.kb && root.sel === modelData
            readonly property Item card: isHeader ? null : loader.item

            // newest card of a folded group: the others become edges behind it
            readonly property int layers: {
                if (isHeader || !info || !root.grouped)
                    return 0;
                const g = root.groupOf(info.group);
                if (!g || g.entries.length < 2 || root.unfolded[info.group] === true)
                    return 0;
                return g.entries[0].key === info.key ? g.entries.length - 1 : 0;
            }

            width: ListView.view ? ListView.view.width : root.width
            height: (loader.item ? loader.item.implicitHeight : 0) + gapAfter

            property real reveal: 1
            SequentialAnimation {
                id: revealAnim
                PauseAnimation {
                    duration: Motion.ms(Motion.fadeInDelay + Math.min(Math.max(0, row.index), 8) * Theme.nc.stagger)
                }
                NumberAnimation {
                    target: row
                    property: "reveal"
                    to: 1
                    duration: Motion.ms(Theme.nc.enter)
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                id: loader
                x: root.nc.pad
                y: (1 - row.reveal) * root.nc.revealShift
                width: row.width - 2 * root.nc.pad
                opacity: row.reveal
                sourceComponent: row.isHeader ? headerComponent : cardComponent
            }

            Component {
                id: headerComponent
                NcGroupHeader {
                    group: row.info
                    unfolded: root.unfolded[row.ref] === true
                    foldable: root.grouped
                    selected: row.selected
                    onToggle: root.setUnfolded(row.ref, !unfolded)
                    onClear: root.clearRow(row.ref)
                }
            }
            Component {
                id: cardComponent
                NcCard {
                    id: rowCard
                    entry: row.info
                    now: root.now
                    fresh: row.info ? root.fresh[row.info.key] === true : false
                    layers: row.layers
                    selected: row.selected
                    actionSel: row.selected ? root.actionSel : -1
                    onActivated: {
                        if (layers > 0)
                            root.setUnfolded(row.group, true);
                        else
                            root.defaultAction(entry, rowCard);
                    }
                    onDismissed: Notifs.dismiss(entry.key)
                    onAction: id => Notifs.invoke(entry.key, id)
                }
            }
        }
    }

    // ---- scroll bar: slim, in the right gutter, above the round corner ---------------------
    Item {
        id: track
        x: root.width - root.nc.pad / 2 - width / 2
        y: list.y + list.topMargin + 4
        width: root.nc.scrollbar
        height: root.height - root.nc.radius - y
        visible: list.scrollable

        Rectangle {
            readonly property real ratio: Math.min(1, list.visibleArea.heightRatio)
            width: parent.width
            radius: width / 2
            height: Math.max(24, parent.height * ratio)
            y: Math.max(0, Math.min(parent.height - height, list.visibleArea.yPosition / Math.max(0.0001, 1 - ratio) * (parent.height - height)))
            color: Theme.nc.scrollbarColor
            opacity: list.moving || scroller.running ? 1 : 0.55
            Behavior on opacity {
                Anim {
                    ms: Theme.fadeIn
                }
            }
        }
    }

    // ---- list edges: fade while more is off view -------------------------------------------
    Rectangle {
        x: root.nc.pad - 4
        y: list.y
        width: root.width - 2 * x
        height: root.nc.edgeFade
        visible: list.scrollable && list.contentY > list.originY - list.topMargin + 1
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.island
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
    Rectangle {
        x: root.nc.pad - 4
        y: list.y + list.height - height + 1
        width: root.width - 2 * x
        height: root.nc.edgeFade
        visible: list.scrollable && list.contentY < list.originY + list.contentHeight + list.bottomMargin - root.viewH - 1
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Theme.island
            }
        }
    }
}
