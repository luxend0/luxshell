import QtQuick
import qs.config
import qs.widgets
import qs.island.bar
import qs.island.widgets
import qs.apps.settings

// Options of the picked widget, next to the palette: what it is, where it sits, its own
// settings (BarRegistry option rows: segment | switch | slider | text), add / remove, reset.
// Every change goes through IslandEditing (undo) and shows on the island at once.
Rectangle {
    id: panel

    readonly property QtObject g: Theme.settings
    readonly property QtObject e: Theme.islandEditor
    property string widgetId: ""
    readonly property var def: BarRegistry.def(widgetId)
    readonly property var lay: BarRegistry.layout
    readonly property bool inC: !!def && BarRegistry.contains(lay, "collapsed", widgetId)
    readonly property bool inH: !!def && BarRegistry.contains(lay, "hover", widgetId)
    readonly property bool changed: !!def && BarRegistry.optionKeys(widgetId).some(k => !Settings.isDefault(k))
    signal addRequested(string state)
    signal removeRequested

    implicitHeight: body.height + 2 * e.panelPad
    radius: e.panelRadius
    color: Theme.mix(g.card, g.field, 0.6)

    // the panel takes its clicks (no deselect, no drag start underneath)
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: body
        x: panel.e.panelPad
        y: panel.e.panelPad
        width: parent.width - 2 * panel.e.panelPad
        spacing: 12

        // ---- nothing picked ----
        Column {
            visible: !panel.def
            width: parent.width
            spacing: 8
            SText {
                text: "Widgets"
                size: 15
            }
            SText {
                width: parent.width
                wrapMode: Text.WordWrap
                size: 13
                color: panel.g.value
                text: "Click a widget in the preview or in the list to see its options. Drag widgets into the island, drag them out to remove them."
            }
        }

        // ---- header ----
        Row {
            visible: !!panel.def
            spacing: 10
            WIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: panel.def ? panel.def.icon : ""
                size: 20
                color: panel.g.label
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.def ? panel.def.name : ""
                size: 16
            }
        }
        SText {
            visible: !!panel.def
            width: parent.width
            wrapMode: Text.WordWrap
            size: 13
            color: panel.g.value
            text: panel.def ? panel.def.desc : ""
        }
        SText {
            visible: !!panel.def
            width: parent.width
            wrapMode: Text.WordWrap
            size: 13
            color: panel.g.caption
            text: {
                if (!panel.def)
                    return "";
                if (panel.widgetId === "battery" && !BarRegistry.hasBattery())
                    return "No battery here: the widget stays hidden.";
                const where = [panel.inC ? "collapsed" : "", panel.inH ? "hover" : ""].filter(x => x !== "");
                return where.length === 0 ? "Not in the island." : where.length === 2 ? "In the collapsed and the hover island." : `In the ${where[0]} island.`;
            }
        }

        // ---- options ----
        Repeater {
            model: panel.def ? panel.def.options : []

            Column {
                id: optRow
                required property var modelData
                width: body.width
                spacing: 6
                readonly property var value: Settings.get(modelData.key)

                Item {
                    width: parent.width
                    height: Math.max(label.implicitHeight, inline.height)
                    SText {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        size: 14
                        text: optRow.modelData.label
                    }
                    // switch, slider value on the label line
                    Item {
                        id: inline
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: optRow.modelData.kind === "switch" ? sw.width : valueText.implicitWidth
                        height: optRow.modelData.kind === "switch" ? sw.height : valueText.implicitHeight
                        SwitchCtl {
                            id: sw
                            visible: optRow.modelData.kind === "switch"
                            on: optRow.value === true
                            hovered: swArea.containsMouse
                            scale: 0.85
                            transformOrigin: Item.Right
                            MouseArea {
                                id: swArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: IslandEditing.setOption(optRow.modelData.key, !optRow.value)
                            }
                        }
                        SText {
                            id: valueText
                            visible: optRow.modelData.kind === "slider"
                            size: 13
                            color: panel.g.value
                            text: optRow.modelData.kind === "slider" ? `${slider.shown}${optRow.modelData.unit ?? ""}` : ""
                        }
                    }
                }
                Segmented {
                    visible: optRow.modelData.kind === "segment"
                    items: optRow.modelData.items ?? []
                    value: optRow.value
                    textSize: 13
                    pad: 9
                    maxWidth: body.width
                    onPicked: v => IslandEditing.setOption(optRow.modelData.key, v)
                }
                SliderCtl {
                    id: slider
                    visible: optRow.modelData.kind === "slider"
                    width: parent.width
                    value: Number(optRow.value) || 0
                    min: optRow.modelData.min ?? 0
                    max: optRow.modelData.max ?? 1
                    step: optRow.modelData.step ?? 1
                    onCommit: v => IslandEditing.setOption(optRow.modelData.key, v)
                }
                Rectangle {
                    visible: optRow.modelData.kind === "text"
                    width: parent.width
                    height: 34
                    radius: panel.g.fieldRadius
                    color: panel.g.field
                    border.width: field.activeFocus ? 1 : 0
                    border.color: Theme.mix(panel.g.field, Theme.text, 0.2)
                    TextInput {
                        id: field
                        x: 10
                        width: parent.width - 20
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        text: optRow.modelData.kind === "text" ? String(optRow.value ?? "") : ""
                        color: panel.g.label
                        selectByMouse: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(14 * Theme.fontScale)
                        onEditingFinished: IslandEditing.setOption(optRow.modelData.key, text.trim())
                        Keys.onEscapePressed: {
                            text = String(optRow.value ?? "");
                            focus = false;
                        }
                    }
                    SText {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === "" && !field.activeFocus
                        size: 14
                        text: optRow.modelData.placeholder ?? ""
                        color: panel.g.placeholder
                    }
                }
            }
        }

        // ---- actions ----
        Flow {
            visible: !!panel.def
            width: parent.width
            spacing: 8
            MiniButton {
                visible: !!panel.def && !panel.inC && panel.def.states.includes("collapsed")
                text: "Add to collapsed"
                onClicked: panel.addRequested("collapsed")
            }
            MiniButton {
                visible: !!panel.def && !panel.inH && panel.def.states.includes("hover")
                text: "Add to hover"
                onClicked: panel.addRequested("hover")
            }
            MiniButton {
                visible: panel.inC || panel.inH
                text: "Remove"
                onClicked: panel.removeRequested()
            }
            MiniButton {
                visible: panel.changed
                text: "Reset options"
                onClicked: IslandEditing.resetOptions(panel.widgetId)
            }
        }
    }
}
