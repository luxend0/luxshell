import QtQuick
import qs.config
import qs.widgets

// Text field of a settings row: shows `text` (live), edits commit on Enter/Tab or when
// focus leaves (if valid), Esc restores. Used by text, path, paths (add), time rows.
Rectangle {
    id: field

    readonly property QtObject g: Theme.settings
    property string text: ""
    property string placeholder: ""
    property string family: Theme.fontFamily // Theme.monoFamily for hex / code fields
    property var valid: t => true
    property var host: null           // SettingsWindow controller (focus back to the window)
    property int flatIndex: -1
    property alias input: input
    property alias inputMask: input.inputMask
    property alias horizontalAlignment: input.horizontalAlignment
    readonly property bool ok: valid(input.text)
    readonly property bool editing: input.activeFocus
    signal applied(string text)
    signal tabbed                     // Tab while editing (after applying): next field of the row

    implicitWidth: g.fieldWidth
    implicitHeight: g.fieldHeight
    radius: g.fieldRadius
    color: g.field
    border.width: input.activeFocus ? 1 : 0
    border.color: ok ? Theme.mix(g.field, Theme.text, 0.25) : Theme.danger

    function edit(): void {
        input.forceActiveFocus();
        input.selectAll();
    }
    function finish(apply: bool, keepFocus: bool): void {
        if (apply && ok && input.text !== field.text)
            field.applied(input.text);
        input.text = Qt.binding(() => field.text);
        if (input.activeFocus && !keepFocus && host) // finished by key; a click elsewhere keeps its own focus
            host.focusRoot();
    }

    TextInput {
        id: input
        anchors.verticalCenter: parent.verticalCenter
        x: field.g.fieldPad
        width: parent.width - 2 * field.g.fieldPad
        clip: true
        text: field.text
        color: field.g.label
        selectionColor: Theme.surfaceHigh
        selectedTextColor: Theme.text
        selectByMouse: true
        font.family: field.family
        font.pixelSize: Math.round(field.g.textSize * Theme.fontScale)
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.text
            visible: input.cursorVisible
        }
        onActiveFocusChanged: if (activeFocus) {
            if (field.host && field.flatIndex >= 0)
                field.host.focusRow(field.flatIndex);
        } else if (text !== field.text) {
            field.finish(true, false);
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                field.finish(true, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                field.finish(true, true);
                field.tabbed();
                if (input.activeFocus && field.host)
                    field.host.focusRoot();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                field.finish(false, false);
                event.accepted = true;
            }
        }
    }

    SText {
        anchors.verticalCenter: parent.verticalCenter
        x: field.g.fieldPad
        visible: input.text === "" && !input.activeFocus
        text: field.placeholder
        color: field.g.placeholder
    }
}
