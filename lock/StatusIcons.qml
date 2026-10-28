import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.widgets

// Top right of ref/11: battery pill + Wi-Fi fan. Like the island (SPEC: no battery on this
// desktop) the battery only shows when UPower reports a laptop battery, otherwise the
// volume glyph takes its place. The fan lights by Net.bars (Ethernet = full, as the
// island's signal bars).
Row {
    id: root

    readonly property QtObject g: Theme.lock
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.ready && battery.isLaptopBattery
    readonly property real charge: {
        const p = battery?.percentage ?? 0;
        return Math.max(0, Math.min(1, p > 1 ? p / 100 : p));
    }

    spacing: g.statusGap
    height: Math.max(g.batteryHeight, g.wifiHeight)

    // ---- battery (laptops) -------------------------------------------------------------
    Item {
        visible: root.hasBattery
        width: root.g.batteryWidth + 4
        height: root.g.batteryHeight
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: body
            width: root.g.batteryWidth
            height: parent.height
            radius: 5.5
            color: Qt.rgba(1, 1, 1, 0.2)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.55)

            Rectangle {
                x: 1.5
                y: 1.5
                height: parent.height - 3
                width: Math.max(height, (parent.width - 3) * root.charge)
                radius: 4
                color: root.g.fg(0.95)
            }
        }
        Rectangle {
            x: body.width + 1.5
            anchors.verticalCenter: body.verticalCenter
            width: 2.5
            height: 6
            radius: 1.25
            color: Qt.rgba(1, 1, 1, 0.3)
        }
    }

    // ---- volume glyph instead (desktop) -------------------------------------------------
    Icon {
        visible: !root.hasBattery
        anchors.verticalCenter: parent.verticalCenter
        name: Audio.ready ? Audio.icon : "volume-2"
        size: root.g.volumeSize
        stroke: 2
        color: root.g.fg(0.92)
    }

    // ---- Wi-Fi fan: wedge + two arcs, lit by Net.bars -----------------------------------
    Shape {
        id: fan
        width: root.g.wifiWidth
        height: root.g.wifiHeight
        anchors.verticalCenter: parent.verticalCenter
        preferredRendererType: Shape.CurveRenderer

        readonly property real cx: width / 2
        readonly property real cy: height
        readonly property real sweep: 76
        readonly property real start: -90 - sweep / 2
        readonly property real stroke: 3
        readonly property int lit: Net.bars >= 4 ? 3 : Net.bars >= 2 ? 2 : Net.bars >= 1 ? 1 : 0
        function tone(level: int): color {
            return level <= lit ? root.g.fg(0.85) : Qt.rgba(1, 1, 1, 0.22);
        }

        ShapePath {
            strokeWidth: -1
            fillColor: fan.tone(1)
            startX: fan.cx
            startY: fan.cy
            PathAngleArc {
                centerX: fan.cx
                centerY: fan.cy
                radiusX: 7.5
                radiusY: 7.5
                startAngle: fan.start
                sweepAngle: fan.sweep
                moveToStart: false
            }
            PathLine {
                x: fan.cx
                y: fan.cy
            }
        }
        ShapePath {
            strokeWidth: fan.stroke
            strokeColor: fan.tone(2)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: fan.cx
                centerY: fan.cy
                radiusX: 10.75
                radiusY: 10.75
                startAngle: fan.start
                sweepAngle: fan.sweep
            }
        }
        ShapePath {
            strokeWidth: fan.stroke
            strokeColor: fan.tone(3)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: fan.cx
                centerY: fan.cy
                radiusX: 15.5
                radiusY: 15.5
                startAngle: fan.start
                sweepAngle: fan.sweep
            }
        }
    }
}
