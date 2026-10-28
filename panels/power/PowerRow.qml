import QtQuick
import qs.config
import qs.widgets

// One action of the power menu: icon tile, title, info line (launcher row metrics, a bit
// narrower). The grey highlight and the selection bar belong to the list so they can slide;
// the armed state belongs to the row: red fill that drains from the right over the
// confirmation time (progress 1 -> 0), white text, "Click again to ..." as the info line.
Item {
    id: row

    required property var modelData
    required property int index
    property bool armed: false
    property real progress: 1        // armed: remaining share of the confirmation time
    property string armedText: ""
    property bool reveal: false      // fade + rise in, staggered by index (panel opening)

    readonly property var lt: Theme.power

    signal hovered(point global)
    signal activated

    height: lt.rowHeight

    // ---- reveal on open ---------------------------------------------------------------
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
            duration: Motion.ms(40 + row.index * row.lt.stagger)
        }
        Anim {
            target: row
            property: "shown"
            to: 1
            ms: Theme.fadeIn
        }
    }

    // ---- armed: red fill draining with the countdown ------------------------------------
    property real armT: armed ? 1 : 0
    Behavior on armT {
        Anim {
            ms: row.lt.armFade
        }
    }

    Item {
        anchors.fill: parent
        opacity: row.armT
        visible: opacity > 0.001

        Rectangle {
            anchors.fill: parent
            radius: row.lt.rowRadius
            color: row.lt.armedSpent
        }
        Item {
            width: Math.round(parent.width * Math.max(0, Math.min(1, row.progress)))
            height: parent.height
            clip: true

            Rectangle {
                width: row.width
                height: row.height
                radius: row.lt.rowRadius
                color: row.lt.armed
            }
        }
    }

    // ---- content ------------------------------------------------------------------------
    Rectangle {
        id: tile
        x: row.lt.tileX
        anchors.verticalCenter: parent.verticalCenter
        width: row.lt.tileSize
        height: row.lt.tileSize
        radius: row.lt.tileRadius
        color: Theme.mix(row.lt.tile, row.lt.armedTile, row.armT)

        PowerGlyph {
            anchors.centerIn: parent
            name: row.modelData.glyph
            size: row.lt.glyphSize
            color: Theme.mix(Theme.text, row.lt.armedInk, row.armT)
        }

        // restart: kernel / packages updated since boot (Power.restartHint)
        Rectangle {
            visible: row.modelData.hint === true
            x: parent.width - width / 2 - 3
            y: -width / 2 + 3
            width: 9
            height: 9
            radius: 4.5
            color: Theme.accent
            border.width: 2
            border.color: Theme.island
            opacity: 1 - row.armT
        }
    }

    Txt {
        id: title
        x: row.lt.textX
        width: row.width - x - row.lt.inset
        y: row.lt.titleBaseline - baselineOffset
        text: row.modelData.title
        elide: Text.ElideRight
        font.pixelSize: row.lt.titleSize
        font.weight: Font.DemiBold
        color: Theme.mix(Theme.text, row.lt.armedInk, row.armT)
    }
    Txt {
        x: row.lt.textX
        width: title.width
        y: row.lt.subtitleBaseline - baselineOffset
        text: row.modelData.subtitle
        elide: Text.ElideRight
        font.pixelSize: row.lt.subtitleSize
        color: row.modelData.hint === true ? Theme.textSecondary : Theme.textDim
        opacity: 1 - row.armT
        visible: opacity > 0.001
    }
    Txt {
        x: row.lt.textX
        width: title.width
        y: row.lt.subtitleBaseline - baselineOffset
        text: row.armedText
        elide: Text.ElideRight
        font.pixelSize: row.lt.subtitleSize
        font.weight: Font.Medium
        color: Qt.rgba(1, 1, 1, 0.9)
        opacity: row.armT
        visible: opacity > 0.001
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: mouse => row.hovered(mapToGlobal(mouse.x, mouse.y))
        onEntered: row.hovered(mapToGlobal(mouseX, mouseY))
        onClicked: row.activated()
    }
}
