import QtQuick
import qs.config
import qs.widgets
import qs.island.widgets
import qs.apps.settings

// A widget of the palette (and the chip under the pointer while dragging): glyph, name and
// two dots for the collapsed / hover island: filled = in it, ring = could go there, none =
// not allowed there. Pointer input belongs to the editor (one area for drag and drop).
Rectangle {
    id: chip

    readonly property QtObject g: Theme.settings
    readonly property QtObject e: Theme.islandEditor
    property var def: null
    property bool hovered: false
    property bool selected: false
    property bool dimmed: false       // its widget is being dragged from here
    property bool floating: false     // the chip that follows the pointer
    property bool removing: false     // floating outside the island: drop removes
    property bool usedC: false
    property bool usedH: false
    property bool unavailable: false  // battery on a desktop

    readonly property bool allowC: !!def && def.states.includes("collapsed")
    readonly property bool allowH: !!def && def.states.includes("hover")

    implicitWidth: e.chipPad + e.chipIcon + 8 + name.implicitWidth + 10 + dots.width + e.chipPad - 2
    implicitHeight: e.chipHeight
    radius: e.chipRadius
    color: removing ? Theme.mix(g.field, e.remove, 0.35) : floating ? Theme.mix(g.field, Theme.text, 0.16) : hovered ? e.chipHover : e.chip
    opacity: dimmed ? 0.35 : unavailable && !floating ? 0.6 : 1
    border.width: selected ? 1.5 : 0
    border.color: e.ring
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    WIcon {
        id: glyph
        x: chip.e.chipPad
        anchors.verticalCenter: parent.verticalCenter
        name: chip.removing ? "trash-2" : chip.def ? chip.def.icon : ""
        size: chip.e.chipIcon
        stroke: 2
        color: chip.removing ? "white" : chip.g.label
    }
    SText {
        id: name
        x: glyph.x + glyph.width + 8
        anchors.verticalCenter: parent.verticalCenter
        size: 14
        text: chip.removing ? "Remove" : chip.def ? chip.def.name : ""
        color: chip.removing ? "white" : chip.g.label
    }
    Row {
        id: dots
        visible: !chip.floating
        x: name.x + name.implicitWidth + 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: [[chip.allowC, chip.usedC], [chip.allowH, chip.usedH]]
            Rectangle {
                required property var modelData
                width: 6
                height: 6
                radius: 3
                color: modelData[1] ? chip.g.label : "transparent"
                border.width: modelData[0] && !modelData[1] ? 1 : 0
                border.color: chip.g.value
                opacity: modelData[0] ? 1 : 0
            }
        }
    }
}
