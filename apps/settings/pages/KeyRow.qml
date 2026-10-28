import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.apps.settings

// One shortcut of Settings > Keybinds (bare custom row; the option has `key`
// "keysBinds.<action>" and `action` = { id, label }): label, keycaps, reset, clear, and a
// note under it when the keys clash (another action, a Hyprland bind) or replace one.
//
// Recording: click the keycaps (or Enter on the row), then press the combination.
//   Super + key / Ctrl / Alt / Shift combos; F-keys, Print and media keys also alone;
//   Super pressed and released alone = "Super tap" (SUPER + Super_L, bound on release).
//   Esc cancels, Backspace or Delete alone clears the shortcut. Focus elsewhere cancels.
// While recording, services/Keybinds parks Hyprland in an empty submap, so keys that are
// bound already reach this window.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    property var row: null     // OptionRow (set by it)
    property var host: null    // SettingsWindow controller (set by the row)

    readonly property string actionId: opt?.action?.id ?? ""
    readonly property string keys: opt ? String(opt.value() ?? "") : ""
    readonly property var clash: Keybinds.conflict(actionId, keys)
    readonly property bool recording: capture.activeFocus
    property string held: ""   // modifiers held while recording ("Super + Shift")
    property string hint: ""   // rejected key while recording
    property bool tapCandidate: false

    implicitHeight: g.rowHeight + (clash.text !== "" && !recording ? 20 : 0)

    // ---- OptionRow hooks ------------------------------------------------------------------
    function activate(): bool {
        start();
        return true;
    }
    function deleteKey(): bool {
        return false; // Delete on the row resets it (OptionRow); Backspace while recording clears
    }

    function start(): void {
        if (recording)
            return;
        if (host && row)
            host.focusRow(row.flatIndex);
        held = "";
        hint = "";
        tapCandidate = false;
        capture.forceActiveFocus();
        Keybinds.recordStart();
    }
    function finish(value: var): void {
        if (value !== undefined && value !== null && opt && value !== keys)
            opt.set(value);
        Keybinds.recordStop();
        if (capture.activeFocus && host)
            host.focusRoot();
    }

    // ---- key names (Qt key -> Hyprland keysym name) ---------------------------------------
    readonly property var named: ({
            [Qt.Key_Tab]: "TAB",
            [Qt.Key_Backtab]: "TAB",
            [Qt.Key_Return]: "RETURN",
            [Qt.Key_Enter]: "RETURN",
            [Qt.Key_Space]: "SPACE",
            [Qt.Key_Escape]: "ESCAPE",
            [Qt.Key_Backspace]: "BACKSPACE",
            [Qt.Key_Delete]: "DELETE",
            [Qt.Key_Insert]: "INSERT",
            [Qt.Key_Home]: "HOME",
            [Qt.Key_End]: "END",
            [Qt.Key_PageUp]: "Page_Up",
            [Qt.Key_PageDown]: "Page_Down",
            [Qt.Key_Left]: "Left",
            [Qt.Key_Right]: "Right",
            [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down",
            [Qt.Key_Comma]: "COMMA",
            [Qt.Key_Period]: "PERIOD",
            [Qt.Key_Slash]: "SLASH",
            [Qt.Key_Backslash]: "BACKSLASH",
            [Qt.Key_Semicolon]: "SEMICOLON",
            [Qt.Key_Apostrophe]: "APOSTROPHE",
            [Qt.Key_Minus]: "MINUS",
            [Qt.Key_Equal]: "EQUAL",
            [Qt.Key_BracketLeft]: "BRACKETLEFT",
            [Qt.Key_BracketRight]: "BRACKETRIGHT",
            [Qt.Key_QuoteLeft]: "GRAVE",
            [Qt.Key_Print]: "Print",
            [Qt.Key_Pause]: "Pause",
            [Qt.Key_ScrollLock]: "Scroll_Lock",
            [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
            [Qt.Key_MediaPause]: "XF86AudioPause",
            [Qt.Key_MediaStop]: "XF86AudioStop",
            [Qt.Key_MediaNext]: "XF86AudioNext",
            [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume",
            [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute",
            [Qt.Key_Calculator]: "XF86Calculator",
            [Qt.Key_Search]: "XF86Search",
            [Qt.Key_LaunchMail]: "XF86Mail",
            [Qt.Key_HomePage]: "XF86HomePage"
        })
    // shifted symbols: the key's US position by XKB keycode (evdev + 8)
    readonly property var usPosition: ({
            "20": "MINUS",
            "21": "EQUAL",
            "34": "BRACKETLEFT",
            "35": "BRACKETRIGHT",
            "47": "SEMICOLON",
            "48": "APOSTROPHE",
            "49": "GRAVE",
            "51": "BACKSLASH",
            "59": "COMMA",
            "60": "PERIOD",
            "61": "SLASH"
        })
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock, Qt.Key_NumLock]

    function keyName(e: var): string {
        const k = e.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            return "F" + (k - Qt.Key_F1 + 1);
        const sc = e.nativeScanCode;
        if (sc >= 10 && sc <= 19) // number row with Shift (any layout with digits there)
            return String((sc - 9) % 10);
        if (named[k] !== undefined)
            return named[k];
        if ((e.modifiers & Qt.ShiftModifier) && usPosition[String(sc)] !== undefined)
            return usPosition[String(sc)];
        return "";
    }
    function modFlag(k: int): int {
        if (k === Qt.Key_Shift)
            return Qt.ShiftModifier;
        if (k === Qt.Key_Control)
            return Qt.ControlModifier;
        if (k === Qt.Key_Alt)
            return Qt.AltModifier;
        if (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R)
            return Qt.MetaModifier;
        return 0;
    }
    function modWords(m: int): var {
        const out = [];
        if (m & Qt.MetaModifier)
            out.push("SUPER");
        if (m & Qt.ControlModifier)
            out.push("CTRL");
        if (m & Qt.AltModifier)
            out.push("ALT");
        if (m & Qt.ShiftModifier)
            out.push("SHIFT");
        return out;
    }
    function bareOk(name: string): bool {
        return /^F\d+$/.test(name) || name.startsWith("XF86") || ["Print", "Pause", "Scroll_Lock"].includes(name);
    }

    function pressed(e: var): void {
        e.accepted = true;
        const mods = e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (modifierKeys.includes(e.key)) {
            const now = mods | modFlag(e.key);
            held = modWords(now).map(w => Keybinds.caps(w)[0]).join(" + ");
            tapCandidate = now === Qt.MetaModifier;
            return;
        }
        tapCandidate = false;
        if (mods === 0 && e.key === Qt.Key_Escape)
            return finish(null);
        if (mods === 0 && (e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete))
            return finish("");
        const name = keyName(e);
        if (name === "") {
            hint = "This key cannot be bound";
            return;
        }
        if (mods === 0 && !bareOk(name)) {
            hint = "Add Super, Ctrl or Alt";
            return;
        }
        finish([...modWords(mods), name].join(" + "));
    }
    function released(e: var): void {
        e.accepted = true;
        if (tapCandidate && (e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R))
            return finish("SUPER + Super_L");
        if (modifierKeys.includes(e.key)) {
            const now = (e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) & ~modFlag(e.key);
            held = modWords(now).map(w => Keybinds.caps(w)[0]).join(" + ");
        }
    }

    Item {
        id: capture
        Keys.onPressed: e => root.pressed(e)
        Keys.onReleased: e => root.released(e)
        onActiveFocusChanged: if (!activeFocus)
            Keybinds.recordStop()
    }

    // ---- layout ---------------------------------------------------------------------------
    SText {
        id: label
        x: root.g.rowInset
        y: root.g.rowHeight / 2 - height / 2
        width: controls.x - x - 16
        elide: Text.ElideRight
        text: root.opt?.action?.label ?? ""
    }

    Row {
        id: controls
        x: root.width - root.g.rowInset - width
        y: root.g.rowHeight / 2 - height / 2
        spacing: root.g.resetGap
        layoutDirection: Qt.LeftToRight

        ResetButton {
            anchors.verticalCenter: parent.verticalCenter
            shown: root.opt ? root.opt.modified() && !root.recording : false
            host: root.host
            tip: {
                const d = root.opt ? String(root.opt.defaultValue() ?? "") : "";
                return d === "" ? "Reset to default: not set" : `Reset to default: ${Keybinds.pretty(d)}`;
            }
            onClicked: root.opt.reset()
        }

        // keycaps / "Press keys..." field
        Rectangle {
            id: field
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(150, (root.recording ? recText.implicitWidth + 28 : capsRow.implicitWidth + 16))
            height: 36
            radius: root.g.fieldRadius
            color: root.recording ? Theme.mix(root.g.field, Theme.text, 0.06) : fieldArea.containsMouse ? Theme.mix(root.g.field, Theme.text, 0.08) : root.g.field
            border.width: root.recording ? 2 : root.clash.kind === "dup" || root.clash.kind === "hypr" ? 1 : 0
            border.color: root.recording ? root.g.ring : root.g.danger

            Row {
                id: capsRow
                visible: !root.recording
                anchors.centerIn: parent
                spacing: 5
                Repeater {
                    model: root.keys === "" ? [] : Keybinds.caps(root.keys)
                    Rectangle {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(26, capText.implicitWidth + 14)
                        height: 24
                        radius: 6
                        color: Theme.mix(root.g.field, Theme.text, 0.1)
                        border.width: 1
                        border.color: Theme.mix(root.g.field, Theme.text, 0.18)
                        SText {
                            id: capText
                            anchors.centerIn: parent
                            size: 13
                            text: parent.modelData
                        }
                    }
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.keys !== "" && Keybinds.parse(root.keys)?.tap === true
                    size: 13
                    text: "tap"
                    color: root.g.value
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.keys === ""
                    size: 15
                    text: "Not set"
                    color: root.g.placeholder
                }
            }
            SText {
                id: recText
                visible: root.recording
                anchors.centerIn: parent
                size: 15
                text: root.hint !== "" ? root.hint : root.held !== "" ? root.held + " + ..." : "Press keys..."
                color: root.hint !== "" ? root.g.danger : root.g.label
            }
            MouseArea {
                id: fieldArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.recording ? root.finish(null) : root.start()
            }
        }

        MiniButton {
            anchors.verticalCenter: parent.verticalCenter
            glyph: Catalog.glyph(0xF0156) // md-close
            active: root.keys !== "" && !root.recording
            onClicked: root.opt.set("")
        }
    }

    // conflict / replaced note under the label
    Row {
        visible: root.clash.text !== "" && !root.recording
        x: root.g.rowInset
        y: root.g.rowHeight - 12
        spacing: 6
        MdIcon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: Catalog.glyph(root.clash.kind === "replaced" ? 0xF02FC : 0xF0026) // md-information / md-alert
            size: 15
            color: root.clash.kind === "replaced" ? root.g.value : root.g.danger
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            size: 14
            text: root.clash.text
            color: root.clash.kind === "replaced" ? root.g.value : root.g.danger
        }
    }
}
