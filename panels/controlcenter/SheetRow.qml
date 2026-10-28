import QtQuick
import qs.config
import qs.widgets

// Device / network row of a sheet (ref/09): rounded card, icon disc, name,
// status, pill button ("Connect", "Pair") or a trailing glyph. Click, Enter or
// Space = primary action, right click / Delete = secondary (forget).
// Extra content (password field) unfolds below the row line while `expanded`.
Rectangle {
    id: row

    readonly property QtObject sh: Theme.cc.sheet

    property string icon
    property string name
    property string sub
    property bool on: false           // disc white (connected, in use)
    property string button: ""        // pill text, "" = none
    property bool busy: false
    property string trailingIcon: ""  // glyph at the right when there is no pill
    property bool expanded: false
    property real extraHeight: 0
    signal activated
    signal secondary

    default property alias extra: extraSlot.data

    width: parent ? parent.width : 300
    height: sh.rowHeight + (expanded ? extraHeight : 0)
    radius: sh.rowRadius
    color: area.containsMouse ? sh.rowHover : sh.rowColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }
    Behavior on height {
        Anim {
            ms: Theme.fadeIn
        }
    }

    // rows that turn up later (scan results) fade in
    opacity: 0
    Component.onCompleted: appear.start()
    Anim {
        id: appear
        target: row
        property: "opacity"
        to: 1
        ms: Theme.fadeIn
    }

    readonly property bool ccControl: true
    function key(k: int): bool {
        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            activated();
        else if (k === Qt.Key_Delete)
            secondary();
        else
            return false;
        return true;
    }

    MouseArea {
        id: area
        width: parent.width
        height: row.sh.rowHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? row.secondary() : row.activated()
    }

    Disc {
        x: row.sh.discX
        y: Math.round((row.sh.rowHeight - height) / 2)
        width: row.sh.disc
        icon: row.icon
        on: row.on
        iconSize: row.sh.discIcon
        offColor: row.sh.discColor
    }

    SheetText {
        x: row.sh.nameX
        width: (pill.visible ? pill.x : trailing.visible ? trailing.x : row.width) - x - 14
        capY: row.sh.nameY
        px: row.sh.nameSize
        text: row.name
        color: row.sh.textColor
        font.weight: Font.Medium
    }
    SheetText {
        x: row.sh.subX
        width: (pill.visible ? pill.x : trailing.visible ? trailing.x : row.width) - x - 14
        capY: row.sh.subY
        px: row.sh.subSize
        text: row.sub
        color: row.sh.subColor
    }

    PillButton {
        id: pill
        x: row.width - row.sh.pillRight - width
        y: Math.round((row.sh.rowHeight - height) / 2)
        height: row.sh.pillHeight
        textSize: row.sh.pillSize
        textWeight: Font.DemiBold
        padX: row.sh.pillPad
        baseColor: row.sh.pillColor
        visible: row.button !== ""
        text: row.button
        busy: row.busy
        onClicked: row.activated()
    }

    Glyph {
        id: trailing
        x: row.width - 22 - width
        y: Math.round((row.sh.rowHeight - height) / 2)
        visible: row.button === "" && row.trailingIcon !== ""
        name: row.trailingIcon
        size: 18
        stroke: 2.2
        color: Theme.textSecondary
    }

    Item {
        id: extraSlot
        y: row.sh.rowHeight
        width: row.width
        height: row.height - y
        clip: true
        visible: row.expanded || height > 0.5 // visible at once, so a field inside can take focus
    }

    FocusRing {
        gap: 2
    }
}
