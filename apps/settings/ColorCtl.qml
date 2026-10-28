import QtQuick
import qs.config
import qs.widgets

// Colour row control: disc + hex in a field; the row opens ColorPopover on click/Enter.
// value "" (allowEmpty) shows `fallback` with `emptyLabel` ("Theme").
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property string value: ""
    property color fallback: Theme.accent
    property string emptyLabel: "Default"
    property bool hovered: false
    readonly property color shown: value === "" ? fallback : value

    implicitWidth: g.colourFieldWidth
    implicitHeight: g.fieldHeight
    radius: g.fieldRadius
    color: hovered ? Theme.mix(g.field, Theme.text, 0.06) : g.field

    Rectangle {
        id: disc
        x: 7
        anchors.verticalCenter: parent.verticalCenter
        width: root.g.colourDisc
        height: width
        radius: width / 2
        color: root.shown
        border.width: 1
        border.color: Theme.mix(root.shown, Theme.text, 0.25)
    }

    SText {
        x: disc.x + disc.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 8
        elide: Text.ElideRight
        text: root.value === "" ? root.emptyLabel : root.value.toUpperCase()
        color: root.value === "" ? root.g.value : root.g.label
    }
}
