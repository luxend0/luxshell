import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.power

// Power menu, variant B: a menu list in the launcher's language. A filter line on top
// (typing narrows the list, "re" -> Restart), below one row per action with an info line
// (lock keybind, open windows, kernel / updates since boot, uptime). Which actions and in
// which order: Settings.powerActions; services/Power runs them (through services/Exec).
//
// Confirmation (Settings.powerConfirm per action): the first click / Enter arms the row
// (red, "Click again to shut down"), a second one within Settings.powerConfirmTime runs it;
// the red fill drains over that time and the row falls back. Clicks in the first
// Theme.power.armGuard ms after arming are ignored (a double click never runs anything).
// Actions without confirmation (default: lock, sleep) run on the first click.
//
// Keys: type to filter, Up/Down, Tab/Shift+Tab (wrap), Home/End, Enter, Esc disarms an armed
// row and otherwise closes (PanelHost). Mouse: hover selects, click arms / runs; a click
// outside closes (island focus grab).
PanelBase {
    id: root

    readonly property var lt: Theme.power

    readonly property var results: probe ? [] : collect(filter.text, Power.shown)
    readonly property int rows: Math.max(1, results.length)
    readonly property int allRows: Math.max(1, Power.ids.length)
    property int selected: 0
    property bool revealing: true
    property bool snap: false
    property point lastPointer: Qt.point(-1, -1)

    // armed action
    property string armedId: ""
    property string armedBy: ""      // "click" | "key"
    property real armedAt: 0
    property real armProgress: 1

    preferredWidth: lt.width
    preferredHeight: lt.listTop + rows * lt.rowHeight + lt.padBottom
    maxHeight: lt.listTop + allRows * lt.rowHeight + lt.padBottom

    function focusDefault() {
        filter.forceActiveFocus();
    }

    // rank: title starts with the query > a title word does > a keyword does. Everything
    // Power.detail() reads is a dependency of `results`: the list follows the info live
    function collect(text: string, ids: var): var {
        const q = text.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < ids.length; i++) {
            const a = Power.entry(ids[i]);
            const title = a.title.toLowerCase();
            const words = title.split(/\s+/);
            const keys = a.keywords.split(/\s+/);
            const score = q === "" ? 1 : title.startsWith(q) ? 4 : words.some(w => w.startsWith(q)) ? 3 : keys.some(k => k.startsWith(q)) ? 2 : title.replace(/\s+/g, "").startsWith(q.replace(/\s+/g, "")) ? 2 : 0;
            if (score > 0)
                out.push({
                    "id": a.id,
                    "title": a.title,
                    "glyph": a.glyph,
                    "verb": a.verb,
                    "subtitle": Power.detail(a.id, Settings.powerDetails),
                    "hint": a.id === "reboot" && Settings.powerDetails && Power.restartHint,
                    "score": score,
                    "order": i
                });
        }
        return out.sort((x, y) => y.score - x.score || x.order - y.order);
    }

    function move(delta: int, wrap: bool): void {
        const n = results.length;
        if (n === 0)
            return;
        let i = selected + delta;
        i = wrap ? (i % n + n) % n : Math.max(0, Math.min(n - 1, i));
        selected = i;
    }

    function hoverSelect(i: int, global: point): void {
        // rows moving under a resting pointer (filtering) must not steal the selection
        if (global.x === lastPointer.x && global.y === lastPointer.y)
            return;
        lastPointer = global;
        if (i >= 0 && i < results.length)
            selected = i;
    }

    // first click / Enter: arm (if the action wants a confirmation) or run; second: run
    function activate(i: int, how: string): void {
        const a = results[i];
        if (!a)
            return;
        selected = i;
        if (armedId === a.id) {
            if (Date.now() - armedAt < lt.armGuard * Env.slowmo)
                return;
            execute(a.id);
        } else if (Power.confirm(a.id)) {
            arm(a.id, how);
        } else {
            execute(a.id);
        }
    }

    function arm(id: string, how: string): void {
        armedId = id;
        armedBy = how;
        armedAt = Date.now();
        countdown.stop();
        armProgress = 1;
        countdown.start();
    }
    function disarm(): void {
        countdown.stop();
        armedId = "";
        armedBy = "";
        armProgress = 1;
    }
    function execute(id: string): void {
        disarm();
        Ui.close(); // collapse first: the lock screen / suspend should not catch the open panel
        Power.run(id);
    }

    NumberAnimation {
        id: countdown
        target: root
        property: "armProgress"
        from: 1
        to: 0
        duration: Math.max(500, Settings.powerConfirmTime * 1000) * Env.slowmo // fixed time, not an animation speed
        onFinished: if (root.armProgress <= 0)
            root.disarm()
    }

    // the selection left the armed row (keys, pointer, filter): fall back at once
    onSelectedChanged: if (armedId !== "" && results[selected]?.id !== armedId)
        disarm()
    onResultsChanged: {
        snap = true;
        unsnap.restart();
        if (selected >= results.length)
            selected = Math.max(0, results.length - 1);
        if (armedId !== "" && results[selected]?.id !== armedId)
            disarm();
    }
    Timer {
        id: unsnap
        interval: 50
        onTriggered: root.snap = false
    }

    Component.onCompleted: if (!probe)
        Power.refresh()
    Timer {
        running: !root.probe
        interval: Motion.ms(80 + root.allRows * root.lt.stagger)
        onTriggered: root.revealing = false
    }

    // ---- filter line --------------------------------------------------------------------
    Item {
        id: header
        width: parent.width
        height: root.lt.headerHeight

        PowerGlyph {
            x: root.lt.lensX
            y: root.lt.centerY - height / 2
            size: root.lt.lensSize
            name: filter.text === "" ? "power" : "search"
            color: Theme.textDim
        }

        TextInput {
            id: filter
            x: root.lt.inputX
            y: root.lt.centerY - height / 2
            width: host.x - 16 - x
            focus: true
            clip: true
            color: Theme.text
            selectionColor: Theme.surfaceHigh
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: root.lt.inputSize
            cursorDelegate: Rectangle {
                width: 2
                color: Theme.text
                visible: filter.cursorVisible
            }

            onTextChanged: {
                root.disarm();
                root.selected = 0;
            }

            Keys.onPressed: event => {
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
                case Qt.Key_Home:
                    if (filter.text !== "")
                        return;
                    root.selected = 0;
                    break;
                case Qt.Key_End:
                    if (filter.text !== "")
                        return;
                    root.selected = Math.max(0, root.results.length - 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activate(root.selected, "key");
                    break;
                case Qt.Key_Escape:
                    if (root.armedId === "")
                        return; // PanelHost closes
                    root.disarm();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: filter.text === ""
                text: "Type to filter"
                color: Theme.textDim
                font.pixelSize: root.lt.inputSize
            }
        }

        Txt {
            id: host
            anchors.right: parent.right
            anchors.rightMargin: root.lt.inset + 10
            y: root.lt.centerY - height / 2
            text: Power.host !== "" ? `${Power.user}@${Power.host}` : Power.user
            color: Theme.textDim
            font.pixelSize: root.lt.hostSize
        }

        Rectangle {
            x: root.lt.inset
            y: root.lt.headerHeight - 1
            width: parent.width - 2 * root.lt.inset
            height: 1
            color: root.lt.separator
        }
    }

    // ---- actions ------------------------------------------------------------------------
    ListView {
        id: list
        x: root.lt.inset
        y: root.lt.listTop
        width: parent.width - 2 * root.lt.inset
        height: root.rows * root.lt.rowHeight
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
            visible: root.results.length > 0
            opacity: root.armedId !== "" ? 0 : 1
            Behavior on y {
                enabled: !root.snap
                Anim {
                    ms: root.lt.highlightMove
                }
            }
            Behavior on opacity {
                Anim {
                    ms: root.lt.armFade
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

        delegate: PowerRow {
            width: list.width
            reveal: root.revealing
            armed: root.armedId === modelData.id
            progress: armed ? root.armProgress : 1
            armedText: `${root.armedBy === "key" ? "Press Enter" : "Click"} again to ${modelData.verb}`
            onHovered: global => root.hoverSelect(index, global)
            onActivated: root.activate(index, "click")
        }
    }

    Txt {
        x: root.lt.inset + root.lt.textX
        y: root.lt.listTop + (root.lt.rowHeight - height) / 2
        visible: !root.probe && root.results.length === 0
        width: list.width - x
        elide: Text.ElideRight
        text: Power.shown.length === 0 ? "No actions: switch some on in Settings > Power" : `No action matches "${filter.text.trim()}"`
        color: Theme.textDim
        font.pixelSize: root.lt.subtitleSize
    }
}
