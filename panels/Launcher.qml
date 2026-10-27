import QtQuick
import Quickshell.Widgets
import qs.config
import qs.core
import qs.services
import qs.widgets

// Placeholder launcher (ref/07): search + app list. Shows the keyboard flow
// (focus on open, Up/Down/Enter, Esc via host) and a panel whose reported
// height follows its content, so the island resizes while typing.
PanelBase {
    id: root

    readonly property int rowH: 64
    readonly property int headerH: 84
    readonly property var results: Apps.search(search.text, 6)
    property int selected: 0

    preferredWidth: 720
    preferredHeight: headerH + Math.max(1, results.length) * rowH + 20

    function focusDefault() {
        search.forceActiveFocus();
    }
    function launch(i: int): void {
        const entry = results[i];
        if (!entry)
            return;
        entry.execute();
        Ui.close();
    }

    onResultsChanged: selected = 0

    Item {
        id: header
        width: parent.width
        height: root.headerH

        Icon {
            id: lens
            x: 28
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 18
            color: Theme.textDim
        }
        TextInput {
            id: search
            anchors.left: lens.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.text
            selectionColor: Theme.surfaceHigh
            font.family: Theme.fontFamily
            font.pixelSize: 18
            cursorDelegate: Rectangle {
                width: 2
                color: Theme.text
            }
            Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
            Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
            Keys.onReturnPressed: root.launch(root.selected)
            Keys.onEnterPressed: root.launch(root.selected)

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Search..."
                color: Theme.textDim
                font.pixelSize: 18
            }
        }
    }

    Column {
        anchors.top: header.bottom
        x: 16
        width: parent.width - 32

        Repeater {
            model: root.results

            Rectangle {
                id: row
                required property var modelData
                required property int index
                width: parent.width
                height: root.rowH
                radius: 16
                color: index === root.selected ? Theme.surfaceHigh : "transparent"

                Rectangle {
                    visible: row.index === root.selected
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 24
                    radius: 1.5
                    color: Theme.accent
                }
                IconImage {
                    id: appIcon
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 32
                    source: Apps.iconPath(row.modelData.icon)
                }
                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        width: parent.width
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        width: parent.width
                        text: row.modelData.comment || row.modelData.genericName || ""
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: Theme.textDim
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.launch(row.index)
                }
            }
        }
    }
}
