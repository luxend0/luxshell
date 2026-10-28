import QtQuick
import qs.config
import qs.widgets

// Small square icon button inside a row (list up/down, remove, browse).
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property string glyph: ""
    property string text: ""
    property bool active: true
    signal clicked

    implicitWidth: text === "" ? g.miniButton : label.implicitWidth + 24
    implicitHeight: g.miniButton
    radius: g.miniRadius
    color: area.containsMouse && active ? Theme.mix(g.field, Theme.text, 0.1) : g.field
    opacity: active ? 1 : 0.35

    MdIcon {
        visible: root.glyph !== ""
        anchors.centerIn: parent
        glyph: root.glyph
        size: 17
        color: area.containsMouse && root.active ? root.g.label : root.g.value
    }
    SText {
        id: label
        visible: root.text !== ""
        anchors.centerIn: parent
        size: 14
        text: root.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
