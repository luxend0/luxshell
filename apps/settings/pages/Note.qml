import QtQuick
import qs.config
import qs.apps.settings

// "custom" row without a label: a short paragraph under an option (what it changes, how
// to undo it). Option fields: `text` (string or function, read live).
//   Component { id: note; Note {} }
//   { "id": "kittyNote", "kind": "custom", "label": "", "component": note, "text": "..." }
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null

    implicitHeight: body.implicitHeight + 2 * 15

    SText {
        id: body
        x: root.g.rowInset
        y: 15
        width: root.width - 2 * root.g.rowInset
        wrapMode: Text.Wrap
        size: 14.5
        lineHeight: 1.12
        font.weight: Font.Normal
        color: root.g.value
        text: root.opt ? (typeof root.opt.text === "function" ? root.opt.text() : (root.opt.text ?? "")) : ""
    }
}
