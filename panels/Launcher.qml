import QtQuick
import qs.config
import qs.core
import qs.widgets
import qs.panels.launcher

// Launcher (ref/16 frame 1): one search field, one list, several providers.
//
//   12*7        calculator row first, Enter copies the result     (= forces it)
//   text        apps, ranked by match + usage; web search last     (? forces it)
//   > cmd       run in kitty, recent commands below
//   w text      switch to an open window
//
// Providers (panels/launcher/*Provider.qml) only turn a query into entries; this
// file owns layout, selection and keys. The reported height follows the number
// of rows, so the island resizes while typing. Which modes run and in which order
// (Settings.launcherProviders), their prefixes (launcherPrefixes, read by the providers)
// and the visible rows (launcherRows) come from the settings app's Launcher page.
//
// Keys: Up/Down, Tab/Shift+Tab (wrap), PgUp/PgDn, Ctrl+N/P, Ctrl+J/K, Enter,
// Esc (PanelHost). Mouse: hover selects, click runs, wheel scrolls.
PanelBase {
    id: root

    readonly property var lt: Theme.launcher

    CalcProvider {
        id: calcProvider
    }
    AppsProvider {
        id: appsProvider
    }
    WindowsProvider {
        id: windowsProvider
    }
    CommandProvider {
        id: commandProvider
    }
    WebProvider {
        id: webProvider
    }
    readonly property var catalog: ({
            "calc": calcProvider,
            "apps": appsProvider,
            "windows": windowsProvider,
            "commands": commandProvider,
            "web": webProvider
        })
    // enabled modes in result order (Settings.launcherProviders)
    readonly property var providers: {
        const out = [];
        for (const id of Array.from(Settings.launcherProviders))
            if (catalog[id] && !out.includes(catalog[id]))
                out.push(catalog[id]);
        return out;
    }
    readonly property int visibleRows: Math.max(1, Settings.launcherRows)

    readonly property Provider mode: modeFor(search.text)
    readonly property var results: probe ? [] : collect(search.text, mode)
    readonly property int rows: Math.max(1, Math.min(results.length, visibleRows))
    property int selected: 0
    property string selectedKey: ""   // entry key of `selected`
    property bool userMoved: false    // selection picked by key/pointer since the query changed
    property string shownQuery: ""    // query the current results answer
    property bool revealing: true     // first frames after opening: rows stagger in
    property bool snap: false         // results changed: highlight jumps, no slide
    property point lastPointer: Qt.point(-1, -1)

    preferredWidth: lt.width
    preferredHeight: lt.listTop + rows * lt.rowHeight + lt.padBottom
    maxHeight: lt.listTop + visibleRows * lt.rowHeight + lt.padBottom

    function focusDefault() {
        search.forceActiveFocus();
    }

    // the longest matching prefix wins (user prefixes may share a start: "=" and "==")
    function modeFor(text: string): Provider {
        let best = null;
        for (const p of providers)
            if (p.prefix !== "" && text.startsWith(p.prefix) && (!best || p.prefix.length > best.prefix.length))
                best = p;
        return best;
    }

    function collect(text: string, mode: Provider): var {
        if (mode)
            return mode.match(text.slice(mode.prefix.length).replace(/^\s+/, ""), true).slice(0, mode.limit);
        let out = [];
        for (const p of providers)
            if (p.inDefault)
                out = out.concat(p.match(text, false).slice(0, p.limit));
        return out;
    }

    function selectable(i: int): bool {
        return i >= 0 && i < results.length && typeof results[i].run === "function";
    }

    // step through selectable rows; wrap for Tab, clamp for arrows/pages
    function move(delta: int, wrap: bool): void {
        const n = results.length;
        if (n === 0)
            return;
        let i = selected;
        const dir = delta > 0 ? 1 : -1;
        for (let left = Math.abs(delta); left > 0; ) {
            let j = i + dir;
            if (wrap)
                j = (j + n) % n;
            while (j >= 0 && j < n && !selectable(j) && j !== i)
                j = wrap ? (j + dir + n) % n : j + dir;
            if (j < 0 || j >= n || !selectable(j))
                break;
            i = j;
            left--;
        }
        select(i);
    }

    function select(i: int): void {
        if (!selectable(i))
            return;
        userMoved = true;
        selected = i;
        ensureVisible(i);
    }

    function ensureVisible(i: int): void {
        const top = i * lt.rowHeight;
        let y = list.contentY;
        if (top < y)
            y = top;
        else if (top + lt.rowHeight > y + list.height)
            y = top + lt.rowHeight - list.height;
        if (y === list.contentY)
            return;
        scroll.stop();
        if (snap) {
            list.contentY = y;
        } else {
            scroll.to = y;
            scroll.start();
        }
    }

    function hoverSelect(i: int, global: point): void {
        // items moving under a resting pointer (scrolling) must not steal the selection
        if (global.x === lastPointer.x && global.y === lastPointer.y)
            return;
        lastPointer = global;
        if (selectable(i)) {
            userMoved = true;
            selected = i;
        }
    }

    function activate(i: int): void {
        if (!selectable(i))
            return;
        const entry = results[i];
        entry.run();
        if (!entry.keepOpen)
            Ui.close();
    }

    // New query: back to the first selectable row. Same query, new data (window
    // retitled, entries still loading) after the user picked a row: keep that entry.
    onSelectedChanged: selectedKey = results[selected]?.key ?? ""
    onResultsChanged: {
        snap = true;
        unsnap.restart(); // the view rebuilds its rows on the next polish
        if (search.text !== shownQuery)
            userMoved = false;
        shownQuery = search.text;
        const keep = userMoved && selectedKey !== "" ? results.findIndex(e => e.key === selectedKey) : -1;
        if (keep >= 0 && selectable(keep)) {
            selected = keep;
            Qt.callLater(() => root.ensureVisible(keep)); // after the view took the new model
            return;
        }
        scroll.stop();
        list.contentY = 0;
        let first = 0;
        while (first < results.length && !selectable(first))
            first++;
        selected = first < results.length ? first : 0;
        selectedKey = results[selected]?.key ?? "";
    }
    Timer {
        id: unsnap
        interval: 50
        onTriggered: root.snap = false
    }

    Component.onCompleted: {
        for (const p of providers)
            p.opened();
    }
    Timer {
        running: true
        interval: 60 + root.visibleRows * root.lt.stagger
        onTriggered: root.revealing = false
    }

    // ---- search field ---------------------------------------------------------
    Item {
        id: header
        width: parent.width
        height: root.lt.headerHeight

        Glyph {
            id: lens
            x: root.lt.lensX
            y: root.lt.centerY - height / 2
            size: root.lt.lensSize
            name: root.mode ? root.mode.glyph : "search"
            color: Theme.textDim
        }

        TextInput {
            id: search
            x: root.lt.inputX
            y: root.lt.centerY - height / 2
            width: (modeLabel.visible ? modeLabel.x - 16 : parent.width - root.lt.inset) - x
            focus: true
            clip: true
            color: Theme.text
            selectionColor: Theme.surfaceHigh
            selectedTextColor: Theme.text
            selectByMouse: true
            font.family: Theme.fontFamily
            font.pixelSize: root.lt.inputSize
            cursorDelegate: Rectangle {
                width: 2
                color: Theme.text
                visible: search.cursorVisible
            }

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                switch (event.key) {
                case Qt.Key_Down:
                    root.move(1, false);
                    break;
                case Qt.Key_Up:
                    root.move(-1, false);
                    break;
                case Qt.Key_Tab:
                    root.move(event.modifiers & Qt.ShiftModifier ? -1 : 1, true);
                    break;
                case Qt.Key_Backtab:
                    root.move(-1, true);
                    break;
                case Qt.Key_PageDown:
                    root.move(root.visibleRows, false);
                    break;
                case Qt.Key_PageUp:
                    root.move(-root.visibleRows, false);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activate(root.selected);
                    break;
                case Qt.Key_N:
                case Qt.Key_J:
                    if (!ctrl)
                        return;
                    root.move(1, false);
                    break;
                case Qt.Key_P:
                case Qt.Key_K:
                    if (!ctrl)
                        return;
                    root.move(-1, false);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Search..."
                color: Theme.textDim
                font.pixelSize: root.lt.inputSize
            }
        }

        Txt {
            id: modeLabel
            anchors.right: parent.right
            anchors.rightMargin: root.lt.inset + 4
            y: root.lt.centerY - height / 2
            visible: root.mode !== null
            text: root.mode ? root.mode.label : ""
            color: Theme.textDim
            font.pixelSize: root.lt.modeSize
        }

        Rectangle {
            x: root.lt.inset
            y: root.lt.headerHeight - 1
            width: parent.width - 2 * root.lt.inset
            height: 1
            color: root.lt.separator
        }
    }

    // ---- results ----------------------------------------------------------------
    ListView {
        id: list
        x: root.lt.inset
        y: root.lt.listTop
        width: parent.width - 2 * root.lt.inset
        height: root.rows * root.lt.rowHeight
        clip: true
        interactive: false
        model: root.results
        currentIndex: root.selected
        highlightFollowsCurrentItem: false

        highlight: Rectangle {
            width: list.width
            height: root.lt.rowHeight
            y: list.currentItem ? list.currentItem.y : 0
            radius: root.lt.rowRadius
            color: root.lt.highlight
            visible: root.selectable(root.selected)
            Behavior on y {
                enabled: !root.snap
                Anim {
                    duration: root.lt.highlightMove
                }
            }

            Rectangle {
                x: root.lt.barX
                anchors.verticalCenter: parent.verticalCenter
                width: root.lt.barWidth
                height: root.lt.barHeight
                radius: width / 2
                color: Theme.accent
            }
        }

        delegate: ResultRow {
            width: list.width
            reveal: root.revealing && index < root.visibleRows
            onHovered: global => root.hoverSelect(index, global)
            onActivated: root.activate(index)
        }

        Anim {
            id: scroll
            target: list
            property: "contentY"
            duration: root.lt.highlightMove
        }
    }

    // one row per wheel notch (120 = one notch, touchpad steps accumulate). Sits above the
    // rows but takes no buttons and no hover, so those still reach the rows.
    MouseArea {
        property real acc: 0

        anchors.fill: list
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            acc += wheel.angleDelta.y / 120 * root.lt.rowHeight; // touchpads send small angle steps too
            const steps = Math.trunc(acc / root.lt.rowHeight);
            if (steps === 0)
                return;
            acc -= steps * root.lt.rowHeight;
            const max = Math.max(0, list.contentHeight - list.height);
            scroll.stop();
            list.contentY = Math.max(0, Math.min(max, Math.round(list.contentY / root.lt.rowHeight - steps) * root.lt.rowHeight));
        }
    }
}
