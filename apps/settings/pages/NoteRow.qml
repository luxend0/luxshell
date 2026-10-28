import QtQuick
import qs.config
import qs.apps.settings

// Bare custom row (label "" in the option): label left, a note right that turns into a
// warning (danger colour + alert glyph) while opt.warn() is true. The option gives
// title (string), note() and warn(); used by Lock Screen > PAM.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    readonly property bool warn: opt && opt.warn ? opt.warn() : false

    implicitHeight: g.rowHeight

    SText {
        x: root.g.rowInset
        anchors.verticalCenter: parent.verticalCenter
        text: root.opt?.title ?? ""
    }
    Row {
        x: parent.width - root.g.rowInset - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        MdIcon {
            visible: root.warn
            anchors.verticalCenter: parent.verticalCenter
            glyph: Catalog.glyph(0xF0026) // md-alert
            size: 18
            color: Theme.danger
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.opt && root.opt.note ? root.opt.note() : ""
            color: root.warn ? Theme.danger : root.g.value
        }
    }
}
