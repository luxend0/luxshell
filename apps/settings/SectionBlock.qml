import QtQuick
import qs.config

// Optional caption ("Accent", "Type") above a card of rows (ref/12).
// Untitled sections keep the 17 px gap of the first card under the header.
Column {
    id: root

    readonly property QtObject g: Theme.settings
    required property var section
    required property var host
    property int firstIndex: 0        // flat index of the first row (keyboard focus)
    property bool tight: false        // first block without a header above it (search results)

    width: g.cardWidth

    Item {
        width: parent.width
        height: root.section.title === "" ? (root.tight ? 0 : root.g.gap) : root.g.labelBlock - (root.tight ? 14 : 0)

        SText {
            id: caption
            visible: root.section.title !== ""
            y: root.g.labelY - (root.tight ? 14 : 0) - height / 2
            size: root.g.labelSize
            text: root.section.title + (jump.containsMouse ? "  \u2192" : "")
            color: jump.containsMouse ? root.g.label : root.g.caption
        }
        // search results: the page caption opens that page
        MouseArea {
            id: jump
            enabled: (root.section.page ?? "") !== ""
            anchors.fill: caption
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsApp.navigate(root.section.page)
        }
    }

    Rectangle {
        width: parent.width
        height: rows.height
        radius: root.g.cardRadius
        color: root.g.card

        Column {
            id: rows
            width: parent.width

            Repeater {
                model: root.section.options

                OptionRow {
                    required property var modelData
                    required property int index
                    opt: modelData
                    host: root.host
                    flatIndex: root.firstIndex + index
                    first: index === 0
                    last: index === root.section.options.length - 1
                }
            }
        }
    }
}
