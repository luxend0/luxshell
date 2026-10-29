import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets
import qs.island.widgets

// Which apps use the microphone, the camera or the screen right now (services/Privacy),
// opened from the island's privacy dot. The power menu's language, smaller: a header line
// with the red dot, then one row per app: icon tile, app name, what it uses, the glyph of it.
// Follows the live list (an app that stops drops out); with nothing left it says so.
PanelBase {
    id: root

    readonly property QtObject p: Theme.barInfo
    readonly property var entries: probe ? [] : Privacy.entries
    readonly property int rows: Math.max(1, entries.length)

    preferredWidth: p.panelWidth
    preferredHeight: p.listTop + rows * p.rowHeight + p.padBottom
    maxHeight: p.listTop + p.maxRows * p.rowHeight + p.padBottom

    // header
    Rectangle {
        x: root.p.dotX
        y: root.p.centerY - height / 2
        width: root.p.headerDot
        height: width
        radius: width / 2
        color: root.entries.length > 0 ? Theme.danger : Theme.textDim
    }
    Txt {
        x: root.p.titleX
        y: root.p.centerY - height / 2
        text: root.entries.length > 0 ? "In use right now" : "Nothing in use"
        font.pixelSize: root.p.headerSize
        font.weight: Font.Medium
    }
    Txt {
        anchors.right: parent.right
        anchors.rightMargin: root.p.padRight
        y: root.p.centerY - height / 2
        visible: root.entries.length > 0
        text: root.entries.length === 1 ? "1 app" : `${root.entries.length} apps`
        color: Theme.textSecondary
        font.pixelSize: root.p.subtitleSize
        font.weight: Font.Medium
    }
    Rectangle {
        x: root.p.inset
        y: root.p.headerHeight - 1
        width: root.width - 2 * root.p.inset
        height: 1
        color: root.p.separator
    }

    // rows
    Column {
        x: root.p.inset
        y: root.p.listTop
        width: root.width - 2 * root.p.inset

        Repeater {
            model: root.entries

            Item {
                id: row
                required property var modelData
                width: parent.width
                height: root.p.rowHeight

                Rectangle {
                    id: tile
                    x: root.p.tileX
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.p.tileSize
                    height: width
                    radius: root.p.tileRadius
                    color: root.p.tile

                    AppIcon {
                        anchors.centerIn: parent
                        visible: row.modelData.icon !== ""
                        source: row.modelData.icon
                        size: root.p.appIconSize
                        fallback: "app-window"
                    }
                    WIcon {
                        anchors.centerIn: parent
                        visible: row.modelData.icon === ""
                        name: row.modelData.glyph
                        size: root.p.glyphSize
                        color: Theme.text
                    }
                }
                Txt {
                    x: root.p.textX
                    width: kind.x - x - 12
                    y: root.p.titleBaseline - baselineOffset
                    text: row.modelData.app
                    elide: Text.ElideRight
                    font.pixelSize: root.p.titleSize
                    font.weight: Font.Medium
                }
                Txt {
                    x: root.p.textX
                    width: kind.x - x - 12
                    y: root.p.subtitleBaseline - baselineOffset
                    text: row.modelData.detail
                    elide: Text.ElideRight
                    color: Theme.textSecondary
                    font.pixelSize: root.p.subtitleSize
                }
                WIcon {
                    id: kind
                    x: parent.width - root.p.glyphRight - width
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.glyph
                    size: root.p.glyphSize
                    color: Theme.textSecondary
                }
            }
        }

        // nothing (left) in use
        Item {
            visible: root.entries.length === 0
            width: parent.width
            height: root.p.rowHeight
            Txt {
                x: root.p.tileX
                width: parent.width - 2 * root.p.tileX
                anchors.verticalCenter: parent.verticalCenter
                text: "No app is using the microphone, the camera or the screen."
                wrapMode: Text.WordWrap
                color: Theme.textSecondary
                font.pixelSize: root.p.subtitleSize
            }
        }
    }
}
