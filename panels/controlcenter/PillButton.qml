import QtQuick
import qs.config
import qs.widgets

// Text pill ("Connect", "Clear"): raised grey, optional spinner while busy.
// Sheet rows use the larger variant (Theme.cc.sheet.pill*).
Rectangle {
    id: pill

    property string text
    property bool busy: false
    property bool primary: false
    property bool focusable: false   // standalone pills take keyboard focus, pills inside a row do not
    property int textSize: 14
    property int textWeight: Font.Medium
    property real padX: 15
    property color baseColor: Theme.cc.chipColor
    signal clicked

    implicitWidth: Math.round(row.implicitWidth + 2 * padX)
    width: implicitWidth
    height: 34
    radius: height / 2
    color: primary ? Theme.accent : area.containsMouse && !busy ? Theme.mix(baseColor, Theme.text, 0.08) : baseColor
    Behavior on color {
        ColorAnim {
            ms: Theme.fadeOut
        }
    }

    readonly property bool ccControl: focusable
    function key(k: int): bool {
        if (k !== Qt.Key_Space && k !== Qt.Key_Return && k !== Qt.Key_Enter)
            return false;
        if (!busy)
            clicked();
        return true;
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Glyph {
            id: spinner
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.busy
            name: "loader"
            size: 14
            color: Theme.textDim
            RotationAnimation on rotation {
                running: pill.busy && pill.visible
                from: 0
                to: 360
                duration: Motion.ms(900)
                loops: Animation.Infinite
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            font.family: Theme.fontFamily
            font.pixelSize: pill.textSize
            font.weight: pill.textWeight
            color: pill.primary ? Theme.onAccent : pill.busy ? Theme.textDim : Theme.text
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: !pill.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }

    FocusRing {
        gap: 2
    }
}
