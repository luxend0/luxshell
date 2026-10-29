import QtQuick
import qs.config
import qs.widgets

// Clickable glyph + short text of the island bar (bar menus and switches: Bluetooth, display,
// microphone, night light, power mode, caffeine). GlyphLabel for the look and the BarWidget
// contract, plus the pointer: the soft highlight of the media chip / notification status under
// it (Theme.menus.hit), left click = clicked, right click = rightClicked, wheel = wheeled(steps)
// only while wantsWheel (else the wheel falls through to the bar: volume / workspaces).
// Middle clicks fall through to the island (Settings.islandMiddleClick).
Item {
    id: root

    property string icon: ""
    property string text: ""
    property color color: Theme.text
    property bool wantsWheel: false
    property bool wantsRight: true

    // BarWidget contract
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null
    readonly property real wC: label.wC
    readonly property real wH: label.wH

    signal clicked
    signal rightClicked
    signal wheeled(int steps)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    readonly property QtObject m: Theme.menus
    readonly property QtObject wm: Theme.widgets

    Rectangle {
        id: highlight
        x: -root.m.hitPad
        width: root.width + 2 * root.m.hitPad
        height: root.wm.iconSize[0] + (root.wm.iconSize[1] - root.wm.iconSize[0]) * root.t + root.m.hitGrow
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: root.m.hit
        opacity: area.containsMouse && root.interactive ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeIn
            }
        }
    }

    GlyphLabel {
        id: label
        anchors.fill: parent
        icon: root.icon
        text: root.text
        color: root.color
        t: root.t
        textOpacity: root.textOpacity
        Behavior on color {
            ColorAnim {
                ms: Theme.fadeIn
            }
        }
    }

    // wheel notches; touchpads and hi-res wheels add up to whole ones
    property real wheelAcc: 0

    MouseArea {
        id: area
        anchors.fill: highlight
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.wantsRight ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: w => {
            if (!root.wantsWheel) {
                w.accepted = false;
                return;
            }
            root.wheelAcc += w.angleDelta.y;
            const steps = Math.trunc(root.wheelAcc / 120);
            if (steps !== 0) {
                root.wheelAcc -= steps * 120;
                root.wheeled(steps);
            }
        }
    }
}
