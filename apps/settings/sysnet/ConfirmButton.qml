import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Small button for something that cannot be undone (forget a network, remove a device): the
// first click (or arm()) turns it into a red "<confirm>" pill for 4 s, the second one runs it.
// Like the settings rows' `confirm` buttons.
Rectangle {
    id: root

    readonly property QtObject g: Theme.settings
    property string glyph: Catalog.glyph(0xF0A7A) // md-trash-can-outline
    property string text: ""                      // idle label ("" = glyph only)
    property string confirm: "Forget"
    property bool active: true
    property bool armed: false
    property bool ring: false
    signal confirmed

    function arm(): void {
        if (armed) {
            armed = false;
            confirmed();
        } else {
            armed = true;
            disarm.restart();
        }
    }

    implicitWidth: armed ? label.implicitWidth + 28 : (text === "" ? g.miniButton : label.implicitWidth + 24)
    implicitHeight: g.miniButton
    width: implicitWidth
    height: implicitHeight
    radius: armed ? height / 2 : g.miniRadius
    color: armed ? g.danger : area.containsMouse && active ? Theme.mix(g.field, Theme.text, 0.1) : g.field
    opacity: active ? 1 : 0.35
    border.width: ring ? 2 : 0
    border.color: g.ring
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }
    Behavior on implicitWidth {
        Anim {
            ms: 160
        }
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = false
    }

    MdIcon {
        visible: !root.armed && root.text === ""
        anchors.centerIn: parent
        glyph: root.glyph
        size: 17
        color: area.containsMouse && root.active ? root.g.label : root.g.value
    }
    SText {
        id: label
        visible: root.armed || root.text !== ""
        anchors.centerIn: parent
        size: 14
        text: root.armed ? root.confirm : root.text
        color: root.armed ? "white" : root.g.label
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.arm()
    }
}
