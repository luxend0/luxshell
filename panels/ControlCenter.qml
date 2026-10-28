import QtQuick
import QtQuick.Effects
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.controlcenter

// Control center (ref/08, ref/09, ref/09c). One main page (4 rows, ends after the
// Display slider; notifications have their own panel); network, Bluetooth, sound and
// display open as a sheet over it:
//
//   open   the main page dims (black, Theme.cc.sheet.dim), the sheet grows out of
//          the tile / card that opened it (container transform: rect, radius),
//          its content fades in and sharpens (blur) while it lands centred in
//          the panel. The opening control hides, the sheet takes its place.
//   close  back disc, Esc, Backspace or a click on the dimmed page: the reverse.
//   resize content changes (a device found) animate the height, still centred.
//   panel  the main page is lower than most sheets: while a sheet is up the panel (and
//          with it the island) grows to the sheet + inset above and below, capped at
//          Theme.cc.maxHeight; a sheet lower than the main page stays centred in it.
//          Closing, the panel shrinks back once the sheet is most of the way home
//          (sheet.shrinkAt), so the shrinking island never cuts the flying sheet.
//
// Start sheet: `startPage` (registry entry "bluetooth"), CcNav (IPC target
// "controlcenter", works before the panel was ever opened) or LUXSHELL_CC_PAGE.
//
// Keyboard: this item keeps the focus; Cc.current is the selected control of the
// main page or of the open sheet. Arrows move spatially (a control may consume
// them first, e.g. slider Left/Right), Tab / Shift+Tab in reading order, Enter /
// Space / Delete go to the control. Esc or Backspace = back; on the main page Esc
// falls through to the host, which closes the panel.
PanelBase {
    id: root

    readonly property QtObject sh: Theme.cc.sheet
    readonly property var sheetIds: ["network", "bluetooth", "sound", "display"]

    property string startPage: ""
    property string page: "main"     // what keyboard, dim and CcNav follow
    property string sheetId: ""      // sheet in the loader; stays while it closes
    property var from: ({ "x": 0, "y": 0, "w": 0, "h": 0, "r": 0 })   // rect of the opening control
    property Item origin: null
    property Item returnTo: null     // main page control selected again on the way back
    property real dim: 0             // 0..1
    property real morph: 0           // 0 = sheet on its origin, 1 = sheet in place
    property bool settled: false     // fully open: height changes animate, no blur

    readonly property Item mainPage: mainLoader.item
    readonly property Item sheetItem: sheetLoader.item
    readonly property Item pageItem: page === "main" ? mainPage : sheetItem

    // the panel height follows the sheet's target height (not the animated one), so the
    // island morphs once per change instead of chasing every frame
    readonly property bool tall: sheetId !== "" && (page !== "main" || morph > sh.shrinkAt)
    readonly property int sheetBox: sheetTarget + 2 * sh.inset

    preferredWidth: Theme.cc.width
    preferredHeight: tall ? Math.max(Theme.cc.height, sheetBox) : Theme.cc.height
    maxHeight: Theme.cc.maxHeight
    cornerRadius: Theme.cc.radius

    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    function originFor(id: string): Item {
        if (!mainPage)
            return null;
        return id === "network" ? mainPage.networkTile : id === "bluetooth" ? mainPage.bluetoothTile : id === "sound" ? mainPage.soundCard : mainPage.displayCard;
    }

    function go(id: string, animate: bool): void {
        if (id === "main" || id === "") {
            back();
            return;
        }
        if (!sheetIds.includes(id)) {
            console.info(`luxshell: control center has no page "${id}"`);
            return;
        }
        if (id === page)
            return;
        if (page === "main")
            returnTo = Cc.current;
        origin = originFor(id);
        if (origin) {
            const p = origin.mapToItem(root, 0, 0);
            from = {
                "x": p.x,
                "y": p.y,
                "w": origin.width,
                "h": origin.height,
                "r": origin.radius
            };
        }
        closeAnim.stop();
        openAnim.stop();
        settled = false;
        sheetId = id;
        page = id;
        if (animate) {
            morph = 0;
            openAnim.start();
        } else {
            morph = 1;
            dim = 1;
            settled = true;
        }
        Cc.current = sheetItem?.defaultItem ?? null;
    }

    function back(): void {
        if (page === "main")
            return;
        openAnim.stop();
        settled = false;
        page = "main";
        // a focused password field goes with the sheet; the panel takes the keys again
        sheetLoader.focus = false;
        forceActiveFocus();
        closeAnim.start();
        Cc.current = returnTo ?? origin ?? mainPage?.defaultItem ?? null;
    }

    function focusDefault() {
        forceActiveFocus();
        Cc.current = pageItem?.defaultItem ?? null;
    }

    onPageChanged: if (!probe)
        CcNav.page = page
    onActiveChanged: if (active && !probe)
        CcNav.page = page

    Component.onCompleted: {
        if (probe) // registry size probe at shell start: no service side effects
            return;
        Cc.kb = false;
        Brightness.refresh(false);
        Brightness.pickPrimary(Ui.panelScreen);
        const start = CcNav.take() || startPage || Env.get("LUXSHELL_CC_PAGE");
        if (start !== "")
            go(start, false);
        CcNav.page = page;
        Cc.current = pageItem?.defaultItem ?? null;
    }

    Connections {
        target: CcNav
        enabled: !root.probe
        function onNavigate(id) {
            root.go(id, true);
        }
        function onBackRequested() {
            root.back();
        }
    }

    // ---- motion -------------------------------------------------------------------
    // ref/09c: the dim leads by a frame, the sheet has landed after ~3/4 of the time.
    // Closing uses the softer standard curve, so the content stays readable longer.
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root
            property: "dim"
            to: 1
            duration: Motion.ms(root.sh.dimMs)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.emphasized
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Motion.ms(root.sh.openDelay)
            }
            NumberAnimation {
                target: root
                property: "morph"
                to: 1
                duration: Motion.ms(root.sh.openMs)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.emphasized
            }
        }
        onFinished: root.settled = true
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root
            property: "morph"
            to: 0
            duration: Motion.ms(root.sh.closeMs)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
        NumberAnimation {
            target: root
            property: "dim"
            to: 0
            duration: Motion.ms(root.sh.closeMs + 40)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
        onFinished: root.sheetId = ""
    }

    // sheet height: content height, clamped; animated once the sheet has landed
    readonly property real sheetW: width - 2 * sh.inset
    readonly property int sheetTarget: Math.min(sh.maxHeight, sheetItem ? Math.ceil(sheetItem.implicitHeight) : 200)
    property real sheetH: sheetTarget
    // where the landed sheet sits: below the inset when the panel grew for it, else centred
    // in the main page
    readonly property real sheetY: sheetBox >= Theme.cc.height ? sh.inset : Math.round((Theme.cc.height - sheetH) / 2)
    Behavior on sheetH {
        enabled: root.settled
        NumberAnimation {
            duration: Motion.ms(root.sh.resizeMs)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.emphasized
        }
    }

    // ---- keyboard -----------------------------------------------------------------
    // visible controls of the shown page, in tree (reading) order
    function controls(): var {
        const out = [];
        const walk = item => {
            if (!item || !item.visible)
                return;
            if (item.ccControl === true)
                out.push(item);
            for (const c of item.children) // a Flickable's contentItem is one of its children
                walk(c);
        };
        walk(pageItem);
        return out;
    }

    // nearest control in a direction: controls whose span overlaps across the axis
    // win, then distance along the axis, then centre offset as tie break
    function neighbour(cur: Item, list: var, dir: string): Item {
        const box = it => {
            const p = it.mapToItem(root, 0, 0);
            return {
                "x": p.x,
                "y": p.y,
                "w": it.width,
                "h": it.height
            };
        };
        const a = box(cur);
        const horizontal = dir === "left" || dir === "right";
        const sign = dir === "right" || dir === "down" ? 1 : -1;
        let best = null, bestScore = Infinity;
        for (const it of list) {
            if (it === cur)
                continue;
            const b = box(it);
            const main = horizontal ? sign * ((b.x + b.w / 2) - (a.x + a.w / 2)) : sign * ((b.y + b.h / 2) - (a.y + a.h / 2));
            if (main <= 1)
                continue;
            const gap = horizontal ? Math.max(0, Math.max(a.y, b.y) - Math.min(a.y + a.h, b.y + b.h)) : Math.max(0, Math.max(a.x, b.x) - Math.min(a.x + a.w, b.x + b.w));
            const centre = horizontal ? Math.abs((b.y + b.h / 2) - (a.y + a.h / 2)) : Math.abs((b.x + b.w / 2) - (a.x + a.w / 2));
            const score = (gap > 0 ? 1e5 + gap : 0) + main + 0.01 * centre; // overlapping spans first
            if (score < bestScore) {
                bestScore = score;
                best = it;
            }
        }
        return best;
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            if (page === "main") {
                event.accepted = false; // host closes the panel
                return;
            }
            back();
            event.accepted = true;
            return;
        }
        const list = controls();
        if (list.length === 0)
            return;
        let cur = list.includes(Cc.current) ? Cc.current : (list.includes(pageItem?.defaultItem) ? pageItem.defaultItem : list[0]);
        const wasHidden = !Cc.kb;
        Cc.kb = true;
        Cc.current = cur;
        event.accepted = true;

        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            if (wasHidden)
                return; // first press only reveals where the selection is
            const backwards = k === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
            const i = list.indexOf(cur);
            Cc.current = list[(i + (backwards ? list.length - 1 : 1)) % list.length];
            return;
        }
        const dir = k === Qt.Key_Left ? "left" : k === Qt.Key_Right ? "right" : k === Qt.Key_Up ? "up" : k === Qt.Key_Down ? "down" : "";
        if (cur.key(k))
            return;
        if (dir !== "") {
            Cc.current = neighbour(cur, list, dir) ?? cur;
            return;
        }
        if (k === Qt.Key_Backspace && page !== "main") {
            back();
            return;
        }
        event.accepted = false;
    }

    // pointer use hides the keyboard selection again
    HoverHandler {
        onPointChanged: Cc.kb = false
    }

    // ---- main page + dim ------------------------------------------------------------
    Loader {
        id: mainLoader
        anchors.fill: parent
        active: !root.probe // the registry's size probe loads nothing
        sourceComponent: MainPage {
            morphSource: root.sheetId !== "" ? root.origin : null
            morphHide: Motion.smooth(root.morph, [0, 0.18])
            onOpenPage: (id, origin) => root.go(id, true)
        }
    }

    Rectangle {
        id: dimmer
        anchors.fill: parent
        bottomLeftRadius: Theme.cc.radius // panel shape: only the bottom corners are round
        bottomRightRadius: Theme.cc.radius
        color: Theme.island
        opacity: root.sh.dim * root.dim
        visible: opacity > 0.001

        // a click next to the sheet goes back (the pointer cannot reach the page below)
        MouseArea {
            anchors.fill: parent
            enabled: root.page !== "main"
            hoverEnabled: true
            onClicked: root.back()
        }
    }

    // ---- sheet ----------------------------------------------------------------------
    Item {
        id: sheet

        readonly property real radius: root.lerp(root.from.r, root.sh.radius, root.morph)
        // the container fades over the first part of the way, in step with the tile below it
        readonly property real body: Motion.smooth(root.morph, [0, 0.18])

        visible: root.sheetId !== "" && root.morph > 0.001
        x: root.lerp(root.from.x, root.sh.inset, root.morph)
        y: root.lerp(root.from.y, root.sheetY, root.morph)
        width: root.lerp(root.from.w, root.sheetW, root.morph)
        height: root.lerp(root.from.h, root.sheetH, root.morph)

        RectangularShadow {
            anchors.fill: parent
            radius: sheet.radius
            blur: 24
            offset.y: 6
            color: Qt.rgba(0, 0, 0, 0.6)
            opacity: root.morph
        }

        Rectangle {
            anchors.fill: parent
            radius: sheet.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.cc.stroke
            opacity: sheet.body
        }

        // content keeps its final layout, anchored at the container's top left, and is
        // clipped by the growing container (ref/09c: unscaled text, cut at the edge)
        Item {
            anchors.fill: parent
            clip: true

            Loader {
                id: sheetLoader

                readonly property real blur: root.settled ? 0 : 1 - Motion.smooth(root.morph, [0.4, 1])

                width: root.sheetW
                height: root.sheetH
                active: !root.probe && root.sheetId !== ""
                opacity: Motion.smooth(root.morph, [0.28, 0.93])
                sourceComponent: root.sheetId === "network" ? networkSheet : root.sheetId === "bluetooth" ? bluetoothSheet : root.sheetId === "sound" ? soundSheet : root.sheetId === "display" ? displaySheet : null
                layer.enabled: blur > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: sheetLoader.blur
                    blurMax: 24
                }
            }
        }
    }

    Component {
        id: networkSheet
        NetworkSheet {
            onBack: root.back()
            onReleaseFocus: {
                sheetLoader.focus = false;
                root.forceActiveFocus();
            }
        }
    }
    Component {
        id: bluetoothSheet
        BluetoothSheet {
            onBack: root.back()
        }
    }
    Component {
        id: soundSheet
        SoundSheet {
            onBack: root.back()
        }
    }
    Component {
        id: displaySheet
        DisplaySheet {
            onBack: root.back()
        }
    }
}
