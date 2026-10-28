import QtQuick
import qs.config
import qs.widgets

// Header row of one app's notifications (panels/NotificationCenter.qml): icon, app name,
// count (when there are several) left; right the fold chevron (several only) and an x
// that clears the whole group (shown on hover / keyboard selection). A click on the row
// folds or unfolds like the chevron.
Item {
    id: head

    property var group: null          // Notifs.groups entry (kept while the row leaves)
    property bool unfolded: false
    property bool foldable: true      // false: no fold chevron (notification center ungrouped)
    property bool selected: false     // keyboard
    readonly property int count: group ? group.entries.length : 0
    readonly property QtObject nc: Theme.nc
    readonly property bool hovered: hover.hovered
    readonly property real targetHeight: nc.groupHeader
    signal toggle
    signal clear

    implicitHeight: nc.groupHeader

    HoverHandler {
        id: hover
    }

    // keyboard selection: soft pill behind the row + ring
    Rectangle {
        id: plate
        x: 0
        y: head.nc.groupY - height / 2
        width: head.width
        height: 32
        radius: height / 2
        color: head.nc.headerHover
        opacity: head.selected ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
        NcRing {
            shown: head.selected
            gap: 0
        }
    }

    MouseArea {
        anchors.fill: plate
        enabled: head.count > 1 && head.foldable
        cursorShape: Qt.PointingHandCursor
        onClicked: head.toggle()
    }

    AppIcon {
        id: icon
        x: head.nc.groupIconX
        y: head.nc.groupY - height / 2
        size: head.nc.groupIcon
        source: head.group?.icon ?? ""
        picture: head.group?.picture ?? false
        fallback: "bell"
    }

    Txt {
        id: name
        x: head.nc.groupTextX
        width: Math.min(implicitWidth, head.width - x - 120)
        y: head.nc.groupY - height / 2
        text: head.group?.app ?? ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.textSecondary
        font.pixelSize: head.nc.groupSize
        font.weight: Font.DemiBold
    }
    Txt {
        x: name.x + name.width + 8
        y: name.y
        visible: head.count > 1
        text: head.count
        color: Theme.textDim
        font.pixelSize: head.nc.groupSize
        font.weight: Font.Medium
    }

    NcChip {
        id: fold
        x: head.width - width - 4
        y: head.nc.groupY - height / 2
        visible: head.count > 1 && head.foldable
        icon: head.unfolded ? "chevron-up" : "chevron-down"
        hot: head.selected
        onClicked: head.toggle()
    }
    NcChip {
        id: clearChip
        x: (fold.visible ? fold.x - 8 : head.width - 4) - width
        y: head.nc.groupY - height / 2
        icon: "x"
        opacity: head.hovered || head.selected ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
        onClicked: head.clear()
    }
}
