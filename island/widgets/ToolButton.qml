import QtQuick
import qs.config
import qs.core
import qs.services
import qs.widgets

// Tool buttons of the island, drawn like the gear (SystemButton: glyph with a hover disc,
// 16 px collapsed, 18 px hover):
//   screenshot   region (slurp); right click: the whole screen      (services/BarTools)
//   colorpicker  hyprpicker, the value is copied and shown           (services/BarTools)
//   launcher     opens the launcher on this screen
//   overview     opens the workspace overview on this screen
Item {
    id: root

    property string kind: "screenshot"
    property real t: 1
    property real textOpacity: 1
    property bool interactive: true
    property var screen: null

    readonly property QtObject h: Theme.hover
    readonly property QtObject wm: Theme.widgets
    readonly property real wC: wm.systemIconSize + 10
    readonly property real wH: h.systemIconSize + 10
    readonly property real size: wm.systemIconSize + (h.systemIconSize - wm.systemIconSize) * t
    readonly property string glyph: ({
            "screenshot": "camera",
            "colorpicker": "pipette",
            "launcher": "search",
            "overview": "layout-dashboard"
        })[kind] ?? "circle-dot"

    implicitWidth: size + 10
    implicitHeight: size + 10

    function screenName(): var {
        return root.screen ? root.screen.name : undefined;
    }
    function run(button: int): void {
        switch (kind) {
        case "screenshot":
            BarTools.screenshot(button === Qt.RightButton ? "screen" : "region");
            break;
        case "colorpicker":
            BarTools.pickColor();
            break;
        case "launcher":
            Ui.toggle("launcher", screenName());
            break;
        case "overview":
            Ui.toggle("overview", screenName());
            break;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.surfaceHigh
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity {
            Anim {
                ms: Theme.fadeOut
            }
        }
    }
    WIcon {
        anchors.centerIn: parent
        name: root.glyph
        size: root.size
        color: Theme.text
        opacity: area.containsMouse ? 1 : 0.6
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => root.run(e.button)
    }
}
