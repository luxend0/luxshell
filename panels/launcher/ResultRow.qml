import QtQuick
import Quickshell.Widgets
import qs.config
import qs.widgets

// One list row (ref/16 frame 1): icon tile, title, dim subtitle. The highlight
// and selection bar belong to the list, so they can slide between rows.
Item {
    id: row

    required property var modelData
    required property int index
    property bool reveal: false     // fade + rise in, staggered by index (panel opening)

    readonly property var lt: Theme.launcher
    readonly property bool selectable: typeof modelData.run === "function"
    readonly property bool hasIcon: (modelData.icon ?? "") !== "" && appIcon.status !== Image.Error

    signal hovered(point global)
    signal activated

    height: lt.rowHeight

    property real shown: 1
    opacity: shown
    transform: Translate {
        y: (1 - row.shown) * row.lt.revealShift
    }
    Component.onCompleted: if (reveal) {
        shown = 0;
        revealAnim.start();
    }
    SequentialAnimation {
        id: revealAnim
        PauseAnimation {
            duration: 40 + row.index * row.lt.stagger
        }
        Anim {
            target: row
            property: "shown"
            to: 1
            duration: Theme.fadeIn
        }
    }

    Rectangle {
        id: tile
        x: row.lt.tileX
        anchors.verticalCenter: parent.verticalCenter
        width: row.lt.tileSize
        height: row.lt.tileSize
        radius: row.lt.tileRadius
        color: row.lt.tile

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: row.lt.iconSize
            source: row.modelData.icon ?? ""
            asynchronous: true
            visible: row.hasIcon
        }
        Glyph {
            anchors.centerIn: parent
            visible: !row.hasIcon
            name: row.modelData.glyph || "app-window"
            size: row.lt.glyphSize
            color: row.selectable ? Theme.text : Theme.textDim
        }
    }

    Txt {
        id: title
        x: row.lt.textX
        width: row.width - x - row.lt.inset
        // title alone sits on the row's optical centre
        y: (sub.visible ? row.lt.titleBaseline : (row.height + font.pixelSize * 0.727) / 2) - baselineOffset
        text: row.modelData.title ?? ""
        elide: Text.ElideRight
        font.pixelSize: row.lt.titleSize
        font.weight: Font.DemiBold
        color: row.selectable ? Theme.text : Theme.textSecondary
    }
    Txt {
        id: sub
        x: row.lt.textX
        width: title.width
        y: row.lt.subtitleBaseline - baselineOffset
        visible: text !== ""
        text: row.modelData.subtitle ?? ""
        elide: Text.ElideRight
        font.pixelSize: row.lt.subtitleSize
        color: Theme.textDim
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.selectable
        onPositionChanged: mouse => row.hovered(mapToGlobal(mouse.x, mouse.y))
        onClicked: row.activated()
    }
}
