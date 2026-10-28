import QtQuick
import qs.config

// Page header card (ref/12): icon disc, title, one-line description, centred.
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property var page: null

    width: g.cardWidth
    height: g.headerHeight
    radius: g.cardRadius
    color: g.card

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
}
