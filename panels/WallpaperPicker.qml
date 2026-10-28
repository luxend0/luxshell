import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.panels.launcher
import qs.panels.picker

// Wallpaper picker (ref/06): title + applied theme name, thumbnail carousel (centred
// card full size with frame, neighbours 10 % smaller and darker per step), file name
// and "6/10 · Enter to apply" below.
//
// Enter applies (Settings.wallpaper via services/Wallpapers). Whether luxshell paints
// it right away depends on the background layer (LUXSHELL_WALLPAPER=1 or
// Settings.wallpaperLayer); otherwise only the setting is written. With the
// "wallpaper" theme the island palette follows the new wallpaper either way.
//
// Typing filters by file name (the title turns into the query). Keys and mouse like
// the theme picker: Left/Right, Tab/Shift+Tab, Home/End, Ctrl+N/P, Enter, Esc.
PanelBase {
    id: root

    readonly property var g: Theme.wallpaperPicker
    readonly property var p: Theme.picker

    readonly property var matches: probe ? [] : filter(Wallpapers.entries, search.text)
    property int selected: 0
    readonly property var entry: matches[selected] ?? null

    preferredWidth: g.width
    preferredHeight: g.height

    function focusDefault() {
        search.forceActiveFocus();
    }

    function filter(all: var, q: string): var {
        const s = q.trim().toLowerCase();
        return s === "" ? all : all.filter(e => e.name.toLowerCase().includes(s));
    }

    function move(delta: int, wrap: bool): void {
        const n = matches.length;
        if (n === 0)
            return;
        selected = wrap ? ((selected + delta) % n + n) % n : Math.max(0, Math.min(n - 1, selected + delta));
    }

    function apply(): void {
        if (!entry)
            return;
        Wallpapers.apply(entry.path);
        Ui.close();
    }

    // rescans and filters keep the highlighted file if it is still listed
    property string keep: ""
    onMatchesChanged: {
        const i = matches.findIndex(e => e.path === keep);
        selected = i >= 0 ? i : Math.max(0, matches.findIndex(e => e.path === Wallpapers.current));
        strip.jump();
    }
    onSelectedChanged: keep = matches[selected]?.path ?? keep

    Component.onCompleted: {
        if (probe)
            return;
        keep = Wallpapers.current;
        const i = matches.findIndex(e => e.path === keep);
        selected = Math.max(0, i);
        strip.jump();
        Wallpapers.scan();
    }

    // ---- header -----------------------------------------------------------------
    Txt {
        x: root.p.inset
        y: root.p.headerY - height / 2
        visible: search.text === ""
        text: "Wallpaper"
        font.pixelSize: root.p.titleSize
    }

    Glyph {
        x: root.p.lensX
        y: root.p.headerY - height / 2
        visible: search.text !== ""
        size: root.p.lensSize
        name: "search"
        color: Theme.textDim
    }

    TextInput {
        id: search
        x: root.p.inputX
        y: root.p.headerY - height / 2
        width: themeName.x - 16 - x
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
            visible: search.cursorVisible && search.text !== ""
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
    }

    Txt {
        id: themeName
        anchors.right: parent.right
        anchors.rightMargin: root.p.inset
        y: root.p.headerY - height / 2
        text: Theme.name
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    // ---- thumbnails -------------------------------------------------------------
    Carousel {
        id: strip
        x: root.p.inset
        y: root.g.stripY
        width: parent.width - 2 * root.p.inset
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

        delegate: WallpaperThumb {
            entry: root.matches[index] ?? null
            current: (entry?.path ?? "") === Wallpapers.current
        }
    }

    Txt {
        anchors.centerIn: strip
        visible: root.matches.length === 0
        text: !Wallpapers.scanned ? "" : search.text !== "" ? "No wallpaper matches" : `No wallpapers in ${Settings.wallpaperDirs.join(", ")}`
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    // ---- footer -----------------------------------------------------------------
    Txt {
        x: root.p.inset
        y: root.g.footerY - height / 2
        width: meta.x - 24 - x
        text: root.entry?.name ?? ""
        elide: Text.ElideMiddle
        color: Theme.textDim
        font.pixelSize: root.p.metaSize
    }

    Row {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: root.p.inset
        y: root.g.footerY - height / 2
        spacing: root.p.metaGap

        Txt {
            text: `${root.matches.length > 0 ? root.selected + 1 : 0}/${root.matches.length}`
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
            font.features: {
                "tnum": 1
            }
        }
        Txt {
            text: "·"
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
        }
        Txt {
            text: "Enter to apply"
            color: Theme.textDim
            font.pixelSize: root.p.metaSize
        }
    }
}
