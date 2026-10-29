import QtQuick
import qs.config
import qs.widgets
import qs.apps.settings

// Custom row content (Displays > Rotation): four small monitors, 0° / 90° / 180° / 270°
// (Hyprland transform 0..3). Each is drawn as it stands on the desk with the picture upright:
// the thick edge is the monitor's own bottom (its stand), so 90° has it on the left.
// A click asks "Keep?". Keys: Left/Right walk, Enter/Space takes it.
Item {
    id: root

    readonly property QtObject g: Theme.settings
    readonly property QtObject d: Theme.displays
    property var ctl: null
    property var opt: null
    property var row: null
    readonly property var v: ctl ? ctl.cur : null
    readonly property int current: v ? v.transform % 4 : 0
    readonly property bool active: row ? row.active : true
    property int cur: 0
    readonly property bool kb: row !== null && row.focused
    readonly property int cursor: kb ? cur : -1
    onKbChanged: if (kb)
        cur = current

    implicitHeight: d.rotationTile
    opacity: active ? 1 : 0.45

    function enter(dir: int): void {
        cur = current;
    }
    function adjust(dd: int): bool {
        const c = cur + dd;
        if (c < 0)
            return false;
        if (c < 4)
            cur = c;
        return true;
    }
    function activate(): bool {
        if (active && cur !== current)
            ctl.setTransform(cur);
        return true;
    }

    Row {
        spacing: root.d.rotationGap

        Repeater {
            model: 4

            Rectangle {
                id: tile
                required property int index
                readonly property bool on: index === root.current
                readonly property bool hot: area.containsMouse && root.active
                readonly property bool portrait: index % 2 === 1
                width: Math.round(root.d.rotationTile * 1.25)
                height: root.d.rotationTile
                radius: root.d.chipRadius
                color: on ? root.d.plate : hot ? Theme.mix(root.g.field, Theme.text, 0.06) : root.g.field
                border.width: root.cursor === index ? 2 : 0
                border.color: root.g.ring

                // the monitor: outline, picture upright, its stand edge thick
                Item {
                    id: mon
                    readonly property real w: tile.portrait ? 22 : 38
                    readonly property real h: tile.portrait ? 34 : 23
                    readonly property color ink: tile.on || tile.hot ? root.g.label : root.g.value
                    x: (tile.width - w) / 2
                    y: 11 + (34 - h) / 2
                    width: w
                    height: h

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "transparent"
                        border.width: 1.5
                        border.color: mon.ink
                    }
                    // stand edge: bottom (0°), left (90°), top (180°), right (270°)
                    Rectangle {
                        readonly property bool side: tile.portrait
                        width: side ? 4 : parent.width - 6
                        height: side ? parent.height - 6 : 4
                        radius: 2
                        x: !side ? 3 : tile.index === 1 ? 0 : parent.width - width
                        y: side ? 3 : tile.index === 0 ? parent.height - height : 0
                        color: mon.ink
                    }
                    // the picture's top: a short line, always up
                    Rectangle {
                        x: (parent.width - width) / 2
                        y: tile.index === 2 ? 9 : 5
                        width: Math.min(12, parent.width - 12)
                        height: 2
                        radius: 1
                        color: mon.ink
                        opacity: 0.6
                    }
                }

                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - height - 9
                    size: 13
                    text: `${tile.index * 90}°`
                    color: tile.on || tile.hot ? root.g.label : root.g.value
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.row) {
                            root.row.host.focusRoot();
                            root.row.host.focusRow(root.row.flatIndex);
                        }
                        root.cur = tile.index;
                        if (!tile.on)
                            root.ctl.setTransform(tile.index);
                    }
                }
            }
        }
    }
}
