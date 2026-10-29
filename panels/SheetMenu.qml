import QtQuick
import qs.config
import qs.core
import qs.services
import qs.panels.controlcenter
import qs.panels.menus

// Bar menus (registry "sheet-*" / "menu-*", opened by the bar widgets or ipc toggle <id>):
// ONE control-center sheet as its own island panel. The island grows straight into the
// sheet: no control center around it, no dimmed page, no back disc (SheetPage.backButton);
// a click next to it or Esc closes it (host). The sheets are the control center's own files
// (panels/controlcenter/*Sheet.qml), switched to their bar-menu extras:
//
//   bluetooth     BluetoothSheet (scans while open)
//   sound         SoundSheet + input part (withInput); section "input" opens it scrolled to
//                 the microphone with its slider selected (registry "sheet-sound-input",
//                 right click on the microphone widget)
//   network       NetworkSheet (scans while open, password field unfolds in its row)
//   display       DisplaySheet + night light switch and temperature (withNightLight)
//   powerprofile  panels/menus/PowerProfileSheet (small menu: the three profiles)
//   caffeine      panels/menus/CaffeineSheet (small menu: 30 min / 1 h / 2 h / until off)
//
// Size: Theme.menus (sheet menus 560 wide, small ones 400), the height follows the sheet's
// content (the island morphs along when a device turns up), capped at Theme.menus.maxHeight;
// taller content scrolls inside the sheet. A pick in a small menu closes it after a moment.
//
// Keyboard like the control center (Cc.current = selected control, rings only after a key):
// arrows move spatially, Tab / Shift+Tab in reading order, Enter / Space / Delete go to the
// control, Esc falls through to the host (closes).
PanelBase {
    id: root

    property string sheet: "bluetooth"
    property string section: ""
    readonly property QtObject m: Theme.menus
    readonly property bool small: sheet === "powerprofile" || sheet === "caffeine"
    readonly property Item page: loader.item

    preferredWidth: small ? m.smallWidth : m.width
    preferredHeight: Math.max(m.minHeight, Math.min(m.maxHeight, m.topPad + (page ? Math.ceil(page.implicitHeight) : m.minHeight)))
    maxWidth: m.width
    maxHeight: m.maxHeight
    cornerRadius: small ? m.smallRadius : m.radius

    function focusDefault() {
        forceActiveFocus();
        select();
    }

    // initial selection: the section asked for (sound: input), the small menu's own choice
    // (menuDefault: the active profile / running duration), else the first control
    function select(): void {
        if (!page)
            return;
        if (page.menuDefault) {
            Cc.current = page.menuDefault;
            return;
        }
        if (section === "input" && page.inputSlider) {
            page.scrollTo(page.inputSection);
            Cc.current = page.inputSlider;
            return;
        }
        const list = controls();
        Cc.current = list.length > 0 ? list[0] : null;
    }

    Component.onCompleted: {
        if (probe) // registry size probe at shell start: no service side effects
            return;
        Cc.kb = false;
        if (sheet === "display") {
            Brightness.pickPrimary(Ui.panelScreen);
            NightLight.refresh();
        }
        selectLater.start();
    }

    // the sheet's columns lay out on the next polish: scroll and select once they have
    Timer {
        id: selectLater
        interval: 40
        onTriggered: root.select()
    }

    Timer {
        id: closeLater
        interval: Motion.ms(root.m.closeDelay)
        onTriggered: Ui.close()
    }

    // ---- keyboard (same rules as panels/ControlCenter.qml) -------------------------------
    function controls(): var {
        const out = [];
        const walk = item => {
            if (!item || !item.visible)
                return;
            if (item.ccControl === true)
                out.push(item);
            for (const c of item.children)
                walk(c);
        };
        walk(page);
        return out;
    }

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
            const score = (gap > 0 ? 1e5 + gap : 0) + main + 0.01 * centre;
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
            event.accepted = false; // host closes the panel
            return;
        }
        const list = controls();
        if (list.length === 0)
            return;
        const cur = list.includes(Cc.current) ? Cc.current : list[0];
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
        if (cur.key(k))
            return;
        const dir = k === Qt.Key_Left ? "left" : k === Qt.Key_Right ? "right" : k === Qt.Key_Up ? "up" : k === Qt.Key_Down ? "down" : "";
        if (dir !== "") {
            Cc.current = neighbour(cur, list, dir) ?? cur;
            return;
        }
        event.accepted = false;
    }

    // pointer use hides the keyboard selection again
    HoverHandler {
        onPointChanged: Cc.kb = false
    }

    // ---- sheet ------------------------------------------------------------------------
    Loader {
        id: loader
        y: root.m.topPad
        width: root.width
        height: root.height - y
        active: !root.probe
        sourceComponent: root.sheet === "bluetooth" ? bluetoothSheet : root.sheet === "sound" ? soundSheet : root.sheet === "network" ? networkSheet : root.sheet === "display" ? displaySheet : root.sheet === "powerprofile" ? powerSheet : root.sheet === "caffeine" ? caffeineSheet : null
    }

    Component {
        id: bluetoothSheet
        BluetoothSheet {
            backButton: false
        }
    }
    Component {
        id: soundSheet
        SoundSheet {
            backButton: false
            withInput: true
        }
    }
    Component {
        id: networkSheet
        NetworkSheet {
            backButton: false
            onReleaseFocus: {
                loader.focus = false;
                root.forceActiveFocus();
            }
        }
    }
    Component {
        id: displaySheet
        DisplaySheet {
            backButton: false
            withNightLight: true
        }
    }
    Component {
        id: powerSheet
        PowerProfileSheet {
            onPicked: closeLater.restart()
        }
    }
    Component {
        id: caffeineSheet
        CaffeineSheet {
            onPicked: closeLater.restart()
        }
    }
}
