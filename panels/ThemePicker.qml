import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.launcher
import qs.panels.picker

// Theme picker (ref/05, ref/15): search field + counter, card carousel, "Enter to apply".
//
// Live preview: the highlighted theme is shown on the island right away (Themes.preview,
// everything bound to Theme.* follows: this panel's frame and text, the workspace strip
// bottom left). Enter applies it (Settings.theme), Esc / click outside / another panel
// drops the preview and the applied theme is back. Settings.pickerThemePreview off: no live
// preview, the island keeps the applied theme until Enter.
//
// Keys: Left/Right, Tab/Shift+Tab (wrap), Home/End, Ctrl+N/P, Enter, Esc (PanelHost),
// typing filters. Mouse: click a card to highlight, click the highlighted one to apply,
// wheel or drag to browse.
PanelBase {
    id: root

    readonly property var g: Theme.themePicker
    readonly property var p: Theme.picker

    readonly property var matches: probe ? [] : filter(search.text)
    property int selected: 0
    readonly property string highlighted: matches[selected] ?? ""
    property bool applied: false

    preferredWidth: g.width
    preferredHeight: g.height

    function focusDefault() {
        search.forceActiveFocus();
    }

    // substring first (prefix before inner), then in-order subsequence; A-Z inside each tier
    function filter(q: string): var {
        const all = Themes.names;
        const s = q.trim().toLowerCase();
        if (s === "")
            return all;
        const tier = n => {
            const i = n.indexOf(s);
            if (i === 0)
                return 0;
            if (i > 0)
                return 1;
            let j = 0;
            for (const ch of n)
                if (ch === s[j])
                    j++;
            return j === s.length ? 2 : -1;
        };
        return all.map(n => [tier(n), n]).filter(x => x[0] >= 0).sort((a, b) => a[0] - b[0] || a[1].localeCompare(b[1])).map(x => x[1]);
    }

    function move(delta: int, wrap: bool): void {
        const n = matches.length;
        if (n === 0)
            return;
        selected = wrap ? ((selected + delta) % n + n) % n : Math.max(0, Math.min(n - 1, selected + delta));
    }

    function apply(): void {
        if (highlighted === "")
            return;
        applied = true;
        Settings.set("theme", highlighted);
        Themes.preview = "";
        Ui.close();
    }

    readonly property bool live: Settings.pickerThemePreview
    onHighlightedChanged: if (active && live)
        Themes.preview = highlighted
    onActiveChanged: {
        if (probe)
            return;
        if (active && live)
            Themes.preview = highlighted;
        else if (!applied)
            Themes.preview = "";
    }
    onLiveChanged: if (active && !probe)
        Themes.preview = live ? highlighted : ""
    Component.onDestruction: if (!probe && !applied && Themes.preview === highlighted)
        Themes.preview = ""

    // a new filter result keeps the highlighted theme if it is still there
    property string keep: ""
    onMatchesChanged: {
        const i = matches.indexOf(keep);
        selected = i >= 0 ? i : 0;
        strip.jump();
    }
    onSelectedChanged: keep = matches[selected] ?? ""

    Component.onCompleted: {
        if (probe)
            return;
        keep = Settings.theme;
        const i = matches.indexOf(Settings.theme);
        selected = i >= 0 ? i : 0;
        strip.jump();
    }

    // ---- search row -------------------------------------------------------------
    Glyph {
        x: root.p.lensX
        y: root.p.headerY - height / 2
        size: root.p.lensSize
        name: "search"
        color: Theme.textDim
    }

    TextInput {
        id: search
        x: root.p.inputX
        y: root.p.headerY - height / 2
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
                root.move(1, false);
                break;
            case Qt.Key_Left:
                root.move(-1, false);
                break;
            case Qt.Key_Tab:
                root.move(event.modifiers & Qt.ShiftModifier ? -1 : 1, true);
                break;
            case Qt.Key_Backtab:
                root.move(-1, true);
                break;
            case Qt.Key_Home:
                root.selected = 0;
                break;
            case Qt.Key_End:
                root.selected = Math.max(0, root.matches.length - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.apply();
                break;
            case Qt.Key_N:
                if (!ctrl)
                    return;
                root.move(1, false);
                break;
            case Qt.Key_P:
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
            text: "Search themes..."
            color: Theme.textDim
            font.pixelSize: root.p.inputSize
        }
    }

    Txt {
        id: counter
        anchors.right: parent.right
        anchors.rightMargin: root.p.inset
        y: root.p.headerY - height / 2
        text: `${root.matches.length > 0 ? root.selected + 1 : 0}/${root.matches.length}`
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
        font.features: {
            "tnum": 1
        }
    }

    // ---- cards ------------------------------------------------------------------
    Carousel {
        id: strip
        x: root.g.clipInset
        y: root.g.stripY
        width: parent.width - 2 * root.g.clipInset
        height: root.g.stripHeight
        step: root.g.step
        count: root.matches.length
        current: root.selected
        onPicked: i => root.selected = i
        onMoved: delta => root.move(delta, false)
        onActivated: i => {
            root.selected = i;
            root.apply();
        }

        delegate: ThemeCard {
            name: root.matches[index] ?? ""
            pal: Themes.palettes[name] ?? Themes.palettes.noir
            applied: name === Settings.theme
        }
    }

    Txt {
        anchors.centerIn: strip
        visible: root.matches.length === 0
        text: "No theme matches"
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    // ---- footer hint (ref/05) -------------------------------------------------------
    Txt {
        anchors.right: parent.right
        anchors.rightMargin: root.p.inset
        y: root.g.footerY - height / 2
        text: "Enter to apply"
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    readonly property string screenName: Ui.panelScreen !== "" ? Ui.panelScreen : Ui.focusedScreen()
}
