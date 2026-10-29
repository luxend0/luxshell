import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Power & Idle: what the idle daemon does right now (services/Idle.describe()).
// While Caffeine is on: coffee glyph, the time left and "Turn off" (the idle stages wait
// for it); while a player plays and idleMediaPause is on: the player's name.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    property var opt: null
    readonly property bool caffeine: Settings.idleEnabled && Caffeine.active
    readonly property bool media: Idle.pausedBy === "media"

    implicitHeight: g.rowHeight

    SText {
        x: root.g.rowInset
        anchors.verticalCenter: parent.verticalCenter
        text: root.opt?.title ?? ""
    }
    Row {
        x: parent.width - root.g.rowInset - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        MdIcon {
            visible: root.caffeine || root.media
            anchors.verticalCenter: parent.verticalCenter
            glyph: Catalog.glyph(root.caffeine ? 0xF0176 : 0xF075A) // md-coffee | md-music
            size: 18
            color: root.g.label
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: Idle.describe()
            color: root.caffeine || root.media ? root.g.label : root.g.value
        }
        MiniButton {
            visible: root.caffeine
            anchors.verticalCenter: parent.verticalCenter
            text: "Turn off"
            onClicked: Caffeine.stop()
        }
    }
}
