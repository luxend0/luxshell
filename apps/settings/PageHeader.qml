import QtQuick
import qs.config
import qs.widgets

// Page header card (ref/12): icon disc, title, one-line description, centred.
// "Reset page" in the top right corner while any option of the page differs from its
// default (one click; the window's toast offers Undo). Ctrl+Backspace does the same.
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property var page: null
    readonly property int changed: page ? Catalog.changedOptions(page).length : 0

    width: g.cardWidth
    height: g.headerHeight
    radius: g.cardRadius
    color: g.card

    function resetPage(): void {
        if (page)
            Catalog.resetPage(page);
    }

    Rectangle {
        id: disc
        x: (parent.width - width) / 2
        y: root.g.headerDiscY - height / 2
        width: root.g.headerDisc
        height: width
        radius: width / 2
        color: root.g.selected

        MdIcon {
            anchors.centerIn: parent
            glyph: root.page?.icon ?? ""
            size: root.g.headerIconSize
            color: root.g.icon
        }
    }

    SText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.g.headerTitleY - height / 2
        size: root.g.titleSize
        font.weight: Font.DemiBold
        text: root.page?.title ?? ""
        color: root.g.label
    }

    SText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.g.headerSubY - height / 2
        width: Math.min(implicitWidth, parent.width - 48)
        elide: Text.ElideRight
        text: root.page?.subtitle ?? ""
        color: Theme.textDim
    }

    Rectangle {
        id: resetBtn
        visible: opacity > 0.01
        opacity: root.changed > 0 ? 1 : 0
        x: parent.width - width - root.g.pageResetInset
        y: root.g.pageResetInset
        width: resetRow.implicitWidth + 24
        height: root.g.pageResetHeight
        radius: height / 2
        color: area.containsMouse ? root.g.field : "transparent"
        border.width: 1
        border.color: root.g.separator
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }

        Row {
            id: resetRow
            anchors.centerIn: parent
            spacing: 6
            MdIcon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: Catalog.glyph(0xF0450)
                size: 15
                color: area.containsMouse ? root.g.label : root.g.value
                transform: Scale {
                    origin.x: 7.5
                    xScale: -1
                }
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                text: "Reset page"
                color: area.containsMouse ? root.g.label : root.g.value
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetPage()
        }
    }
}
