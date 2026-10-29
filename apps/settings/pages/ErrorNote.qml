import QtQuick
import qs.config
import qs.apps.settings

// Bare custom row: a failed system change (polkit refused, command missing) as a warning
// paragraph with a dismiss button. Option fields: text() (live), dismiss(). The page adds the
// row only while there is an error (System > Default Apps, Startup Apps, Date & Time).
//   Component { id: errorNote; ErrorNote {} }
//   { "id": "clockError", "kind": "custom", "label": "", "component": errorNote, "text": () => SysClock.error, "dismiss": () => SysClock.error = "" }
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    readonly property string text: opt && opt.text ? (typeof opt.text === "function" ? opt.text() : opt.text) : ""

    implicitHeight: Math.max(body.implicitHeight, 22) + 2 * 16

    MdIcon {
        id: glyph
        x: root.g.rowInset
        y: 16 + (Math.round(root.g.textSize * Theme.fontScale) * 1.2 - height) / 2
        glyph: Catalog.glyph(0xF0026) // md-alert
        size: 19
        color: Theme.danger
    }
    SText {
        id: body
        x: glyph.x + 30
        y: 16
        width: close.x - x - 14
        wrapMode: Text.Wrap
        lineHeight: 1.1
        size: 15.5
        color: Theme.mix(Theme.danger, root.g.label, 0.35)
        text: root.text
    }
    MiniButton {
        id: close
        x: root.width - root.g.rowInset - width + 4
        y: 16 + (Math.round(root.g.textSize * Theme.fontScale) * 1.2 - height) / 2
        glyph: Catalog.glyph(0xF0156) // md-close
        onClicked: if (root.opt && root.opt.dismiss)
            root.opt.dismiss()
    }

    // Delete / Enter on the row dismisses it
    function activate(): bool {
        if (opt && opt.dismiss)
            opt.dismiss();
        return true;
    }
    function deleteKey(): bool {
        return activate();
    }
}
